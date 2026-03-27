export const TASK_SELECT = `
  *,
  project:projects(id, name, identifier, color),
  assignments:task_assignments(
    user_id,
    role,
    user:users!user_id(id, full_name, username, avatar_url)
  ),
  created_by_user:users!created_by(id, full_name, avatar_url),
  parent:tasks!parent_id(id, title, short_id),
  support_ticket:support_tickets!support_ticket_id(id, subject),
  tags:task_tags(
    id,
    tag:tags(id, name, color)
  )
` as const;

export const TASK_MINIMAL_SELECT = `
  id, title, short_id, status, priority, type, project_id, created_at
` as const;

export const PROJECT_SELECT = `
  *,
  owner:users!owner_id(id, full_name, avatar_url),
  members:project_members(
    user_id,
    role:roles(id, name, slug),
    user:users(id, full_name, username, avatar_url, is_active, deleted_at)
  )
` as const;

export const TICKET_SELECT = `
  *,
  customer:users!customer_id(id, full_name, email, avatar_url),
  agent:users!assigned_agent_id(id, full_name, avatar_url)
` as const;

export const MEMBER_SELECT = `
  *,
  user:users(id, full_name, username, email, avatar_url, last_seen_at),
  role:roles(id, name, slug)
` as const;

export const ATTACHMENT_SELECT = `
  *,
  uploader:users!uploaded_by(id, full_name, avatar_url)
` as const;

export const WIKI_FOLDER_SELECT = `*` as const;

export const WIKI_PAGE_META_SELECT = `
  id, title, folder_id, position, icon, created_by, updated_at
` as const;

export const WIKI_PAGE_FULL_SELECT = `
  *,
  created_by_user:users!created_by(id, full_name, avatar_url),
  updated_by_user:users!updated_by(id, full_name, avatar_url)
` as const;