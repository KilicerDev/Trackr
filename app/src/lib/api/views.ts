import { getClient } from "./client";

export type SavedView = {
  id: string;
  user_id: string;
  name: string;
  filters: Record<string, unknown>;
  view_mode: string;
  group_by: string;
  sort_order: number;
  created_at: string;
  updated_at: string;
};

export type CreateViewInput = {
  name: string;
  filters: Record<string, unknown>;
  view_mode: string;
  group_by: string;
};

export type UpdateViewInput = Partial<CreateViewInput> & { sort_order?: number };

async function getAll(): Promise<SavedView[]> {
  const { data, error } = await getClient()
    .from("saved_views")
    .select("*")
    .order("sort_order")
    .order("created_at");
  if (error) throw new Error(error.message);
  return data as SavedView[];
}

async function create(input: CreateViewInput): Promise<SavedView> {
  const { data: { user } } = await getClient().auth.getUser();
  if (!user) throw new Error("Not authenticated");

  const { data, error } = await getClient()
    .from("saved_views")
    .insert({ ...input, user_id: user.id })
    .select()
    .single();
  if (error) throw new Error(error.message);
  return data as SavedView;
}

async function update(id: string, input: UpdateViewInput): Promise<SavedView> {
  const { data, error } = await getClient()
    .from("saved_views")
    .update({ ...input, updated_at: new Date().toISOString() })
    .eq("id", id)
    .select()
    .single();
  if (error) throw new Error(error.message);
  return data as SavedView;
}

async function remove(id: string): Promise<void> {
  const { error } = await getClient()
    .from("saved_views")
    .delete()
    .eq("id", id);
  if (error) throw new Error(error.message);
}

export const views = { getAll, create, update, delete: remove };
