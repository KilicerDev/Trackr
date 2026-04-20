export type ApiKey = {
  id: string;
  name: string;
  prefix: string;
  scopes: string[];
  expires_at: string | null;
  last_used_at: string | null;
  created_at: string;
  revoked_at: string | null;
};

export type CreateApiKeyResponse = {
  key: ApiKey;
  plaintext: string;
};

export const keys = {
  /** List the current user's API keys. */
  async list(): Promise<ApiKey[]> {
    const res = await fetch("/api/auth/keys");
    if (!res.ok) throw new Error("Failed to load API keys");
    const data = await res.json();
    return data.keys;
  },

  /**
   * Create a new API key. Returns the plaintext exactly once.
   * Pass `expiresInDays = null` for a key that never expires.
   */
  async create(
    name: string,
    expiresInDays: 7 | 30 | 90 | 365 | null
  ): Promise<CreateApiKeyResponse> {
    const res = await fetch("/api/auth/keys", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ name, expires_in_days: expiresInDays }),
    });
    if (!res.ok) {
      const text = await res.text().catch(() => "");
      throw new Error(text || "Failed to create API key");
    }
    return res.json();
  },

  /** Revoke an API key. */
  async revoke(id: string): Promise<void> {
    const res = await fetch(`/api/auth/keys/${id}`, { method: "DELETE" });
    if (!res.ok) throw new Error("Failed to revoke API key");
  },
};
