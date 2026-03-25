<script lang="ts">
	import { LoaderCircle, CircleX, CircleCheckBig, X, Copy } from '@lucide/svelte';
	import type { Notification } from '$lib/stores/notifications.svelte';

	interface Props {
		notification: Notification;
		onDismiss: () => void;
	}

	let { notification, onDismiss }: Props = $props();

	let copied = $state(false);

	const borderColor = $derived(
		notification.type === 'loading'
			? 'border-accent'
			: notification.type === 'error'
				? 'border-red-500'
				: 'border-green-500'
	);

	async function copyDescription() {
		if (!notification.description) return;
		try {
			await navigator.clipboard.writeText(notification.description);
			copied = true;
			setTimeout(() => (copied = false), 1500);
		} catch {
		// no-op
	}
	}
</script>

<div
	class="pointer-events-auto relative flex w-80 gap-3 rounded border-l-2 {borderColor} border border-surface-border/40 bg-surface px-4 py-3 shadow-lg shadow-black/20"
>
	<div class="shrink-0 pt-0.5">
		{#if notification.type === 'loading'}
			<LoaderCircle class="h-4 w-4 animate-spin text-accent" />
		{:else if notification.type === 'error'}
			<CircleX class="h-4 w-4 text-red-500" />
		{:else}
			<CircleCheckBig class="h-4 w-4 text-green-500" />
		{/if}
	</div>

	<div class="min-w-0 flex-1">
		<p class="text-base font-semibold text-sidebar-text">{notification.message}</p>
		{#if notification.description}
			<p class="mt-0.5 line-clamp-2 text-sm text-muted">{notification.description}</p>
		{/if}
	</div>

	<div class="flex shrink-0 items-start gap-0.5">
		{#if notification.type === 'error' && notification.description}
			<button
				type="button"
				class="flex h-6 w-6 items-center justify-center rounded-sm text-muted/40 transition-all duration-150 hover:bg-surface-hover hover:text-sidebar-text"
				onclick={copyDescription}
				title={copied ? 'Copied' : 'Copy error'}
			>
				<Copy class="h-3.5 w-3.5" />
			</button>
		{/if}
		<button
			type="button"
			class="flex h-6 w-6 items-center justify-center rounded-sm text-muted/40 transition-all duration-150 hover:bg-surface-hover hover:text-sidebar-text"
			onclick={onDismiss}
			title="Dismiss"
		>
			<X class="h-3.5 w-3.5" />
		</button>
	</div>
</div>
