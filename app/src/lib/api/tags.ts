import { getClient } from "./client";

export type Tag = {
  id: string;
  project_id: string;
  name: string;
  color: string;
  created_by: string;
  created_at: string;
  updated_at: string;
};

export type CreateTagInput = {
  project_id: string;
  name: string;
  color: string;
};

async function getByProject(projectId: string): Promise<Tag[]> {
  const { data, error } = await getClient()
    .from("tags")
    .select("*")
    .eq("project_id", projectId)
    .order("name");
  if (error) throw new Error(error.message);
  return data as Tag[];
}

async function create(input: CreateTagInput): Promise<Tag> {
  const { data: { user } } = await getClient().auth.getUser();
  if (!user) throw new Error("Not authenticated");

  const { data, error } = await getClient()
    .from("tags")
    .insert({ ...input, created_by: user.id })
    .select()
    .single();
  if (error) throw new Error(error.message);
  return data as Tag;
}

async function update(id: string, input: { name?: string; color?: string }): Promise<Tag> {
  const { data, error } = await getClient()
    .from("tags")
    .update(input)
    .eq("id", id)
    .select()
    .single();
  if (error) throw new Error(error.message);
  return data as Tag;
}

async function remove(id: string): Promise<void> {
  const { error } = await getClient()
    .from("tags")
    .delete()
    .eq("id", id);
  if (error) throw new Error(error.message);
}

async function addToTask(taskId: string, tagId: string): Promise<void> {
  const { error } = await getClient()
    .from("task_tags")
    .upsert({ task_id: taskId, tag_id: tagId }, { onConflict: "task_id,tag_id" });
  if (error) throw new Error(error.message);
}

async function removeFromTask(taskId: string, tagId: string): Promise<void> {
  const { error } = await getClient()
    .from("task_tags")
    .delete()
    .eq("task_id", taskId)
    .eq("tag_id", tagId);
  if (error) throw new Error(error.message);
}

async function getTaskTags(taskId: string): Promise<Tag[]> {
  const { data, error } = await getClient()
    .from("task_tags")
    .select("tag:tags(*)")
    .eq("task_id", taskId);
  if (error) throw new Error(error.message);
  return (data as { tag: Tag }[]).map((r) => r.tag);
}

export const tags = { getByProject, create, update, delete: remove, addToTask, removeFromTask, getTaskTags };
