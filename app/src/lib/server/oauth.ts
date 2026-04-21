import { timingSafeEqual } from "node:crypto";
import { env } from "$env/dynamic/private";
import { sha256 } from "./ical";

/**
 * OAuth 2.1 + PKCE + DCR primitives shared by the /oauth/* endpoints.
 * All secrets leave this module as plaintext exactly once (HTTP response);
 * database storage is always the sha256 hex hash.
 */

const CLIENT_ID_PREFIX = "cli_";
const ACCESS_TOKEN_PREFIX = "mcp_at_";

export const SUPPORTED_SCOPES = ["mcp"] as const;
export type Scope = (typeof SUPPORTED_SCOPES)[number];

export const CODE_TTL_SEC = 300; // 5 minutes
export const ACCESS_TOKEN_TTL_SEC = 3600; // 1 hour

function randomBase64Url(byteLen: number): string {
  const bytes = new Uint8Array(byteLen);
  crypto.getRandomValues(bytes);
  return Buffer.from(bytes).toString("base64url");
}

export function generateClientId(): string {
  return `${CLIENT_ID_PREFIX}${randomBase64Url(24)}`;
}

export function generateAuthorizationCode(): string {
  return randomBase64Url(32);
}

export function generateAccessToken(): string {
  return `${ACCESS_TOKEN_PREFIX}${randomBase64Url(32)}`;
}

export const hash = sha256;

/**
 * Public resource URL the MCP server is reachable at.
 * Configurable via MCP_RESOURCE_URL; falls back to a sensible default derived
 * from the app's public URL.
 */
export function mcpResourceUrl(): string {
  const override = env.MCP_RESOURCE_URL;
  if (override) return override.replace(/\/$/, "") + "/";
  const site = env.SITE_URL ?? "";
  const u = new URL(site || "https://example.com");
  u.hostname = u.hostname.replace(/^trackr\./, "mcp.trackr.").replace(/^(?!mcp\.)/, "mcp.");
  return u.toString().replace(/\/$/, "") + "/";
}

export function issuerUrl(fallback?: string): string {
  const site = env.SITE_URL ?? fallback;
  if (!site) throw new Error("SITE_URL not set and no fallback provided");
  return site.replace(/\/$/, "");
}

/**
 * Redirect URI allow-list per OAuth 2.1 + RFC 8252.
 * - https: required for web clients
 * - http://localhost | 127.0.0.1 | [::1] allowed for native / CLI redirectors
 * - custom schemes with a dot (e.g. com.example.app) allowed for native apps
 * - explicit denylist for dangerous schemes
 */
export function isAllowedRedirectUri(raw: string): boolean {
  let u: URL;
  try {
    u = new URL(raw);
  } catch {
    return false;
  }
  const scheme = u.protocol.replace(/:$/, "").toLowerCase();
  if (["javascript", "data", "file", "vbscript"].includes(scheme)) return false;
  if (scheme === "https") return true;
  if (scheme === "http") {
    const host = u.hostname.toLowerCase();
    return host === "localhost" || host === "127.0.0.1" || host === "[::1]" || host === "::1";
  }
  // Native-app custom scheme per RFC 8252 §7.1 — must be dotted reverse-DNS style
  // or a simple app scheme like "claude-desktop:". Be conservative: require the
  // scheme to not contain special chars and to not be in a known-bad list.
  if (!/^[a-z][a-z0-9+\-.]*$/.test(scheme)) return false;
  return true;
}

/** Strict exact-match helper — no normalization, no path prefixing. */
export function redirectUriMatches(requested: string, registered: string[]): boolean {
  return registered.some((u) => u === requested);
}

/**
 * Verify an RFC 7636 PKCE code_verifier against the stored code_challenge.
 * code_challenge = base64url(SHA256(code_verifier))
 */
export async function verifyPkce(codeVerifier: string, storedChallenge: string): Promise<boolean> {
  if (!codeVerifier || codeVerifier.length < 43 || codeVerifier.length > 128) return false;
  if (!/^[A-Za-z0-9\-._~]+$/.test(codeVerifier)) return false;
  const encoded = new TextEncoder().encode(codeVerifier);
  const buf = await crypto.subtle.digest("SHA-256", encoded);
  const computed = Buffer.from(buf).toString("base64url");
  const a = Buffer.from(computed);
  const b = Buffer.from(storedChallenge);
  if (a.length !== b.length) return false;
  return timingSafeEqual(a, b);
}

/** Discovery metadata (RFC 8414) — now also advertising RFC 9207 `iss` param. */
export function authorizationServerMetadata(fallbackIssuer?: string) {
  const issuer = issuerUrl(fallbackIssuer);
  return {
    issuer,
    authorization_endpoint: `${issuer}/oauth/authorize`,
    token_endpoint: `${issuer}/oauth/token`,
    registration_endpoint: `${issuer}/oauth/register`,
    revocation_endpoint: `${issuer}/oauth/revoke`,
    response_types_supported: ["code"],
    grant_types_supported: ["authorization_code"],
    code_challenge_methods_supported: ["S256"],
    token_endpoint_auth_methods_supported: ["none"],
    scopes_supported: [...SUPPORTED_SCOPES],
    authorization_response_iss_parameter_supported: true,
  };
}

/**
 * Trivial in-memory IP rate limiter. Good enough for /oauth/register and
 * /oauth/token defense-in-depth; when the app runs multi-replica, move to a
 * shared store. Returns true if the request is allowed.
 */
type BucketKey = string;
type Bucket = { count: number; resetAt: number };
const buckets = new Map<BucketKey, Bucket>();

export function rateLimit(key: string, max: number, windowMs: number): boolean {
  const now = Date.now();
  const existing = buckets.get(key);
  if (!existing || existing.resetAt <= now) {
    buckets.set(key, { count: 1, resetAt: now + windowMs });
    return true;
  }
  existing.count += 1;
  return existing.count <= max;
}
