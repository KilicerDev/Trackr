import { getClient } from "./client";

export type SupportTier = {
  id: string;
  name: string;
  slug: string;
  response_time_hours: number;
  resolution_time_hours: number;
};

export type Organization = {
  id: string;
  name: string;
  slug: string;
  domain: string | null;
  logo_url: string | null;
  website_url: string | null;
  notes: string | null;
  support_tier_id: string | null;
  support_tier: SupportTier | null;
  is_active: boolean;
  created_at: string;
  updated_at: string;
};

const ORG_SELECT = `
  id, name, slug, domain, logo_url, website_url, notes,
  support_tier_id, is_active, created_at, updated_at,
  support_tier:support_tiers(id, name, slug, response_time_hours, resolution_time_hours)
`;

export type CreateOrgInput = {
  name: string;
  slug: string;
  domain?: string | null;
  logo_url?: string | null;
  website_url?: string | null;
  notes?: string | null;
  support_tier_id?: string | null;
};

export const organizations = {
  async getAll() {
    const supabase = getClient();
    const { data, error } = await supabase
      .from("organizations")
      .select(ORG_SELECT)
      .is("deleted_at", null)
      .order("name");

    if (error) throw error;
    return (data ?? []) as Organization[];
  },

  async getById(id: string) {
    const supabase = getClient();
    const { data, error } = await supabase
      .from("organizations")
      .select(ORG_SELECT)
      .eq("id", id)
      .single();

    if (error) throw error;
    return data as Organization;
  },

  async create(input: CreateOrgInput) {
    const supabase = getClient();
    const { data, error } = await supabase
      .from("organizations")
      .insert(input)
      .select(ORG_SELECT)
      .single();

    if (error) throw error;
    return data as Organization;
  },

  async update(id: string, values: Partial<CreateOrgInput> & { is_active?: boolean }) {
    const supabase = getClient();
    const { data, error } = await supabase
      .from("organizations")
      .update(values)
      .eq("id", id)
      .select(ORG_SELECT)
      .single();

    if (error) throw error;
    return data as Organization;
  },
};
