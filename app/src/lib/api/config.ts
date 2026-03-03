import { getClient } from "./client";

export type Tier = {
  id: string;
  name: string;
  slug: string;
  response_time_hours: number;
  resolution_time_hours: number;
  description: string | null;
  sort_order: number;
  is_active: boolean;
  created_at: string;
  updated_at: string;
};

export type CreateTierInput = {
  name: string;
  slug: string;
  response_time_hours: number;
  resolution_time_hours: number;
  description?: string | null;
  sort_order?: number;
  is_active?: boolean;
};

export const config = {
  // ── System config (singleton) ──

  async getSystem() {
    const supabase = getClient();
    const { data, error } = await supabase
      .from("system_config")
      .select("*, default_tier:support_tiers!default_support_tier_id(id, name, slug)")
      .single();

    if (error) throw error;

    let platform_organization: { id: string; name: string; slug: string } | null = null;
    if (data.platform_organization_id) {
      const { data: org } = await supabase
        .from("organizations")
        .select("id, name, slug")
        .eq("id", data.platform_organization_id)
        .single();
      platform_organization = org;
    }

    return { ...data, platform_organization };
  },

  async updateSystem(values: Record<string, unknown>) {
    const supabase = getClient();

    const { data: existing, error: fetchErr } = await supabase
      .from("system_config")
      .select("id")
      .limit(1)
      .single();

    if (fetchErr) throw fetchErr;

    const { data, error } = await supabase
      .from("system_config")
      .update(values)
      .eq("id", existing.id)
      .select("*, default_tier:support_tiers!default_support_tier_id(id, name, slug)")
      .single();

    if (error) throw error;
    return data;
  },

  // ── Support tiers ──

  async getTiers() {
    const supabase = getClient();
    const { data, error } = await supabase
      .from("support_tiers")
      .select("*")
      .order("sort_order");

    if (error) throw error;
    return (data ?? []) as Tier[];
  },

  async createTier(input: CreateTierInput) {
    const supabase = getClient();
    const { data, error } = await supabase
      .from("support_tiers")
      .insert(input)
      .select()
      .single();

    if (error) throw error;
    return data as Tier;
  },

  async updateTier(id: string, values: Partial<CreateTierInput>) {
    const supabase = getClient();
    const { data, error } = await supabase
      .from("support_tiers")
      .update(values)
      .eq("id", id)
      .select()
      .single();

    if (error) throw error;
    return data as Tier;
  },

  async deleteTier(id: string) {
    const supabase = getClient();
    const { error } = await supabase
      .from("support_tiers")
      .delete()
      .eq("id", id);

    if (error) throw error;
  },

  // ── Org settings ──

  async getOrgSettings(orgId: string) {
    const supabase = getClient();
    const { data, error } = await supabase
      .from("organization_settings")
      .select("*")
      .eq("organization_id", orgId)
      .single();

    if (error?.code === "PGRST116") return null;
    if (error) throw error;
    return data;
  },

  async upsertOrgSettings(
    orgId: string,
    values: Record<string, unknown>
  ) {
    const supabase = getClient();
    const { data, error } = await supabase
      .from("organization_settings")
      .upsert(
        { organization_id: orgId, ...values },
        { onConflict: "organization_id" }
      )
      .select()
      .single();

    if (error) throw error;
    return data;
  },

  // ── SLA breaches ──

  async getBreaches(ticketId?: string) {
    const supabase = getClient();
    let q = supabase
      .from("sla_breaches")
      .select(`
        *,
        ticket:support_tickets!ticket_id(id, subject, customer_id),
        tier:support_tiers!support_tier_id(id, name),
        escalated_to_user:users!escalated_to(id, full_name)
      `)
      .order("breached_at", { ascending: false });

    if (ticketId) {
      q = q.eq("ticket_id", ticketId);
    }

    const { data, error } = await q;
    if (error) throw error;
    return data ?? [];
  },
};
