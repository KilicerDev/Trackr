-- OAuth 2.1 with DCR + PKCE so Claude.ai Connectors (and any other MCP-Authorization-
-- spec-compliant client) can register themselves and obtain per-user access tokens
-- to reach the MCP server. All secrets stored as sha256 hex hashes.

CREATE TABLE public.oauth_clients (
  id                         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id                  text NOT NULL UNIQUE,
  client_name                text NOT NULL CHECK (char_length(client_name) BETWEEN 1 AND 120),
  redirect_uris              text[] NOT NULL CHECK (array_length(redirect_uris, 1) BETWEEN 1 AND 10),
  grant_types                text[] NOT NULL DEFAULT ARRAY['authorization_code'],
  response_types             text[] NOT NULL DEFAULT ARRAY['code'],
  token_endpoint_auth_method text NOT NULL DEFAULT 'none'
                             CHECK (token_endpoint_auth_method = 'none'),
  software_id                text,
  software_version           text,
  logo_uri                   text,
  policy_uri                 text,
  tos_uri                    text,
  created_at                 timestamptz NOT NULL DEFAULT now(),
  last_used_at               timestamptz,
  revoked_at                 timestamptz
);

CREATE TABLE public.oauth_authorization_codes (
  code_hash              text PRIMARY KEY,
  client_id              text NOT NULL REFERENCES public.oauth_clients(client_id) ON DELETE CASCADE,
  user_id                uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  redirect_uri           text NOT NULL,
  code_challenge         text NOT NULL,
  code_challenge_method  text NOT NULL CHECK (code_challenge_method = 'S256'),
  scope                  text[] NOT NULL DEFAULT ARRAY['mcp'],
  resource               text,
  created_at             timestamptz NOT NULL DEFAULT now(),
  expires_at             timestamptz NOT NULL,
  used_at                timestamptz
);

CREATE TABLE public.oauth_access_tokens (
  token_hash     text PRIMARY KEY,
  client_id      text NOT NULL REFERENCES public.oauth_clients(client_id) ON DELETE CASCADE,
  user_id        uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  authz_code_hash text REFERENCES public.oauth_authorization_codes(code_hash) ON DELETE SET NULL,
  scope          text[] NOT NULL,
  resource       text,
  created_at     timestamptz NOT NULL DEFAULT now(),
  expires_at     timestamptz NOT NULL,
  revoked_at     timestamptz,
  last_used_at   timestamptz
);

CREATE TABLE public.oauth_consents (
  user_id      uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  client_id    text NOT NULL REFERENCES public.oauth_clients(client_id) ON DELETE CASCADE,
  scope        text[] NOT NULL,
  approved_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, client_id)
);

CREATE INDEX idx_oauth_access_tokens_user ON public.oauth_access_tokens(user_id)
  WHERE revoked_at IS NULL;
CREATE INDEX idx_oauth_authz_codes_expiry ON public.oauth_authorization_codes(expires_at)
  WHERE used_at IS NULL;

-- RLS: everything is server-role only. Only client metadata (name, logo) needs to be
-- readable for the consent screen, and that's loaded via the admin client anyway.
ALTER TABLE public.oauth_clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.oauth_authorization_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.oauth_access_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.oauth_consents ENABLE ROW LEVEL SECURITY;

-- Users can see which clients they have consented to, for the "Connected Apps" UI.
CREATE POLICY oauth_consents_self ON public.oauth_consents
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY oauth_consents_self_delete ON public.oauth_consents
  FOR DELETE USING (user_id = auth.uid());

-- Users can see their own issued tokens (for the revoke UI).
CREATE POLICY oauth_access_tokens_self ON public.oauth_access_tokens
  FOR SELECT USING (user_id = auth.uid());

-- Users can see client metadata for clients they have consented to.
CREATE POLICY oauth_clients_via_consent ON public.oauth_clients
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.oauth_consents c
      WHERE c.client_id = oauth_clients.client_id AND c.user_id = auth.uid()
    )
  );
