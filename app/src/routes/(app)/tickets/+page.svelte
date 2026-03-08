<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/state';
	import { replaceState, afterNavigate } from '$app/navigation';
	import { auth } from '$lib/stores/auth.svelte';
	import { ticketStore } from '$lib/stores/tickets.svelte';
	import { api } from '$lib/api';
	import { clickOutside } from '$lib/actions/clickOutside';
	import type { Organization } from '$lib/api/organizations';
	import type { TicketFilters } from '$lib/api/tickets';
	import { localizeHref } from '$lib/paraglide/runtime';
	import TaskRow from '$lib/components/TaskRow.svelte';
	import CreateTicketModal from '$lib/components/CreateTicketModal.svelte';
	import TicketDetailPanel from '$lib/components/TicketDetailPanel.svelte';
	import { ListFilter } from '@lucide/svelte';

	const TICKET_STATUSES = [
		'open',
		'in_progress',
		'waiting_on_customer',
		'waiting_on_agent',
		'resolved',
		'closed'
	] as const;
	const TICKET_PRIORITIES = ['low', 'medium', 'high', 'urgent'] as const;
	const TICKET_CATEGORIES = ['billing', 'technical_issue', 'feature_request', 'general'] as const;
	const TICKET_CHANNELS = ['email', 'api', 'chat', 'web_form'] as const;

	type Member = {
		user_id: string;
		user: { id: string; full_name: string; avatar_url: string | null };
		role: { id: string; name: string; slug: string } | null;
	};
	type CustomerOption = { id: string; full_name: string; email: string; avatar_url: string | null };

	let organizations = $state<Organization[]>([]);
	let selectedOrgId = $state<string | null>(ticketStore.lastLoadedOrgId ?? null);
	let orgDropdownOpen = $state(false);

	let status = $state<string>('');
	let priority = $state<string>('');
	let category = $state<string>('');
	let channel = $state<string>('');
	let assignedAgentId = $state<string>('');
	let customerId = $state<string>('');
	let createdFrom = $state<string>('');
	let createdTo = $state<string>('');
	let resolvedFrom = $state<string>('');
	let resolvedTo = $state<string>('');
	let satisfactionMin = $state<number | ''>('');
	let satisfactionMax = $state<number | ''>('');

	let members = $state<Member[]>([]);
	let customers = $state<CustomerOption[]>([]);
	let filterDropdownOpen = $state<string | null>(null);
	let filtersVisible = $state(false);
	let createModalOpen = $state(false);
	let selectedTicketId = $state<string | null>(null);

	function selectTicket(id: string | null) {
		selectedTicketId = id;
		const url = new URL(window.location.href);
		if (id) {
			url.searchParams.set('id', id);
		} else {
			url.searchParams.delete('id');
		}
		replaceState(localizeHref(url.pathname + url.search), {});
	}

	const ticketOrgs = $derived(organizations.filter((o) => o.support_tier_id !== null));
	const selectedOrg = $derived(organizations.find((o) => o.id === selectedOrgId) ?? null);

	function getFilters(): TicketFilters {
		const f: TicketFilters = {};
		if (status) f.status = status;
		if (priority) f.priority = priority;
		if (category) f.category = category;
		if (channel) f.channel = channel;
		if (assignedAgentId === 'none') f.assigned_agent_id = 'none';
		else if (assignedAgentId) f.assigned_agent_id = assignedAgentId;
		if (customerId) f.customer_id = customerId;
		if (createdFrom) f.created_at_from = createdFrom + 'T00:00:00.000Z';
		if (createdTo) f.created_at_to = createdTo + 'T23:59:59.999Z';
		if (resolvedFrom) f.resolved_at_from = resolvedFrom + 'T00:00:00.000Z';
		if (resolvedTo) f.resolved_at_to = resolvedTo + 'T23:59:59.999Z';
		if (satisfactionMin !== '') f.satisfaction_min = Number(satisfactionMin);
		if (satisfactionMax !== '') f.satisfaction_max = Number(satisfactionMax);
		return f;
	}

	function applyFilters() {
		ticketStore.load(selectedOrgId ?? undefined, getFilters());
	}

	function selectOrg(orgId: string | null) {
		selectedOrgId = orgId;
		orgDropdownOpen = false;
		ticketStore.load(orgId ?? undefined, getFilters());
		if (orgId) {
			api.members
				.getAll(orgId)
				.then((m) => {
					members = m as Member[];
				})
				.catch(() => {
					members = [];
				});
			api.tickets
				.getCustomersByOrg(orgId)
				.then((c) => {
					customers = c;
				})
				.catch(() => {
					customers = [];
				});
		} else {
			members = [];
			customers = [];
		}
	}

	function openFilterDropdown(key: string) {
		filterDropdownOpen = filterDropdownOpen === key ? null : key;
	}

	function clearFilters() {
		status = '';
		priority = '';
		category = '';
		channel = '';
		assignedAgentId = '';
		customerId = '';
		createdFrom = '';
		createdTo = '';
		resolvedFrom = '';
		resolvedTo = '';
		satisfactionMin = '';
		satisfactionMax = '';
		filterDropdownOpen = null;
		ticketStore.load(selectedOrgId ?? undefined, {});
	}

	const hasActiveFilters = $derived(
		!!(
			status ||
			priority ||
			category ||
			channel ||
			assignedAgentId ||
			customerId ||
			createdFrom ||
			createdTo ||
			resolvedFrom ||
			resolvedTo ||
			satisfactionMin !== '' ||
			satisfactionMax !== ''
		)
	);

	const activeFiltersCount = $derived(
		[
			status,
			priority,
			category,
			channel,
			assignedAgentId,
			customerId,
			createdFrom,
			createdTo,
			resolvedFrom,
			resolvedTo,
			satisfactionMin !== '',
			satisfactionMax !== ''
		].filter(Boolean).length
	);

	const filterLabelClass = 'text-[11px] font-medium uppercase tracking-wider text-sidebar-icon';
	const dropdownBtnClass =
		'flex min-w-[6.5rem] cursor-pointer items-center justify-between gap-2 border border-surface-border bg-surface px-3 py-2 text-xs text-sidebar-text shadow-sm transition-colors hover:border-sidebar-icon/30 hover:bg-surface-hover';
	const dropdownPanelClass =
		'absolute left-0 z-20 mt-1.5 max-h-56 min-w-[10rem] overflow-y-auto border border-surface-border bg-surface py-1 shadow-xl';

	onMount(async () => {
		try {
			organizations = await api.organizations.getAll();
		} catch {
			organizations = [];
		}

		if (!selectedOrgId || !ticketOrgs.some((o) => o.id === selectedOrgId)) {
			const orgId = auth.organizationId;
			selectedOrgId = ticketOrgs.some((o) => o.id === orgId) ? orgId : null;
		}

		ticketStore.loadIfNeeded(selectedOrgId ?? undefined, getFilters());

		if (selectedOrgId) {
			Promise.all([
				api.members.getAll(selectedOrgId).catch(() => [] as Member[]),
				api.tickets.getCustomersByOrg(selectedOrgId).catch(() => [] as CustomerOption[]),
			]).then(([m, c]) => {
				members = m as Member[];
				customers = c;
			});
		}

		const ticketIdParam = page.url.searchParams.get('id');
		if (ticketIdParam) selectTicket(ticketIdParam);
	});

	afterNavigate(({ to }) => {
		const ticketIdParam = to?.url.searchParams.get('id') ?? null;
		if (ticketIdParam) selectedTicketId = ticketIdParam;
	});
