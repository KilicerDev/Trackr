<script lang="ts">
  import { browser } from "$app/environment";
  import type { WikiEditorInstance } from "./use-editor";
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

  function handleCommand(command: unknown, payload?: unknown) {
    instance?.runCommand(command, payload);
  }

  function handleSlashPick(item: SlashItem) {
    instance?.runSlashItem(item.command, item.payload);
  }

  function handleSlashClose() {
    instance?.hideSlash();
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
  <SelectionToolbar bind:element={toolbarEl} dispatch={handleCommand} />
  <SlashMenu
    bind:element={slashEl}
    visible={slashVisible}
    query={slashQuery}
    onPick={handleSlashPick}
    onClose={handleSlashClose}
  />
  <BlockHandle bind:element={blockEl} />
{/if}
