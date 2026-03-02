export type PermissionScope = "own" | "all";

export type UserPermission = {
  resource: string;
  action: string;
  scope: PermissionScope;
};

export type UserRole = {
  role_id: string;
  role_slug: string;
  role_name: string;
};

export type AppUser = {
  id: string;
  email: string;
  full_name: string;
  username: string;
  avatar_url: string | null;
  timezone: string;
  locale: string;
  organization_id: string | null;
  is_active: boolean;
};