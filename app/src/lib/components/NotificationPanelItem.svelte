<script lang="ts">
	import {
		Ticket,
		UserCheck,
		CircleCheckBig,
		MessageSquare,
		ClipboardList,
		RefreshCw,
		AlertTriangle,
		Trash2,
	} from '@lucide/svelte';
	import type { AppNotification } from '$lib/api/notifications';

	interface Props {
		notification: AppNotification;
		onNavigate: (n: AppNotification) => void;
		onRemove: (id: string) => void;
	}

	let { notification, onNavigate, onRemove }: Props = $props();

	function timeAgo(dateStr: string): string {
		const diff = Date.now() - new Date(dateStr).getTime();
		const mins = Math.floor(diff / 60000);
		if (mins < 1) return 'now';
		if (mins < 60) return `${mins}m`;
		const hours = Math.floor(mins / 60);
		if (hours < 24) return `${hours}h`;
		const days = Math.floor(hours / 24);
		if (days < 30) return `${days}d`;
		return new Date(dateStr).toLocaleDateString('de-DE', {
			day: '2-digit',
			month: '2-digit',
		});
	}

	const actorName = $derived(
		(notification.actor as { full_name?: string } | null)?.full_name ?? 'System'
	);
</script>

<div
	role="button"
	tabindex="0"
	class="group flex cursor-pointer items-start gap-2.5 px-3 py-2 transition-all duration-100 hover:bg-surface-hover/40 {notification.is_read ? 'opacity-50' : ''}"
	onclick={() => onNavigate(notification)}
	onkeydown={(e) => { if (e.key === 'Enter' || e.key === ' ') onNavigate(notification); }}
>
	<!-- Unread dot -->
	{#if !notification.is_read}
		<span class="mt-1.5 h-1.5 w-1.5 shrink-0 rounded-full bg-accent"></span>
	{:else}
		<span class="mt-1.5 h-1.5 w-1.5 shrink-0"></span>
	{/if}

	<!-- Icon -->
	<div class="mt-0.5 shrink-0 text-muted/40">
		{#if notification.type === 'ticket_created'}
			<Ticket size={13} />
		{:else if notification.type === 'ticket_assigned'}
			<UserCheck size={13} />
		{:else if notification.type === 'ticket_resolved'}
			<CircleCheckBig size={13} />
		{:else if notification.type === 'ticket_message' || notification.type === 'task_comment'}
			<MessageSquare size={13} />
		{:else if notification.type === 'task_assigned'}
			<ClipboardList size={13} />
		{:else if notification.type === 'task_status_change'}
			<RefreshCw size={13} />
		{:else if notification.type === 'sla_breach'}
			<AlertTriangle size={13} />
		{:else}
			<Ticket size={13} />
		{/if}
	</div>

	<!-- Content -->
	<div class="min-w-0 flex-1">
		<div class="flex items-center gap-2">
			<p class="truncate text-sm font-medium text-sidebar-text">{notification.title}</p>
			<span class="ml-auto shrink-0 font-mono text-2xs text-muted/30">{timeAgo(notification.created_at)}</span>
		</div>
		{#if notification.body}
			<p class="mt-0.5 truncate text-xs text-muted/50">{notification.body}</p>
		{/if}
		<p class="mt-0.5 text-2xs text-muted/30">{actorName}</p>
	</div>

	<!-- Delete -->
	<button
		type="button"
		class="mt-0.5 shrink-0 rounded-sm p-0.5 text-muted/20 opacity-0 transition-opacity group-hover:opacity-100 hover:text-red-400"
		title="Remove"
		onclick={(e) => { e.stopPropagation(); onRemove(notification.id); }}
	>
		<Trash2 size={11} />
	</button>
</div>
