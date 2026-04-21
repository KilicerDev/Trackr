import adapter from '@sveltejs/adapter-node';

/** @type {import('@sveltejs/kit').Config} */
const config = {
	kit: {
		adapter: adapter(),
		// RFC 6749 requires /oauth/token to accept cross-origin
		// x-www-form-urlencoded POSTs from OAuth clients (Claude.ai, other
		// MCP hosts). SvelteKit's default origin CSRF guard rejects those,
		// and trustedOrigins can't help because server-to-server clients
		// typically send no Origin header — which the guard also blocks.
		// Session cookies default to SameSite=Lax, so browser-CSRF on form
		// actions is still blocked at the cookie layer; the OAuth consent
		// flow has its own anti-CSRF cookie token.
		csrf: {
			checkOrigin: false
		}
	}
};

export default config;
