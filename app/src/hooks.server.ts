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

  const [{ data: { session } }, { data: { user } }] = await Promise.all([
    event.locals.supabase.auth.getSession(),
    event.locals.supabase.auth.getUser(),
  ]);

  event.locals.session = session;
  event.locals.user = user;

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