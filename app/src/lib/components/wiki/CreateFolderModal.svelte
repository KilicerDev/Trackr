<script lang="ts">
  import Modal from "$lib/components/Modal.svelte";

  let {
    open = false,
    onClose,
    onSubmit,
  }: {
    open: boolean;
    onClose: () => void;
    onSubmit: (name: string) => void;
  } = $props();

  let name = $state("");
  let inputEl: HTMLInputElement | undefined = $state();

  function handleSubmit() {
    const trimmed = name.trim();
    if (!trimmed) return;
    onSubmit(trimmed);
    name = "";
  }

  function handleKeydown(e: KeyboardEvent) {
    if (e.key === "Enter") {
      e.preventDefault();
      handleSubmit();
    }
  }

  $effect(() => {
    if (open && inputEl) {
      inputEl.focus();
    }
  });
</script>

<Modal {open} {onClose} maxWidth="max-w-sm">
  <div class="p-4">
    <h3 class="mb-3 text-base font-semibold text-sidebar-text">New Folder</h3>
    <input
      bind:this={inputEl}
      bind:value={name}
      onkeydown={handleKeydown}
      placeholder="Folder name"
      class="w-full rounded-sm bg-surface-hover/40 px-2.5 py-1.5 text-base text-sidebar-text outline-none placeholder:text-muted/30 focus:bg-surface-hover/60"
    />
    <div class="mt-3 flex justify-end gap-2">
      <button
        class="text-sm text-muted/50 transition-colors hover:text-accent"
        onclick={onClose}
      >
        Cancel
      </button>
      <button
        class="flex h-7 items-center gap-1 rounded-sm bg-accent px-2.5 text-sm font-medium text-white transition-all duration-150 hover:bg-accent/90 disabled:opacity-30"
        disabled={!name.trim()}
        onclick={handleSubmit}
      >
        Create
      </button>
    </div>
  </div>
</Modal>
