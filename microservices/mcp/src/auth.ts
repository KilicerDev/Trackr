import { jwtVerify, type JWTPayload } from "jose";

function required(name: string): string {
  const v = process.env[name];
  if (!v) throw new Error(`Missing required env var: ${name}`);
  return v;
}

const supabaseUrl = required("SUPABASE_URL").replace(/\/$/, "");
const issuer = `${supabaseUrl}/auth/v1`;
const jwtSecret = new TextEncoder().encode(required("JWT_SECRET"));

export type ValidatedAuth = {
  userId: string;
  jwt: string;
  clientId: string | null;
  expiresAt: number;
};

type SupabaseClaims = JWTPayload & {
  client_id?: string;
  role?: string;
};

export async function validateToken(raw: string): Promise<ValidatedAuth> {
  // Supabase Auth's OAuth 2.1 Server issues access tokens without an "iss"
  // claim, unlike its regular session JWTs. Don't require the claim, but if
  // it is present, it must match the expected GoTrue issuer.
  const { payload } = await jwtVerify<SupabaseClaims>(raw, jwtSecret, {
    algorithms: ["HS256"],
    requiredClaims: ["sub", "exp"],
  });
  if (payload.iss && payload.iss !== issuer) {
    throw new Error(`unexpected iss claim: ${payload.iss}`);
  }
  return {
    userId: payload.sub!,
    jwt: raw,
    clientId: payload.client_id ?? null,
    expiresAt: (payload.exp ?? 0) * 1000,
  };
}

export { issuer as supabaseAuthIssuer };
