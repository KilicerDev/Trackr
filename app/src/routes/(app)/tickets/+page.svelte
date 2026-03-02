<script lang="ts">
	import { onMount } from 'svelte';
	import { auth } from '$lib/stores/auth.svelte';
	import { ticketStore } from '$lib/stores/tickets.svelte';
	import { api } from '$lib/api';
	import { clickOutside } from '$lib/actions/clickOutside';
	import type { Organization } from '$lib/api/organizations';
	import TaskRow from '$lib/components/TaskRow.svelte';

	let organizations = $state<Organization[]>([]);
	let selectedOrgId = $state<string | null>(null);
	let dropdownOpen = $state(false);

	const selectedOrg = $derived(organizations.find((o) => o.id === selectedOrgId) ?? null);

	function selectOrg(orgId: string | null) {
		selectedOrgId = orgId;
		dropdownOpen = false;
		ticketStore.load(orgId);
	}

	onMount(async () => {
		try {
			organizations = await api.organizations.getAll();
		} catch {
			organizations = [];
		}

		const orgId = auth.organizationId;
		ticketStore.load(orgId);
		selectedOrgId = orgId;
	});
</script>

<div class="mx-auto w-full max-w-[1200px]">
	<div class="flex items-center justify-between px-4 py-3">
		<div
			class="relative"
			use:clickOutside={{ onClickOutside: () => (dropdownOpen = false), enabled: dropdownOpen }}
		>
			<button
				class="flex cursor-pointer items-center gap-2 border border-gray-200 bg-white px-3 py-1.5 text-xs font-medium transition-colors hover:border-gray-300"
				onclick={() => (dropdownOpen = !dropdownOpen)}
			>
				<span class="text-gray-700">{selectedOrg?.name ?? 'All Organizations'}</span>
				<svg
					class="h-4 w-4 text-gray-400 transition-transform {dropdownOpen ? 'rotate-180' : ''}"
					fill="none"
					stroke="currentColor"
					viewBox="0 0 24 24"
				>
					<path
						stroke-linecap="round"
						stroke-linejoin="round"
						stroke-width="2"
						d="M19 9l-7 7-7-7"
					/>
				</svg>
			</button>

			{#if dropdownOpen}
				<div
					class="absolute left-0 z-10 mt-1 min-w-[200px] overflow-hidden border border-gray-200 bg-white shadow-lg"
				>
					<button
						class="flex w-full items-center px-4 py-2 text-left text-xs transition-colors hover:bg-gray-50 {selectedOrgId === null ? 'font-medium text-accent' : 'text-gray-600'}"
					onmousedown={(e) => { e.preventDefault(); selectOrg(null); }}
				>
					All Organizations
				</button>
					{#each organizations as org (org.id)}
						<button
							class="flex w-full items-center px-4 py-2 text-left text-xs transition-colors hover:bg-gray-50 {selectedOrgId === org.id ? 'font-medium text-accent' : 'text-gray-600'}"
							onmousedown={(e) => { e.preventDefault(); selectOrg(org.id); }}
						>
							{org.name}
						</button>
					{/each}
				</div>
			{/if}
		</div>

		{#if auth.can('tickets', 'create')}
			<button
				class="rounded bg-accent px-3 py-1.5 text-xs font-medium text-white transition-colors hover:bg-accent/90"
			>
				New Ticket
			</button>
		{/if}
	</div>

	{#if ticketStore.loading}
		<p class="px-4 py-8 text-center text-sm text-gray-400">Loading...</p>
	{:else if ticketStore.error}
		<p class="px-4 py-8 text-center text-sm text-red-500">{ticketStore.error}</p>
	{:else}
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
