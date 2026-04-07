<script lang="ts">
  import Modal from "$lib/components/Modal.svelte";
  import { wikiStore } from "$lib/stores/wiki.svelte";
  import { auth } from "$lib/stores/auth.svelte";
  import { api } from "$lib/api";
  import { Search, X } from "@lucide/svelte";

  let {
    open = false,
    targetId,
    targetType,
    targetName,
    organizationId,
    onClose,
  }: {
    open: boolean;
    targetId: string;
    targetType: "folder" | "page";
    targetName: string;
    organizationId: string;
    onClose: () => void;
  } = $props();

  let searchQuery = $state("");
  let allUsers = $state<{ id: string; full_name: string; email: string; avatar_url: string | null }[]>([]);
  let usersLoaded = $state(false);
  let selectedLevel = $state<"read" | "read_write">("read");

  const filteredUsers = $derived(() => {
    const grantedUserIds = new Set(wikiStore.activePageGrants.map((g) => g.user_id));
    const q = searchQuery.toLowerCase().trim();
    return allUsers
      .filter((u) => !grantedUserIds.has(u.id))
      .filter((u) => u.id !== auth.user?.id)
      .filter((u) => !q || u.full_name.toLowerCase().includes(q) || u.email.toLowerCase().includes(q));
  });

  $effect(() => {
    if (open) {
      wikiStore.loadAccessGrants(targetId, targetType);
      if (!usersLoaded) {
        api.users.getAll().then((data) => {
          allUsers = data.map((u) => ({
            id: u.id,
            full_name: u.full_name,
            email: u.email,
            avatar_url: u.avatar_url,
          }));
          usersLoaded = true;
        });
      }
      searchQuery = "";
    }
  });

  let granting = $state(false);
  let grantError = $state<string | null>(null);

  async function handleGrant(userId: string) {
    if (granting) return;
    granting = true;
    grantError = null;
    try {
      await wikiStore.grantAccess({
        organization_id: organizationId,
        user_id: userId,
        ...(targetType === "folder" ? { folder_id: targetId } : { page_id: targetId }),
        access_level: selectedLevel,
        granted_by: auth.user!.id,
      });
      // Reload grants to ensure list is fresh
      await wikiStore.loadAccessGrants(targetId, targetType);
    } catch (e) {
      console.error("[WikiShareModal.handleGrant]", e);
      grantError = e instanceof Error ? e.message : "Failed to grant access";
    } finally {
      granting = false;
      searchQuery = "";
    }
  }

  async function handleLevelChange(grantId: string, userId: string, newLevel: "read" | "read_write") {
    await wikiStore.grantAccess({
      organization_id: organizationId,
      user_id: userId,
      ...(targetType === "folder" ? { folder_id: targetId } : { page_id: targetId }),
      access_level: newLevel,
      granted_by: auth.user!.id,
    });
  }

  async function handleRevoke(grantId: string) {
    await wikiStore.revokeAccess(grantId);
  }

  function getInitials(name: string): string {
    return name.split(" ").map((w) => w[0]).join("").toUpperCase().slice(0, 2);
  }
</script>

<Modal {open} {onClose} maxWidth="max-w-md">
  <div class="p-4">
    <h3 class="mb-1 text-base font-semibold text-sidebar-text">Share "{targetName}"</h3>
    <p class="mb-3 text-xs text-muted/40">
      {targetType === "folder" ? "Folder access cascades to all contents." : "Grant access to this page."}
    </p>

    <!-- User search -->
    <div class="relative">
      <div class="flex gap-1.5">
        <div class="relative flex-1">
          <Search size={12} class="pointer-events-none absolute left-2 top-1/2 -translate-y-1/2 text-muted/30" />
          <input
            type="text"
            placeholder="Search members..."
            bind:value={searchQuery}
            class="w-full rounded-sm bg-surface-hover/40 py-1.5 pl-7 pr-2 text-base text-sidebar-text outline-none placeholder:text-muted/30 focus:bg-surface-hover/60"
          />
        </div>
        <select
          bind:value={selectedLevel}
          class="rounded-sm bg-surface-hover/40 px-2 py-1.5 text-xs text-sidebar-text outline-none"
        >
          <option value="read">Read</option>
          <option value="read_write">Read & Write</option>
        </select>
      </div>

      <!-- Search results dropdown -->
      {#if searchQuery.trim() && filteredUsers().length > 0}
        <div class="absolute left-0 right-0 z-20 mt-1 max-h-[160px] overflow-y-auto rounded-md border border-surface-border bg-surface shadow-lg shadow-black/15 ring-1 ring-white/[0.07] animate-dropdown-in">
          {#each filteredUsers() as user (user.id)}
            <button
              class="flex w-full items-center gap-2 px-2.5 py-1.5 text-left text-sm text-muted transition-colors hover:bg-surface-hover/60 hover:text-sidebar-text"
              onclick={() => handleGrant(user.id)}
            >
              {#if user.avatar_url}
                <img src={user.avatar_url} alt="" class="h-5 w-5 rounded-full" />
              {:else}
                <span class="flex h-5 w-5 items-center justify-center rounded-full bg-surface-hover text-3xs font-medium text-muted">
                  {getInitials(user.full_name)}
                </span>
              {/if}
              <span class="truncate">{user.full_name}</span>
              <span class="ml-auto truncate text-xs text-muted/30">{user.email}</span>
            </button>
          {/each}
        </div>
      {/if}
    </div>

    <!-- Current grants -->
    {#if wikiStore.activePageGrants.length > 0}
      <div class="mt-4 space-y-1">
        <p class="mb-1 text-xs font-medium text-muted/40">People with access</p>
        {#each wikiStore.activePageGrants as grant (grant.id)}
          <div class="flex items-center gap-2 rounded-sm px-1 py-1 hover:bg-surface-hover/40">
            {#if grant.user?.avatar_url}
              <img src={grant.user.avatar_url} alt="" class="h-6 w-6 rounded-full" />
            {:else}
              <span class="flex h-6 w-6 items-center justify-center rounded-full bg-surface-hover text-3xs font-medium text-muted">
                {getInitials(grant.user?.full_name ?? "?")}
              </span>
            {/if}
            <div class="min-w-0 flex-1">
              <p class="truncate text-sm text-sidebar-text">{grant.user?.full_name}</p>
              <p class="truncate text-xs text-muted/30">{grant.user?.email}</p>
            </div>
            <select
              value={grant.access_level}
              onchange={(e) => handleLevelChange(grant.id, grant.user_id, (e.target as HTMLSelectElement).value as "read" | "read_write")}
              class="rounded-sm bg-surface-hover/40 px-1.5 py-0.5 text-xs text-sidebar-text outline-none"
            >
              <option value="read">Read</option>
              <option value="read_write">Read & Write</option>
            </select>
            <button
              class="flex h-5 w-5 items-center justify-center rounded-sm text-muted/40 transition-all duration-150 hover:bg-surface-hover hover:text-red-400"
              onclick={() => handleRevoke(grant.id)}
              title="Revoke access"
            >
              <X size={10} />
            </button>
          </div>
        {/each}
      </div>
    {/if}

    {#if grantError}
      <p class="mt-2 text-xs text-red-400/60">{grantError}</p>
    {/if}

    <div class="mt-4 flex justify-end">
      <button
        class="text-sm text-muted/50 transition-colors hover:text-accent"
        onclick={onClose}
      >
        Done
      </button>
    </div>
  </div>
</Modal>
