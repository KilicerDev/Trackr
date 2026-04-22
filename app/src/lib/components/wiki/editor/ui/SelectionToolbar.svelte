<script lang="ts">
  import { Bold, Italic, Strikethrough, Code, Link as LinkIcon } from "@lucide/svelte";
  import {
    toggleStrongCommand,
    toggleEmphasisCommand,
    toggleInlineCodeCommand,
    toggleLinkCommand,
  } from "@milkdown/kit/preset/commonmark";
  import { toggleStrikethroughCommand } from "@milkdown/kit/preset/gfm";

  let { element = $bindable<HTMLElement | null>(null), dispatch }: {
    element?: HTMLElement | null;
    dispatch: (command: unknown, payload?: unknown) => void;
  } = $props();

  function promptForHref(): string | null {
    if (typeof window === "undefined") return null;
    const url = window.prompt("URL");
    if (!url) return null;
    return url;
  }
</script>

<div
  bind:this={element}
  class="wiki-editor-tooltip"
  role="toolbar"
  aria-label="Text formatting"
>
  <button
    type="button"
    class="wiki-editor-tooltip__btn"
    title="Bold (⌘B)"
    aria-label="Bold"
    onmousedown={(e) => e.preventDefault()}
    onclick={() => dispatch(toggleStrongCommand.key)}
  >
    <Bold size={14} />
  </button>
  <button
    type="button"
    class="wiki-editor-tooltip__btn"
    title="Italic (⌘I)"
    aria-label="Italic"
    onmousedown={(e) => e.preventDefault()}
    onclick={() => dispatch(toggleEmphasisCommand.key)}
  >
    <Italic size={14} />
  </button>
  <button
    type="button"
    class="wiki-editor-tooltip__btn"
    title="Strikethrough"
    aria-label="Strikethrough"
    onmousedown={(e) => e.preventDefault()}
    onclick={() => dispatch(toggleStrikethroughCommand.key)}
  >
    <Strikethrough size={14} />
  </button>
  <button
    type="button"
    class="wiki-editor-tooltip__btn"
    title="Inline code"
    aria-label="Inline code"
    onmousedown={(e) => e.preventDefault()}
    onclick={() => dispatch(toggleInlineCodeCommand.key)}
  >
    <Code size={14} />
  </button>
  <button
    type="button"
    class="wiki-editor-tooltip__btn"
    title="Link"
    aria-label="Link"
    onmousedown={(e) => e.preventDefault()}
    onclick={() => {
      const href = promptForHref();
      if (href) dispatch(toggleLinkCommand.key, { href, title: "" });
    }}
  >
    <LinkIcon size={14} />
  </button>
</div>
