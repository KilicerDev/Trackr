<script lang="ts">
  import { GripVertical } from "@lucide/svelte";

  let { element = $bindable<HTMLElement | null>(null) }: {
    element?: HTMLElement | null;
  } = $props();
</script>

<div
  bind:this={element}
  class="wiki-editor-block-handle"
  role="button"
  tabindex="-1"
  aria-label="Drag block"
  title="Drag to reorder"
>
  <GripVertical size={14} />
</div>
