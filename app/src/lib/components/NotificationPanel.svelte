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

<div class="absolute right-0 top-full z-50 mt-1 w-96 border border-surface-border bg-surface shadow-xl">
	<div class="flex items-center justify-between border-b border-surface-border px-4 py-2.5">
		<h3 class="text-sm font-semibold text-sidebar-text">Notifications</h3>
		{#if notificationCenter.unreadCount > 0}
			<button
				type="button"
				class="flex items-center gap-1 text-[11px] text-muted transition-colors hover:text-sidebar-text"
				onclick={handleMarkAllRead}
			>
				<CheckCheck size={13} />
				Mark all as read
			</button>
		{/if}
	</div>

	<div class="max-h-[420px] overflow-y-auto" onscroll={handleScroll}>
		{#if notificationCenter.loading && notificationCenter.items.length === 0}
			<div class="flex items-center justify-center py-12">
				<Loader2 size={20} class="animate-spin text-muted" />
			</div>
		{:else if notificationCenter.items.length === 0}
			<div class="py-12 text-center">
				<p class="text-xs text-muted">You're all caught up</p>
			</div>
		{:else}
			{#each notificationCenter.items as n (n.id)}
				<NotificationPanelItem
					notification={n}
					onNavigate={handleNavigate}
					onRemove={handleRemove}
				/>
			{/each}
			{#if notificationCenter.loading}
				<div class="flex items-center justify-center py-3">
					<Loader2 size={16} class="animate-spin text-muted" />
				</div>
			{/if}
			{#if !notificationCenter.hasMore && notificationCenter.items.length > 0}
				<p class="py-3 text-center text-[10px] text-muted">No more notifications</p>
			{/if}
		{/if}
	</div>
</div>
