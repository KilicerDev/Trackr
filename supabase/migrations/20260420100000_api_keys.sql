-- API keys: user-generated long-lived tokens for programmatic access (MCP server, public API).
-- Stored as SHA-256 hashes; plaintext is shown once at creation time.
-- The POST /api/auth/exchange endpoint trades an API key for a short-lived Supabase JWT.

CREATE TABLE public.api_keys (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  name           text NOT NULL,
  key_hash       text NOT NULL,
  prefix         text NOT NULL,
  scopes         text[] NOT NULL DEFAULT ARRAY['mcp'],
  expires_at     timestamptz,
  last_used_at   timestamptz,
  created_at     timestamptz NOT NULL DEFAULT now(),
  revoked_at     timestamptz
);

CREATE INDEX idx_api_keys_hash ON public.api_keys (key_hash) WHERE revoked_at IS NULL;
CREATE INDEX idx_api_keys_user ON public.api_keys (user_id);

ALTER TABLE public.api_keys ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own api keys"
  ON public.api_keys FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Users can insert own api keys"
  ON public.api_keys FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update own api keys"
  ON public.api_keys FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can delete own api keys"
  ON public.api_keys FOR DELETE
  USING (user_id = auth.uid());
