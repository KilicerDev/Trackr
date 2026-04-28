<svelte:head><title>Tickets – Trackr</title></svelte:head>

<script lang="ts">
	import { onMount } from 'svelte';
	import { browser } from '$app/environment';
	import { page } from '$app/state';
	import { replaceState, afterNavigate } from '$app/navigation';
	import { dndzone } from 'svelte-dnd-action';
	import { auth } from '$lib/stores/auth.svelte';
	import { ticketStore, type Ticket } from '$lib/stores/tickets.svelte';
	import { orgStore } from '$lib/stores/organizations.svelte';
	import { api } from '$lib/api';
	import { clickOutside } from '$lib/actions/clickOutside';
	import type { TicketFilters } from '$lib/api/tickets';
	import type { FilterOp } from '$lib/api/tasks';
	import type { SavedView } from '$lib/api/views';
	import { localizeHref } from '$lib/paraglide/runtime';
	import { slide } from 'svelte/transition';
	import { ChevronDown } from '@lucide/svelte';
	import TicketRow from '$lib/components/TicketRow.svelte';
	import TicketBoardCard from '$lib/components/TicketBoardCard.svelte';
	import CreateTicketModal from '$lib/components/CreateTicketModal.svelte';
	import TicketDetailPanel from '$lib/components/TicketDetailPanel.svelte';
	import FilterDropdown from '$lib/components/FilterDropdown.svelte';
	import ListBoardToolbar from '$lib/components/ListBoardToolbar.svelte';
	import Modal from '$lib/components/Modal.svelte';

	const TICKET_STATUSES = [
		'open',
		'in_progress',
		'paused',
		'waiting_on_customer',
		'waiting_on_agent',
		'resolved',
		'closed'
	] as const;
	const TICKET_PRIORITIES = ['low', 'medium', 'high', 'urgent'] as const;
	const TICKET_CATEGORIES = ['billing', 'technical_issue', 'feature_request', 'general'] as const;
	const TICKET_CHANNELS = ['email', 'api', 'chat', 'web_form'] as const;
	const GROUP_OPTIONS = ['none', 'status', 'priority', 'category'] as const;

	type ViewMode = 'list' | 'board';
	type GroupBy = (typeof GROUP_OPTIONS)[number];

	type Member = {
		user_id: string;
		user: { id: string; full_name: string; avatar_url: string | null; is_active: boolean; deleted_at: string | null };
		role: { id: string; name: string; slug: string } | null;
	};
	type CustomerOption = { id: string; full_name: string; email: string; avatar_url: string | null };

	const organizations = $derived(orgStore.all);
	let selectedOrgId = $state<string | null>(ticketStore.lastLoadedOrgId ?? null);
	let orgDropdownOpen = $state(false);

	const initView = (page.url.searchParams.get('view') as ViewMode) ?? (browser ? localStorage.getItem('tickets-view') : null) ?? 'list';
	let viewMode = $state<ViewMode>(initView === 'board' ? 'board' : 'list');

	const initGroup = (browser ? localStorage.getItem('tickets-group') : null) ?? 'status';
	let groupBy = $state<GroupBy>(GROUP_OPTIONS.includes(initGroup as GroupBy) ? (initGroup as GroupBy) : 'status');

	function loadCollapsed(): Record<string, string[]> {
		if (!browser) return {};
		try {
			const raw = localStorage.getItem('tickets-collapsed');
			return raw ? JSON.parse(raw) : {};
		} catch {
			return {};
		}
	}
	let collapsedByGroup = $state<Record<string, string[]>>(loadCollapsed());
	const collapsedSet = $derived(new Set(collapsedByGroup[groupBy] ?? []));

	function toggleCollapsed(key: string) {
		const next = new Set(collapsedByGroup[groupBy] ?? []);
		if (next.has(key)) next.delete(key);
		else next.add(key);
		collapsedByGroup = { ...collapsedByGroup, [groupBy]: Array.from(next) };
		if (browser) localStorage.setItem('tickets-collapsed', JSON.stringify(collapsedByGroup));
	}

	function setGroupBy(g: GroupBy) {
		groupBy = g;
		if (browser) localStorage.setItem('tickets-group', g);
	}

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

	// ---------- saved views ----------
	let savedViews = $state<SavedView[]>([]);
	let activeViewId = $state<string | null>(browser ? localStorage.getItem('tickets-active-view') : null);
	$effect(() => {
		if (!browser) return;
		if (activeViewId) localStorage.setItem('tickets-active-view', activeViewId);
		else localStorage.removeItem('tickets-active-view');
	});
	let saveModalOpen = $state(false);
	let saveViewName = $state('');
	let savingView = $state(false);

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
		// Skip status filter when board groups by status (column = status)
		if (viewMode !== 'board') f.status = toFilterOp(statusOp, statusSelected);
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

	async function applyFilters(keepView = false) {
		if (!keepView) activeViewId = null;
		await ticketStore.load(selectedOrgId ?? undefined, getFilters());
		if (viewMode === 'board') rebuildBoard();
	}

	function selectOrg(orgId: string | null) {
		selectedOrgId = orgId;
		orgDropdownOpen = false;
		applyFilters(true);
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
		applyFilters();
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

	import { dropdownPanelClass } from '$lib/config/filter-styles';

	// ---------- Board ----------

	function formatStatus(s: string): string {
		return s.split('_').map((w) => w.charAt(0).toUpperCase() + w.slice(1)).join(' ');
	}

	// List grouping
	type ListGroup = { key: string; label: string; tickets: Ticket[] };

	const listGroups = $derived.by((): ListGroup[] | null => {
		if (groupBy === 'none') return null;
		const items = ticketStore.items;
		const map = new Map<string, ListGroup>();
		const order: string[] = [];

		const seedKeys =
			groupBy === 'status'
				? (TICKET_STATUSES as readonly string[])
				: groupBy === 'priority'
				? (TICKET_PRIORITIES as readonly string[])
				: (TICKET_CATEGORIES as readonly string[]);

		for (const k of seedKeys) {
			map.set(k, { key: k, label: formatStatus(k), tickets: [] });
			order.push(k);
		}

		for (const t of items) {
			const raw =
				groupBy === 'status'
					? t.status
					: groupBy === 'priority'
					? t.priority
					: (t.category ?? '__none__');
			const key = raw || '__none__';
			let g = map.get(key);
			if (!g) {
				g = {
					key,
					label: key === '__none__' ? 'Uncategorized' : formatStatus(key),
					tickets: []
				};
				map.set(key, g);
				order.push(key);
			}
			g.tickets.push(t);
		}

		return order.map((k) => map.get(k)!).filter((g) => g.tickets.length > 0);
	});

	type BoardColumn = { key: string; label: string; items: (Ticket & { id: string })[] };
	let boardColumns = $state<BoardColumn[]>([]);

	function rebuildBoard() {
		boardColumns = TICKET_STATUSES.map((s) => ({
			key: s,
			label: formatStatus(s),
			items: ticketStore.items
				.filter((t) => t.status === s)
				.map((t) => ({ ...t, id: t.id })) as (Ticket & { id: string })[]
		}));
	}

	function handleConsider(colIndex: number, e: CustomEvent<{ items: (Ticket & { id: string })[] }>) {
		boardColumns[colIndex].items = e.detail.items;
	}

	async function handleFinalize(
		colIndex: number,
		colKey: string,
		e: CustomEvent<{ items: (Ticket & { id: string })[] }>
	) {
		boardColumns[colIndex].items = e.detail.items;

		const moved: { id: string; status: string }[] = [];
		for (const item of e.detail.items) {
			if (item.status !== colKey) {
				item.status = colKey;
				moved.push({ id: item.id, status: colKey });
			}
		}

		for (const m of moved) {
			try {
				const patch: Record<string, unknown> = { status: m.status };
				if (m.status === 'resolved') patch.resolved_at = new Date().toISOString();
				await api.tickets.update(m.id, patch);
			} catch (err) {
				console.error('[Tickets board] Failed to persist move:', err);
				await ticketStore.load(selectedOrgId ?? undefined, getFilters());
				rebuildBoard();
				return;
			}
		}

		if (moved.length > 0) {
			const moveMap = new Map(moved.map((m) => [m.id, m.status]));
			ticketStore.items = ticketStore.items.map((t) => {
				const newStatus = moveMap.get(t.id);
				return newStatus ? { ...t, status: newStatus } : t;
			});
		}
	}

	$effect(() => {
		const _ = ticketStore.items; // track dependency
		if (viewMode === 'board') rebuildBoard();
	});

	async function setView(v: ViewMode) {
		viewMode = v;
		if (browser) localStorage.setItem('tickets-view', v);
		const url = new URL(window.location.href);
		url.searchParams.set('view', v);
		replaceState(localizeHref(url.pathname + url.search), {});
		await ticketStore.load(selectedOrgId ?? undefined, getFilters());
		if (v === 'board') rebuildBoard();
	}

	// ---------- saved views ----------

	function getCurrentViewState() {
		return {
			statusOp, statusSelected,
			priorityOp, prioritySelected,
			categoryOp, categorySelected,
			channelOp, channelSelected,
			assignedAgentId, customerId,
			createdFrom, createdTo,
			resolvedFrom, resolvedTo,
			satisfactionMin, satisfactionMax,
			selectedOrgId
		};
	}

	async function loadSavedViews() {
		try {
			savedViews = await api.views.getAll('tickets');
			if (activeViewId && !savedViews.some((v) => v.id === activeViewId)) {
				activeViewId = null;
			}
		} catch { /* ignore */ }
	}

	async function saveCurrentView() {
		const name = saveViewName.trim();
		if (!name) return;
		savingView = true;
		try {
			const view = await api.views.create({
				name,
				filters: getCurrentViewState(),
				view_mode: viewMode,
				group_by: groupBy,
				scope: 'tickets'
			});
			savedViews = [...savedViews, view];
			activeViewId = view.id;
			saveViewName = '';
			saveModalOpen = false;
		} catch (e) {
			console.error('Failed to save view:', e);
		} finally {
			savingView = false;
		}
	}

	async function applySavedView(view: SavedView) {
		const f = view.filters as Record<string, unknown>;
		statusOp = (f.statusOp as 'is' | 'is_not') ?? 'is';
		statusSelected = (f.statusSelected as string[]) ?? [];
		priorityOp = (f.priorityOp as 'is' | 'is_not') ?? 'is';
		prioritySelected = (f.prioritySelected as string[]) ?? [];
		categoryOp = (f.categoryOp as 'is' | 'is_not') ?? 'is';
		categorySelected = (f.categorySelected as string[]) ?? [];
		channelOp = (f.channelOp as 'is' | 'is_not') ?? 'is';
		channelSelected = (f.channelSelected as string[]) ?? [];
		assignedAgentId = (f.assignedAgentId as string) ?? '';
		customerId = (f.customerId as string) ?? '';
		createdFrom = (f.createdFrom as string) ?? '';
		createdTo = (f.createdTo as string) ?? '';
		resolvedFrom = (f.resolvedFrom as string) ?? '';
		resolvedTo = (f.resolvedTo as string) ?? '';
		satisfactionMin = (f.satisfactionMin as number | '') ?? '';
		satisfactionMax = (f.satisfactionMax as number | '') ?? '';

		const orgFromView = (f.selectedOrgId as string | null | undefined) ?? null;
		if (orgFromView !== selectedOrgId) {
			selectOrg(orgFromView);
		}

		if (view.view_mode === 'board' || view.view_mode === 'list') viewMode = view.view_mode as ViewMode;
		if (GROUP_OPTIONS.includes(view.group_by as GroupBy)) setGroupBy(view.group_by as GroupBy);

		activeViewId = view.id;
		await applyFilters(true);
	}

	async function renameSavedView(id: string, name: string) {
		try {
			const updated = await api.views.update(id, { name });
			savedViews = savedViews.map((v) => (v.id === id ? updated : v));
		} catch (e) {
			console.error('Failed to rename view:', e);
		}
	}

	async function deleteView(id: string) {
		try {
			await api.views.delete(id);
			savedViews = savedViews.filter((v) => v.id !== id);
			if (activeViewId === id) activeViewId = null;
		} catch (e) {
			console.error('Failed to delete view:', e);
		}
	}

	async function updateViewFilters(id: string) {
		try {
			const updated = await api.views.update(id, {
				filters: getCurrentViewState(),
				view_mode: viewMode,
				group_by: groupBy
			});
			savedViews = savedViews.map((v) => (v.id === id ? updated : v));
		} catch (e) {
			console.error('Failed to update view:', e);
		}
	}

	// ---------- lifecycle ----------

	onMount(async () => {
		await orgStore.loadIfNeeded();

		if (!selectedOrgId || !ticketOrgs.some((o) => o.id === selectedOrgId)) {
			const orgId = auth.organizationId;
			selectedOrgId = ticketOrgs.some((o) => o.id === orgId) ? orgId : null;
		}

		await ticketStore.loadIfNeeded(selectedOrgId ?? undefined, getFilters());
		loadSavedViews();
		if (viewMode === 'board') rebuildBoard();

		if (selectedOrgId) {
			Promise.all([
				api.members.getAll(selectedOrgId).catch(() => [] as Member[]),
				api.tickets.getCustomersByOrg(selectedOrgId).catch(() => [] as CustomerOption[])
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
					document.querySelector(`[data-ticket-id="${items[next].id}"]`)
						?.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
				});
			}
		}
		document.addEventListener('keydown', handleKeydown);
		return () => document.removeEventListener('keydown', handleKeydown);
	});
