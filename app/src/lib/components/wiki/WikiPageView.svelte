<script lang="ts">
  import { MilkdownEditor } from "./editor";
  import WikiShareModal from "./WikiShareModal.svelte";
  import { wikiStore, type WikiPageFull } from "$lib/stores/wiki.svelte";
  import { auth } from "$lib/stores/auth.svelte";
  import { Check, Loader2, AlertCircle, Save, Share2, Code2, Eye, MoreVertical, Link2 } from "@lucide/svelte";

  let { page: wikiPage }: { page: WikiPageFull } = $props();

  let title = $state(wikiPage.title);
  let pendingContent: string | null = null;
  let titleDirty = $state(false);
  let shareModalOpen = $state(false);
  let showSource = $state(false);
  let moreMenuOpen = $state(false);
  let moreMenuEl: HTMLDivElement | undefined = $state();
  let linkCopied = $state(false);
  let markdownCopied = $state(false);

  async function copyLink() {
    if (typeof window === "undefined") return;
    try {
      await navigator.clipboard.writeText(window.location.href);
      linkCopied = true;
      setTimeout(() => { linkCopied = false; }, 1500);
    } catch { /* noop */ }
    moreMenuOpen = false;
  }

  async function copyMarkdown() {
    if (typeof window === "undefined") return;
    const md = pendingContent ?? wikiPage.content ?? "";
    try {
      await navigator.clipboard.writeText(md);
      markdownCopied = true;
      setTimeout(() => { markdownCopied = false; }, 1500);
    } catch { /* noop */ }
    moreMenuOpen = false;
  }

  $effect(() => {
    if (!moreMenuOpen) return;
    function handler(e: MouseEvent) {
      if (moreMenuEl && !moreMenuEl.contains(e.target as Node)) moreMenuOpen = false;
    }
    function esc(e: KeyboardEvent) { if (e.key === "Escape") moreMenuOpen = false; }
    document.addEventListener("mousedown", handler);
    document.addEventListener("keydown", esc);
    return () => {
      document.removeEventListener("mousedown", handler);
      document.removeEventListener("keydown", esc);
    };
  });

  function autosize(node: HTMLTextAreaElement) {
    const resize = () => {
      node.style.height = 'auto';
      node.style.height = node.scrollHeight + 'px';
    };
    resize();
    node.addEventListener('input', resize);
    return { destroy: () => node.removeEventListener('input', resize) };
  }

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
    showSource = false;
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

  import { formatTimeAgo, formatFullDate } from '$lib/utils/date';

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
        <div class="flex items-center gap-0.5 rounded-sm bg-surface-hover/40 p-0.5">
          <button
            class="flex h-6 w-6 items-center justify-center rounded-sm transition-all duration-150 {!showSource ? 'bg-surface-hover text-sidebar-text' : 'text-muted/50 hover:text-accent'}"
            onclick={() => showSource = false}
            title="Show rendered"
            aria-label="Show rendered"
            aria-pressed={!showSource}
          >
            <Eye size={13} />
          </button>
          <button
            class="flex h-6 w-6 items-center justify-center rounded-sm transition-all duration-150 {showSource ? 'bg-surface-hover text-sidebar-text' : 'text-muted/50 hover:text-accent'}"
            onclick={() => showSource = true}
            title="Show markdown source"
            aria-label="Show markdown source"
            aria-pressed={showSource}
          >
            <Code2 size={13} />
          </button>
        </div>
        {#if canEdit}
          {#if wikiStore.saveStatus === "saving"}
            <span class="flex items-center gap-1 text-xs text-muted/40">
              <Loader2 size={10} class="animate-spin" /> Saving...
            </span>
          {:else if wikiStore.saveStatus === "unsaved"}
            <span class="flex items-center rounded-sm bg-yellow-500/15 px-1.5 py-0.5 text-sm font-medium text-yellow-600 dark:text-yellow-400">
              Unsaved
            </span>
          {:else if wikiStore.saveStatus === "error"}
            <span class="flex items-center gap-1 text-xs text-red-400/60">
              <AlertCircle size={10} /> Error
            </span>
          {/if}
        {:else}
          <span class="text-xs text-muted/30">Read only</span>
        {/if}
        <div class="relative" bind:this={moreMenuEl}>
          <button
            class="flex h-6 w-6 items-center justify-center rounded-sm text-muted/50 transition-all duration-150 hover:bg-surface-hover/60 hover:text-sidebar-text"
            onclick={() => moreMenuOpen = !moreMenuOpen}
            title="More actions"
            aria-label="More actions"
            aria-expanded={moreMenuOpen}
          >
            <MoreVertical size={14} />
          </button>
          {#if moreMenuOpen}
            <div class="absolute right-0 z-30 mt-1.5 w-48 rounded-md border border-surface-border bg-surface py-1 shadow-lg shadow-black/15 ring-1 ring-white/[0.07] animate-dropdown-in">
              {#if canEdit}
                <button
                  class="flex w-full items-center gap-2 px-3 py-1.5 text-left text-sm text-sidebar-text transition-colors hover:bg-surface-hover/60 disabled:cursor-not-allowed disabled:opacity-40"
                  onclick={() => { save(); moreMenuOpen = false; }}
                  disabled={wikiStore.saveStatus === "saved" || wikiStore.saveStatus === "saving"}
                >
                  <Save size={13} class="text-muted/60" />
                  Save
                  <span class="ml-auto font-mono text-xs text-muted/30">&#8984;S</span>
                </button>
              {/if}
              {#if canShare}
                <button
                  class="flex w-full items-center gap-2 px-3 py-1.5 text-left text-sm text-sidebar-text transition-colors hover:bg-surface-hover/60"
                  onclick={() => { shareModalOpen = true; moreMenuOpen = false; }}
                >
                  <Share2 size={13} class="text-muted/60" />
                  Share
                </button>
              {/if}
              <button
                class="flex w-full items-center gap-2 px-3 py-1.5 text-left text-sm text-sidebar-text transition-colors hover:bg-surface-hover/60"
                onclick={copyLink}
              >
                <Link2 size={13} class="text-muted/60" />
                {linkCopied ? "Link copied" : "Copy link"}
              </button>
              <button
                class="flex w-full items-center gap-2 px-3 py-1.5 text-left text-sm text-sidebar-text transition-colors hover:bg-surface-hover/60"
                onclick={copyMarkdown}
              >
                <Code2 size={13} class="text-muted/60" />
                {markdownCopied ? "Markdown copied" : "Copy markdown"}
              </button>
            </div>
          {/if}
        </div>
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
    {#if showSource}
      <textarea
        use:autosize
        value={pendingContent ?? wikiPage.content}
        oninput={(e) => handleContentChange(e.currentTarget.value)}
        readonly={!canEdit}
        spellcheck="false"
        class="block w-full resize-none overflow-hidden bg-transparent font-mono text-sm leading-relaxed text-sidebar-text outline-none placeholder:text-muted/30 {!canEdit ? 'cursor-default' : ''}"
      ></textarea>
    {:else}
      <MilkdownEditor
        content={pendingContent ?? wikiPage.content}
        onchange={handleContentChange}
        readonly={!canEdit}
      />
    {/if}
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
