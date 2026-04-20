<script lang="ts">
  import { goto } from "$app/navigation";
  import { page } from "$app/stores";
  import { localizeHref } from "$lib/paraglide/runtime";
  import { wikiStore, type WikiFolder, type WikiPageMeta, type WikiFile } from "$lib/stores/wiki.svelte";
  import { auth } from "$lib/stores/auth.svelte";
  import { notifications } from "$lib/stores/notifications.svelte";
  import { isAllowedMimeType, MAX_FILE_SIZE, formatFileSize } from "$lib/config/attachments";
  import { api } from "$lib/api";
  import { Plus, FolderPlus, Search, PanelLeftClose, PanelLeftOpen } from "@lucide/svelte";
  import WikiTreeItem from "./WikiTreeItem.svelte";
  import MoveToFolderModal from "./MoveToFolderModal.svelte";
  import WikiShareModal from "./WikiShareModal.svelte";
  import ConfirmDialog from "$lib/components/ConfirmDialog.svelte";

  let { collapsed = $bindable(false) }: { collapsed?: boolean } = $props();

  let searchQuery = $state("");
  let renamingId = $state<string | null>(null);

  // Move modal state
  let moveModalOpen = $state(false);
  let moveTargetId = $state<string | null>(null);
  let moveTargetType = $state<"folder" | "page">("page");
  let moveCurrentFolderId = $state<string | null>(null);

  // Delete confirm state
  let deleteConfirmOpen = $state(false);
  let deleteTargetId = $state<string | null>(null);
  let deleteTargetType = $state<"folder" | "page" | "file">("page");
  let deleteTargetName = $state("");
  let deleteTargetStoragePath = $state<string | null>(null);
  let deleteLoading = $state(false);

  // Share modal state
  let shareModalOpen = $state(false);
  let shareTargetId = $state("");
  let shareTargetType = $state<"folder" | "page">("page");
  let shareTargetName = $state("");

  const isAdmin = $derived(wikiStore.isWikiAdmin);

  const activePageId = $derived(($page.params as Record<string, string>)?.pageId ?? null);
  const activeFileId = $derived(($page.params as Record<string, string>)?.fileId ?? null);

  const isSearching = $derived(searchQuery.trim().length > 0);
  const query = $derived(searchQuery.toLowerCase().trim());

  // When searching: flat list of ALL matching items. Matching folders show with their full children.
  // Matching pages show flat at depth 0.
  const rootFolders = $derived(
    isSearching
      ? wikiStore.folders.filter((f) => f.name.toLowerCase().includes(query))
      : wikiStore.folders.filter((f) => !f.parent_id)
  );

  const rootPages = $derived(
    isSearching
      ? wikiStore.pages.filter((p) => p.title.toLowerCase().includes(query))
      : wikiStore.pages.filter((p) => !p.folder_id)
  );

  const searchFiles = $derived(
    isSearching
      ? wikiStore.files.filter((f) => f.file_name.toLowerCase().includes(query))
      : []
  );

  function getFolderChildren(folderId: string) {
    return {
      folders: wikiStore.folders.filter((f) => f.parent_id === folderId),
      pages: wikiStore.pages.filter((p) => p.folder_id === folderId),
      files: wikiStore.files.filter((f) => f.folder_id === folderId),
    };
  }

  async function handleNewPage() {
    const orgId = auth.organizationId;
    const userId = auth.user?.id;
    if (!orgId || !userId) return;

    const newPage = await wikiStore.createPage({
      organization_id: orgId,
      created_by: userId,
    });
    if (newPage) {
      goto(localizeHref(`/wiki/${newPage.id}`));
    }
  }

  async function handleNewPageInFolder(folderId: string) {
    const parentFolder = wikiStore.folders.find((f) => f.id === folderId);
    const orgId = parentFolder?.organization_id ?? auth.organizationId;
    const userId = auth.user?.id;
    if (!orgId || !userId) return;

    try {
      const newPage = await wikiStore.createPage({
        organization_id: orgId,
        created_by: userId,
        folder_id: folderId,
      });
      if (newPage) {
        goto(localizeHref(`/wiki/${newPage.id}`));
      }
    } catch (e) {
      console.error("[Wiki] Failed to create page:", e);
      alert("Failed to create page: " + (e instanceof Error ? e.message : JSON.stringify(e)) + "\norgId=" + orgId + " folderId=" + folderId + " userId=" + userId);
    }
  }

  async function handleNewFolderInFolder(parentId: string) {
    const parentFolder = wikiStore.folders.find((f) => f.id === parentId);
    const orgId = parentFolder?.organization_id ?? auth.organizationId;
    const userId = auth.user?.id;
    if (!orgId || !userId) return;

    try {
      const folder = await wikiStore.createFolder({
        name: "New Folder",
        organization_id: orgId,
        parent_id: parentId,
        created_by: userId,
      });
      if (folder) {
        renamingId = folder.id;
      }
    } catch (e) {
      console.error("[Wiki] Failed to create folder:", e);
      alert("Failed to create folder: " + (e instanceof Error ? e.message : JSON.stringify(e)));
    }
  }

  async function handleNewFolder() {
    const orgId = auth.organizationId;
    const userId = auth.user?.id;
    if (!orgId || !userId) return;

    const folder = await wikiStore.createFolder({
      name: "New Folder",
      organization_id: orgId,
      created_by: userId,
    });
    if (folder) {
      renamingId = folder.id;
    }
  }

  function handleSelectPage(id: string) {
    goto(localizeHref(`/wiki/${id}`));
  }

  function handleRenameStart(id: string, _type: "folder" | "page" | "file") {
    renamingId = id;
  }

  async function handleRenameCommit(id: string, value: string, itemType: "folder" | "page" | "file") {
    if (itemType === "folder") {
      await wikiStore.updateFolder(id, { name: value });
    } else if (itemType === "file") {
      await wikiStore.renameFile(id, value);
    } else {
      await wikiStore.updatePage(id, { title: value, updated_by: auth.user?.id });
    }
    renamingId = null;
  }

  function handleRenameCancel() {
    renamingId = null;
  }

  function handleDeleteFolder(id: string) {
    const folder = wikiStore.folders.find((f) => f.id === id);
    deleteTargetId = id;
    deleteTargetType = "folder";
    deleteTargetName = folder?.name ?? "Folder";
    deleteConfirmOpen = true;
  }

  function handleDeletePage(id: string) {
    const page = wikiStore.pages.find((p) => p.id === id);
    deleteTargetId = id;
    deleteTargetType = "page";
    deleteTargetName = page?.title ?? "Page";
    deleteConfirmOpen = true;
  }

  function handleSelectFile(id: string) {
    goto(localizeHref(`/wiki/file/${id}`));
  }

  function handleDeleteFile(id: string, storagePath: string) {
    const file = wikiStore.files.find((f) => f.id === id);
    deleteTargetId = id;
    deleteTargetType = "file";
    deleteTargetName = file?.file_name ?? "File";
    deleteTargetStoragePath = storagePath;
    deleteConfirmOpen = true;
  }

  async function handleDownloadFile(file: WikiFile) {
    try {
      const url = await api.wiki.files.getSignedUrl(file.storage_path);
      const a = document.createElement("a");
      a.href = url;
      a.download = file.file_name;
      a.click();
    } catch {
      notifications.add("error", "Failed to download file");
    }
  }

  async function handleUploadFiles(folderId: string, droppedFiles: File[]) {
    const orgId = auth.organizationId;
    const userId = auth.user?.id;
    if (!orgId || !userId) return;

    for (const file of droppedFiles) {
      if (!isAllowedMimeType(file.type)) {
        notifications.add("error", `${file.name}: file type not allowed`);
        continue;
      }
      if (file.size > MAX_FILE_SIZE) {
        notifications.add("error", `${file.name}: exceeds ${formatFileSize(MAX_FILE_SIZE)} limit`);
        continue;
      }
      const n = notifications.action(`Uploading ${file.name}...`);
      try {
        await wikiStore.uploadFile(file, folderId, orgId, userId);
        n.success(`Uploaded ${file.name}`);
      } catch (e) {
        n.error(`Failed to upload ${file.name}`, e instanceof Error ? e.message : undefined);
      }
    }
  }

  async function confirmDelete() {
    if (!deleteTargetId) return;
    deleteLoading = true;
    try {
      if (deleteTargetType === "folder") {
        await wikiStore.deleteFolder(deleteTargetId);
      } else if (deleteTargetType === "file" && deleteTargetStoragePath) {
        const wasActive = deleteTargetId === activeFileId;
        await wikiStore.deleteFile(deleteTargetId, deleteTargetStoragePath);
        if (wasActive) goto(localizeHref("/wiki"));
      } else {
        const wasActive = deleteTargetId === activePageId;
        await wikiStore.deletePage(deleteTargetId);
        if (wasActive) goto(localizeHref("/wiki"));
      }
      deleteConfirmOpen = false;
      deleteTargetId = null;
      deleteTargetStoragePath = null;
    } catch (e) {
      console.error("[Wiki] Delete failed:", e);
      alert("Failed to delete: " + (e instanceof Error ? e.message : JSON.stringify(e)));
    } finally {
      deleteLoading = false;
    }
  }

  function handleShareRequest(id: string, type: "folder" | "page") {
    shareTargetId = id;
    shareTargetType = type;
    shareTargetName = type === "folder"
      ? wikiStore.folders.find((f) => f.id === id)?.name ?? "Folder"
      : wikiStore.pages.find((p) => p.id === id)?.title ?? "Page";
    shareModalOpen = true;
  }

  function handleMovePageRequest(id: string) {
    const pg = wikiStore.pages.find((p) => p.id === id);
    moveTargetId = id;
    moveTargetType = "page";
    moveCurrentFolderId = pg?.folder_id ?? null;
    moveModalOpen = true;
  }

  function handleMoveFolderRequest(id: string) {
    const folder = wikiStore.folders.find((f) => f.id === id);
    moveTargetId = id;
    moveTargetType = "folder";
    moveCurrentFolderId = folder?.parent_id ?? null;
    moveModalOpen = true;
  }

  async function handleMoveSubmit(folderId: string | null) {
    if (!moveTargetId) return;
    if (moveTargetType === "page") {
      await wikiStore.updatePage(moveTargetId, {
        folder_id: folderId,
        updated_by: auth.user?.id,
      });
    } else {
      // Prevent moving a folder into itself or its descendants
      if (folderId === moveTargetId) return;
      await wikiStore.updateFolder(moveTargetId, { parent_id: folderId });
    }
    moveModalOpen = false;
    moveTargetId = null;
  }

  // Folders available for the move modal (exclude the target folder and its descendants for folder moves)
  const movableFolders = $derived.by(() => {
    if (moveTargetType === "page") return wikiStore.folders;
    // For folder moves, exclude the folder itself and all its descendants
    const excluded = new Set<string>();
    function collectDescendants(id: string) {
      excluded.add(id);
      for (const f of wikiStore.folders) {
        if (f.parent_id === id) collectDescendants(f.id);
      }
    }
    if (moveTargetId) collectDescendants(moveTargetId);
    return wikiStore.folders.filter((f) => !excluded.has(f.id));
  });


