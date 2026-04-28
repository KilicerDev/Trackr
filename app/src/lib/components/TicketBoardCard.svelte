<script lang="ts">
	import type { Ticket } from '$lib/stores/tickets.svelte';
	import { ticketStatusIcons, defaultStatusIcon } from '$lib/config/status-icons';
	import { tStatus, tPriority, tCategory } from '$lib/i18n/ticket-labels';

	interface Props {
		ticket: Ticket;
		selected?: boolean;
		showStatus?: boolean;
		onclick: () => void;
	}

	let { ticket, selected = false, showStatus = false, onclick }: Props = $props();

	const statusInfo = $derived(ticketStatusIcons[ticket.status] ?? defaultStatusIcon);
	const StatusIcon = $derived(statusInfo.icon);

	const priorityClass = $derived(
		ticket.priority === 'urgent' ? 'text-red-400'
			: ticket.priority === 'high' ? 'text-orange-400'
			: ticket.priority === 'medium' ? 'text-yellow-500'
			: ticket.priority === 'low' ? 'text-blue-400'
			: 'text-muted/30'
	);
</script>

<button
	class="mb-1.5 w-full cursor-pointer rounded border border-surface-border/50 bg-surface/50 px-3 py-2 text-left transition-all duration-150 hover:bg-surface/80 last:mb-0 {selected ? '!border-accent/50 !bg-accent/15' : ''}"
	{onclick}
>
	<div class="mb-1 flex items-center gap-1.5">
		<StatusIcon size={11} class={statusInfo.className} />
		{#if ticket.category}
			<span class="text-xs text-muted/50">{tCategory(ticket.category)}</span>
		{/if}
		<span class="ml-auto text-xs {priorityClass}">{tPriority(ticket.priority)}</span>
	</div>

	<p class="mb-1.5 line-clamp-2 text-base leading-snug text-sidebar-text">{ticket.subject}</p>

	{#if showStatus || ticket.agent}
		<div class="flex items-center gap-1.5">
			{#if showStatus}
				<span class="text-xs text-muted/40">{tStatus(ticket.status)}</span>
			{/if}
			<div class="flex-1"></div>
			{#if ticket.agent}
				<div class="flex shrink-0" title={ticket.agent.full_name}>
					{#if ticket.agent.avatar_url}
						<img src={ticket.agent.avatar_url} alt={ticket.agent.full_name} class="h-4 w-4 rounded-full object-cover" />
					{:else}
						<span class="flex h-4 w-4 items-center justify-center rounded-full bg-accent/10 text-4xs font-semibold text-accent">
							{ticket.agent.full_name.charAt(0)}
						</span>
					{/if}
				</div>
			{/if}
		</div>
	{/if}
</button>
