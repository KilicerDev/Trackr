import { getAdminClient } from "./supabase-admin";

let setupComplete: boolean | null = null;
let cachedPlatformOrgId: string | null = null;

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
      cachedPlatformOrgId = data.platform_organization_id;
      return true;
    }
  } catch {
    // DB not ready yet or no system_config row
  }

  return false;
}

export function getPlatformOrgId(): string | null {
  return cachedPlatformOrgId;
}

export function invalidateSetupCache() {
  setupComplete = null;
  cachedPlatformOrgId = null;
}
