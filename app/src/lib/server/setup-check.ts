import { getAdminClient } from "./supabase-admin";

let setupComplete: boolean | null = null;

export async function isSetupComplete(): Promise<boolean> {
  if (setupComplete === true) return true;

  try {
    const admin = getAdminClient();
    const { data } = await admin
      .from("system_config")
      .select("platform_organization_id")
      .limit(1)
      .single();

    if (data?.platform_organization_id) {
      setupComplete = true;
      return true;
    }
  } catch {
    // DB not ready yet or no system_config row
  }

  return false;
}

export function invalidateSetupCache() {
  setupComplete = null;
}
