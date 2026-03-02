import { getClient } from "./client";

export type Organization = {
  id: string;
  name: string;
  slug: string;
  logo_url: string | null;
};

export const organizations = {
  async getAll() {
    const supabase = getClient();
    const { data, error } = await supabase
      .from("organizations")
      .select("id, name, slug, logo_url")
      .is("deleted_at", null)
      .eq("is_active", true)
      .order("name");

    if (error) throw error;
    return data ?? [];
  },
};
