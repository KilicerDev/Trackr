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
  is_system: boolean;
};

/**
 * A user belongs in the client area (/c) when their role is the built-in
 * `client` slug or any non-system role (per-org custom or global custom).
 * Non-system roles are not internal staff, so they get the client UX.
 */
export function isClientAreaRole(role: UserRole | null | undefined): boolean {
  if (!role) return false;
  if (role.role_slug === "client") return true;
  return role.is_system === false;
}

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