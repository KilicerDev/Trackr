#!/usr/bin/env node
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { buildClient } from "./supabase.js";
import { registerTools } from "./tools.js";

async function main() {
  const db = await buildClient();
  const server = new McpServer({
    name: "trackr",
    version: "0.1.0",
  });
  registerTools(server, db);

  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch((error) => {
  console.error("[trackr-mcp] fatal:", error);
  process.exit(1);
});
