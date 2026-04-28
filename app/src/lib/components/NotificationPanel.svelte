<script lang="ts">
	import { goto } from '$app/navigation';
	import { notificationCenter } from '$lib/stores/notificationCenter.svelte';
	import { notifications } from '$lib/stores/notifications.svelte';
	import { auth } from '$lib/stores/auth.svelte';
	import { api } from '$lib/api';
	import { localizeHref } from '$lib/paraglide/runtime';
	import { CheckCheck, Loader2, Mail, MailX } from '@lucide/svelte';
	import NotificationPanelItem from './NotificationPanelItem.svelte';
	import type { AppNotification } from '$lib/api/notifications';

	async function handleNavigate(n: AppNotification) {
		if (!n.is_read) {
			await notificationCenter.markRead(n.id);
		}
		notificationCenter.close();

		if (n.resource_type === 'ticket' && n.resource_id) {
			// Clients live under /c — they don't have access to the staff /tickets route.
			if (auth.isClient) {
				await goto(localizeHref(`/c?ticket=${n.resource_id}`));
			} else {
				const tab = n.type === 'ticket_message' ? '&tab=messages' : '';
				await goto(localizeHref(`/tickets?id=${n.resource_id}${tab}`));
			}
		} else if (n.resource_type === 'task' && n.resource_id) {
			try {
				const task = await api.tasks.getById(n.resource_id);
				if (task?.project_id) {
					const tab = n.type === 'task_comment' ? '&tab=comments' : '';
					await goto(localizeHref(`/projects/${task.project_id}?task=${n.resource_id}${tab}`));
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

	async function handleToggleEmail() {
		try {
			await notificationCenter.toggleEmailNotifications(!notificationCenter.emailEnabled);
		} catch (e: unknown) {
			const msg = e instanceof Error ? e.message : 'Unknown error';
			notifications.add('error', 'Failed to update email preference', msg);
		}
	}
</script>

<div class="absolute right-0 top-full z-30 mt-1.5 w-80 origin-top-right animate-dropdown-in rounded-md border border-surface-border bg-surface shadow-lg shadow-black/15 ring-1 ring-white/[0.07]">
	<div class="flex items-center justify-between px-3 py-2">
		<h3 class="text-base font-semibold text-sidebar-text">Notifications{#if notificationCenter.unreadCount > 0} <span class="text-sm font-normal text-muted">({notificationCenter.unreadCount})</span>{/if}</h3>
		<div class="flex items-center gap-3">
			<button
				type="button"
				class="flex items-center gap-1 rounded px-1.5 py-0.5 text-2xs transition-colors {notificationCenter.emailEnabled ? 'text-accent' : 'text-muted/70'} hover:bg-surface-hover"
				title={notificationCenter.emailEnabled ? 'Disable email notifications' : 'Enable email notifications'}
				onclick={handleToggleEmail}
			>
				{#if notificationCenter.emailEnabled}
					<Mail size={12} />
					<span>On</span>
				{:else}
					<MailX size={12} />
					<span>Off</span>
				{/if}
			</button>
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
		from { opacity: 0; }
		to { opacity: 1; }
	}
	:global(.animate-dropdown-in) {
		animation: dropdown-in 150ms ease-out;
	}
</style>
