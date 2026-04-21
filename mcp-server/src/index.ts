#!/usr/bin/env node
import express, { type Request, type Response } from "express";
import { randomUUID } from "node:crypto";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import { buildClient, exchangeApiKey } from "./supabase.js";
import { registerTools } from "./tools.js";

async function createServerForApiKey(apiKey: string): Promise<McpServer> {
  const auth = await exchangeApiKey(apiKey);
  const db = buildClient(apiKey, auth);
  const server = new McpServer({ name: "trackr", version: "0.2.0" });
  registerTools(server, db, auth.userId);
  return server;
}

async function runStdio(): Promise<void> {
  const apiKey = process.env.TRACKR_API_KEY;
  if (!apiKey) throw new Error("TRACKR_API_KEY required in stdio mode");
  const server = await createServerForApiKey(apiKey);
  await server.connect(new StdioServerTransport());
}

function resourceMetadata() {
  const resource = (process.env.MCP_RESOURCE_URL ?? "").replace(/\/$/, "") + "/";
  const authServer = (process.env.TRACKR_URL ?? "").replace(/\/$/, "");
  return {
    resource,
    authorization_servers: authServer ? [authServer] : [],
    scopes_supported: ["mcp"],
    bearer_methods_supported: ["header"],
  };
}

function wwwAuthenticateHeader(): string {
  const resource = (process.env.MCP_RESOURCE_URL ?? "").replace(/\/$/, "");
  const metaUrl = resource
    ? `${resource}/.well-known/oauth-protected-resource`
    : `/.well-known/oauth-protected-resource`;
  return `Bearer realm="trackr", resource_metadata="${metaUrl}"`;
}

async function runHttp(): Promise<void> {
  const port = Number(process.env.PORT ?? 3100);
  const app = express();
  app.set("trust proxy", 1);
  app.use(express.json({ limit: "4mb" }));

  app.get("/health", (_req, res) => {
    res.json({ ok: true });
  });

  app.get("/.well-known/oauth-protected-resource", (_req, res) => {
    res.set("Cache-Control", "public, max-age=3600");
    res.json(resourceMetadata());
  });

  type SessionEntry = { server: McpServer; transport: StreamableHTTPServerTransport };
  const sessions = new Map<string, SessionEntry>();

  async function handleMcp(req: Request, res: Response): Promise<void> {
    const sessionId = req.header("mcp-session-id") ?? undefined;
    let entry = sessionId ? sessions.get(sessionId) : undefined;

    if (!entry) {
      const authz = req.header("authorization") ?? "";
      const m = authz.match(/^Bearer\s+(.+)$/);
      if (!m) {
        res.set("WWW-Authenticate", wwwAuthenticateHeader());
        res.status(401).json({ error: "Missing Bearer token" });
        return;
      }
      const bearer = m[1];

      let server: McpServer;
      try {
        server = await createServerForApiKey(bearer);
      } catch (e) {
        res.set("WWW-Authenticate", wwwAuthenticateHeader());
        res.status(401).json({ error: (e as Error).message });
        return;
      }

      const newId = randomUUID();
      const transport = new StreamableHTTPServerTransport({
        sessionIdGenerator: () => newId,
        onsessionclosed: () => {
          sessions.delete(newId);
        },
      });
      await server.connect(transport);
      entry = { server, transport };
      sessions.set(newId, entry);
    }

    await entry.transport.handleRequest(req, res, req.body);
  }

  app.post("/mcp", handleMcp);
  app.get("/mcp", handleMcp);
  app.delete("/mcp", handleMcp);

  app.listen(port, () => {
    console.error(`[trackr-mcp] http listening on :${port}`);
  });
}

const mode = process.env.MCP_TRANSPORT ?? "stdio";
(mode === "http" ? runHttp() : runStdio()).catch((error) => {
  console.error("[trackr-mcp] fatal:", error);
  process.exit(1);
});
