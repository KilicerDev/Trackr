<script lang="ts">
  import { browser } from "$app/environment";
  import type { WikiEditorInstance } from "./use-editor";
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
  let instance: WikiEditorInstance | null = null;
  let currentPageContent: string | null = null;

  $effect(() => {
    if (!browser || !editorEl) return;

    let destroyed = false;
    currentPageContent = content;

    import("./use-editor").then(({ createWikiEditor }) => {
      if (destroyed) return;
      createWikiEditor({
        target: editorEl!,
        content: currentPageContent ?? "",
        onChange: (md) => onchange?.(md),
        readonly,
      }).then((ed) => {
        if (destroyed) {
          ed.destroy();
          return;
        }
        instance = ed;
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
