import { api } from "$lib/api";
import type { Organization } from "$lib/api/organizations";

type PlatformOrg = { id: string; name: string; slug: string };

class OrganizationStore {
  clientOrgs = $state<Organization[]>([]);
  platformOrg = $state<PlatformOrg | null>(null);
  loaded = $state(false);

  get all(): Organization[] {
    if (!this.platformOrg) return this.clientOrgs;
    return [
      {
        id: this.platformOrg.id,
        name: this.platformOrg.name,
        slug: this.platformOrg.slug,
        domain: null,
        logo_url: null,
        website_url: null,
        notes: null,
        support_tier_id: null,
        support_tier: null,
        is_active: true,
        created_at: "",
        updated_at: "",
      },
      ...this.clientOrgs,
    ];
  }

  get platformOrgId(): string | null {
    return this.platformOrg?.id ?? null;
  }

  async load() {
    const [clientOrgs, sysConfig] = await Promise.all([
      api.organizations.getAll().catch(() => [] as Organization[]),
      api.config.getSystem().catch(() => null),
    ]);

    this.clientOrgs = clientOrgs;
    this.platformOrg =
      (sysConfig?.platform_organization as PlatformOrg | null) ?? null;
    this.loaded = true;
  }

  async loadIfNeeded() {
    if (this.loaded) return;
    await this.load();
  }
}

export const orgStore = new OrganizationStore();
