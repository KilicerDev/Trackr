<script lang="ts">
	import { browser } from '$app/environment';
	import { page } from '$app/state';
	import { goto, replaceState } from '$app/navigation';
	import { auth } from '$lib/stores/auth.svelte';
	import { clientPortal, type ClientTicket } from '$lib/stores/clientPortal.svelte';
	import { ListFilter, LayoutList, Columns3, Plus } from '@lucide/svelte';
	import { ticketStatusIcons, defaultStatusIcon } from '$lib/config/status-icons';
	import FilterDropdown from '$lib/components/FilterDropdown.svelte';
	import TicketRow from '$lib/components/TicketRow.svelte';
	import TicketBoardCard from '$lib/components/TicketBoardCard.svelte';
	import ClientTicketChat from '$lib/components/ClientTicketChat.svelte';
	import CreateTicketModal from '$lib/components/CreateTicketModal.svelte';
	import { SvelteURLSearchParams } from 'svelte/reactivity';
	import { localizeHref } from '$lib/paraglide/runtime';
	import * as m from '$lib/paraglide/messages';
	import { tStatus, tPriority, tCategory } from '$lib/i18n/ticket-labels';
	import type { LayoutData } from './$types';

	let { data }: { data: LayoutData } = $props();

	const TICKET_STATUSES = ['open', 'in_progress', 'paused', 'waiting_on_customer', 'waiting_on_agent', 'resolved', 'closed'] as const;
	const TICKET_PRIORITIES = ['urgent', 'high', 'medium', 'low'] as const;
	const TICKET_CATEGORIES = ['billing', 'technical_issue', 'feature_request', 'general'] as const;

	type ViewMode = 'list' | 'board';
	type GroupBy = 'none' | 'status' | 'priority';

	const selectedOrgId = $derived(page.url.searchParams.get('org') ?? data.organizations[0]?.id ?? '');
	const selectedTicketId = $derived(page.url.searchParams.get('ticket'));

	// Ensure ?org is always set in URL
	$effect(() => {
		if (!page.url.searchParams.get('org') && data.organizations.length > 0) {
			const params = new SvelteURLSearchParams(page.url.searchParams);
			params.set('org', data.organizations[0].id);
			goto(`${localizeHref('/c')}?${params.toString()}`, { replaceState: true });
		}
	});

	// Load tickets when org changes. Users whose role grants
	// support_tickets.read = all (e.g. a custom client-admin role) see every
	// ticket in the org; default 'own' scope keeps a customer to their own.
	$effect(() => {
		const orgId = selectedOrgId;
		const userId = auth.user?.id;
		if (!orgId || !userId) return;
		const scope = auth.scope('support_tickets', 'read');
		const filterCustomerId = scope === 'all' ? null : userId;
		clientPortal.loadTickets(orgId, filterCustomerId);
	});

	// ----- view mode + group + filters (persisted) -----
	function parseFilterParam(raw: string | null): { op: 'is' | 'is_not'; values: string[] } {
		if (!raw) return { op: 'is', values: [] };
		if (raw.startsWith('not:')) return { op: 'is_not', values: raw.slice(4).split(',').filter(Boolean) };
		if (raw.startsWith('is:')) return { op: 'is', values: raw.slice(3).split(',').filter(Boolean) };
		return { op: 'is', values: raw.split(',').filter(Boolean) };
	}
	function encodeFilterParam(op: 'is' | 'is_not', values: string[]): string {
		if (values.length === 0) return '';
		return (op === 'is_not' ? 'not:' : 'is:') + values.join(',');
	}

	function loadFiltersFromStorage() {
		if (!browser) return null;
		try {
			const raw = localStorage.getItem('c-filters');
			if (!raw) return null;
			const parsed = JSON.parse(raw);
			const has = parsed.statusSelected?.length || parsed.prioritySelected?.length || parsed.categorySelected?.length;
			return has ? parsed : null;
		} catch { return null; }
	}

	const initView = (page.url.searchParams.get('view') as ViewMode) ?? (browser ? localStorage.getItem('c-view') : null) ?? 'list';
	const initGroup = (page.url.searchParams.get('group') as GroupBy) ?? (browser ? localStorage.getItem('c-group') : null) ?? 'status';
	const hasUrlFilters = ['status', 'priority', 'category'].some((k) => page.url.searchParams.has(k));
	const stored = !hasUrlFilters && browser ? loadFiltersFromStorage() : null;

	const initStatusF = stored
		? { op: stored.statusOp, values: stored.statusSelected }
		: parseFilterParam(page.url.searchParams.get('status'));
	const initPriorityF = stored
		? { op: stored.priorityOp, values: stored.prioritySelected }
		: parseFilterParam(page.url.searchParams.get('priority'));
	const initCategoryF = stored
		? { op: stored.categoryOp, values: stored.categorySelected }
		: parseFilterParam(page.url.searchParams.get('category'));

	let viewMode = $state<ViewMode>(initView === 'board' ? 'board' : 'list');
	let groupBy = $state<GroupBy>((['none', 'status', 'priority'] as const).includes(initGroup as GroupBy) ? initGroup as GroupBy : 'status');
	let statusOp = $state<'is' | 'is_not'>(initStatusF.op);
	let statusSelected = $state<string[]>(initStatusF.values);
	let priorityOp = $state<'is' | 'is_not'>(initPriorityF.op);
	let prioritySelected = $state<string[]>(initPriorityF.values);
	let categoryOp = $state<'is' | 'is_not'>(initCategoryF.op);
	let categorySelected = $state<string[]>(initCategoryF.values);

	let filtersVisible = $state(false);
	let createModalOpen = $state(false);

	function saveFiltersToStorage() {
		if (!browser) return;
		const empty = !statusSelected.length && !prioritySelected.length && !categorySelected.length;
		if (empty) {
			localStorage.removeItem('c-filters');
		} else {
			localStorage.setItem('c-filters', JSON.stringify({
				statusOp, statusSelected, priorityOp, prioritySelected, categoryOp, categorySelected
			}));
		}
	}

	function syncUrl() {
		const url = new URL(window.location.href);
		const set = (k: string, v: string) => (v ? url.searchParams.set(k, v) : url.searchParams.delete(k));
		set('view', viewMode);
		set('group', groupBy);
		set('status', encodeFilterParam(statusOp, statusSelected));
		set('priority', encodeFilterParam(priorityOp, prioritySelected));
		set('category', encodeFilterParam(categoryOp, categorySelected));
		replaceState(localizeHref(url.pathname + url.search), {});
		saveFiltersToStorage();
	}

	function persistViewMode(v: ViewMode) {
		viewMode = v;
		if (browser) localStorage.setItem('c-view', v);
		// Board needs a group
		if (v === 'board' && groupBy === 'none') {
			groupBy = 'status';
			if (browser) localStorage.setItem('c-group', 'status');
		}
		syncUrl();
	}
	function persistGroupBy(g: GroupBy) {
		groupBy = g;
		if (browser) localStorage.setItem('c-group', g);
		syncUrl();
	}

	const hasActiveFilters = $derived(
		!!(statusSelected.length || prioritySelected.length || categorySelected.length)
	);
	const activeFiltersCount = $derived(
		[statusSelected.length, prioritySelected.length, categorySelected.length].filter(Boolean).length
	);

	function clearFilters() {
		statusOp = 'is'; statusSelected = [];
		priorityOp = 'is'; prioritySelected = [];
		categoryOp = 'is'; categorySelected = [];
		syncUrl();
	}

	function passes(t: ClientTicket): boolean {
		const apply = (val: string, op: 'is' | 'is_not', sel: string[]) => {
			if (sel.length === 0) return true;
			const inSet = sel.includes(val);
			return op === 'is' ? inSet : !inSet;
		};
		return (
			apply(t.status, statusOp, statusSelected)
			&& apply(t.priority, priorityOp, prioritySelected)
			&& apply(t.category ?? '', categoryOp, categorySelected)
		);
	}

	const filteredTickets = $derived(clientPortal.tickets.filter(passes));

	function groupLabel(key: string): string {
		return groupBy === 'priority' ? tPriority(key) : tStatus(key);
	}

	// ----- list view groups -----
	type ListGroup = { key: string; label: string; tickets: ClientTicket[] };
	const listGroups = $derived.by((): ListGroup[] | null => {
		if (groupBy === 'none') return null;
		const map = new Map<string, ListGroup>();
		const order: string[] = [];
		const keys = groupBy === 'status' ? TICKET_STATUSES : TICKET_PRIORITIES;
		for (const k of keys) {
			map.set(k, { key: k, label: groupLabel(k), tickets: [] });
			order.push(k);
		}
		for (const t of filteredTickets) {
			const k = (groupBy === 'status' ? t.status : t.priority);
			if (!map.has(k)) {
				map.set(k, { key: k, label: groupLabel(k), tickets: [] });
				order.push(k);
			}
			map.get(k)!.tickets.push(t);
		}
		return order.map((k) => map.get(k)!).filter((g) => g.tickets.length > 0);
	});

	// ----- board columns -----
	type BoardColumn = { key: string; label: string; tickets: ClientTicket[] };
	const boardColumns = $derived.by((): BoardColumn[] => {
		const keys = groupBy === 'priority' ? TICKET_PRIORITIES : TICKET_STATUSES;
		return keys.map((k) => ({
			key: k,
			label: groupLabel(k),
			tickets: filteredTickets.filter((t) => (groupBy === 'priority' ? t.priority : t.status) === k)
		}));
	});

	// ----- collapsed groups (shared between list & board, per groupBy) -----
	function loadCollapsed(): Record<string, string[]> {
		if (!browser) return {};
		try {
			const raw = localStorage.getItem('c-collapsed');
			return raw ? JSON.parse(raw) : {};
		} catch { return {}; }
	}
	let collapsedByGroup = $state<Record<string, string[]>>(loadCollapsed());
	const collapsedSet = $derived(new Set(collapsedByGroup[groupBy] ?? []));

	function toggleCollapsed(key: string) {
		const next = new Set(collapsedByGroup[groupBy] ?? []);
		if (next.has(key)) next.delete(key);
		else next.add(key);
		collapsedByGroup = { ...collapsedByGroup, [groupBy]: Array.from(next) };
		if (browser) localStorage.setItem('c-collapsed', JSON.stringify(collapsedByGroup));
	}

	// ----- helpers -----
	function formatLabel(s: string): string {
		return s.split('_').map((w) => w.charAt(0).toUpperCase() + w.slice(1)).join(' ');
	}

	function selectTicket(id: string) {
		const params = new SvelteURLSearchParams(page.url.searchParams);
		params.set('ticket', id);
		goto(`${localizeHref('/c')}?${params.toString()}`);
	}
	function backToList() {
		const params = new SvelteURLSearchParams(page.url.searchParams);
		params.delete('ticket');
		goto(`${localizeHref('/c')}?${params.toString()}`);
	}

