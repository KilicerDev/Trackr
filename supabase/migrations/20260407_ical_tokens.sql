-- iCal feed tokens: per-user secret tokens for calendar subscription URLs
-- Tokens are SHA-256 hashed before storage; plaintext is shown once at generation time.

CREATE TABLE public.ical_tokens (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  token_hash   text NOT NULL,
  label        text NOT NULL DEFAULT 'Default',
  last_used_at timestamptz,
  created_at   timestamptz NOT NULL DEFAULT now(),
  revoked_at   timestamptz,

  CONSTRAINT ical_tokens_one_per_user UNIQUE (user_id)
);

-- Fast lookup of active tokens by hash
CREATE INDEX idx_ical_tokens_hash ON public.ical_tokens (token_hash) WHERE revoked_at IS NULL;
CREATE INDEX idx_ical_tokens_user ON public.ical_tokens (user_id);

ALTER TABLE public.ical_tokens ENABLE ROW LEVEL SECURITY;

-- Users can only read/manage their own tokens
CREATE POLICY "Users can view own ical tokens"
  ON public.ical_tokens FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Users can insert own ical tokens"
  ON public.ical_tokens FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can delete own ical tokens"
  ON public.ical_tokens FOR DELETE
  USING (user_id = auth.uid());

CREATE POLICY "Users can update own ical tokens"
  ON public.ical_tokens FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());
