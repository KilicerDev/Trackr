<script lang="ts">
	import Modal from './Modal.svelte';

	interface Props {
		open: boolean;
		title?: string;
		message: string;
		confirmLabel?: string;
		loading?: boolean;
		destructive?: boolean;
		onConfirm: () => void;
		onCancel: () => void;
	}

	let {
		open = false,
		title = 'Confirm Delete',
		message,
		confirmLabel = 'Delete',
		loading = false,
		destructive = true,
		onConfirm,
		onCancel
	}: Props = $props();

	import { btnPrimary as btnConfirm, btnSecondary, btnDestructive } from '$lib/styles/ui';
</script>

<Modal {open} onClose={onCancel} maxWidth="max-w-sm">
	<div class="border-b border-surface-border px-4 py-3">
		<h2 class="text-lg font-semibold text-sidebar-text">{title}</h2>
	</div>
	<div class="p-4">
		<p class="text-base leading-relaxed text-sidebar-text/80">{message}</p>
	</div>
	<div class="flex justify-end gap-2 border-t border-surface-border px-4 py-3">
		<button type="button" class={btnSecondary} disabled={loading} onclick={onCancel}>
			Cancel
		</button>
		<button
			type="button"
			class={destructive ? btnDestructive : btnConfirm}
			disabled={loading}
			onclick={onConfirm}
		>
			{loading ? 'Deleting...' : confirmLabel}
		</button>
	</div>
</Modal>
