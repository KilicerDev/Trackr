import { SignJWT } from "jose";
import { env } from "$env/dynamic/private";

const PLAINTEXT_PREFIX = "trk_";

function secretKey(): Uint8Array {
  const secret = env.JWT_SECRET;
  if (!secret) throw new Error("JWT_SECRET is not set");
  return new TextEncoder().encode(secret);
}

export function generateApiKeyPlaintext(): { plaintext: string; prefix: string } {
  const bytes = new Uint8Array(24);
  crypto.getRandomValues(bytes);
  const body = Buffer.from(bytes).toString("base64url");
  const plaintext = `${PLAINTEXT_PREFIX}${body}`;
  return { plaintext, prefix: plaintext.slice(0, 12) };
}

export async function signSupabaseJwt(
  userId: string,
  ttlSec = 3600
): Promise<{ token: string; expiresIn: number }> {
  const token = await new SignJWT({ role: "authenticated" })
    .setProtectedHeader({ alg: "HS256" })
    .setSubject(userId)
    .setAudience("authenticated")
    .setIssuedAt()
    .setExpirationTime(`${ttlSec}s`)
    .sign(secretKey());
  return { token, expiresIn: ttlSec };
}
