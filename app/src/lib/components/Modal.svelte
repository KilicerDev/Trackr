<script lang="ts">
	import type { Snippet } from 'svelte';

	interface Props {
		open: boolean;
		onClose: () => void;
		maxWidth?: string;
		children?: Snippet;
	}

	let { open = false, onClose, maxWidth = 'max-w-lg', children }: Props = $props();

	$effect(() => {
		if (!open) return;
		function handleKeydown(e: KeyboardEvent) {
			if (e.key === 'Escape') onClose();
		}
		document.addEventListener('keydown', handleKeydown);
		return () => document.removeEventListener('keydown', handleKeydown);
	});
</script>

{#if open}
	<div
		role="dialog"
		aria-modal="true"
		class="fixed inset-0 z-50 flex items-center justify-center p-4"
	>
		<div class="absolute inset-0 bg-black/50"></div>
		<!-- Panel: same surface/border as app dropdowns and filter bar -->
		<div
			class="relative max-h-[90vh] w-full {maxWidth} overflow-y-auto border border-surface-border bg-surface shadow-xl"
		>
			{#if children}
				{@render children()}
			{/if}
		</div>
	</div>
{/if}
