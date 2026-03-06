import { error } from "@sveltejs/kit";
import type { PageServerLoad } from "./$types";

export const load: PageServerLoad = async ({ parent }) => {
  const { permissions } = await parent();
  const canRead = permissions.some(
    (p: { resource: string; action: string }) =>
      p.resource === "support_tickets" && p.action === "read"
  );

  if (!canRead) {
    throw error(403, "You do not have permission to access this page.");
  }
};
