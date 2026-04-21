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
  const { payload } = await jwtVerify<SupabaseClaims>(raw, jwtSecret, {
    issuer,
    algorithms: ["HS256"],
    requiredClaims: ["sub", "exp"],
  });
  return {
    userId: payload.sub!,
    jwt: raw,
    clientId: payload.client_id ?? null,
    expiresAt: (payload.exp ?? 0) * 1000,
  };
}

export { issuer as supabaseAuthIssuer };
