<script lang="ts">
	import type { Ticket } from '$lib/stores/tickets.svelte';
	import { ticketStatusIcons, defaultStatusIcon } from '$lib/config/status-icons';
	import { tStatus, tPriority, tCategory } from '$lib/i18n/ticket-labels';

	type Props = {
		ticket: Ticket;
		selected?: boolean;
		onclick?: () => void;
	};

	let { ticket, selected = false, onclick }: Props = $props();

	const priorityColors: Record<string, string> = {
		urgent: 'text-red-400',
		high: 'text-orange-400',
		medium: 'text-yellow-500',
		low: 'text-blue-400'
	};

	function formatDate(dateStr: unknown): string {
		if (!dateStr || typeof dateStr !== 'string') return '';
		const d = new Date(dateStr);
		if (isNaN(d.getTime())) return '';
		const day = d.getDate().toString().padStart(2, '0');
		const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
		return `${day} ${months[d.getMonth()]}`;
	}

	const statusInfo = $derived(ticketStatusIcons[ticket.status] ?? defaultStatusIcon);
	const StatusIcon = $derived(statusInfo.icon);
	const updatedAt = $derived((ticket as Record<string, unknown>).updated_at as string | undefined);
</script>

<button
	data-ticket-id={ticket.id}
	class="group flex w-full items-center gap-4 px-3 py-[7px] text-left transition-all duration-100 {selected ? 'bg-accent/8' : 'hover:bg-surface-hover/40'}"
	{onclick}
>
	<StatusIcon size={12} class="shrink-0 {statusInfo.className}" />

	<span class="min-w-0 flex-1 truncate text-base text-sidebar-text">
		{ticket.subject}
	</span>

	{#if ticket.category}
		<span class="shrink-0 whitespace-nowrap text-xs text-muted/50">
			{tCategory(ticket.category)}
		</span>
	{/if}

	<span class="w-14 shrink-0 text-right text-xs font-medium {priorityColors[ticket.priority] ?? 'text-muted/40'}">
		{tPriority(ticket.priority)}
	</span>

	<span class="w-24 shrink-0 whitespace-nowrap text-right text-xs text-muted/50">
		{tStatus(ticket.status)}
	</span>

	{#if ticket.agent}
		<div class="flex shrink-0 items-center gap-1.5" title={ticket.agent.full_name}>
			{#if ticket.agent.avatar_url}
				<img src={ticket.agent.avatar_url} alt={ticket.agent.full_name} class="h-4 w-4 rounded-full object-cover" />
			{:else}
				<span class="flex h-4 w-4 items-center justify-center rounded-full bg-accent/10 text-2xs font-semibold text-accent">
					{ticket.agent.full_name.charAt(0)}
				</span>
			{/if}
		</div>
	{:else}
		<div class="w-4 shrink-0"></div>
	{/if}

	{#if formatDate(updatedAt)}
		<span class="w-12 shrink-0 text-right font-mono text-xs text-muted/30">{formatDate(updatedAt)}</span>
	{:else}
		<div class="w-12 shrink-0"></div>
	{/if}
</button>
