<script lang="ts">
  import Modal from "$lib/components/Modal.svelte";
  import { Folder, CornerDownRight } from "@lucide/svelte";
  import type { WikiFolder } from "$lib/stores/wiki.svelte";

  let {
    open = false,
    folders = [],
    currentFolderId = null,
    onClose,
    onSubmit,
  }: {
    open: boolean;
    folders: WikiFolder[];
    currentFolderId?: string | null;
    onClose: () => void;
    onSubmit: (folderId: string | null) => void;
  } = $props();

  // Build nested folder tree for display
  type FolderNode = WikiFolder & { children: FolderNode[]; depth: number };

  const tree = $derived.by(() => {
    const map = new Map<string | null, FolderNode[]>();
    for (const f of folders) {
      const parentKey = f.parent_id ?? null;
      if (!map.has(parentKey)) map.set(parentKey, []);
      map.get(parentKey)!.push({ ...f, children: [], depth: 0 });
    }
    function buildTree(parentId: string | null, depth: number): FolderNode[] {
      const nodes = map.get(parentId) ?? [];
      return nodes.map((n) => ({
        ...n,
        depth,
        children: buildTree(n.id, depth + 1),
      }));
    }
    return buildTree(null, 0);
  });

  function flattenTree(nodes: FolderNode[]): FolderNode[] {
    const result: FolderNode[] = [];
    for (const n of nodes) {
      result.push(n);
      result.push(...flattenTree(n.children));
    }
    return result;
  }

  const flatFolders = $derived(flattenTree(tree));
</script>

<Modal {open} {onClose} maxWidth="max-w-sm">
  <div class="p-4">
    <h3 class="mb-3 text-base font-semibold text-sidebar-text">Move to folder</h3>

    <div class="max-h-[240px] overflow-y-auto rounded border border-surface-border/40">
      <!-- Root option -->
      <button
        class="flex w-full items-center gap-2 px-2.5 py-1.5 text-left text-sm transition-colors hover:bg-surface-hover/60
          {currentFolderId === null ? 'text-accent font-medium' : 'text-muted hover:text-sidebar-text'}"
        onclick={() => onSubmit(null)}
      >
        <CornerDownRight size={12} class="text-muted/40" />
        Root (no folder)
      </button>

      {#each flatFolders as folder (folder.id)}
        <button
          class="flex w-full items-center gap-2 py-1.5 text-left text-sm transition-colors hover:bg-surface-hover/60
            {folder.id === currentFolderId ? 'text-accent font-medium' : 'text-muted hover:text-sidebar-text'}"
          style="padding-left: {12 + folder.depth * 16}px; padding-right: 10px;"
          onclick={() => onSubmit(folder.id)}
        >
          <Folder size={12} class="shrink-0 text-muted/40" />
          <span class="truncate">{folder.name}</span>
          {#if folder.id === currentFolderId}
            <span class="ml-auto text-2xs text-muted/30">current</span>
          {/if}
        </button>
      {/each}
    </div>

    <div class="mt-3 flex justify-end">
      <button
        class="text-sm text-muted/50 transition-colors hover:text-accent"
        onclick={onClose}
      >
        Cancel
      </button>
    </div>
  </div>
</Modal>
