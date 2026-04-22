<script lang="ts">
  import { Bold, Italic, Strikethrough, Code, Link as LinkIcon } from "@lucide/svelte";
  import {
    toggleStrongCommand,
    toggleEmphasisCommand,
    toggleInlineCodeCommand,
  } from "@milkdown/kit/preset/commonmark";
  import { toggleStrikethroughCommand } from "@milkdown/kit/preset/gfm";
  import type { ActiveMarks } from "../use-editor";

  let {
    element = $bindable<HTMLElement | null>(null),
    dispatch,
    onRequestLink,
    activeMarks,
  }: {
    element?: HTMLElement | null;
    dispatch: (command: unknown, payload?: unknown) => void;
    onRequestLink: () => void;
    activeMarks: ActiveMarks;
  } = $props();
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
    class:wiki-editor-tooltip__btn--active={activeMarks.bold}
    title="Bold (⌘B)"
    aria-label="Bold"
    aria-pressed={activeMarks.bold}
    onmousedown={(e) => e.preventDefault()}
    onclick={() => dispatch(toggleStrongCommand.key)}
  >
    <Bold size={14} />
  </button>
  <button
    type="button"
    class="wiki-editor-tooltip__btn"
    class:wiki-editor-tooltip__btn--active={activeMarks.italic}
    title="Italic (⌘I)"
    aria-label="Italic"
    aria-pressed={activeMarks.italic}
    onmousedown={(e) => e.preventDefault()}
    onclick={() => dispatch(toggleEmphasisCommand.key)}
  >
    <Italic size={14} />
  </button>
  <button
    type="button"
    class="wiki-editor-tooltip__btn"
    class:wiki-editor-tooltip__btn--active={activeMarks.strike}
    title="Strikethrough"
    aria-label="Strikethrough"
    aria-pressed={activeMarks.strike}
    onmousedown={(e) => e.preventDefault()}
    onclick={() => dispatch(toggleStrikethroughCommand.key)}
  >
    <Strikethrough size={14} />
  </button>
  <button
    type="button"
    class="wiki-editor-tooltip__btn"
    class:wiki-editor-tooltip__btn--active={activeMarks.code}
    title="Inline code"
    aria-label="Inline code"
    aria-pressed={activeMarks.code}
    onmousedown={(e) => e.preventDefault()}
    onclick={() => dispatch(toggleInlineCodeCommand.key)}
  >
    <Code size={14} />
  </button>
  <button
    type="button"
    class="wiki-editor-tooltip__btn"
    class:wiki-editor-tooltip__btn--active={activeMarks.link}
    title="Link"
    aria-label="Link"
    aria-pressed={activeMarks.link}
    onmousedown={(e) => e.preventDefault()}
    onclick={onRequestLink}
  >
    <LinkIcon size={14} />
  </button>
</div>
