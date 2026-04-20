import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname } from "node:path";
import { homedir } from "node:os";
import { join } from "node:path";

export function sessionFilePath(): string {
  const base =
    process.env.TRACKR_MCP_STATE_DIR ??
    join(homedir(), ".config", "trackr-mcp");
  return join(base, "session.json");
}

type Entry = { value: string };

export function createFileStorage() {
  const path = sessionFilePath();
  let cache: Record<string, Entry> = {};

  if (existsSync(path)) {
    try {
      cache = JSON.parse(readFileSync(path, "utf8"));
    } catch {
      cache = {};
    }
  }

  const flush = () => {
    mkdirSync(dirname(path), { recursive: true });
    writeFileSync(path, JSON.stringify(cache, null, 2), { mode: 0o600 });
  };

  return {
    getItem: async (key: string) => cache[key]?.value ?? null,
    setItem: async (key: string, value: string) => {
      cache[key] = { value };
      flush();
    },
    removeItem: async (key: string) => {
      delete cache[key];
      flush();
    },
  };
}