</script>

<svelte:head><title>{m.client_page_title()}</title></svelte:head>

{#if selectedTicketId}
	<div class="flex h-[calc(100vh-3rem)] min-h-0 flex-col">
		<ClientTicketChat ticketId={selectedTicketId} onBack={backToList} />
	</div>
{:else}
	<div class="flex h-[calc(100vh-3rem)] min-h-0 flex-col">
		<!-- Toolbar -->
		<div class="flex shrink-0 items-center justify-between gap-2 border-b border-surface-border px-3 py-1.5">
			<div class="flex items-center gap-1">
				<button
					class="flex h-7 items-center gap-1 rounded-sm px-2 text-sm font-medium leading-none transition-all duration-150 hover:bg-surface-hover/50 {viewMode === 'list' ? 'text-accent' : 'text-muted'}"
					onclick={() => persistViewMode('list')}
				>
					<LayoutList size={12} /> {m.client_view_list()}
				</button>
				<button
					class="flex h-7 items-center gap-1 rounded-sm px-2 text-sm font-medium leading-none transition-all duration-150 hover:bg-surface-hover/50 {viewMode === 'board' ? 'text-accent' : 'text-muted'}"
					onclick={() => persistViewMode('board')}
				>
					<Columns3 size={12} /> {m.client_view_board()}
				</button>

				<div class="mx-1 h-4 w-px bg-surface-border/60"></div>

				<!-- Group by -->
				<button
					class="flex h-7 items-center gap-1 rounded-sm px-2 text-sm font-medium leading-none transition-all duration-150 hover:bg-surface-hover/50 {groupBy === 'status' ? 'text-accent' : 'text-muted'}"
					onclick={() => persistGroupBy('status')}
				>
					{m.client_group_status()}
				</button>
				<button
					class="flex h-7 items-center gap-1 rounded-sm px-2 text-sm font-medium leading-none transition-all duration-150 hover:bg-surface-hover/50 {groupBy === 'priority' ? 'text-accent' : 'text-muted'}"
					onclick={() => persistGroupBy('priority')}
				>
					{m.client_group_priority()}
				</button>
				{#if viewMode === 'list'}
					<button
						class="flex h-7 items-center gap-1 rounded-sm px-2 text-sm font-medium leading-none transition-all duration-150 hover:bg-surface-hover/50 {groupBy === 'none' ? 'text-accent' : 'text-muted'}"
						onclick={() => persistGroupBy('none')}
					>
						{m.client_group_none()}
					</button>
				{/if}

				<div class="mx-1 h-4 w-px bg-surface-border/60"></div>

				<button
					class="relative flex h-7 items-center gap-1 rounded-sm px-2 text-sm font-medium leading-none transition-all duration-150 hover:bg-surface-hover/50 {filtersVisible || hasActiveFilters ? 'text-accent' : 'text-muted'}"
					onclick={() => (filtersVisible = !filtersVisible)}
				>
					<ListFilter size={12} />
					{#if activeFiltersCount > 0}
						<span class="absolute -top-0.5 -right-0.5 flex h-3.5 w-3.5 items-center justify-center rounded-full bg-accent/15 text-2xs font-semibold text-accent">
							{activeFiltersCount}
						</span>
					{/if}
				</button>
			</div>

			<div class="flex items-center gap-2">
				<button
					class="flex h-7 items-center justify-center gap-1 rounded-sm bg-accent px-2.5 text-sm leading-none font-medium text-white transition-all duration-150 hover:bg-accent/90"
					onclick={() => (createModalOpen = true)}
				>
					<Plus size={14} class="shrink-0" />
					{m.client_new_ticket()}
				</button>
			</div>
		</div>

		<!-- Filters bar -->
		{#if filtersVisible}
			<div class="flex shrink-0 items-center gap-0.5 border-b border-surface-border px-3 py-1">
				<div class="flex flex-wrap items-center gap-0.5">
					<FilterDropdown
						label={m.client_filter_status()}
						options={TICKET_STATUSES.map((s) => ({ value: s, label: tStatus(s) }))}
						operator={statusOp}
						selected={statusSelected}
						onchange={(op, sel) => { statusOp = op; statusSelected = sel; syncUrl(); }}
					/>
					<FilterDropdown
						label={m.client_filter_priority()}
						options={TICKET_PRIORITIES.map((p) => ({ value: p, label: tPriority(p) }))}
						operator={priorityOp}
						selected={prioritySelected}
						onchange={(op, sel) => { priorityOp = op; prioritySelected = sel; syncUrl(); }}
					/>
					<FilterDropdown
						label={m.client_filter_category()}
						options={TICKET_CATEGORIES.map((c) => ({ value: c, label: tCategory(c) }))}
						operator={categoryOp}
						selected={categorySelected}
						onchange={(op, sel) => { categoryOp = op; categorySelected = sel; syncUrl(); }}
					/>
				</div>
				{#if hasActiveFilters}
					<button class="ml-1 text-xs text-muted/40 transition-colors hover:text-accent" onclick={clearFilters}>
						{m.client_clear()}
					</button>
				{/if}
			</div>
		{/if}

		<!-- Content -->
		{#if clientPortal.loading && clientPortal.tickets.length === 0}
			<p class="px-4 py-12 text-center text-lg text-muted">{m.client_loading()}</p>
		{:else if clientPortal.error}
			<p class="px-4 py-12 text-center text-lg text-red-500">{clientPortal.error}</p>
		{:else if clientPortal.tickets.length === 0}
			<div class="flex flex-1 flex-col items-center justify-center gap-4 px-4 py-12">
				<p class="text-base text-muted">{m.client_no_tickets_yet()}</p>
				<button
					class="flex h-8 items-center gap-1.5 rounded-sm bg-accent px-3 text-sm font-medium text-white transition-all duration-150 hover:bg-accent/90"
					onclick={() => (createModalOpen = true)}
				>
					<Plus size={14} /> {m.client_create_first_ticket()}
				</button>
			</div>
		{:else if filteredTickets.length === 0}
			<div class="flex flex-1 flex-col items-center justify-center gap-3 px-4 py-12">
				<p class="text-base text-muted">{m.client_no_match_filters()}</p>
				<button class="text-sm text-accent hover:underline" onclick={clearFilters}>{m.client_clear_filters()}</button>
			</div>
		{:else if viewMode === 'list'}
			<div class="flex-1 overflow-y-auto">
				{#if listGroups}
					{#each listGroups as group (group.key)}
						{@const isCollapsed = collapsedSet.has(group.key)}
						{@const statusInfo = ticketStatusIcons[group.key] ?? defaultStatusIcon}
						{@const StatusIcon = statusInfo.icon}
						<button
							class="sticky top-0 z-10 flex w-full items-center gap-2 border-b border-surface-border bg-page-bg px-3 py-1.5 text-left transition-colors hover:bg-surface-hover/30"
							onclick={() => toggleCollapsed(group.key)}
						>
							{#if groupBy === 'status'}
								<StatusIcon size={11} class={statusInfo.className} />
							{/if}
							<span class="text-sm font-medium text-sidebar-text">{group.label}</span>
							<span class="text-xs text-muted/50">{group.tickets.length}</span>
						</button>
						{#if !isCollapsed}
							<div>
								{#each group.tickets as ticket, i (ticket.id)}
									<TicketRow
										ticket={ticket as never}
										onclick={() => selectTicket(ticket.id)}
									/>
									{#if i < group.tickets.length - 1}
										<div class="mx-3 h-px bg-surface-border/30"></div>
									{/if}
								{/each}
							</div>
						{/if}
					{/each}
				{:else}
					<div>
						{#each filteredTickets as ticket (ticket.id)}
							<TicketRow ticket={ticket as never} onclick={() => selectTicket(ticket.id)} />
						{/each}
					</div>
				{/if}
			</div>
		{:else}
			<!-- Board view (read-only, no DnD) -->
			<div class="flex min-h-0 flex-1 gap-0 overflow-x-auto">
				{#each boardColumns as col (col.key)}
					{@const collapsed = collapsedSet.has(col.key)}
					{@const statusInfo = ticketStatusIcons[col.key] ?? defaultStatusIcon}
					{@const StatusIcon = statusInfo.icon}
					<div class="flex {collapsed ? 'w-9' : 'w-64'} shrink-0 flex-col border-r border-surface-border/50 max-h-full last:border-r-0 transition-[width] duration-150">
						{#if collapsed}
							<button
								type="button"
								class="flex flex-col items-center gap-2 px-2 py-2 text-left transition-colors hover:bg-surface-hover/30 cursor-pointer"
								title="Expand {col.label}"
								onclick={() => toggleCollapsed(col.key)}
							>
								{#if groupBy === 'status'}
									<StatusIcon size={11} class={statusInfo.className} />
								{/if}
								<span class="text-sm font-medium text-muted truncate [writing-mode:vertical-rl]">{col.label}</span>
								<span class="text-xs text-muted/30">{col.tickets.length}</span>
							</button>
						{:else}
							<button
								type="button"
								class="flex items-center gap-2 px-3 py-2 text-left transition-colors hover:bg-surface-hover/30 cursor-pointer"
								title="Collapse {col.label}"
								onclick={() => toggleCollapsed(col.key)}
							>
								{#if groupBy === 'status'}
									<StatusIcon size={11} class={statusInfo.className} />
								{/if}
								<span class="text-sm font-medium text-muted truncate">{col.label}</span>
								<span class="text-xs text-muted/30">{col.tickets.length}</span>
							</button>
							<div class="flex-1 overflow-y-auto px-2 pb-2 min-h-[60px] scrollbar-none" style="-ms-overflow-style: none; scrollbar-width: none;">
								{#each col.tickets as ticket (ticket.id)}
									<TicketBoardCard
										ticket={ticket as never}
										showStatus={groupBy === 'priority'}
										onclick={() => selectTicket(ticket.id)}
									/>
								{/each}
							</div>
						{/if}
					</div>
				{/each}
			</div>
		{/if}
	</div>
{/if}

{#if createModalOpen}
	<CreateTicketModal
		organizationId={selectedOrgId}
		customers={[]}
		onClose={() => (createModalOpen = false)}
		onSuccess={() => {
			createModalOpen = false;
			if (auth.user) {
				const scope = auth.scope('support_tickets', 'read');
				clientPortal.loadTickets(selectedOrgId, scope === 'all' ? null : auth.user.id);
			}
		}}
	/>
{/if}

<style>
	.scrollbar-none::-webkit-scrollbar { display: none; }
</style>
