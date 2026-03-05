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
		if (mins < 1) return 'just now';
		if (mins < 60) return `${mins}m ago`;
		const hours = Math.floor(mins / 60);
		if (hours < 24) return `${hours}h ago`;
		const days = Math.floor(hours / 24);
		if (days < 30) return `${days}d ago`;
		return new Date(dateStr).toLocaleDateString('de-DE', {
			day: '2-digit',
			month: '2-digit',
			year: 'numeric',
		});
	}

	const actorName = $derived(
		(notification.actor as { full_name?: string } | null)?.full_name ?? 'System'
	);
</script>

<div
	role="button"
	tabindex="0"
	class="group flex items-start gap-3 px-4 py-3 transition-colors hover:bg-sidebar-hover-bg cursor-pointer {notification.is_read
		? 'opacity-60'
		: ''}"
	onclick={() => onNavigate(notification)}
	onkeydown={(e) => {
		if (e.key === 'Enter' || e.key === ' ') onNavigate(notification);
	}}
>
	{#if !notification.is_read}
		<span class="mt-2 h-2 w-2 shrink-0 rounded-full bg-blue-500"></span>
	{:else}
		<span class="mt-2 h-2 w-2 shrink-0"></span>
	{/if}

	<div class="mt-0.5 shrink-0 text-muted">
		{#if notification.type === 'ticket_created'}
			<Ticket size={16} />
		{:else if notification.type === 'ticket_assigned'}
			<UserCheck size={16} />
		{:else if notification.type === 'ticket_resolved'}
			<CircleCheckBig size={16} />
		{:else if notification.type === 'ticket_message' || notification.type === 'task_comment'}
			<MessageSquare size={16} />
		{:else if notification.type === 'task_assigned'}
			<ClipboardList size={16} />
		{:else if notification.type === 'task_status_change'}
			<RefreshCw size={16} />
		{:else if notification.type === 'sla_breach'}
			<AlertTriangle size={16} />
		{:else}
			<Ticket size={16} />
		{/if}
	</div>

	<div class="min-w-0 flex-1">
		<p class="text-xs font-medium text-sidebar-text truncate">{notification.title}</p>
		{#if notification.body}
			<p class="mt-0.5 text-[11px] text-muted truncate">{notification.body}</p>
		{/if}
		<p class="mt-1 text-[10px] text-muted">
			{actorName} &middot; {timeAgo(notification.created_at)}
		</p>
	</div>

	<button
		type="button"
		class="mt-1 shrink-0 p-1 text-muted opacity-0 transition-opacity hover:text-red-400 group-hover:opacity-100"
		title="Remove"
		onclick={(e) => { e.stopPropagation(); onRemove(notification.id); }}
	>
		<Trash2 size={13} />
	</button>
</div>
