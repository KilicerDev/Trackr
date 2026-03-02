<script lang="ts">
	import { onMount } from 'svelte';
	import { auth } from '$lib/stores/auth.svelte';
	import { ticketStore } from '$lib/stores/tickets.svelte';
	import TaskRow from '$lib/components/TaskRow.svelte';

	onMount(() => {
		const orgId = auth.organizationId;
		if (orgId) {
			ticketStore.load(orgId);
		}
	});
</script>

<div class="mx-auto w-full max-w-[1200px]">
	{#if ticketStore.loading}
		<p class="px-4 py-8 text-center text-sm text-gray-400">Loading...</p>
	{:else if ticketStore.error}
		<p class="px-4 py-8 text-center text-sm text-red-500">{ticketStore.error}</p>
	{:else}
		{#if auth.can('tickets', 'create')}
			<div class="flex justify-end px-4 py-3">
				<button
					class="rounded bg-accent px-3 py-1.5 text-xs font-medium text-white transition-colors hover:bg-accent/90"
				>
					New Ticket
				</button>
			</div>
		{/if}

		<div class="border-t border-gray-100">
			{#each ticketStore.items as ticket (ticket.id)}
				<TaskRow
					task={{
						id: ticket.id,
						title: ticket.subject,
						status: ticket.status,
						priority: ticket.priority,
						type: 'task',
						short_id: ticket.id.slice(0, 6),
						project_id: '',
						created_by: '',
						project: null,
						assignments: [],
						created_by_user: null,
						start_at: ticket.created_at,
						end_at: ticket.resolved_at
					}}
				/>
			{/each}
		</div>

		<p class="px-4 py-3 text-xs text-gray-400">{ticketStore.count} tickets total</p>
	{/if}
</div>
