<script lang="ts">
  import { slide } from "svelte/transition";
  import { ChevronRight, Folder, FolderOpen, FileText, Pencil, Trash2, FolderInput, FilePlus, FolderPlus, Share2, Users, Download, Image, Table, Presentation, File as FileIcon } from "@lucide/svelte";
  import { wikiStore, type WikiFolder, type WikiPageMeta, type WikiFile } from "$lib/stores/wiki.svelte";
  import { wikiUi } from "$lib/stores/wiki-ui.svelte";
  import { isImageType, isPdfType } from "$lib/config/attachments";
  import WikiTreeItem from "./WikiTreeItem.svelte";

  let {
    type,
    item,
    depth = 0,
    activePageId = null,
    activeFileId = null,
    childFolders = [],
    childPages = [],
    childFiles = [],
    allFolders = [],
    allPages = [],
    allFiles = [],
    canEdit = false,
    canShare = false,
    renamingId = null,
    forceExpanded = false,
    onSelectPage,
    onSelectFile,
    onRenameStart,
    onRenameCommit,
    onRenameCancel,
    onDeleteFolder,
    onDeletePage,
    onDeleteFile,
    onDownloadFile,
    onUploadFiles,
    onMovePageRequest,
    onMoveFolderRequest,
    onNewPageInFolder,
    onNewFolderInFolder,
    onShareRequest,
  }: {
    type: "folder" | "page" | "file";
    item: WikiFolder | WikiPageMeta | WikiFile;
    depth?: number;
    activePageId?: string | null;
    activeFileId?: string | null;
    childFolders?: WikiFolder[];
    childPages?: WikiPageMeta[];
    childFiles?: WikiFile[];
    allFolders?: WikiFolder[];
    allPages?: WikiPageMeta[];
    allFiles?: WikiFile[];
    canEdit?: boolean;
    canShare?: boolean;
    renamingId?: string | null;
    forceExpanded?: boolean;
    onSelectPage?: (id: string) => void;
    onSelectFile?: (id: string) => void;
    onRenameStart?: (id: string, type: "folder" | "page" | "file") => void;
    onRenameCommit?: (id: string, value: string, type: "folder" | "page" | "file") => void;
    onRenameCancel?: () => void;
    onDeleteFolder?: (id: string) => void;
    onDeletePage?: (id: string) => void;
    onDeleteFile?: (id: string, storagePath: string) => void;
    onDownloadFile?: (file: WikiFile) => void;
    onUploadFiles?: (folderId: string, files: File[]) => void;
    onMovePageRequest?: (id: string) => void;
    onMoveFolderRequest?: (id: string) => void;
    onNewPageInFolder?: (folderId: string) => void;
    onNewFolderInFolder?: (parentId: string) => void;
    onShareRequest?: (id: string, type: "folder" | "page") => void;
  } = $props();

  const expanded = $derived(forceExpanded || wikiUi.isExpanded(item.id));
  let showMenu = $state(false);
  let menuX = $state(0);
  let menuY = $state(0);
  let menuEl: HTMLDivElement | undefined = $state();
  let rowEl: HTMLDivElement | undefined = $state();
  let renameInputEl: HTMLInputElement | undefined = $state();
  let renameValue = $state("");
  let dragOver = $state(false);
  let dragCounter = 0;

  const isFolder = $derived(type === "folder");
  const isFile = $derived(type === "file");
  const isActive = $derived(
    (type === "page" && item.id === activePageId) ||
    (type === "file" && item.id === activeFileId)
  );
  const isRenaming = $derived(renamingId === item.id);
  const indentLeft = $derived(`${depth * 16}px`);

  const AVATAR_COLORS = ['#3b82f6', '#10b981', '#f59e0b', '#8b5cf6', '#ef4444', '#06b6d4'];
  function avatarColor(name: string): string {
    let hash = 0;
    for (let i = 0; i < name.length; i++) hash = name.charCodeAt(i) + ((hash << 5) - hash);
    return AVATAR_COLORS[Math.abs(hash) % AVATAR_COLORS.length];
  }

  const itemGrants = $derived(!isFile ? wikiStore.getGrantsForItem(item.id, type as "folder" | "page") : []);
  const sharedUsers = $derived(
    itemGrants.filter(g => g.user).map(g => ({ name: g.user!.full_name, id: g.user_id }))
  );

  function getFileIconComponent(mime: string) {
    if (isImageType(mime)) return Image;
    if (isPdfType(mime)) return FileText;
    if (mime.includes("spreadsheet") || mime.includes("excel") || mime === "text/csv") return Table;
    if (mime.includes("presentation") || mime.includes("powerpoint")) return Presentation;
    return FileIcon;
  }

  function handleClick(e: MouseEvent) {
    if (isRenaming) return;
    if (isFolder) {
      wikiUi.toggleFolder(item.id);
    } else if (isFile) {
      onSelectFile?.(item.id);
    } else {
      onSelectPage?.(item.id);
    }
  }

  function handleContextMenu(e: MouseEvent) {
    e.preventDefault();
    e.stopPropagation();
    menuX = e.clientX;
    menuY = e.clientY;
    showMenu = true;
  }

  function handleRename() {
    showMenu = false;
    if (isFolder) renameValue = (item as WikiFolder).name;
    else if (isFile) renameValue = (item as WikiFile).file_name;
    else renameValue = (item as WikiPageMeta).title;
    onRenameStart?.(item.id, type);
  }

  function commitRename() {
    if (renameValue.trim()) {
      onRenameCommit?.(item.id, renameValue.trim(), type);
    } else {
      onRenameCancel?.();
    }
  }

  function handleRenameKeydown(e: KeyboardEvent) {
    if (e.key === "Enter") { e.stopPropagation(); commitRename(); return; }
    if (e.key === "Escape") { e.stopPropagation(); onRenameCancel?.(); return; }
    // Prevent space/other keys from triggering the parent button
    e.stopPropagation();
  }

  function handleDelete() {
    showMenu = false;
    if (isFolder) {
      onDeleteFolder?.(item.id);
    } else if (isFile) {
      onDeleteFile?.(item.id, (item as WikiFile).storage_path);
    } else {
      onDeletePage?.(item.id);
    }
  }

  function handleMove() {
    showMenu = false;
    if (isFolder) {
      onMoveFolderRequest?.(item.id);
    } else {
      onMovePageRequest?.(item.id);
    }
  }

  function handleDownload() {
    showMenu = false;
    if (isFile) onDownloadFile?.(item as WikiFile);
  }

  function handleNewPage() {
    showMenu = false;
    onNewPageInFolder?.(item.id);
  }

  function handleNewFolder() {
    showMenu = false;
    onNewFolderInFolder?.(item.id);
  }

  function handleShare() {
    showMenu = false;
    if (!isFile) onShareRequest?.(item.id, type as "folder" | "page");
  }

  function getFolderChildren(folderId: string) {
    return {
      folders: allFolders.filter((f) => f.parent_id === folderId),
      pages: allPages.filter((p) => p.folder_id === folderId),
      files: allFiles.filter((f) => f.folder_id === folderId),
    };
  }

  // Initialize rename value and focus input once when entering rename mode
  let wasRenaming = false;
  $effect(() => {
    if (isRenaming && !wasRenaming) {
      if (isFolder) renameValue = (item as WikiFolder).name;
      else if (isFile) renameValue = (item as WikiFile).file_name;
      else renameValue = (item as WikiPageMeta).title;
      requestAnimationFrame(() => {
        renameInputEl?.focus();
        renameInputEl?.select();
      });
    }
    wasRenaming = isRenaming;
  });

  // Close context menu on outside click
  $effect(() => {
    if (!showMenu) return;
    function handleClickOutside(e: MouseEvent) {
      if (menuEl && !menuEl.contains(e.target as Node)) {
        showMenu = false;
      }
    }
    function handleScroll() { showMenu = false; }

    document.addEventListener("click", handleClickOutside, true);
    document.addEventListener("contextmenu", handleClickOutside, true);
    document.addEventListener("scroll", handleScroll, true);
    return () => {
      document.removeEventListener("click", handleClickOutside, true);
      document.removeEventListener("contextmenu", handleClickOutside, true);
      document.removeEventListener("scroll", handleScroll, true);
    };
  });