</script>

<div class="flex h-full overflow-hidden">
<div class="flex min-w-0 flex-1 flex-col {viewMode === 'board' ? 'overflow-hidden' : 'overflow-y-auto'}">
<div
	class="flex h-full min-h-0 w-full flex-col"
	use:clickOutside={{
		onClickOutside: () => {
			orgDropdownOpen = false;
			filterDropdownOpen = null;
		},
		enabled: orgDropdownOpen || filterDropdownOpen !== null
	}}
>
	<!-- ===== HEADER ===== -->
	<ListBoardToolbar
		viewMode={viewMode}
		onViewChange={setView}
		groupBy={groupBy}
		groupOptions={GROUP_OPTIONS}
		groupOptionsForBoard={[]}
		onGroupChange={(g) => setGroupBy(g as GroupBy)}
		filtersVisible={filtersVisible}
		activeFiltersCount={activeFiltersCount}
		onFilterToggle={() => (filtersVisible = !filtersVisible)}
		savedViews={savedViews}
		activeViewId={activeViewId}
		onApplyView={applySavedView}
		onSaveCurrentView={() => { saveModalOpen = true; saveViewName = ''; }}
		onRenameView={renameSavedView}
		onDeleteView={deleteView}
		onUpdateViewFilters={updateViewFilters}
		newLabel="New Ticket"
		newDisabled={!auth.can('support_tickets', 'create')}
		newDisabledTitle="You don't have permission to create tickets"
		onNew={() => (createModalOpen = true)}
	>
		{#snippet leftSlot()}
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
		{/snippet}
	</ListBoardToolbar>

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
		<div class="shrink-0 border-b border-surface-border px-3 py-1.5">
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
				{#if viewMode !== 'board'}
					<FilterDropdown
						label="Status"
						options={TICKET_STATUSES.map((s) => ({ value: s, label: s.replace(/_/g, ' ') }))}
						operator={statusOp}
						selected={statusSelected}
						onchange={(op, sel) => { statusOp = op; statusSelected = sel; applyFilters(); }}
					/>
				{/if}
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
											onchange={() => applyFilters()}
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
											onchange={() => applyFilters()}
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
											onchange={() => applyFilters()}
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
											onchange={() => applyFilters()}
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
												onchange={() => applyFilters()}
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
												onchange={() => applyFilters()}
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

	<!-- ===== CONTENT ===== -->
	{#if ticketStore.loading}
		<p class="px-4 py-8 text-center text-sm text-muted">Loading...</p>
	{:else if ticketStore.error}
		<p class="px-4 py-8 text-center text-sm text-red-500">{ticketStore.error}</p>
	{:else if viewMode === 'list'}
		<!-- LIST VIEW -->
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
			{:else if listGroups}
				<div class="space-y-1">
					{#each listGroups as group (group.key)}
						{@const isCollapsed = collapsedSet.has(group.key)}
						<button
							class="flex w-full items-center gap-1.5 px-1 py-1 text-left"
							onclick={() => toggleCollapsed(group.key)}
						>
							<ChevronDown size={10} class="shrink-0 text-muted/30 transition-transform duration-150 {isCollapsed ? '-rotate-90' : ''}" />
							<span class="text-sm font-medium text-muted">{group.label}</span>
							<span class="text-xs text-muted/30">{group.tickets.length}</span>
						</button>
						{#if !isCollapsed}
							<div transition:slide={{ duration: 150 }} class="mb-2 overflow-hidden rounded border border-surface-border/50 bg-surface/50">
								{#each group.tickets as ticket, i (ticket.id)}
									<TicketRow
										ticket={ticket}
										selected={ticket.id === selectedTicketId}
										onclick={() => selectTicket(ticket.id)}
									/>
									{#if i < group.tickets.length - 1}
										<div class="mx-3 h-px bg-surface-border/30"></div>
									{/if}
								{/each}
							</div>
						{/if}
					{/each}
				</div>
			{:else}
				<div class="overflow-hidden rounded border border-surface-border/50 bg-surface/50">
					{#each ticketStore.items as ticket, i (ticket.id)}
						<TicketRow
							ticket={ticket}
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
	{:else}
		<!-- BOARD VIEW -->
		<div class="flex min-h-0 flex-1 gap-0 overflow-x-auto">
			{#each boardColumns as col, colIndex (col.key)}
				<div class="flex w-64 shrink-0 flex-col border-r border-surface-border/50 max-h-full last:border-r-0">
					<div class="flex items-center gap-2 px-3 py-2">
						<span class="text-sm font-medium text-muted truncate">{col.label}</span>
						<span class="ml-auto shrink-0 text-xs text-muted/30">{col.items.length}</span>
					</div>
					<div
						class="flex-1 overflow-y-auto px-2 pb-2 min-h-[60px] scrollbar-none"
						style="-ms-overflow-style: none; scrollbar-width: none;"
						use:dndzone={{ items: col.items, flipDurationMs: 200, dropTargetStyle: { outline: '2px solid var(--color-accent)', outlineOffset: '-2px' } }}
						onconsider={(e) => handleConsider(colIndex, e)}
						onfinalize={(e) => handleFinalize(colIndex, col.key, e)}
					>
						{#each col.items as ticket (ticket.id)}
							<TicketBoardCard
								ticket={ticket}
								selected={selectedTicketId === ticket.id}
								onclick={() => selectTicket(ticket.id)}
							/>
						{/each}
					</div>
				</div>
			{/each}
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
				onUpdate={(updated) => {
					if (updated) ticketStore.patch(updated.id, updated as unknown as Partial<typeof ticketStore.items[number]>);
					else applyFilters(true);
				}}
			/>
		</div>
	{/if}
</div>
</div>

<!-- ===== SAVE VIEW MODAL ===== -->
<Modal open={saveModalOpen} onClose={() => (saveModalOpen = false)} maxWidth="max-w-sm">
	<div class="px-3 py-2.5 border-b border-surface-border">
		<h2 class="text-md font-semibold text-sidebar-text">Save view</h2>
	</div>
	<form onsubmit={(e) => { e.preventDefault(); saveCurrentView(); }} class="p-3 space-y-3">
		<div>
			<label for="ticket-view-name" class="mb-1.5 block text-xs font-medium uppercase tracking-[0.08em] text-muted/50">Name</label>
			<input
				id="ticket-view-name"
				type="text"
				bind:value={saveViewName}
				placeholder="e.g. Open billing tickets"
				class="w-full rounded-sm bg-surface-hover/40 px-2.5 py-1.5 text-base text-sidebar-text outline-none transition-all duration-150 placeholder:text-muted/30 focus:bg-surface-hover/60"
			/>
			<p class="mt-1.5 text-xs text-muted/40">Saves the current filters, organization, and view mode.</p>
		</div>
		<div class="flex justify-end gap-2 pt-1">
			<button
				type="button"
				class="flex h-7 items-center rounded-sm bg-surface-hover/40 px-2.5 text-sm font-medium text-sidebar-text transition-all duration-150 hover:bg-surface-hover/60"
				onclick={() => (saveModalOpen = false)}
			>
				Cancel
			</button>
			<button
				type="submit"
				disabled={savingView || !saveViewName.trim()}
				class="flex h-7 items-center gap-1 rounded-sm bg-accent px-2.5 text-sm font-medium text-white transition-all duration-150 hover:bg-accent/90 disabled:opacity-30"
			>
				{savingView ? 'Saving…' : 'Save view'}
			</button>
		</div>
	</form>
</Modal>

<style>
	.scrollbar-none::-webkit-scrollbar {
		display: none;
	}

	@keyframes dropdown-in {
		from { opacity: 0; }
		to { opacity: 1; }
	}
	:global(.animate-dropdown-in) {
		animation: dropdown-in 150ms ease-out;
	}
</style>
