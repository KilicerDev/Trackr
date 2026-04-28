import type {
    AppUser,
    UserRole,
    UserPermission,
} from "$lib/types/auth";
import { isClientAreaRole } from "$lib/types/auth";

// Runes-based state (Svelte 5)
class AuthState {
    user = $state<AppUser | null>(null);
    role = $state<UserRole | null>(null);
    permissions = $state<UserPermission[]>([]);
    isPlatformMember = $state(false);

    get isAuthenticated() {
        return this.user !== null;
    }

    get isOwner() {
        return this.role?.role_slug === "owner";
    }

    get isAdmin() {
        return this.role?.role_slug === "admin";
    }

    get isClient() {
        return isClientAreaRole(this.role);
    }

    get isAdminRole() {
        return this.isPlatformMember || this.isOwner || this.isAdmin;
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
        permissions: UserPermission[],
        isPlatformMember = false
    ) {
        this.user = user;
        this.role = role;
        this.permissions = permissions;
        this.isPlatformMember = isPlatformMember;
    }

    clear() {
        this.user = null;
        this.role = null;
        this.permissions = [];
        this.isPlatformMember = false;
    }
}

export const auth = new AuthState();