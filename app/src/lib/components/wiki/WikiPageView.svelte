<script lang="ts">
  import { MilkdownEditor } from "./editor";
  import WikiShareModal from "./WikiShareModal.svelte";
  import { wikiStore, type WikiPageFull } from "$lib/stores/wiki.svelte";
  import { auth } from "$lib/stores/auth.svelte";
  import { Check, Loader2, AlertCircle, Save, Share2 } from "@lucide/svelte";

  let { page: wikiPage }: { page: WikiPageFull } = $props();

  let title = $state(wikiPage.title);
  let pendingContent: string | null = null;
  let titleDirty = $state(false);
  let shareModalOpen = $state(false);

  const canEdit = $derived(
    wikiStore.isWikiAdmin ||
    wikiStore.getEffectiveAccess(wikiPage, "page") === "read_write"
  );
  const canShare = $derived(wikiStore.isWikiAdmin);

  // Reset state when page changes
  $effect(() => {
    title = wikiPage.title;
    pendingContent = null;
    titleDirty = false;
  });

  async function save() {
    if (!canEdit || wikiStore.saveStatus !== "unsaved") return;

    const updates: Record<string, unknown> = { updated_by: auth.user?.id };
    if (pendingContent !== null && pendingContent !== wikiPage.content) {
      updates.content = pendingContent;
    }
    if (titleDirty && title.trim() !== wikiPage.title) {
      updates.title = title.trim() || "Untitled";
    }
    if (Object.keys(updates).length <= 1) {
      wikiStore.saveStatus = "saved";
      return;
    }

    await wikiStore.updatePage(wikiPage.id, updates);
    pendingContent = null;
    titleDirty = false;
  }

  function handleContentChange(markdown: string) {
    if (!canEdit) return;
    pendingContent = markdown;
    wikiStore.saveStatus = "unsaved";
  }

  function handleTitleInput() {
    if (!canEdit) return;
    titleDirty = true;
    wikiStore.saveStatus = "unsaved";
  }

  function formatTimeAgo(dateStr: string): string {
    const diff = Date.now() - new Date(dateStr).getTime();
    const mins = Math.floor(diff / 60000);
    if (mins < 1) return "just now";
    if (mins < 60) return `${mins}m ago`;
    const hours = Math.floor(mins / 60);
    if (hours < 24) return `${hours}h ago`;
    const days = Math.floor(hours / 24);
    return `${days}d ago`;
  }

  // Register flush callback so layout can trigger save before navigation
  $effect(() => {
    wikiStore.flushSave = () => save();
    return () => { wikiStore.flushSave = null; };
  });

  // Flush pending save on page switch (cleanup)
  $effect(() => {
    wikiPage.id;
    return () => {
      if (canEdit && wikiStore.saveStatus === "unsaved") save();
    };
  });

  // Cmd+S / Ctrl+S keyboard shortcut
  $effect(() => {
    if (typeof window === "undefined") return;
    function handleKeydown(e: KeyboardEvent) {
      if ((e.metaKey || e.ctrlKey) && e.key === "s") {
        e.preventDefault();
        if (canEdit) save();
      }
    }
    window.addEventListener("keydown", handleKeydown);
    return () => window.removeEventListener("keydown", handleKeydown);
  });

  // beforeunload warning
  $effect(() => {
    if (typeof window === "undefined") return;
    function handler(e: BeforeUnloadEvent) {
      if (wikiStore.saveStatus === "unsaved") {
        e.preventDefault();
      }
    }
    window.addEventListener("beforeunload", handler);
    return () => window.removeEventListener("beforeunload", handler);
  });
</script>

<div class="mx-auto w-full max-w-[740px] py-6 px-6">
  <!-- Header -->
  <div class="mb-4">
    <div class="flex items-start justify-between gap-3">
      <input
        type="text"
        bind:value={title}
        oninput={handleTitleInput}
        readonly={!canEdit}
        placeholder="Untitled"
        class="w-full bg-transparent text-xl font-semibold text-sidebar-text outline-none placeholder:text-muted/30
          {!canEdit ? 'cursor-default' : ''}"
      />
      <!-- Actions area -->
      <div class="mt-0.5 flex shrink-0 items-center gap-3">
        {#if canShare}
          <button
            class="flex items-center gap-1 text-sm text-muted/50 transition-all duration-150 hover:text-accent"
            onclick={() => shareModalOpen = true}
          >
            <Share2 size={12} />
            Share
          </button>
        {/if}
        {#if canEdit}
          {#if wikiStore.saveStatus === "saved"}
            <span class="flex items-center gap-1 text-xs text-muted/40">
              <Check size={10} class="text-green-400" /> Saved
            </span>
          {:else if wikiStore.saveStatus === "saving"}
            <span class="flex items-center gap-1 text-xs text-muted/40">
              <Loader2 size={10} class="animate-spin" /> Saving...
            </span>
          {:else if wikiStore.saveStatus === "error"}
            <span class="flex items-center gap-1 text-xs text-red-400/60">
              <AlertCircle size={10} /> Error
            </span>
          {/if}
          {#if wikiStore.saveStatus === "unsaved" || wikiStore.saveStatus === "error"}
            <button
              class="flex items-center gap-1 text-sm font-medium text-accent transition-all duration-150 hover:text-accent/80"
              onclick={save}
            >
              <Save size={12} />
              Save
            </button>
          {/if}
        {:else}
          <span class="text-xs text-muted/30">Read only</span>
        {/if}
      </div>
    </div>
    <!-- Metadata -->
    <div class="mt-1 flex items-center gap-2 text-xs text-muted/40">
      {#if wikiPage.updated_by_user}
        <span>Last edited by {wikiPage.updated_by_user.full_name} · {formatTimeAgo(wikiPage.updated_at)}</span>
      {:else if wikiPage.created_by_user}
        <span>Created by {wikiPage.created_by_user.full_name} · {formatTimeAgo(wikiPage.created_at)}</span>
      {/if}
      {#if canEdit}
        <span class="font-mono text-muted/20">&#8984;S</span>
      {/if}
    </div>
  </div>

  <!-- Divider -->
  <div class="mb-4 h-px bg-surface-border/30"></div>

  <!-- Editor -->
  {#key wikiPage.id}
    <MilkdownEditor
      content={wikiPage.content}
      onchange={handleContentChange}
      readonly={!canEdit}
    />
  {/key}
</div>

{#if canShare}
  <WikiShareModal
    open={shareModalOpen}
    targetId={wikiPage.id}
    targetType="page"
    targetName={wikiPage.title}
    organizationId={wikiPage.organization_id}
    onClose={() => shareModalOpen = false}
  />
{/if}
