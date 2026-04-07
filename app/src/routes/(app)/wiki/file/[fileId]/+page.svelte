<svelte:head><title>Wiki – Trackr</title></svelte:head>

<script lang="ts">
  import { page } from "$app/stores";
  import { wikiStore } from "$lib/stores/wiki.svelte";
  import WikiFileView from "$lib/components/wiki/WikiFileView.svelte";
  import { Loader2 } from "@lucide/svelte";

  const fileId = $derived(($page.params as Record<string, string>).fileId);
  const file = $derived(wikiStore.files.find((f) => f.id === fileId));
</script>

{#if !file && wikiStore.loading}
  <div class="flex h-full items-center justify-center">
    <Loader2 size={16} class="animate-spin text-muted/30" />
  </div>
{:else if file}
  <WikiFileView {file} />
{:else}
  <div class="flex h-full items-center justify-center">
    <p class="text-base text-red-400/60">File not found</p>
  </div>
{/if}
