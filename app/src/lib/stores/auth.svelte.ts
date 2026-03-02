import type {
    AppUser,
    UserRole,
    UserPermission,
} from "$lib/types/auth";

// Runes-based state (Svelte 5)
class AuthState {
    user = $state<AppUser | null>(null);
    role = $state<UserRole | null>(null);
    permissions = $state<UserPermission[]>([]);

    get isAuthenticated() {
        return this.user !== null;
    }

    get isOwner() {
        return this.role?.role_slug === "owner";
    }

    get isClient() {
        return this.role?.role_slug === "client";
    }

    get organizationId() {
        return this.user?.organization_id ?? null;
    }

    can(resource: string, action: string): boolean {
        return this.permissions.some(
            (p) => p.resource === resource && p.action === action
        );
    }

    canAll(resource: string, action: string): boolean {
        return this.permissions.some(
            (p) =>
                p.resource === resource &&
                p.action === action &&
                p.scope === "all"
        );
    }

    scope(resource: string, action: string): "own" | "all" | null {
        return (
            this.permissions.find(
                (p) => p.resource === resource && p.action === action
            )?.scope ?? null
        );
    }

    init(
        user: AppUser | null,
        role: UserRole | null,
        permissions: UserPermission[]
    ) {
        this.user = user;
        this.role = role;
        this.permissions = permissions;
    }

    clear() {
        this.user = null;
        this.role = null;
        this.permissions = [];
    }
}

export const auth = new AuthState();