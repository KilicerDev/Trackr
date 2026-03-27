<script lang="ts">
  import { beforeNavigate, goto } from "$app/navigation";
  import WikiSidebar from "$lib/components/wiki/WikiSidebar.svelte";
  import UnsavedChangesModal from "$lib/components/wiki/UnsavedChangesModal.svelte";
  import { wikiStore } from "$lib/stores/wiki.svelte";
  import { auth } from "$lib/stores/auth.svelte";

  let { children } = $props();
  let sidebarCollapsed = $state(false);

  // Unsaved changes navigation guard
  let showUnsavedModal = $state(false);
  let pendingNavigationUrl = $state<string | null>(null);

  $effect(() => {
    const orgId = auth.organizationId;
    if (orgId) {
      // Wiki admin = platform org member with admin or owner role
      wikiStore.setWikiAdmin(auth.isPlatformMember && (auth.isOwner || auth.isAdmin));
      wikiStore.loadTree(orgId);
    }
  });

  beforeNavigate(({ cancel, to }) => {
    if (wikiStore.saveStatus === "unsaved" && !showUnsavedModal) {
      cancel();
      pendingNavigationUrl = to?.url?.pathname ?? null;
      showUnsavedModal = true;
    }
  });

  function handleDiscard() {
    showUnsavedModal = false;
    wikiStore.saveStatus = "saved";
    if (pendingNavigationUrl) {
      goto(pendingNavigationUrl);
      pendingNavigationUrl = null;
    }
  }

  async function handleSave() {
    if (wikiStore.flushSave) {
      await wikiStore.flushSave();
    }
    showUnsavedModal = false;
    if (pendingNavigationUrl) {
      goto(pendingNavigationUrl);
      pendingNavigationUrl = null;
    }
  }

  function handleCancel() {
    showUnsavedModal = false;
    pendingNavigationUrl = null;
  }
</script>

<div class="flex h-full">
  <WikiSidebar bind:collapsed={sidebarCollapsed} />
  <div class="min-w-0 flex-1 overflow-y-auto">
    {@render children()}
  </div>
</div>

<UnsavedChangesModal
  open={showUnsavedModal}
  onDiscard={handleDiscard}
  onSave={handleSave}
  onCancel={handleCancel}
/>
