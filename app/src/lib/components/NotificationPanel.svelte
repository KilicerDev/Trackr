<script lang="ts">
	import { goto } from '$app/navigation';
	import { notificationCenter } from '$lib/stores/notificationCenter.svelte';
	import { notifications } from '$lib/stores/notifications.svelte';
	import { api } from '$lib/api';
	import { localizeHref } from '$lib/paraglide/runtime';
	import { CheckCheck, Loader2 } from '@lucide/svelte';
	import NotificationPanelItem from './NotificationPanelItem.svelte';
	import type { AppNotification } from '$lib/api/notifications';

	async function handleNavigate(n: AppNotification) {
		if (!n.is_read) {
			await notificationCenter.markRead(n.id);
		}
		notificationCenter.close();

		if (n.resource_type === 'ticket' && n.resource_id) {
			await goto(localizeHref(`/tickets?id=${n.resource_id}`));
		} else if (n.resource_type === 'task' && n.resource_id) {
			try {
				const task = await api.tasks.getById(n.resource_id);
				if (task?.project_id) {
					await goto(localizeHref(`/projects/${task.project_id}?task=${n.resource_id}`));
				}
			} catch {
				notifications.add('error', 'Could not open task');
			}
		}
	}

	async function handleRemove(id: string) {
		try {
			await notificationCenter.remove(id);
		} catch (e: unknown) {
			const msg = e instanceof Error ? e.message : 'Unknown error';
			notifications.add('error', 'Failed to remove notification', msg);
		}
	}

	async function handleMarkAllRead() {
		try {
			await notificationCenter.markAllRead();
		} catch (e: unknown) {
			const msg = e instanceof Error ? e.message : 'Unknown error';
			notifications.add('error', 'Failed to mark all as read', msg);
		}
	}

	function handleScroll(e: Event) {
		const el = e.target as HTMLElement;
		if (el.scrollTop + el.clientHeight >= el.scrollHeight - 40) {
			notificationCenter.loadMore();
		}
	}
</script>

<div class="absolute right-0 top-full z-30 mt-1.5 w-80 origin-top-right animate-dropdown-in rounded-md border border-surface-border/70 bg-surface shadow-lg shadow-black/20">
	<div class="flex items-center justify-between px-3 py-2">
		<h3 class="text-base font-semibold text-sidebar-text">Notifications</h3>
		{#if notificationCenter.unreadCount > 0}
			<button
				type="button"
				class="text-xs text-muted/50 transition-colors hover:text-accent"
				onclick={handleMarkAllRead}
			>
				Mark all read
			</button>
		{/if}
	</div>

	<div class="max-h-[360px] overflow-y-auto border-t border-surface-border/40" onscroll={handleScroll}>
		{#if notificationCenter.loading && notificationCenter.items.length === 0}
			<div class="flex items-center justify-center py-10">
				<Loader2 size={16} class="animate-spin text-muted/40" />
			</div>
		{:else if notificationCenter.items.length === 0}
			<p class="py-10 text-center text-sm text-muted/40">All caught up</p>
		{:else}
			{#each notificationCenter.items as n (n.id)}
				<NotificationPanelItem
					notification={n}
					onNavigate={handleNavigate}
					onRemove={handleRemove}
				/>
			{/each}
			{#if notificationCenter.loading}
				<div class="flex items-center justify-center py-2">
					<Loader2 size={14} class="animate-spin text-muted/40" />
				</div>
			{/if}
			{#if !notificationCenter.hasMore && notificationCenter.items.length > 0}
				<p class="py-2 text-center text-2xs text-muted/30">End of notifications</p>
			{/if}
		{/if}
	</div>
</div>

<style>
	@keyframes dropdown-in {
		from { opacity: 0; transform: scale(0.95) translateY(-4px); }
		to { opacity: 1; transform: scale(1) translateY(0); }
	}
	:global(.animate-dropdown-in) {
		animation: dropdown-in 150ms ease-out;
	}
</style>