</script>

<aside
  class="flex h-full shrink-0 flex-col border-r border-surface-border bg-surface/30 overflow-hidden transition-[width] duration-200 ease-out"
  style="width: {collapsed ? '40px' : '280px'}"
>
  <!-- Collapsed: just the expand button -->
  {#if collapsed}
    <button
      class="flex h-10 w-10 items-center justify-center text-muted/40 transition-all duration-150 hover:bg-surface-hover hover:text-sidebar-text"
      title="Expand wiki sidebar"
      onclick={() => collapsed = false}
    >
      <PanelLeftOpen size={16} />
    </button>
  {:else}
    <!-- Header -->
    <div class="flex h-10 items-center justify-between px-3" style="min-width: 280px;">
      <span class="text-xs font-medium tracking-[0.08em] uppercase text-sidebar-label/70">Wiki</span>
      <div class="flex items-center gap-0.5">
        {#if isAdmin}
          <button
            class="flex h-7 w-7 items-center justify-center rounded-sm text-muted/40 transition-all duration-150 hover:bg-surface-hover hover:text-sidebar-text"
            title="New page"
            onclick={handleNewPage}
          >
            <Plus size={16} />
          </button>
          <button
            class="flex h-7 w-7 items-center justify-center rounded-sm text-muted/40 transition-all duration-150 hover:bg-surface-hover hover:text-sidebar-text"
            title="New folder"
            onclick={handleNewFolder}
          >
            <FolderPlus size={16} />
          </button>
        {/if}
        <button
          class="flex h-7 w-7 items-center justify-center rounded-sm text-muted/40 transition-all duration-150 hover:bg-surface-hover hover:text-sidebar-text"
          title="Collapse sidebar"
          onclick={() => collapsed = true}
        >
          <PanelLeftClose size={16} />
        </button>
      </div>
    </div>

    <!-- Search -->
    <div class="px-2.5 pb-1.5" style="min-width: 280px;">
      <div class="relative">
        <Search size={14} class="pointer-events-none absolute left-2 top-1/2 -translate-y-1/2 text-muted/30" />
        <input
          type="text"
          placeholder="Search wiki..."
          bind:value={searchQuery}
          class="w-full rounded-sm bg-surface-hover/40 py-1 pl-7 pr-2 text-base text-sidebar-text outline-none placeholder:text-muted/30 focus:bg-surface-hover/60"
        />
      </div>
    </div>

    <!-- Tree -->
    <div class="min-h-0 flex-1 overflow-y-auto py-1" style="min-width: 280px;">
      {#each rootFolders as folder (folder.id)}
        {@const children = getFolderChildren(folder.id)}
        <WikiTreeItem
          type="folder"
          item={folder}
          depth={0}
          {activePageId}
          {activeFileId}
          childFolders={children.folders}
          childPages={children.pages}
          childFiles={children.files}
          allFolders={wikiStore.folders}
          allPages={wikiStore.pages}
          allFiles={wikiStore.files}
          canEdit={isAdmin || wikiStore.getEffectiveAccess(folder, "folder") === "read_write"}
          canShare={isAdmin}
          {renamingId}
          forceExpanded={isSearching}
          onSelectPage={handleSelectPage}
          onSelectFile={handleSelectFile}
          onRenameStart={handleRenameStart}
          onRenameCommit={handleRenameCommit}
          onRenameCancel={handleRenameCancel}
          onDeleteFolder={handleDeleteFolder}
          onDeletePage={handleDeletePage}
          onDeleteFile={handleDeleteFile}
          onDownloadFile={handleDownloadFile}
          onUploadFiles={handleUploadFiles}
          onMovePageRequest={handleMovePageRequest}
          onMoveFolderRequest={handleMoveFolderRequest}
          onNewPageInFolder={handleNewPageInFolder}
          onNewFolderInFolder={handleNewFolderInFolder}
          onShareRequest={handleShareRequest}
        />
      {/each}

      {#each rootPages as p (p.id)}
        <WikiTreeItem
          type="page"
          item={p}
          depth={0}
          {activePageId}
          {activeFileId}
          allFolders={wikiStore.folders}
          allPages={wikiStore.pages}
          allFiles={wikiStore.files}
          canEdit={isAdmin || wikiStore.getEffectiveAccess(p, "page") === "read_write"}
          canShare={isAdmin}
          {renamingId}
          onSelectPage={handleSelectPage}
          onSelectFile={handleSelectFile}
          onRenameStart={handleRenameStart}
          onRenameCommit={handleRenameCommit}
          onRenameCancel={handleRenameCancel}
          onDeletePage={handleDeletePage}
          onDeleteFile={handleDeleteFile}
          onDownloadFile={handleDownloadFile}
          onUploadFiles={handleUploadFiles}
          onMovePageRequest={handleMovePageRequest}
          onMoveFolderRequest={handleMoveFolderRequest}
          onNewPageInFolder={handleNewPageInFolder}
          onNewFolderInFolder={handleNewFolderInFolder}
          onShareRequest={handleShareRequest}
        />
      {/each}

      {#each searchFiles as f (f.id)}
        <WikiTreeItem
          type="file"
          item={f}
          depth={0}
          {activePageId}
          {activeFileId}
          allFolders={wikiStore.folders}
          allPages={wikiStore.pages}
          allFiles={wikiStore.files}
          canEdit={isAdmin || wikiStore.getEffectiveAccess({ id: f.id, folder_id: f.folder_id }, "page") === "read_write"}
          canShare={isAdmin}
          {renamingId}
          onSelectPage={handleSelectPage}
          onSelectFile={handleSelectFile}
          onRenameStart={handleRenameStart}
          onRenameCommit={handleRenameCommit}
          onRenameCancel={handleRenameCancel}
          onDeleteFile={handleDeleteFile}
          onDownloadFile={handleDownloadFile}
          onUploadFiles={handleUploadFiles}
          onShareRequest={handleShareRequest}
        />
      {/each}

      {#if !rootFolders.length && !rootPages.length && !searchFiles.length && !wikiStore.loading}
        <div class="px-3 py-6 text-center text-xs text-muted/40">
          No pages yet
        </div>
      {/if}
    </div>
  {/if}
</aside>

<!-- Move to folder modal -->
<MoveToFolderModal
  open={moveModalOpen}
  folders={movableFolders}
  currentFolderId={moveCurrentFolderId}
  onClose={() => { moveModalOpen = false; moveTargetId = null; }}
  onSubmit={handleMoveSubmit}
/>

<!-- Share modal -->
{#if isAdmin}
  <WikiShareModal
    open={shareModalOpen}
    targetId={shareTargetId}
    targetType={shareTargetType}
    targetName={shareTargetName}
    organizationId={auth.organizationId ?? ""}
    onClose={() => shareModalOpen = false}
  />
{/if}

<!-- Delete confirm -->
<ConfirmDialog
  open={deleteConfirmOpen}
  title={`Delete ${deleteTargetType === 'folder' ? 'Folder' : deleteTargetType === 'file' ? 'File' : 'Page'}`}
  message={`Are you sure you want to delete "${deleteTargetName}"? This action cannot be undone.`}
  loading={deleteLoading}
  onConfirm={confirmDelete}
  onCancel={() => { deleteConfirmOpen = false; deleteTargetId = null; deleteTargetStoragePath = null; }}
/>
