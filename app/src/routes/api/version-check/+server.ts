import { json } from "@sveltejs/kit";
import type { RequestHandler } from "./$types";

const VERSION_URL = "https://trackr.dev/api/version";

export const GET: RequestHandler = async ({ locals }) => {
  if (!locals.session) return json(null, { status: 401 });

  try {
    const res = await fetch(`${VERSION_URL}?t=${Date.now()}`);
    if (!res.ok) return json(null, { status: 502 });
    const data = await res.json();
    return json(data);
  } catch {
    return json(null, { status: 502 });
  }
};
