<script lang="ts">
  import {
    Heading1, Heading2, Heading3,
    List, ListOrdered, Quote, Code2, Table as TableIcon, Minus,
  } from "@lucide/svelte";
  import {
    wrapInHeadingCommand,
    wrapInBulletListCommand,
    wrapInOrderedListCommand,
    wrapInBlockquoteCommand,
    createCodeBlockCommand,
    insertHrCommand,
  } from "@milkdown/kit/preset/commonmark";
  import { insertTableCommand } from "@milkdown/kit/preset/gfm";

  export type SlashItem = {
    label: string;
    icon: typeof Heading1;
    keywords: string[];
    command: unknown;
    payload?: unknown;
  };

  const ALL_ITEMS: SlashItem[] = [
    { label: "Heading 1", icon: Heading1, keywords: ["h1", "heading1", "title"], command: wrapInHeadingCommand.key, payload: 1 },
    { label: "Heading 2", icon: Heading2, keywords: ["h2", "heading2"], command: wrapInHeadingCommand.key, payload: 2 },
    { label: "Heading 3", icon: Heading3, keywords: ["h3", "heading3"], command: wrapInHeadingCommand.key, payload: 3 },
    { label: "Bullet list", icon: List, keywords: ["ul", "bullet", "list", "unordered"], command: wrapInBulletListCommand.key },
    { label: "Numbered list", icon: ListOrdered, keywords: ["ol", "numbered", "ordered"], command: wrapInOrderedListCommand.key },
    { label: "Quote", icon: Quote, keywords: ["quote", "blockquote"], command: wrapInBlockquoteCommand.key },
    { label: "Code block", icon: Code2, keywords: ["code", "pre", "codeblock"], command: createCodeBlockCommand.key },
    { label: "Table", icon: TableIcon, keywords: ["table", "tbl"], command: insertTableCommand.key, payload: { row: 3, col: 2 } },
    { label: "Divider", icon: Minus, keywords: ["hr", "divider", "rule"], command: insertHrCommand.key },
  ];

  let {
    element = $bindable<HTMLElement | null>(null),
    visible,
    query,
    onPick,
    onClose,
  }: {
    element?: HTMLElement | null;
    visible: boolean;
    query: string;
    onPick: (item: SlashItem) => void;
    onClose: () => void;
  } = $props();

  let selectedIndex = $state(0);

  const filtered = $derived.by(() => {
    const q = query.trim().toLowerCase();
    if (!q) return ALL_ITEMS;
    return ALL_ITEMS.filter(
      (i) => i.label.toLowerCase().includes(q) || i.keywords.some((k) => k.startsWith(q))
    );
  });

  $effect(() => {
    // reset selection when query changes
    filtered;
    selectedIndex = 0;
  });

  $effect(() => {
    if (!visible) return;
    if (typeof window === "undefined") return;
    function onKey(e: KeyboardEvent) {
      if (!visible) return;
      if (e.key === "ArrowDown") {
        e.preventDefault();
        selectedIndex = (selectedIndex + 1) % Math.max(1, filtered.length);
      } else if (e.key === "ArrowUp") {
        e.preventDefault();
        selectedIndex = (selectedIndex - 1 + filtered.length) % Math.max(1, filtered.length);
      } else if (e.key === "Enter") {
        e.preventDefault();
        const item = filtered[selectedIndex];
        if (item) onPick(item);
      } else if (e.key === "Escape") {
        e.preventDefault();
        onClose();
      }
    }
    window.addEventListener("keydown", onKey, true);
    return () => window.removeEventListener("keydown", onKey, true);
  });
</script>

<div
  bind:this={element}
  class="wiki-editor-slash"
  role="listbox"
  aria-label="Insert block"
>
  {#if filtered.length === 0}
    <div class="wiki-editor-slash__empty">No matches</div>
  {:else}
    {#each filtered as item, i (item.label)}
      {@const Icon = item.icon}
      <button
        type="button"
        class="wiki-editor-slash__item"
        class:wiki-editor-slash__item--active={i === selectedIndex}
        role="option"
        aria-selected={i === selectedIndex}
        onmousedown={(e) => e.preventDefault()}
        onmouseenter={() => (selectedIndex = i)}
        onclick={() => onPick(item)}
      >
        <Icon size={14} />
        <span>{item.label}</span>
      </button>
    {/each}
  {/if}
</div>