</script>

<div class="relative" bind:this={rowEl} style="margin-left: {indentLeft};">
  <button
    class="flex h-8 w-full select-none items-center gap-1.5 text-[15px] transition-all duration-150
      {isActive ? 'text-accent hover:bg-accent/10' : isFolder ? 'text-sidebar-text/80 hover:bg-surface-hover/60 hover:text-sidebar-text' : 'text-sidebar-text/60 hover:bg-surface-hover/60 hover:text-sidebar-text'}
      {dragOver ? 'ring-1 ring-accent/50 bg-accent/5' : ''}"
    style="padding-left: 12px; padding-right: 8px;"
    onclick={handleClick}
    oncontextmenu={handleContextMenu}
    ondragenter={(e) => { if (isFolder) { e.preventDefault(); dragCounter++; dragOver = true; } }}
    ondragover={(e) => { if (isFolder) e.preventDefault(); }}
    ondragleave={() => { if (isFolder) { dragCounter--; if (dragCounter <= 0) { dragOver = false; dragCounter = 0; } } }}
    ondrop={(e) => {
      if (!isFolder) return;
      e.preventDefault();
      dragOver = false;
      dragCounter = 0;
      const droppedFiles = e.dataTransfer?.files;
      if (droppedFiles && droppedFiles.length > 0) {
        onUploadFiles?.(item.id, Array.from(droppedFiles));
      }
    }}
  >
    {#if isFolder}
      <span
        class="flex shrink-0 items-center justify-center transition-transform duration-150 {expanded ? 'rotate-90' : ''}"
      >
        <ChevronRight size={12} class="text-muted/30" />
      </span>
      {#if expanded}
        <FolderOpen size={18} class="shrink-0 text-muted/50" />
      {:else}
        <Folder size={18} class="shrink-0 text-muted/50" />
      {/if}
      {#if isRenaming}
        <!-- svelte-ignore a11y_autofocus -->
        <input
          bind:this={renameInputEl}
          bind:value={renameValue}
          onblur={commitRename}
          onkeydown={handleRenameKeydown}
          onkeyup={(e) => e.stopPropagation()}
          onclick={(e) => e.stopPropagation()}
          class="min-w-0 flex-1 rounded-sm bg-surface-hover/60 px-1 py-0.5 text-[15px] text-sidebar-text outline-none"
        />
      {:else}
        <span class="truncate">{(item as WikiFolder).name}</span>
        {#if sharedUsers.length > 0}
          <span class="ml-auto shrink-0" title="Shared with {sharedUsers.map(u => u.name).join(', ')}">
            <Users size={14} class="text-muted/60" />
          </span>
        {/if}
      {/if}
    {:else if isFile}
      <span class="w-[12px] shrink-0"></span>
      <svelte:component this={getFileIconComponent((item as WikiFile).mime_type)} size={18} class="shrink-0 {isActive ? 'text-accent' : 'text-muted/50'}" />
      {#if isRenaming}
        <!-- svelte-ignore a11y_autofocus -->
        <input
          bind:this={renameInputEl}
          bind:value={renameValue}
          onblur={commitRename}
          onkeydown={handleRenameKeydown}
          onkeyup={(e) => e.stopPropagation()}
          onclick={(e) => e.stopPropagation()}
          class="min-w-0 flex-1 rounded-sm bg-surface-hover/60 px-1 py-0.5 text-[15px] text-sidebar-text outline-none"
        />
      {:else}
        <span class="truncate">{(item as WikiFile).file_name}</span>
      {/if}
    {:else}
      <span class="w-[12px] shrink-0"></span>
      <FileText size={18} class="shrink-0 {isActive ? 'text-accent' : 'text-muted/50'}" />
      {#if isRenaming}
        <!-- svelte-ignore a11y_autofocus -->
        <input
          bind:this={renameInputEl}
          bind:value={renameValue}
          onblur={commitRename}
          onkeydown={handleRenameKeydown}
          onkeyup={(e) => e.stopPropagation()}
          onclick={(e) => e.stopPropagation()}
          class="min-w-0 flex-1 rounded-sm bg-surface-hover/60 px-1 py-0.5 text-[15px] text-sidebar-text outline-none"
        />
      {:else}
        <span class="truncate">{(item as WikiPageMeta).title}</span>
        {#if sharedUsers.length > 0}
          <div class="ml-auto flex shrink-0 items-center -space-x-1.5" title="Shared with {sharedUsers.map(u => u.name).join(', ')}">
            {#each sharedUsers.slice(0, 3) as user (user.id)}
              <span
                class="flex h-5 w-5 items-center justify-center rounded-full border border-surface/80 text-[10px] font-semibold leading-none"
                style="background-color: {avatarColor(user.name)}22; color: {avatarColor(user.name)};"
              >
                {user.name.charAt(0).toUpperCase()}
              </span>
            {/each}
            {#if sharedUsers.length > 3}
              <span class="flex h-5 w-5 items-center justify-center rounded-full border border-surface/80 bg-surface-hover text-[9px] text-muted">
                +{sharedUsers.length - 3}
              </span>
            {/if}
          </div>
        {/if}
      {/if}
    {/if}
  </button>

  <!-- Right-click context menu -->
  {#if showMenu}
    <div
      bind:this={menuEl}
      class="fixed z-50 min-w-[11rem] animate-dropdown-in rounded-md border border-surface-border bg-surface shadow-lg shadow-black/15 ring-1 ring-white/[0.07] py-0.5"
      style="left: {menuX}px; top: {menuY}px;"
    >
      {#if isFile}
        <!-- File context menu -->
        <button
          class="flex w-full items-center gap-2 px-2.5 py-1.5 text-left text-base text-muted transition-colors hover:bg-surface-hover/60 hover:text-sidebar-text"
          onclick={handleDownload}
        >
          <Download size={14} /> Download
        </button>
        {#if canEdit}
          <button
            class="flex w-full items-center gap-2 px-2.5 py-1.5 text-left text-base text-muted transition-colors hover:bg-surface-hover/60 hover:text-sidebar-text"
            onclick={handleRename}
          >
            <Pencil size={14} /> Rename
          </button>
          <div class="my-0.5 h-px bg-surface-border/30"></div>
          <button
            class="flex w-full items-center gap-2 px-2.5 py-1.5 text-left text-base text-muted transition-colors hover:bg-surface-hover/60 hover:text-red-400"
            onclick={handleDelete}
          >
            <Trash2 size={14} /> Delete
          </button>
        {/if}
      {:else}
        <!-- Folder / Page context menu -->
        {#if canEdit && isFolder}
          <button
            class="flex w-full items-center gap-2 px-2.5 py-1.5 text-left text-base text-muted transition-colors hover:bg-surface-hover/60 hover:text-sidebar-text"
            onclick={handleNewPage}
          >
            <FilePlus size={14} /> New page here
          </button>
          <button
            class="flex w-full items-center gap-2 px-2.5 py-1.5 text-left text-base text-muted transition-colors hover:bg-surface-hover/60 hover:text-sidebar-text"
            onclick={handleNewFolder}
          >
            <FolderPlus size={14} /> New folder here
          </button>
        {/if}
        {#if canShare}
          <button
            class="flex w-full items-center gap-2 px-2.5 py-1.5 text-left text-base text-muted transition-colors hover:bg-surface-hover/60 hover:text-sidebar-text"
            onclick={handleShare}
          >
            <Share2 size={14} /> Share...
          </button>
        {/if}
        {#if canEdit}
          <button
            class="flex w-full items-center gap-2 px-2.5 py-1.5 text-left text-base text-muted transition-colors hover:bg-surface-hover/60 hover:text-sidebar-text"
            onclick={handleRename}
          >
            <Pencil size={14} /> Rename
          </button>
          <button
            class="flex w-full items-center gap-2 px-2.5 py-1.5 text-left text-base text-muted transition-colors hover:bg-surface-hover/60 hover:text-sidebar-text"
            onclick={handleMove}
          >
            <FolderInput size={14} /> Move to...
          </button>
          <div class="my-0.5 h-px bg-surface-border/30"></div>
          <button
            class="flex w-full items-center gap-2 px-2.5 py-1.5 text-left text-base text-muted transition-colors hover:bg-surface-hover/60 hover:text-red-400"
            onclick={handleDelete}
          >
            <Trash2 size={14} /> Delete
          </button>
        {/if}
      {/if}
    </div>
  {/if}
</div>

{#if isFolder && expanded}
  <div transition:slide={{ duration: 150 }}>
    {#each childFolders as child (child.id)}
      {@const nested = getFolderChildren(child.id)}
      <WikiTreeItem
        type="folder"
        item={child}
        depth={depth + 1}
        {activePageId}
        {activeFileId}
        childFolders={nested.folders}
        childPages={nested.pages}
        childFiles={nested.files}
        {allFolders}
        {allPages}
        {allFiles}
        {canEdit}
        {canShare}
        {renamingId}
        {forceExpanded}
        {onSelectPage}
        {onSelectFile}
        {onRenameStart}
        {onRenameCommit}
        {onRenameCancel}
        {onDeleteFolder}
        {onDeletePage}
        {onDeleteFile}
        {onDownloadFile}
        {onUploadFiles}
        {onMovePageRequest}
        {onMoveFolderRequest}
        {onNewPageInFolder}
        {onNewFolderInFolder}
        {onShareRequest}
      />
    {/each}
    {#each childPages as child (child.id)}
      <WikiTreeItem
        type="page"
        item={child}
        depth={depth + 1}
        {activePageId}
        {activeFileId}
        {allFolders}
        {allPages}
        {allFiles}
        {canEdit}
        {canShare}
        {renamingId}
        {onSelectPage}
        {onSelectFile}
        {onRenameStart}
        {onRenameCommit}
        {onRenameCancel}
        {onDeletePage}
        {onDeleteFile}
        {onDownloadFile}
        {onUploadFiles}
        {onMovePageRequest}
        {onMoveFolderRequest}
        {onNewPageInFolder}
        {onNewFolderInFolder}
        {onShareRequest}
      />
    {/each}
    {#each childFiles as child (child.id)}
      <WikiTreeItem
        type="file"
        item={child}
        depth={depth + 1}
        {activePageId}
        {activeFileId}
        {allFolders}
        {allPages}
        {allFiles}
        {canEdit}
        {canShare}
        {renamingId}
        {onSelectPage}
        {onSelectFile}
        {onRenameStart}
        {onRenameCommit}
        {onRenameCancel}
        {onDeleteFolder}
        {onDeletePage}
        {onDeleteFile}
        {onDownloadFile}
        {onUploadFiles}
        {onMovePageRequest}
        {onMoveFolderRequest}
        {onNewPageInFolder}
        {onNewFolderInFolder}
        {onShareRequest}
      />
    {/each}
  </div>
{/if}

<style>
  @keyframes dropdown-in {
    from { opacity: 0; transform: scale(0.95) translateY(-4px); }
    to   { opacity: 1; transform: scale(1) translateY(0); }
  }
  :global(.animate-dropdown-in) {
    animation: dropdown-in 150ms ease-out;
  }
</style>
