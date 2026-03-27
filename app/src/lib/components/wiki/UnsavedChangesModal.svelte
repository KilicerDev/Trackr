<script lang="ts">
  import Modal from "$lib/components/Modal.svelte";
  import { AlertTriangle } from "@lucide/svelte";

  let {
    open = false,
    onDiscard,
    onSave,
    onCancel,
  }: {
    open: boolean;
    onDiscard: () => void;
    onSave: () => void;
    onCancel: () => void;
  } = $props();
</script>

<Modal {open} onClose={onCancel} maxWidth="max-w-sm">
  <div class="p-4">
    <div class="flex items-center gap-2 mb-3">
      <AlertTriangle size={14} class="text-accent" />
      <h3 class="text-base font-semibold text-sidebar-text">Unsaved changes</h3>
    </div>
    <p class="text-sm text-muted mb-4">
      You have unsaved changes. Do you want to save before leaving?
    </p>
    <div class="flex justify-end gap-2">
      <button
        class="text-sm text-muted/50 transition-colors hover:text-red-400"
        onclick={onDiscard}
      >
        Discard
      </button>
      <button
        class="text-sm text-muted/50 transition-colors hover:text-accent"
        onclick={onCancel}
      >
        Cancel
      </button>
      <button
        class="flex h-7 items-center gap-1 rounded-sm bg-accent px-2.5 text-sm font-medium text-white transition-all duration-150 hover:bg-accent/90"
        onclick={onSave}
      >
        Save
      </button>
    </div>
  </div>
</Modal>
