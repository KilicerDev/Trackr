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
			if (e.key === 'Escape') {
				e.stopImmediatePropagation();
				e.stopPropagation();
				e.preventDefault();
				onClose();
			}
		}
		document.addEventListener('keydown', handleKeydown, true);
		return () => document.removeEventListener('keydown', handleKeydown, true);
	});
</script>

{#if open}
	<div
		role="dialog"
		aria-modal="true"
		class="modal-enter fixed inset-0 z-9999 flex items-center justify-center p-4"
	>
		<div class="absolute inset-0 bg-black/50"></div>
		<!-- Panel: same surface/border as app dropdowns and filter bar -->
		<div
			class="modal-panel relative w-full {maxWidth} overflow-visible rounded border border-surface-border bg-surface shadow-xl"
		>
			{#if children}
				{@render children()}
			{/if}
		</div>
	</div>
{/if}

<style>
	@keyframes modal-overlay-in {
		from { opacity: 0; }
		to { opacity: 1; }
	}
	@keyframes modal-panel-in {
		from { opacity: 0; transform: scale(0.97) translateY(6px); }
		to { opacity: 1; transform: scale(1) translateY(0); }
	}
	.modal-enter {
		animation: modal-overlay-in 150ms ease-out;
	}
	.modal-panel {
		animation: modal-panel-in 150ms ease-out;
	}
</style>