</script>

<div
	class="mx-auto w-full max-w-[1200px]"
	use:clickOutside={{
		onClickOutside: () => {
			orgDropdownOpen = false;
			filterDropdownOpen = null;
		},
		enabled: orgDropdownOpen || filterDropdownOpen !== null
	}}
>
	<!-- Header: org + actions -->
	<div class="flex items-center justify-between border-b border-surface-border px-4 py-3">
		<div class="flex items-center gap-2">
			<div class="relative">
				<button
					class="flex min-w-[11rem] cursor-pointer items-center justify-between gap-2 border border-surface-border bg-surface px-3 py-2 text-xs font-medium text-sidebar-text shadow-sm transition-colors hover:border-sidebar-icon/30 hover:bg-surface-hover"
					onclick={() => (orgDropdownOpen = !orgDropdownOpen)}
				>
					<span>{selectedOrg?.name ?? 'All Organizations'}</span>
					<svg
						class="h-4 w-4 shrink-0 text-sidebar-icon transition-transform {orgDropdownOpen
							? 'rotate-180'
							: ''}"
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
				{#if orgDropdownOpen}
					<div
						class="absolute left-0 z-10 mt-1.5 min-w-[200px] overflow-hidden border border-surface-border bg-surface py-1 shadow-xl"
					>
						<button
							class="flex w-full items-center px-4 py-2.5 text-left text-xs transition-colors hover:bg-surface-hover {selectedOrgId ===
							null
								? 'font-medium text-accent'
								: 'text-sidebar-text'}"
							onmousedown={(e) => {
								e.preventDefault();
								selectOrg(null);
							}}
						>
							All Organizations
						</button>
						{#each ticketOrgs as org (org.id)}
							<button
								class="flex w-full items-center px-4 py-2.5 text-left text-xs transition-colors hover:bg-surface-hover {selectedOrgId ===
								org.id
									? 'font-medium text-accent'
									: 'text-sidebar-text'}"
								onmousedown={(e) => {
									e.preventDefault();
									selectOrg(org.id);
								}}
							>
								{org.name}
							</button>
						{/each}
					</div>
				{/if}
			</div>
			<div class="relative shrink-0">
				<button
					class="flex items-center justify-center border border-surface-border bg-surface p-2 shadow-sm transition-colors hover:border-sidebar-icon/30 hover:bg-surface-hover {filtersVisible
						? 'text-accent'
						: 'text-sidebar-icon'}"
					onclick={() => (filtersVisible = !filtersVisible)}
					title={filtersVisible ? 'Hide filters' : 'Show filters'}
				>
					<ListFilter size={16} />
				</button>
				{#if activeFiltersCount > 0}
					<span
						class="absolute -top-1.5 -right-1.5 flex h-4 min-w-4 items-center justify-center bg-accent px-1 text-[10px] leading-none font-medium text-white"
						aria-label="{activeFiltersCount} active filter{activeFiltersCount === 1 ? '' : 's'}"
					>
						{activeFiltersCount > 9 ? '9+' : activeFiltersCount}
					</span>
				{/if}
			</div>
		</div>

		{#if auth.can('support_tickets', 'create')}
			<button
				class="bg-accent px-4 py-2 text-xs font-medium text-white shadow-sm transition-colors hover:bg-accent/90"
				onclick={() => (createModalOpen = true)}
			>
				New Ticket
			</button>
		{/if}
	</div>

	{#if createModalOpen}
		<CreateTicketModal
			organizationId={selectedOrgId}
			{customers}
			onClose={() => (createModalOpen = false)}
			onSuccess={() => applyFilters()}
		/>
	{/if}

	<!-- Filter bar -->
	{#if filtersVisible}
		<div class="border-b border-surface-border bg-surface/40 px-4 py-4">
			<div class="mb-3 flex items-center justify-between">
				<span class={filterLabelClass}>Filters</span>
				{#if hasActiveFilters}
					<button
						class="text-xs font-medium text-sidebar-icon transition-colors hover:text-accent"
						onclick={clearFilters}
					>
						Clear all
					</button>
				{/if}
			</div>
			<div class="flex flex-wrap items-end gap-4">
				<div class="flex flex-col gap-1.5">
					<span class={filterLabelClass}>Status</span>
					<div class="relative">
						<button class={dropdownBtnClass} onclick={() => openFilterDropdown('status')}>
							<span class="truncate">{status ? status.replace(/_/g, ' ') : 'All'}</span>
							<svg
								class="h-4 w-4 shrink-0 text-sidebar-icon transition-transform {filterDropdownOpen ===
								'status'
									? 'rotate-180'
									: ''}"
								fill="none"
								stroke="currentColor"
								viewBox="0 0 24 24"
								><path
									stroke-linecap="round"
									stroke-linejoin="round"
									stroke-width="2"
									d="M19 9l-7 7-7-7"
								/></svg
							>
						</button>
						{#if filterDropdownOpen === 'status'}
							<div class={dropdownPanelClass}>
								<button
									class="flex w-full items-center px-4 py-2.5 text-left text-xs transition-colors hover:bg-surface-hover {!status
										? 'font-medium text-accent'
										: 'text-sidebar-text'}"
									onmousedown={(e) => {
										e.preventDefault();
										status = '';
										filterDropdownOpen = null;
										applyFilters();
									}}>All</button
								>
								{#each TICKET_STATUSES as s (s)}
									<button
										class="flex w-full items-center px-4 py-2.5 text-left text-xs whitespace-nowrap transition-colors hover:bg-surface-hover {status ===
										s
											? 'font-medium text-accent'
											: 'text-sidebar-text'}"
										onmousedown={(e) => {
											e.preventDefault();
											status = s;
											filterDropdownOpen = null;
											applyFilters();
										}}>{s.replace(/_/g, ' ')}</button
									>
								{/each}
							</div>
						{/if}
					</div>
				</div>
				<div class="flex flex-col gap-1.5">
					<span class={filterLabelClass}>Priority</span>
					<div class="relative">
						<button class={dropdownBtnClass} onclick={() => openFilterDropdown('priority')}>
							<span class="truncate">{priority || 'All'}</span>
							<svg
								class="h-4 w-4 shrink-0 text-sidebar-icon transition-transform {filterDropdownOpen ===
								'priority'
									? 'rotate-180'
									: ''}"
								fill="none"
								stroke="currentColor"
								viewBox="0 0 24 24"
								><path
									stroke-linecap="round"
									stroke-linejoin="round"
									stroke-width="2"
									d="M19 9l-7 7-7-7"
								/></svg
							>
						</button>
						{#if filterDropdownOpen === 'priority'}
							<div class={dropdownPanelClass}>
								<button
									class="flex w-full items-center px-4 py-2.5 text-left text-xs transition-colors hover:bg-surface-hover {!priority
										? 'font-medium text-accent'
										: 'text-sidebar-text'}"
									onmousedown={(e) => {
										e.preventDefault();
										priority = '';
										filterDropdownOpen = null;
										applyFilters();
									}}>All</button
								>
								{#each TICKET_PRIORITIES as p (p)}
									<button
										class="flex w-full items-center px-4 py-2.5 text-left text-xs transition-colors hover:bg-surface-hover {priority ===
										p
											? 'font-medium text-accent'
											: 'text-sidebar-text'}"
										onmousedown={(e) => {
											e.preventDefault();
											priority = p;
											filterDropdownOpen = null;
											applyFilters();
										}}>{p}</button
									>
								{/each}
							</div>
						{/if}
					</div>
				</div>
				<div class="flex flex-col gap-1.5">
					<span class={filterLabelClass}>Category</span>
					<div class="relative">
						<button class={dropdownBtnClass} onclick={() => openFilterDropdown('category')}>
							<span class="truncate">{category ? category.replace(/_/g, ' ') : 'All'}</span>
							<svg
								class="h-4 w-4 shrink-0 text-sidebar-icon transition-transform {filterDropdownOpen ===
								'category'
									? 'rotate-180'
									: ''}"
								fill="none"
								stroke="currentColor"
								viewBox="0 0 24 24"
								><path
									stroke-linecap="round"
									stroke-linejoin="round"
									stroke-width="2"
									d="M19 9l-7 7-7-7"
								/></svg
							>
						</button>
						{#if filterDropdownOpen === 'category'}
							<div class={dropdownPanelClass}>
								<button
									class="flex w-full items-center px-4 py-2.5 text-left text-xs transition-colors hover:bg-surface-hover {!category
										? 'font-medium text-accent'
										: 'text-sidebar-text'}"
									onmousedown={(e) => {
										e.preventDefault();
										category = '';
										filterDropdownOpen = null;
										applyFilters();
									}}>All</button
								>
								{#each TICKET_CATEGORIES as c (c)}
									<button
										class="flex w-full items-center px-4 py-2.5 text-left text-xs transition-colors hover:bg-surface-hover {category ===
										c
											? 'font-medium text-accent'
											: 'text-sidebar-text'}"
										onmousedown={(e) => {
											e.preventDefault();
											category = c;
											filterDropdownOpen = null;
											applyFilters();
										}}>{c.replace(/_/g, ' ')}</button
									>
								{/each}
							</div>
						{/if}
					</div>
				</div>
				<div class="flex flex-col gap-1.5">
					<span class={filterLabelClass}>Channel</span>
					<div class="relative">
						<button class={dropdownBtnClass} onclick={() => openFilterDropdown('channel')}>
							<span class="truncate">{channel ? channel.replace(/_/g, ' ') : 'All'}</span>
							<svg
								class="h-4 w-4 shrink-0 text-sidebar-icon transition-transform {filterDropdownOpen ===
								'channel'
									? 'rotate-180'
									: ''}"
								fill="none"
								stroke="currentColor"
								viewBox="0 0 24 24"
								><path
									stroke-linecap="round"
									stroke-linejoin="round"
									stroke-width="2"
									d="M19 9l-7 7-7-7"
								/></svg
							>
						</button>
						{#if filterDropdownOpen === 'channel'}
							<div class={dropdownPanelClass}>
								<button
									class="flex w-full items-center px-4 py-2.5 text-left text-xs transition-colors hover:bg-surface-hover {!channel
										? 'font-medium text-accent'
										: 'text-sidebar-text'}"
									onmousedown={(e) => {
										e.preventDefault();
										channel = '';
										filterDropdownOpen = null;
										applyFilters();
									}}>All</button
								>
								{#each TICKET_CHANNELS as ch (ch)}
									<button
										class="flex w-full items-center px-4 py-2.5 text-left text-xs transition-colors hover:bg-surface-hover {channel ===
										ch
											? 'font-medium text-accent'
											: 'text-sidebar-text'}"
										onmousedown={(e) => {
											e.preventDefault();
											channel = ch;
											filterDropdownOpen = null;
											applyFilters();
										}}>{ch.replace(/_/g, ' ')}</button
									>
								{/each}
							</div>
						{/if}
					</div>
				</div>
				{#if selectedOrgId}
					<div class="flex flex-col gap-1.5">
						<span class={filterLabelClass}>Assigned</span>
						<div class="relative">
							<button
								class="{dropdownBtnClass} min-w-[8rem]"
								onclick={() => openFilterDropdown('agent')}
							>
								<span class="truncate"
									>{assignedAgentId === 'none'
										? 'Unassigned'
										: assignedAgentId
											? (members.find((m) => m.user_id === assignedAgentId)?.user?.full_name ?? '—')
											: 'All'}</span
								>
								<svg
									class="h-4 w-4 shrink-0 text-sidebar-icon transition-transform {filterDropdownOpen ===
									'agent'
										? 'rotate-180'
										: ''}"
									fill="none"
									stroke="currentColor"
									viewBox="0 0 24 24"
									><path
										stroke-linecap="round"
										stroke-linejoin="round"
										stroke-width="2"
										d="M19 9l-7 7-7-7"
									/></svg
								>
							</button>
							{#if filterDropdownOpen === 'agent'}
								<div class="{dropdownPanelClass} min-w-[12rem]">
									<button
										class="flex w-full items-center px-4 py-2.5 text-left text-xs transition-colors hover:bg-surface-hover {!assignedAgentId
											? 'font-medium text-accent'
											: 'text-sidebar-text'}"
										onmousedown={(e) => {
											e.preventDefault();
											assignedAgentId = '';
											filterDropdownOpen = null;
											applyFilters();
										}}>All</button
									>
									<button
										class="flex w-full items-center px-4 py-2.5 text-left text-xs transition-colors hover:bg-surface-hover {assignedAgentId ===
										'none'
											? 'font-medium text-accent'
											: 'text-sidebar-text'}"
										onmousedown={(e) => {
											e.preventDefault();
											assignedAgentId = 'none';
											filterDropdownOpen = null;
											applyFilters();
										}}>Unassigned</button
									>
									{#each members as m (m.user_id)}
										<button
											class="flex w-full items-center px-4 py-2.5 text-left text-xs transition-colors hover:bg-surface-hover {assignedAgentId ===
											m.user_id
												? 'font-medium text-accent'
												: 'text-sidebar-text'}"
											onmousedown={(e) => {
												e.preventDefault();
												assignedAgentId = m.user_id;
												filterDropdownOpen = null;
												applyFilters();
											}}>{m.user?.full_name ?? m.user_id}</button
										>
									{/each}
								</div>
							{/if}
						</div>
					</div>
					<div class="flex flex-col gap-1.5">
						<span class={filterLabelClass}>Customer</span>
						<div class="relative">
							<button
								class="{dropdownBtnClass} min-w-[8rem]"
								onclick={() => openFilterDropdown('customer')}
							>
								<span class="truncate"
									>{customerId
										? (customers.find((c) => c.id === customerId)?.full_name ?? '—')
										: 'All'}</span
								>
								<svg
									class="h-4 w-4 shrink-0 text-sidebar-icon transition-transform {filterDropdownOpen ===
									'customer'
										? 'rotate-180'
										: ''}"
									fill="none"
									stroke="currentColor"
									viewBox="0 0 24 24"
									><path
										stroke-linecap="round"
										stroke-linejoin="round"
										stroke-width="2"
										d="M19 9l-7 7-7-7"
									/></svg
								>
							</button>
							{#if filterDropdownOpen === 'customer'}
								<div class="{dropdownPanelClass} min-w-[14rem]">
									<button
										class="flex w-full items-center px-4 py-2.5 text-left text-xs transition-colors hover:bg-surface-hover {!customerId
											? 'font-medium text-accent'
											: 'text-sidebar-text'}"
										onmousedown={(e) => {
											e.preventDefault();
											customerId = '';
											filterDropdownOpen = null;
											applyFilters();
										}}>All</button
									>
									{#each customers as c (c.id)}
										<button
											class="whitespace-nowrap flex flex-col w-full items-start justify-center px-4 py-2.5 text-left text-xs transition-colors hover:bg-surface-hover {customerId ===
											c.id
												? 'font-medium text-accent'
												: 'text-sidebar-text'}"
											onmousedown={(e) => {
												e.preventDefault();
												customerId = c.id;
												filterDropdownOpen = null;
												applyFilters();
											}}
											>{c.full_name}{#if c.email}
												<span class="text-sidebar-icon">({c.email})</span>{/if}</button
										>
									{/each}
								</div>
							{/if}
						</div>
					</div>
				{/if}
				<div class="flex flex-col gap-1.5">
					<span class={filterLabelClass}>More</span>
					<div class="relative">
						<button
							class="{dropdownBtnClass} min-w-[5rem]"
							onclick={() => openFilterDropdown('dates')}
							title="Date range & satisfaction"
						>
							<span class="flex items-center gap-1.5">
								{#if createdFrom || createdTo || resolvedFrom || resolvedTo || satisfactionMin !== '' || satisfactionMax !== ''}
									<span class="inline-block h-1.5 w-1.5 rounded-full bg-accent" aria-hidden="true"
									></span>
								{/if}
								Dates
							</span>
							<svg
								class="h-4 w-4 shrink-0 text-sidebar-icon transition-transform {filterDropdownOpen ===
								'dates'
									? 'rotate-180'
									: ''}"
								fill="none"
								stroke="currentColor"
								viewBox="0 0 24 24"
								><path
									stroke-linecap="round"
									stroke-linejoin="round"
									stroke-width="2"
									d="M19 9l-7 7-7-7"
								/></svg
							>
						</button>
						{#if filterDropdownOpen === 'dates'}
							<div
								class="absolute left-0 z-20 mt-1.5 min-w-[240px] border border-surface-border bg-surface p-4 shadow-xl"
							>
								<p class="mb-3 text-xs font-medium tracking-wider text-sidebar-icon uppercase">
									Date range & satisfaction
								</p>
								<div class="space-y-3 text-xs">
									<div>
										<label for="filter-created-from" class="mb-1 block text-sidebar-icon"
											>Created from</label
										>
										<input
											id="filter-created-from"
											type="date"
											bind:value={createdFrom}
											class="w-full border border-surface-border bg-surface px-2.5 py-1.5 text-sidebar-text"
											onchange={applyFilters}
										/>
									</div>
									<div>
										<label for="filter-created-to" class="mb-1 block text-sidebar-icon"
											>Created to</label
										>
										<input
											id="filter-created-to"
											type="date"
											bind:value={createdTo}
											class="w-full border border-surface-border bg-surface px-2.5 py-1.5 text-sidebar-text"
											onchange={applyFilters}
										/>
									</div>
									<div>
										<label for="filter-resolved-from" class="mb-1 block text-sidebar-icon"
											>Resolved from</label
										>
										<input
											id="filter-resolved-from"
											type="date"
											bind:value={resolvedFrom}
											class="w-full border border-surface-border bg-surface px-2.5 py-1.5 text-sidebar-text"
											onchange={applyFilters}
										/>
									</div>
									<div>
										<label for="filter-resolved-to" class="mb-1 block text-sidebar-icon"
											>Resolved to</label
										>
										<input
											id="filter-resolved-to"
											type="date"
											bind:value={resolvedTo}
											class="w-full border border-surface-border bg-surface px-2.5 py-1.5 text-sidebar-text"
											onchange={applyFilters}
										/>
									</div>
									<div class="grid grid-cols-2 gap-2">
										<div>
											<label for="filter-satisfaction-min" class="mb-1 block text-sidebar-icon"
												>Satisfaction min</label
											>
											<input
												id="filter-satisfaction-min"
												type="number"
												min="1"
												max="5"
												bind:value={satisfactionMin}
												class="w-full border border-surface-border bg-surface px-2.5 py-1.5 text-sidebar-text"
												onchange={applyFilters}
											/>
										</div>
										<div>
											<label for="filter-satisfaction-max" class="mb-1 block text-sidebar-icon"
												>Satisfaction max</label
											>
											<input
												id="filter-satisfaction-max"
												type="number"
												min="1"
												max="5"
												bind:value={satisfactionMax}
												class="w-full border border-surface-border bg-surface px-2.5 py-1.5 text-sidebar-text"
												onchange={applyFilters}
											/>
										</div>
									</div>
								</div>
								<button
									class="mt-3 w-full border border-surface-border bg-surface py-2 text-xs font-medium text-sidebar-text transition-colors hover:bg-surface-hover"
									onmousedown={(e) => {
										e.preventDefault();
										filterDropdownOpen = null;
									}}>Done</button
								>
							</div>
						{/if}
					</div>
				</div>
			</div>
		</div>
	{/if}

	{#if ticketStore.loading}
		<p class="px-4 py-8 text-center text-sm text-muted">Loading...</p>
	{:else if ticketStore.error}
		<p class="px-4 py-8 text-center text-sm text-red-500">{ticketStore.error}</p>
	{:else}
		<div>
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
				onclick={() => selectTicket(ticket.id)}
			/>
			{/each}
		</div>

		<p class="px-4 py-3 text-xs text-muted">{ticketStore.count} tickets total</p>
	{/if}
</div>

{#if selectedTicketId}
	<TicketDetailPanel
		ticketId={selectedTicketId}
		{members}
		onClose={() => selectTicket(null)}
		onUpdate={() => applyFilters()}
	/>
{/if}
