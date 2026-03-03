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

	const btnSecondary =
		'border border-surface-border bg-surface px-4 py-2 text-xs font-medium text-sidebar-text transition-colors hover:border-sidebar-icon/30 hover:bg-surface-hover disabled:opacity-50';
	const btnDestructive =
		'bg-red-500 px-4 py-2 text-xs font-medium text-white shadow-sm transition-colors hover:bg-red-600 disabled:opacity-50';
	const btnConfirm =
		'bg-accent px-4 py-2 text-xs font-medium text-white shadow-sm transition-colors hover:bg-accent/90 disabled:opacity-50';
</script>

<Modal {open} onClose={onCancel} maxWidth="max-w-sm">
	<div class="border-b border-surface-border px-5 py-3.5">
		<h2 class="text-[13px] font-semibold text-sidebar-text">{title}</h2>
	</div>
	<div class="px-5 py-4">
		<p class="text-xs leading-relaxed text-sidebar-text/80">{message}</p>
	</div>
	<div class="flex justify-end gap-2 border-t border-surface-border px-5 py-3.5">
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
