import { sequence } from "@sveltejs/kit/hooks";
import { redirect, type Handle } from "@sveltejs/kit";
import { getTextDirection } from "$lib/paraglide/runtime";
import { paraglideMiddleware } from "$lib/paraglide/server";
import { createServerClient } from "@supabase/ssr";
import {
  PUBLIC_SUPABASE_URL,
  PUBLIC_SUPABASE_ANON_KEY,
} from "$env/static/public";
import { env } from "$env/dynamic/private";
import { isSetupComplete } from "$lib/server/setup-check";
import { getAdminClient } from "$lib/server/supabase-admin";

const handleSetup: Handle = async ({ event, resolve }) => {
  const path = event.url.pathname;

  if (path === "/setup" || path.startsWith("/_app/") || path.startsWith("/favicon")) {
    return resolve(event);
  }

  const done = await isSetupComplete();
  if (!done) {
    redirect(303, "/setup");
  }

  return resolve(event);
};

const handleSupabase: Handle = async ({ event, resolve }) => {
  // iCal feed uses token-based auth, skip session/cookie handling entirely.
  // Note: /api/ical/token still needs session auth so we only skip the exact path.
  if (event.url.pathname === "/api/ical") {
    return resolve(event);
  }

  const internalUrl = env.SUPABASE_URL;

  event.locals.supabase = createServerClient(
    PUBLIC_SUPABASE_URL,
    PUBLIC_SUPABASE_ANON_KEY,
    {
      cookies: {
        getAll: () => event.cookies.getAll(),
        setAll: (cookies) => {
          cookies.forEach(({ name, value, options }) => {
            event.cookies.set(name, value, {
              ...options,
              path: "/",
            });
          });
        },
      },
      ...(internalUrl && internalUrl !== PUBLIC_SUPABASE_URL
        ? {
            global: {
              fetch: (input, init) => {
                const url = typeof input === "string" ? input : input instanceof URL ? input.toString() : input.url;
                const rewritten = url.replace(PUBLIC_SUPABASE_URL, internalUrl);
                return fetch(rewritten, init);
              },
            },
          }
        : {}),
    }
  );

  const { data: { user } } = await event.locals.supabase.auth.getUser();

  event.locals.session = user ? { user } : null;
  event.locals.user = user;

  // Kick out inactive users (uses admin client to avoid session-based warnings)
  if (user) {
    const adminClient = getAdminClient();
    const { data: dbUser } = await adminClient
      .from("users")
      .select("is_active")
      .eq("id", user.id)
      .single();

    if (dbUser && !dbUser.is_active) {
      await event.locals.supabase.auth.signOut();
      event.locals.session = null;
      event.locals.user = null;
    }
  }

  return resolve(event, {
    filterSerializedResponseHeaders(name) {
      return (
        name === "content-range" ||
        name === "x-supabase-api-version"
      );
    },
  });
};

const handleParaglide: Handle = ({ event, resolve }) =>
  paraglideMiddleware(event.request, ({ request, locale }) => {
    event.request = request;

    return resolve(event, {
      transformPageChunk: ({ html }) =>
        html
          .replace("%paraglide.lang%", locale)
          .replace("%paraglide.dir%", getTextDirection(locale)),
    });
  });

export const handle = sequence(handleParaglide, handleSetup, handleSupabase);