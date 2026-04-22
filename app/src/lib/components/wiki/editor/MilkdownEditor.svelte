<script lang="ts">
  import { browser } from "$app/environment";
  import { toggleLinkCommand } from "@milkdown/kit/preset/commonmark";
  import Modal from "$lib/components/Modal.svelte";
  import type { ActiveMarks, WikiEditorInstance } from "./use-editor";
  import SelectionToolbar from "./ui/SelectionToolbar.svelte";
  import SlashMenu, { type SlashItem } from "./ui/SlashMenu.svelte";
  import BlockHandle from "./ui/BlockHandle.svelte";
  import "./editor-styles.css";

  let {
    content = "",
    onchange,
    readonly = false,
  }: {
    content?: string;
    onchange?: (markdown: string) => void;
    readonly?: boolean;
  } = $props();

  let editorEl: HTMLDivElement | undefined = $state();
  let toolbarEl: HTMLElement | null = $state(null);
  let slashEl: HTMLElement | null = $state(null);
  let blockEl: HTMLElement | null = $state(null);
  let instance: WikiEditorInstance | null = null;
  let currentPageContent: string | null = null;

  let slashVisible = $state(false);
  let slashQuery = $state("");
  let activeMarks = $state<ActiveMarks>({ bold: false, italic: false, strike: false, code: false, link: false });

  let linkModalOpen = $state(false);
  let linkUrl = $state("");
  let linkInput: HTMLInputElement | undefined = $state();

  function handleCommand(command: unknown, payload?: unknown) {
    instance?.runCommand(command, payload);
  }

  function handleSlashPick(item: SlashItem) {
    instance?.runSlashItem(item.command, item.payload);
  }

  function handleSlashClose() {
    instance?.hideSlash();
  }

  function openLinkModal() {
    linkUrl = "";
    linkModalOpen = true;
    setTimeout(() => linkInput?.focus(), 0);
  }

  function confirmLink() {
    const href = linkUrl.trim();
    linkModalOpen = false;
    linkUrl = "";
    if (!href) return;
    instance?.runCommand(toggleLinkCommand.key, { href, title: "" });
  }

  function cancelLink() {
    linkModalOpen = false;
    linkUrl = "";
  }

  $effect(() => {
    if (!browser || !editorEl) return;

    let destroyed = false;
    let ready = false;
    currentPageContent = content;

    import("./use-editor").then(({ createWikiEditor }) => {
      if (destroyed) return;
      createWikiEditor({
        target: editorEl!,
        content: currentPageContent ?? "",
        onChange: (md) => { if (ready) onchange?.(md); },
        readonly,
        toolbarEl,
        slashEl,
        blockEl,
        onSlashChange: (visible, query) => {
          slashVisible = visible;
          slashQuery = query;
        },
        onActiveMarksChange: (marks) => {
          activeMarks = marks;
        },
      }).then((ed) => {
        if (destroyed) {
          ed.destroy();
          return;
        }
        instance = ed;
        ready = true;
      });
    });

    return () => {
      destroyed = true;
      instance?.destroy();
      instance = null;
    };
  });
</script>

<div class="wiki-editor" bind:this={editorEl}></div>

{#if !readonly}
  <SelectionToolbar
    bind:element={toolbarEl}
    dispatch={handleCommand}
    onRequestLink={openLinkModal}
    {activeMarks}
  />
  <SlashMenu
    bind:element={slashEl}
    visible={slashVisible}
    query={slashQuery}
    onPick={handleSlashPick}
    onClose={handleSlashClose}
  />
  <BlockHandle bind:element={blockEl} />

  <Modal open={linkModalOpen} onClose={cancelLink} maxWidth="max-w-md">
    <form
      class="flex flex-col gap-3 p-4"
      onsubmit={(e) => { e.preventDefault(); confirmLink(); }}
    >
      <label class="text-sm font-medium text-sidebar-text" for="wiki-link-url">
        Insert link
      </label>
      <input
        id="wiki-link-url"
        bind:this={linkInput}
        bind:value={linkUrl}
        type="url"
        placeholder="https://…"
        autocomplete="off"
        class="h-8 rounded-sm border border-surface-border bg-surface-hover/40 px-2.5 text-sm text-sidebar-text placeholder:text-muted/30 focus:bg-surface-hover/60"
      />
      <div class="mt-1 flex items-center justify-end gap-2">
        <button
          type="button"
          class="h-7 cursor-pointer rounded-sm bg-surface-hover/40 px-3 text-sm text-sidebar-text transition-colors hover:bg-surface-hover/60"
          onclick={cancelLink}
        >
          Cancel
        </button>
        <button
          type="submit"
          class="h-7 cursor-pointer rounded-sm bg-accent px-3 text-sm font-medium text-white transition-colors hover:bg-accent/90"
        >
          Insert
        </button>
      </div>
    </form>
  </Modal>
{/if}
