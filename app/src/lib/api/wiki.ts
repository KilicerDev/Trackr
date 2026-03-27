import { getClient } from "./client";
import { WIKI_FOLDER_SELECT, WIKI_PAGE_META_SELECT, WIKI_PAGE_FULL_SELECT } from "./queries";

export type CreateFolderInput = {
  name: string;
  organization_id: string;
  parent_id?: string | null;
  created_by: string;
};

export type UpdateFolderInput = {
  name?: string;
  parent_id?: string | null;
  position?: number;
};

export type CreatePageInput = {
  title?: string;
  content?: string;
  folder_id?: string | null;
  organization_id: string;
  created_by: string;
};

export type UpdatePageInput = {
  title?: string;
  content?: string;
  folder_id?: string | null;
  position?: number;
  updated_by?: string;
};

const folders = {
  async getAll() {
    const { data, error } = await getClient()
      .from("wiki_folders")
      .select(WIKI_FOLDER_SELECT)
      .is("deleted_at", null)
      .order("position")
      .order("name");
    if (error) throw error;
    return data ?? [];
  },

  async create(input: CreateFolderInput) {
    const client = getClient();
    const { error: insertError } = await client
      .from("wiki_folders")
      .insert(input);
    if (insertError) throw insertError;

    const { data, error } = await client
      .from("wiki_folders")
      .select(WIKI_FOLDER_SELECT)
      .eq("created_by", input.created_by)
      .is("deleted_at", null)
      .order("created_at", { ascending: false })
      .limit(1)
      .single();
    if (error) throw error;
    return data;
  },

  async update(id: string, input: UpdateFolderInput) {
    const { data, error } = await getClient()
      .from("wiki_folders")
      .update(input)
      .eq("id", id)
      .select(WIKI_FOLDER_SELECT)
      .single();
    if (error) throw error;
    return data;
  },

  async delete(id: string) {
    const { error } = await getClient()
      .rpc("wiki_soft_delete_folder", { _folder_id: id });
    if (error) throw error;
  },
};

const pages = {
  async getAll() {
    const { data, error } = await getClient()
      .from("wiki_pages")
      .select(WIKI_PAGE_META_SELECT)
      .is("deleted_at", null)
      .order("position")
      .order("created_at");
    if (error) throw error;
    return data ?? [];
  },

  async getById(id: string) {
    const { data, error } = await getClient()
      .from("wiki_pages")
      .select(WIKI_PAGE_FULL_SELECT)
      .eq("id", id)
      .is("deleted_at", null)
      .single();
    if (error) throw error;
    return data;
  },

  async create(input: CreatePageInput) {
    const client = getClient();
    // INSERT without RETURNING (RLS SELECT policy + RETURNING has a visibility issue for non-admin users)
    const { error: insertError } = await client
      .from("wiki_pages")
      .insert(input);
    if (insertError) throw insertError;

    // Fetch the newly created page (RLS SELECT works fine as a separate query)
    const { data, error } = await client
      .from("wiki_pages")
      .select(WIKI_PAGE_META_SELECT)
      .eq("created_by", input.created_by)
      .is("deleted_at", null)
      .order("created_at", { ascending: false })
      .limit(1)
      .single();
    if (error) throw error;
    return data;
  },

  async update(id: string, input: UpdatePageInput) {
    const { data, error } = await getClient()
      .from("wiki_pages")
      .update(input)
      .eq("id", id)
      .select(WIKI_PAGE_META_SELECT)
      .single();
    if (error) throw error;
    return data;
  },

  async delete(id: string) {
    const { error } = await getClient()
      .rpc("wiki_soft_delete_page", { _page_id: id });
    if (error) throw error;
  },
};

export type WikiAccessGrant = {
  id: string;
  organization_id: string;
  user_id: string;
  folder_id: string | null;
  page_id: string | null;
  access_level: "read" | "read_write";
  granted_by: string;
  created_at: string;
  user: { id: string; full_name: string; email: string; avatar_url: string | null } | null;
};

export type GrantAccessInput = {
  organization_id: string;
  user_id: string;
  folder_id?: string | null;
  page_id?: string | null;
  access_level: "read" | "read_write";
  granted_by: string;
};

const WIKI_ACCESS_SELECT = `
  *,
  user:users!user_id(id, full_name, email, avatar_url)
` as const;

const access = {
  async getForFolder(folderId: string) {
    const { data, error } = await getClient()
      .from("wiki_access")
      .select(WIKI_ACCESS_SELECT)
      .eq("folder_id", folderId)
      .order("created_at");
    if (error) throw error;
    return (data ?? []) as WikiAccessGrant[];
  },

  async getForPage(pageId: string) {
    const { data, error } = await getClient()
      .from("wiki_access")
      .select(WIKI_ACCESS_SELECT)
      .eq("page_id", pageId)
      .order("created_at");
    if (error) throw error;
    return (data ?? []) as WikiAccessGrant[];
  },

  async grant(input: GrantAccessInput) {
    const client = getClient();
    const isFolder = !!input.folder_id;
    const targetCol = isFolder ? "folder_id" : "page_id";
    const targetVal = isFolder ? input.folder_id : input.page_id;

    // Check if grant already exists
    const { data: existing } = await client
      .from("wiki_access")
      .select("id")
      .eq("user_id", input.user_id)
      .eq(targetCol, targetVal!)
      .maybeSingle();

    if (existing) {
      // Update existing grant
      const { data, error } = await client
        .from("wiki_access")
        .update({ access_level: input.access_level, granted_by: input.granted_by })
        .eq("id", existing.id)
        .select(WIKI_ACCESS_SELECT)
        .single();
      if (error) throw error;
      return data as WikiAccessGrant;
    }

    // Insert new grant
    const row: Record<string, unknown> = {
      organization_id: input.organization_id,
      user_id: input.user_id,
      access_level: input.access_level,
      granted_by: input.granted_by,
    };
    if (input.folder_id) row.folder_id = input.folder_id;
    if (input.page_id) row.page_id = input.page_id;

    const { data, error } = await client
      .from("wiki_access")
      .insert(row)
      .select(WIKI_ACCESS_SELECT)
      .single();
    if (error) throw error;
    return data as WikiAccessGrant;
  },

  async revoke(grantId: string) {
    const { error } = await getClient()
      .from("wiki_access")
      .delete()
      .eq("id", grantId);
    if (error) throw error;
  },

  async getMyAccess() {
    const { data, error } = await getClient()
      .from("wiki_access")
      .select("id, folder_id, page_id, access_level");
    if (error) throw error;
    return data ?? [];
  },

  async getAll() {
    const { data, error } = await getClient()
      .from("wiki_access")
      .select(WIKI_ACCESS_SELECT)
      .order("created_at");
    if (error) throw error;
    return (data ?? []) as WikiAccessGrant[];
  },
};

export const wiki = { folders, pages, access };
