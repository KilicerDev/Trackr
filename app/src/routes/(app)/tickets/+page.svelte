<svelte:head><title>Tickets – Trackr</title></svelte:head>

<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/state';
	import { replaceState, afterNavigate } from '$app/navigation';
	import { auth } from '$lib/stores/auth.svelte';
	import { ticketStore } from '$lib/stores/tickets.svelte';
	import { orgStore } from '$lib/stores/organizations.svelte';
	import { api } from '$lib/api';
	import { clickOutside } from '$lib/actions/clickOutside';
	import type { TicketFilters } from '$lib/api/tickets';
	import type { FilterOp } from '$lib/api/tasks';
	import { localizeHref } from '$lib/paraglide/runtime';
	import TaskRow from '$lib/components/TaskRow.svelte';
	import CreateTicketModal from '$lib/components/CreateTicketModal.svelte';
	import TicketDetailPanel from '$lib/components/TicketDetailPanel.svelte';
	import FilterDropdown from '$lib/components/FilterDropdown.svelte';
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
		user: { id: string; full_name: string; avatar_url: string | null; is_active: boolean; deleted_at: string | null };
		role: { id: string; name: string; slug: string } | null;
	};
	type CustomerOption = { id: string; full_name: string; email: string; avatar_url: string | null };

	const organizations = $derived(orgStore.all);
	let selectedOrgId = $state<string | null>(ticketStore.lastLoadedOrgId ?? null);
	let orgDropdownOpen = $state(false);

	let statusOp = $state<'is' | 'is_not'>('is');
	let statusSelected = $state<string[]>([]);
	let priorityOp = $state<'is' | 'is_not'>('is');
	let prioritySelected = $state<string[]>([]);
	let categoryOp = $state<'is' | 'is_not'>('is');
	let categorySelected = $state<string[]>([]);
	let channelOp = $state<'is' | 'is_not'>('is');
	let channelSelected = $state<string[]>([]);
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
	let selectedTicketTab = $state<'details' | 'messages' | 'time'>('details');

	function selectTicket(id: string | null) {
		filterDropdownOpen = null;
		orgDropdownOpen = false;
		selectedTicketId = id;
		selectedTicketTab = 'details';
		const url = new URL(window.location.href);
		if (id) {
			url.searchParams.set('id', id);
		} else {
			url.searchParams.delete('id');
		}
		url.searchParams.delete('tab');
		replaceState(localizeHref(url.pathname + url.search), {});
	}

	const ticketOrgs = $derived(organizations.filter((o) => o.support_tier_id !== null));
	const selectedOrg = $derived(organizations.find((o) => o.id === selectedOrgId) ?? null);

	function toFilterOp(op: 'is' | 'is_not', values: string[]): FilterOp | undefined {
		if (values.length === 0) return undefined;
		return { values, not: op === 'is_not' };
	}

	function getFilters(): TicketFilters {
		const f: TicketFilters = {};
		f.status = toFilterOp(statusOp, statusSelected);
		f.priority = toFilterOp(priorityOp, prioritySelected);
		f.category = toFilterOp(categoryOp, categorySelected);
		f.channel = toFilterOp(channelOp, channelSelected);
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
		statusOp = 'is'; statusSelected = [];
		priorityOp = 'is'; prioritySelected = [];
		categoryOp = 'is'; categorySelected = [];
		channelOp = 'is'; channelSelected = [];
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
			statusSelected.length ||
			prioritySelected.length ||
			categorySelected.length ||
			channelSelected.length ||
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
			statusSelected.length,
			prioritySelected.length,
			categorySelected.length,
			channelSelected.length,
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

	import { filterLabelClass, dropdownBtnClass, dropdownPanelClass } from '$lib/config/filter-styles';

	onMount(async () => {
		await orgStore.loadIfNeeded();

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
		if (ticketIdParam) {
			selectedTicketId = ticketIdParam;
			const tabParam = page.url.searchParams.get('tab');
			if (tabParam === 'messages' || tabParam === 'time') selectedTicketTab = tabParam;
		}
	});

	afterNavigate(({ to }) => {
		const ticketIdParam = to?.url.searchParams.get('id') ?? null;
		if (ticketIdParam) {
			selectedTicketId = ticketIdParam;
			const tabParam = to?.url.searchParams.get('tab') ?? null;
			if (tabParam === 'messages' || tabParam === 'time') selectedTicketTab = tabParam;
			else selectedTicketTab = 'details';
		}
	});

	$effect(() => {
		if (!selectedTicketId) return;
		function handleKeydown(e: KeyboardEvent) {
			const tag = (e.target as HTMLElement)?.tagName;
			if (tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT') return;
			if (e.key !== 'ArrowDown' && e.key !== 'ArrowUp') return;
			e.preventDefault();
			const items = ticketStore.items;
			const idx = items.findIndex((t) => t.id === selectedTicketId);
			if (idx === -1) return;
			const next = e.key === 'ArrowDown'
				? Math.min(idx + 1, items.length - 1)
				: Math.max(idx - 1, 0);
			if (next !== idx) {
				selectTicket(items[next].id);
				requestAnimationFrame(() => {
					document.querySelector(`[data-task-id="${items[next].id}"]`)
						?.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
				});
			}
		}
		document.addEventListener('keydown', handleKeydown);
		return () => document.removeEventListener('keydown', handleKeydown);
	});
</script>

<div class="flex h-full overflow-hidden">
<div class="min-w-0 flex-1 overflow-y-auto">
<div
	class="mx-auto w-full"
	use:clickOutside={{
		onClickOutside: () => {
			orgDropdownOpen = false;
			filterDropdownOpen = null;
		},
		enabled: orgDropdownOpen || filterDropdownOpen !== null
	}}
>
	<!-- Header: org + actions -->
	<div class="flex items-center justify-between px-3 py-1.5">
		<div class="flex items-center gap-2">
			<div class="relative">
				<button
					class="flex h-7 min-w-[11rem] cursor-pointer items-center justify-between gap-2 rounded-sm bg-surface-hover/40 px-2.5 text-sm font-medium text-sidebar-text transition-all duration-150 hover:bg-surface-hover/60"
					onclick={() => (orgDropdownOpen = !orgDropdownOpen)}
				>
					<span>{selectedOrg?.name ?? 'All Organizations'}</span>
					<svg
						class="h-3.5 w-3.5 shrink-0 text-muted/40 transition-transform duration-150 {orgDropdownOpen
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
						class="absolute left-0 z-20 mt-1.5 min-w-[12rem] origin-top-left animate-dropdown-in rounded-md border border-surface-border bg-surface py-1 shadow-lg shadow-black/15 ring-1 ring-white/[0.07]"
					>
						<button
							class="flex w-full items-center px-2.5 py-1.5 text-left text-sm transition-colors hover:bg-surface-hover/60 {selectedOrgId ===
							null
								? 'font-medium text-accent'
								: 'text-muted'}"
							onmousedown={(e) => {
								e.preventDefault();
								selectOrg(null);
							}}
						>
							All Organizations
						</button>
						{#each ticketOrgs as org (org.id)}
							<button
								class="flex w-full items-center px-2.5 py-1.5 text-left text-sm transition-colors hover:bg-surface-hover/60 {selectedOrgId ===
								org.id
									? 'font-medium text-accent'
									: 'text-muted'}"
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
					class="flex h-7 w-7 items-center justify-center rounded-sm text-muted/40 transition-all duration-150 hover:bg-surface-hover/40 {filtersVisible
						? 'text-accent'
						: 'text-sidebar-icon'}"
					onclick={() => (filtersVisible = !filtersVisible)}
					title={filtersVisible ? 'Hide filters' : 'Show filters'}
				>
					<ListFilter size={16} />
				</button>
				{#if activeFiltersCount > 0}
					<span
						class="absolute -top-1.5 -right-1.5 flex h-4 min-w-4 items-center justify-center rounded-full bg-accent px-1 text-2xs font-semibold leading-none text-white"
						aria-label="{activeFiltersCount} active filter{activeFiltersCount === 1 ? '' : 's'}"
					>
						{activeFiltersCount > 9 ? '9+' : activeFiltersCount}
					</span>
				{/if}
			</div>
		</div>

		{#if auth.can('support_tickets', 'create')}
			<button
				class="flex h-7 items-center justify-center gap-1 rounded-sm bg-accent px-2.5 text-sm leading-none font-medium text-white transition-all duration-150 hover:bg-accent/90"
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
		<div class="px-3 py-1.5">
			<div class="mb-3 flex items-center justify-between">
				<span class="text-xs font-medium uppercase tracking-[0.08em] text-muted/50">Filters</span>
				{#if hasActiveFilters}
					<button
						class="text-sm text-muted/50 transition-colors hover:text-accent"
						onclick={clearFilters}
					>
						Clear all
					</button>
				{/if}
			</div>
			<div class="flex flex-wrap items-end gap-4">
				<FilterDropdown
					label="Status"
					options={TICKET_STATUSES.map((s) => ({ value: s, label: s.replace(/_/g, ' ') }))}
					operator={statusOp}
					selected={statusSelected}
					onchange={(op, sel) => { statusOp = op; statusSelected = sel; applyFilters(); }}
				/>
				<FilterDropdown
					label="Priority"
					options={TICKET_PRIORITIES.map((p) => ({ value: p, label: p }))}
					operator={priorityOp}
					selected={prioritySelected}
					onchange={(op, sel) => { priorityOp = op; prioritySelected = sel; applyFilters(); }}
				/>
				<FilterDropdown
					label="Category"
					options={TICKET_CATEGORIES.map((c) => ({ value: c, label: c.replace(/_/g, ' ') }))}
					operator={categoryOp}
					selected={categorySelected}
					onchange={(op, sel) => { categoryOp = op; categorySelected = sel; applyFilters(); }}
				/>
				<FilterDropdown
					label="Channel"
					options={TICKET_CHANNELS.map((ch) => ({ value: ch, label: ch.replace(/_/g, ' ') }))}
					operator={channelOp}
					selected={channelSelected}
					onchange={(op, sel) => { channelOp = op; channelSelected = sel; applyFilters(); }}
				/>
				{#if selectedOrgId}
					<div class="relative"
						use:clickOutside={{ onClickOutside: () => { if (filterDropdownOpen === 'agent') filterDropdownOpen = null; }, enabled: filterDropdownOpen === 'agent' }}
					>
							<button
								class="flex h-7 items-center gap-1.5 rounded-sm px-2 text-sm transition-all duration-150 {assignedAgentId ? 'text-accent' : 'text-muted hover:text-sidebar-text'}"
								onclick={() => openFilterDropdown('agent')}
							>
								<span class="text-muted/50">Agent</span>
								<span class="truncate {assignedAgentId ? 'font-medium' : ''}">{assignedAgentId === 'none' ? 'Unassigned' : assignedAgentId ? (members.find((m) => m.user_id === assignedAgentId)?.user?.full_name ?? '—') : 'All'}</span>
								<svg class="h-3 w-3 shrink-0 text-muted/40 transition-transform duration-150 {filterDropdownOpen === 'agent' ? 'rotate-180' : ''}" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" /></svg>
							</button>
							{#if filterDropdownOpen === 'agent'}
								<div class="{dropdownPanelClass} min-w-[12rem]">
									<button
										class="flex w-full items-center px-2.5 py-1.5 text-left text-sm transition-colors hover:bg-surface-hover/60 {!assignedAgentId
											? 'font-medium text-accent'
											: 'text-muted'}"
										onmousedown={(e) => {
											e.preventDefault();
											assignedAgentId = '';
											filterDropdownOpen = null;
											applyFilters();
										}}>All</button
									>
									<button
										class="flex w-full items-center px-2.5 py-1.5 text-left text-sm transition-colors hover:bg-surface-hover/60 {assignedAgentId ===
										'none'
											? 'font-medium text-accent'
											: 'text-muted'}"
										onmousedown={(e) => {
											e.preventDefault();
											assignedAgentId = 'none';
											filterDropdownOpen = null;
											applyFilters();
										}}>Unassigned</button
									>
									{#each members as m (m.user_id)}
										<button
											class="flex w-full items-center px-2.5 py-1.5 text-left text-sm transition-colors hover:bg-surface-hover/60 {assignedAgentId ===
											m.user_id
												? 'font-medium text-accent'
												: 'text-muted'}"
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
					<div class="relative"
						use:clickOutside={{ onClickOutside: () => { if (filterDropdownOpen === 'customer') filterDropdownOpen = null; }, enabled: filterDropdownOpen === 'customer' }}
					>
							<button
								class="flex h-7 items-center gap-1.5 rounded-sm px-2 text-sm transition-all duration-150 {customerId ? 'text-accent' : 'text-muted hover:text-sidebar-text'}"
								onclick={() => openFilterDropdown('customer')}
							>
								<span class="text-muted/50">Customer</span>
								<span class="truncate {customerId ? 'font-medium' : ''}">{customerId ? (customers.find((c) => c.id === customerId)?.full_name ?? '—') : 'All'}</span>
								<svg class="h-3 w-3 shrink-0 text-muted/40 transition-transform duration-150 {filterDropdownOpen === 'customer' ? 'rotate-180' : ''}" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" /></svg>
							</button>
							{#if filterDropdownOpen === 'customer'}
								<div class="{dropdownPanelClass} min-w-[14rem]">
									<button
										class="flex w-full items-center px-2.5 py-1.5 text-left text-sm transition-colors hover:bg-surface-hover/60 {!customerId
											? 'font-medium text-accent'
											: 'text-muted'}"
										onmousedown={(e) => {
											e.preventDefault();
											customerId = '';
											filterDropdownOpen = null;
											applyFilters();
										}}>All</button
									>
									{#each customers as c (c.id)}
										<button
											class="whitespace-nowrap flex flex-col w-full items-start justify-center px-4 py-2.5 text-left text-base transition-colors hover:bg-surface-hover {customerId ===
											c.id
												? 'font-medium text-accent'
												: 'text-muted'}"
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
				{/if}
				<div class="relative"
					use:clickOutside={{ onClickOutside: () => { if (filterDropdownOpen === 'dates') filterDropdownOpen = null; }, enabled: filterDropdownOpen === 'dates' }}
				>
						<button
							class="flex h-7 items-center gap-1.5 rounded-sm px-2 text-sm transition-all duration-150 {createdFrom || createdTo || resolvedFrom || resolvedTo || satisfactionMin !== '' || satisfactionMax !== '' ? 'text-accent' : 'text-muted hover:text-sidebar-text'}"
							onclick={() => openFilterDropdown('dates')}
						>
							<span class="text-muted/50">Dates</span>
							{#if createdFrom || createdTo || resolvedFrom || resolvedTo || satisfactionMin !== '' || satisfactionMax !== ''}
								<span>Active</span>
							{:else}
								<span>All</span>
							{/if}
							<svg class="h-3 w-3 shrink-0 text-muted/40 transition-transform duration-150 {filterDropdownOpen === 'dates' ? 'rotate-180' : ''}" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" /></svg>
						</button>
						{#if filterDropdownOpen === 'dates'}
							<div
								class="absolute right-0 z-20 mt-1.5 min-w-[220px] origin-top-right animate-dropdown-in rounded-md border border-surface-border bg-surface p-3 shadow-lg shadow-black/15 ring-1 ring-white/[0.07]"
							>
								<p class="mb-3 text-xs font-medium tracking-[0.08em] text-muted/50 uppercase">
									Date range & satisfaction
								</p>
								<div class="space-y-3 text-base">
									<div>
										<label for="filter-created-from" class="mb-1 block text-sm text-muted/50"
											>Created from</label
										>
										<input
											id="filter-created-from"
											type="date"
											bind:value={createdFrom}
											class="w-full rounded-sm bg-surface-hover/40 px-2.5 py-1.5 text-base text-sidebar-text outline-none focus:bg-surface-hover/60"
											onchange={applyFilters}
										/>
									</div>
									<div>
										<label for="filter-created-to" class="mb-1 block text-sm text-muted/50"
											>Created to</label
										>
										<input
											id="filter-created-to"
											type="date"
											bind:value={createdTo}
											class="w-full rounded-sm bg-surface-hover/40 px-2.5 py-1.5 text-base text-sidebar-text outline-none focus:bg-surface-hover/60"
											onchange={applyFilters}
										/>
									</div>
									<div>
										<label for="filter-resolved-from" class="mb-1 block text-sm text-muted/50"
											>Resolved from</label
										>
										<input
											id="filter-resolved-from"
											type="date"
											bind:value={resolvedFrom}
											class="w-full rounded-sm bg-surface-hover/40 px-2.5 py-1.5 text-base text-sidebar-text outline-none focus:bg-surface-hover/60"
											onchange={applyFilters}
										/>
									</div>
									<div>
										<label for="filter-resolved-to" class="mb-1 block text-sm text-muted/50"
											>Resolved to</label
										>
										<input
											id="filter-resolved-to"
											type="date"
											bind:value={resolvedTo}
											class="w-full rounded-sm bg-surface-hover/40 px-2.5 py-1.5 text-base text-sidebar-text outline-none focus:bg-surface-hover/60"
											onchange={applyFilters}
										/>
									</div>
									<div class="grid grid-cols-2 gap-2">
										<div>
											<label for="filter-satisfaction-min" class="mb-1 block text-sm text-muted/50"
												>Satisfaction min</label
											>
											<input
												id="filter-satisfaction-min"
												type="number"
												min="1"
												max="5"
												bind:value={satisfactionMin}
												class="w-full rounded-sm bg-surface-hover/40 px-2.5 py-1.5 text-base text-sidebar-text outline-none focus:bg-surface-hover/60"
												onchange={applyFilters}
											/>
										</div>
										<div>
											<label for="filter-satisfaction-max" class="mb-1 block text-sm text-muted/50"
												>Satisfaction max</label
											>
											<input
												id="filter-satisfaction-max"
												type="number"
												min="1"
												max="5"
												bind:value={satisfactionMax}
												class="w-full rounded-sm bg-surface-hover/40 px-2.5 py-1.5 text-base text-sidebar-text outline-none focus:bg-surface-hover/60"
												onchange={applyFilters}
											/>
										</div>
									</div>
								</div>
								<button
									class="mt-3 flex h-7 w-full items-center justify-center rounded-sm bg-surface-hover/40 text-sm font-medium text-sidebar-text transition-all duration-150 hover:bg-surface-hover/60"
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
	{/if}

	{#if ticketStore.loading}
		<p class="px-4 py-8 text-center text-sm text-muted">Loading...</p>
	{:else if ticketStore.error}
		<p class="px-4 py-8 text-center text-sm text-red-500">{ticketStore.error}</p>
	{:else}
		<!-- svelte-ignore a11y_no_static_element_interactions -->
		<div class="p-3" onclick={() => { filterDropdownOpen = null; orgDropdownOpen = false; }}>
			{#if ticketStore.items.length === 0}
				<div class="flex flex-col items-center gap-3 py-12">
					<p class="text-sm text-muted">No tickets found.</p>
					{#if auth.can('support_tickets', 'create')}
						<button
							class="flex h-7 items-center justify-center gap-1 rounded-sm bg-accent px-2.5 text-sm leading-none font-medium text-white transition-all duration-150 hover:bg-accent/90"
							onclick={() => (createModalOpen = true)}
						>
							New Ticket
						</button>
					{/if}
				</div>
			{:else}
				<div class="overflow-hidden rounded border border-surface-border/50 bg-surface/50">
					{#each ticketStore.items as ticket, i (ticket.id)}
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
							selected={ticket.id === selectedTicketId}
							onclick={() => selectTicket(ticket.id)}
						/>
						{#if i < ticketStore.items.length - 1}
							<div class="mx-3 h-px bg-surface-border/30"></div>
						{/if}
					{/each}
				</div>
			{/if}
			<p class="mt-2 text-xs text-muted/30">{ticketStore.count} ticket{ticketStore.count === 1 ? '' : 's'}</p>
		</div>
	{/if}
</div>
</div>

<div
	class="h-full shrink-0 overflow-hidden transition-[width] duration-200 ease-out"
	style="width: {selectedTicketId ? '420px' : '0px'}"
>
	{#if selectedTicketId}
		<div class="h-full w-[420px]">
			<TicketDetailPanel
				ticketId={selectedTicketId}
				{members}
				initialTab={selectedTicketTab}
				onClose={() => selectTicket(null)}
				onTabChange={(tab) => {
					const url = new URL(window.location.href);
					if (tab === 'details') url.searchParams.delete('tab');
					else url.searchParams.set('tab', tab);
					replaceState(localizeHref(url.pathname + url.search), {});
				}}
				onUpdate={() => applyFilters()}
			/>
		</div>
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
