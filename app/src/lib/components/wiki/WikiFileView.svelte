<script lang="ts">
  import { Download, Loader2, FileText, Image, Table, Presentation, File as FileIcon } from "@lucide/svelte";
  import { isImageType, isPdfType, formatFileSize } from "$lib/config/attachments";
  import { api } from "$lib/api";
  import type { WikiFile } from "$lib/api/wiki";

  let { file }: { file: WikiFile } = $props();

  let signedUrl = $state<string | null>(null);
  let loading = $state(true);

  $effect(() => {
    const f = file;
    signedUrl = null;
    loading = true;
    api.wiki.files.getSignedUrl(f.storage_path)
      .then((url) => { signedUrl = url; })
      .catch(() => { signedUrl = null; })
      .finally(() => { loading = false; });
  });

  async function handleDownload() {
    const url = signedUrl || (await api.wiki.files.getSignedUrl(file.storage_path));
    const a = document.createElement("a");
    a.href = url;
    a.download = file.file_name;
    a.click();
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

  function getIconComponent(mime: string) {
    if (isImageType(mime)) return Image;
    if (isPdfType(mime)) return FileText;
    if (mime.includes("spreadsheet") || mime.includes("excel") || mime === "text/csv") return Table;
    if (mime.includes("presentation") || mime.includes("powerpoint")) return Presentation;
    return FileIcon;
  }
</script>

<div class="mx-auto w-full max-w-[740px] py-6 px-6">
  <!-- Header -->
  <div class="mb-4">
    <div class="flex items-start justify-between gap-3">
      <div class="flex items-center gap-2 min-w-0">
        <svelte:component this={getIconComponent(file.mime_type)} size={18} class="shrink-0 text-muted/50" />
        <h1 class="truncate text-xl font-semibold text-sidebar-text">{file.file_name}</h1>
      </div>
      <button
        class="flex shrink-0 items-center gap-1.5 rounded-sm px-2.5 py-1.5 text-sm text-muted/60 transition-all duration-150 hover:bg-surface-hover/60 hover:text-sidebar-text"
        onclick={handleDownload}
      >
        <Download size={14} />
        Download
      </button>
    </div>
    <div class="mt-1 flex items-center gap-2 text-xs text-muted/40">
      <span>{formatFileSize(file.file_size)}</span>
      <span class="text-muted/20">&middot;</span>
      {#if file.uploader}
        <span>Uploaded by {file.uploader.full_name}</span>
        <span class="text-muted/20">&middot;</span>
      {/if}
      <span>{formatTimeAgo(file.created_at)}</span>
    </div>
  </div>

  <!-- Divider -->
  <div class="mb-4 h-px bg-surface-border/30"></div>

  <!-- Preview -->
  {#if loading}
    <div class="flex h-64 items-center justify-center">
      <Loader2 size={16} class="animate-spin text-muted/30" />
    </div>
  {:else if signedUrl && isImageType(file.mime_type)}
    <div class="flex justify-center">
      <img src={signedUrl} alt={file.file_name} class="max-w-full rounded" />
    </div>
  {:else if signedUrl && isPdfType(file.mime_type)}
    <iframe src={signedUrl} title={file.file_name} class="h-[80vh] w-full rounded border-0 bg-white"></iframe>
  {:else}
    <!-- Fallback: metadata card -->
    <div class="flex flex-col items-center gap-4 rounded-md border border-surface-border/30 bg-surface/40 py-12 px-6">
      <svelte:component this={getIconComponent(file.mime_type)} size={48} class="text-muted/30" />
      <div class="text-center">
        <p class="text-md font-medium text-sidebar-text">{file.file_name}</p>
        <p class="mt-1 text-xs text-muted/40">{formatFileSize(file.file_size)} &middot; {file.mime_type}</p>
      </div>
      <button
        class="flex items-center gap-1.5 rounded-md bg-accent/10 px-4 py-2 text-sm font-medium text-accent transition-all duration-150 hover:bg-accent/20"
        onclick={handleDownload}
      >
        <Download size={14} />
        Download file
      </button>
    </div>
  {/if}
</div>
