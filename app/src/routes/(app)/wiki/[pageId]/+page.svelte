<svelte:head><title>Wiki – Trackr</title></svelte:head>

<script lang="ts">
  import { page } from "$app/stores";
  import { wikiStore } from "$lib/stores/wiki.svelte";
  import WikiPageView from "$lib/components/wiki/WikiPageView.svelte";
  import { Loader2 } from "@lucide/svelte";

  const pageId = $derived(($page.params as Record<string, string>).pageId);

  $effect(() => {
    if (pageId) {
      wikiStore.loadPage(pageId);
    }
  });
</script>

{#if wikiStore.loading && !wikiStore.activePage}
  <div class="flex h-full items-center justify-center">
    <Loader2 size={16} class="animate-spin text-muted/30" />
  </div>
{:else if wikiStore.activePage && wikiStore.activePage.id === pageId}
  <WikiPageView page={wikiStore.activePage} />
{:else if wikiStore.error}
  <div class="flex h-full items-center justify-center">
    <p class="text-base text-red-400/60">{wikiStore.error}</p>
  </div>
{/if}
