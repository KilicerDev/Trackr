#!/usr/bin/env node
import express, { type Request, type Response } from "express";
import { randomUUID } from "node:crypto";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import { supabaseAuthIssuer, validateToken, type ValidatedAuth } from "./auth.js";
import { buildClient } from "./supabase.js";
import { registerTools } from "./tools.js";

function createServerForJwt(jwt: string, userId: string): McpServer {
  const db = buildClient(jwt);
  const server = new McpServer({ name: "trackr", version: "0.2.0" });
  registerTools(server, db, userId);
  return server;
}

async function runStdio(): Promise<void> {
  const jwt = process.env.TRACKR_JWT;
  if (!jwt) throw new Error("TRACKR_JWT required in stdio mode");
  const auth = await validateToken(jwt);
  const server = createServerForJwt(auth.jwt, auth.userId);
  await server.connect(new StdioServerTransport());
}

function mcpOrigin(): string {
  const resource = (process.env.MCP_RESOURCE_URL ?? "").replace(/\/$/, "");
  if (!resource) return "";
  try {
    return new URL(resource).origin;
  } catch {
    return "";
  }
}

function resourceMetadata() {
  const resource = (process.env.MCP_RESOURCE_URL ?? "").replace(/\/$/, "");
  // Point clients at this MCP server as the authorization server so they
  // fetch our hand-rolled AS metadata (with absolute URLs) instead of
  // GoTrue's self-served document, which currently returns an empty issuer
  // and relative endpoint paths that MCP clients can't resolve.
  const origin = mcpOrigin();
  return {
    resource: resource || "",
    authorization_servers: [origin || supabaseAuthIssuer],
    scopes_supported: ["mcp"],
    bearer_methods_supported: ["header"],
  };
}

function authorizationServerMetadata() {
  const origin = mcpOrigin();
  const asBase = supabaseAuthIssuer;
  return {
    issuer: origin,
    authorization_endpoint: `${asBase}/oauth/authorize`,
    token_endpoint: `${asBase}/oauth/token`,
    registration_endpoint: `${asBase}/oauth/clients/register`,
    revocation_endpoint: `${asBase}/oauth/revoke`,
    response_types_supported: ["code"],
    grant_types_supported: ["authorization_code", "refresh_token"],
    code_challenge_methods_supported: ["S256"],
    token_endpoint_auth_methods_supported: [
      "client_secret_basic",
      "client_secret_post",
      "none",
    ],
    scopes_supported: ["mcp"],
  };
}

function wwwAuthenticateHeader(): string {
  const resource = (process.env.MCP_RESOURCE_URL ?? "").replace(/\/$/, "");
  // RFC 9728 §3.1: insert /.well-known/oauth-protected-resource between host and path.
  let metaUrl: string;
  if (resource) {
    try {
      const u = new URL(resource);
      metaUrl = `${u.origin}/.well-known/oauth-protected-resource${u.pathname || ""}`;
    } catch {
      metaUrl = `${resource}/.well-known/oauth-protected-resource`;
    }
  } else {
    metaUrl = "/.well-known/oauth-protected-resource";
  }
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

  const serveProtectedResource = (req: Request, res: Response) => {
    console.error(`[trackr-mcp] ${req.method} ${req.originalUrl} -> resource-metadata`);
    res.set("Cache-Control", "public, max-age=3600");
    res.json(resourceMetadata());
  };
  // Serve at both the RFC 9728 path (with resource pathname suffix) and the
  // bare well-known so naïve clients that don't preserve the suffix also work.
  app.get("/.well-known/oauth-protected-resource", serveProtectedResource);
  app.get("/.well-known/oauth-protected-resource/*", serveProtectedResource);

  const serveAuthorizationServer = (req: Request, res: Response) => {
    console.error(`[trackr-mcp] ${req.method} ${req.originalUrl} -> as-metadata`);
    res.set("Cache-Control", "public, max-age=3600");
    res.json(authorizationServerMetadata());
  };
  app.get("/.well-known/oauth-authorization-server", serveAuthorizationServer);
  app.get("/.well-known/oauth-authorization-server/*", serveAuthorizationServer);

  type SessionEntry = { server: McpServer; transport: StreamableHTTPServerTransport; auth: ValidatedAuth };
  const sessions = new Map<string, SessionEntry>();

  async function handleMcp(req: Request, res: Response): Promise<void> {
    const sessionId = req.header("mcp-session-id") ?? undefined;
    const hasAuthz = Boolean(req.header("authorization"));
    console.error(
      `[trackr-mcp] ${req.method} ${req.originalUrl} authz=${hasAuthz} session=${sessionId ?? "-"}`
    );
    let entry = sessionId ? sessions.get(sessionId) : undefined;

    if (!entry) {
      const authz = req.header("authorization") ?? "";
      const m = authz.match(/^Bearer\s+(.+)$/);
      if (!m) {
        console.error(`[trackr-mcp] 401 no-bearer`);
        res.set("WWW-Authenticate", wwwAuthenticateHeader());
        res.status(401).json({ error: "Missing Bearer token" });
        return;
      }
      const bearer = m[1];

      let auth: ValidatedAuth;
      try {
        auth = await validateToken(bearer);
      } catch (e) {
        console.error(`[trackr-mcp] 401 invalid-token: ${(e as Error).message}`);
        res.set("WWW-Authenticate", `${wwwAuthenticateHeader()}, error="invalid_token"`);
        res.status(401).json({ error: (e as Error).message });
        return;
      }

      const server = createServerForJwt(auth.jwt, auth.userId);

      const newId = randomUUID();
      const transport = new StreamableHTTPServerTransport({
        sessionIdGenerator: () => newId,
        onsessionclosed: () => {
          console.error(`[trackr-mcp] session closed: ${newId}`);
          sessions.delete(newId);
        },
      });
      await server.connect(transport);
      entry = { server, transport, auth };
      sessions.set(newId, entry);
      console.error(
        `[trackr-mcp] session opened: ${newId} user=${auth.userId} client=${auth.clientId ?? "-"}`
      );
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
