-- Supersede the hand-rolled OAuth 2.1 + API-key tables: Supabase's built-in
-- OAuth 2.1 Server now issues the tokens the MCP server validates via JWKS.
drop table if exists public.oauth_access_tokens cascade;
drop table if exists public.oauth_authorization_codes cascade;
drop table if exists public.oauth_consents cascade;
drop table if exists public.oauth_clients cascade;
drop table if exists public.api_keys cascade;
