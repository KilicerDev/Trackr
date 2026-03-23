<script lang="ts">
	import { onMount } from 'svelte';
	import { browser } from '$app/environment';
	import { page } from '$app/state';
	import { replaceState } from '$app/navigation';
	import { dndzone } from 'svelte-dnd-action';
	import { taskStore, type Task } from '$lib/stores/tasks.svelte';
	import { projectStore } from '$lib/stores/projects.svelte';
	import { orgStore } from '$lib/stores/organizations.svelte';
	import { auth } from '$lib/stores/auth.svelte';
	import { localizeHref } from '$lib/paraglide/runtime';
	import { typeIcons, defaultTypeIcon } from '$lib/config/task-icons';
	import { api } from '$lib/api';
	import type { TaskFilters } from '$lib/api/tasks';
	import type { FilterOp } from '$lib/api/tasks';
	import TaskRow from '$lib/components/TaskRow.svelte';
	import TaskDetailPanel from '$lib/components/TaskDetailPanel.svelte';
	import CreateTaskModal from '$lib/components/CreateTaskModal.svelte';
	import FilterDropdown from '$lib/components/FilterDropdown.svelte';
	import {
		ListFilter,
		LayoutList,
		Columns3,
		ChevronLeft,
		ChevronRight,
		Search,
		X,
		Plus
	} from '@lucide/svelte';

	const TASK_STATUSES = ['backlog', 'todo', 'in_progress', 'in_review', 'done', 'cancelled'] as const;
	const TASK_PRIORITIES = ['none', 'low', 'medium', 'high', 'urgent'] as const;
	const TASK_TYPES = ['task', 'bug', 'feature', 'improvement', 'epic'] as const;
	const GROUP_OPTIONS = ['none', 'status', 'project'] as const;

	type ViewMode = 'list' | 'board';
	type GroupBy = (typeof GROUP_OPTIONS)[number];

	const priorityColors: Record<string, string> = {
		urgent: 'bg-red-100 text-red-700 dark:bg-red-950/60 dark:text-red-300',
		high: 'bg-orange-100 text-orange-700 dark:bg-orange-950/60 dark:text-orange-300',
		medium: 'bg-yellow-100 text-yellow-700 dark:bg-yellow-950/60 dark:text-yellow-300',
		low: 'bg-blue-100 text-blue-700 dark:bg-blue-950/60 dark:text-blue-300',
		none: 'bg-gray-100 text-gray-500 dark:bg-surface-hover dark:text-muted'
	};

	const statusColors: Record<string, string> = {
		backlog: 'bg-gray-100 text-gray-600 dark:bg-surface-hover dark:text-sidebar-text',
		todo: 'bg-gray-100 text-gray-700 dark:bg-surface-hover dark:text-sidebar-text',
		in_progress: 'bg-pink-100 text-pink-700 dark:bg-pink-950/60 dark:text-pink-300',
		in_review: 'bg-purple-100 text-purple-700 dark:bg-purple-950/60 dark:text-purple-300',
		done: 'bg-green-100 text-green-700 dark:bg-green-950/60 dark:text-green-300',
		cancelled: 'bg-gray-100 text-gray-400 dark:bg-surface-hover dark:text-muted'
	};

	// ---------- state ----------

	const initView = (page.url.searchParams.get('view') as ViewMode) ?? (browser ? localStorage.getItem('tasks-view') : null) ?? 'list';
	const initGroup = (page.url.searchParams.get('group') as GroupBy) ?? (browser ? localStorage.getItem('tasks-group') : null) ?? 'status';

	let viewMode = $state<ViewMode>(initView === 'board' ? 'board' : 'list');
	let groupBy = $state<GroupBy>(GROUP_OPTIONS.includes(initGroup as GroupBy) ? (initGroup as GroupBy) : 'status');

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

	function saveFiltersToStorage() {
		if (!browser) return;
		localStorage.setItem('tasks-filters', JSON.stringify({
			statusOp, statusSelected, priorityOp, prioritySelected,
			typeOp, typeSelected, projectOp, projectSelected, searchQuery
		}));
	}

	function loadFiltersFromStorage() {
		if (!browser) return null;
		try {
			const raw = localStorage.getItem('tasks-filters');
			return raw ? JSON.parse(raw) : null;
		} catch { return null; }
	}

	const hasUrlFilters = ['status', 'priority', 'type', 'project', 'q'].some(k => page.url.searchParams.has(k));
	const storedFilters = !hasUrlFilters && browser ? loadFiltersFromStorage() : null;

	const rawStatus = page.url.searchParams.get('status');
	const initStatusF = storedFilters
		? { op: storedFilters.statusOp, values: storedFilters.statusSelected }
		: rawStatus ? parseFilterParam(rawStatus) : { op: 'is_not' as const, values: ['done', 'cancelled'] };
	const initPriorityF = storedFilters
		? { op: storedFilters.priorityOp, values: storedFilters.prioritySelected }
		: parseFilterParam(page.url.searchParams.get('priority'));
	const initTypeF = storedFilters
		? { op: storedFilters.typeOp, values: storedFilters.typeSelected }
		: parseFilterParam(page.url.searchParams.get('type'));
	const initProjectF = storedFilters
		? { op: storedFilters.projectOp, values: storedFilters.projectSelected }
		: parseFilterParam(page.url.searchParams.get('project'));

	let statusOp = $state<'is' | 'is_not'>(initStatusF.op);
	let statusSelected = $state<string[]>(initStatusF.values);
	let priorityOp = $state<'is' | 'is_not'>(initPriorityF.op);
	let prioritySelected = $state<string[]>(initPriorityF.values);
	let typeOp = $state<'is' | 'is_not'>(initTypeF.op);
	let typeSelected = $state<string[]>(initTypeF.values);
	let projectOp = $state<'is' | 'is_not'>(initProjectF.op);
	let projectSelected = $state<string[]>(initProjectF.values);
	let searchQuery = $state(storedFilters ? storedFilters.searchQuery : (page.url.searchParams.get('q') ?? ''));

	let filtersVisible = $state(false);
	let createModalOpen = $state(false);
	let createPrefill = $state<{ projectId?: string; status?: string }>({});
	let selectedTaskId = $state<string | null>(page.url.searchParams.get('task') ?? null);
	let currentPage = $state(1);
	const perPage = 50;
	let initialLoading = $state(true);

	// ---------- derived ----------

	const projects = $derived(projectStore.items);
	const orgNameMap = $derived(Object.fromEntries(orgStore.all.map((o) => [o.id, o.name])));

	const hasActiveFilters = $derived(
		!!(statusSelected.length || prioritySelected.length || typeSelected.length || projectSelected.length || searchQuery)
	);

	const activeFiltersCount = $derived(
		[statusSelected.length, prioritySelected.length, typeSelected.length, projectSelected.length, searchQuery].filter(Boolean).length
	);

	// List view grouping
	type ListGroup = { key: string; label: string; color?: string; tasks: Task[] };

	const listGroups = $derived.by((): ListGroup[] | null => {
		if (groupBy === 'none') return null;
		const items = taskStore.items;
		const map = new Map<string, ListGroup>();
		const order: string[] = [];

		if (groupBy === 'status') {
			for (const s of TASK_STATUSES) {
				map.set(s, { key: s, label: formatStatus(s), tasks: [] });
				order.push(s);
			}
			for (const t of items) {
				map.get(t.status)?.tasks.push(t);
			}
		} else {
			for (const t of items) {
				const pid = t.project_id ?? '__none__';
				if (!map.has(pid)) {
					map.set(pid, {
						key: pid,
						label: t.project?.name ?? 'No Project',
						color: t.project?.color ?? undefined,
						tasks: []
					});
					order.push(pid);
				}
				map.get(pid)!.tasks.push(t);
			}
		}

		const sorted = groupBy === 'status'
			? order
			: order.sort((a, b) => (map.get(a)!.label).localeCompare(map.get(b)!.label));
		return sorted.map((k) => map.get(k)!).filter((g) => g.tasks.length > 0);
	});

	// Kanban columns – mutable state so dnd can update them during drag
	type BoardColumn = { key: string; label: string; color: string; items: (Task & { id: string })[] };
	let boardColumns = $state<BoardColumn[]>([]);

	function buildStatusColumns(tasks: Task[]): BoardColumn[] {
		return TASK_STATUSES.map((s) => ({
			key: s,
			label: formatStatus(s),
			color: statusColors[s] ?? '',
			items: tasks.filter((t) => t.status === s).map((t) => ({ ...t, id: t.id }))
		}));
	}

	function buildProjectColumns(tasks: Task[]): BoardColumn[] {
		const map = new Map<string, BoardColumn>();
		const order: string[] = [];

		for (const t of tasks) {
			const pid = t.project_id ?? '__none__';
			if (!map.has(pid)) {
				const proj = t.project;
				map.set(pid, {
					key: pid,
					label: proj ? proj.name : 'No Project',
					color: proj?.color ?? 'var(--color-muted)',
					items: []
				});
				order.push(pid);
			}
			map.get(pid)!.items.push({ ...t, id: t.id });
		}

		return order
			.sort((a, b) => (map.get(a)!.label).localeCompare(map.get(b)!.label))
			.map((k) => map.get(k)!);
	}

	function rebuildBoard() {
		const tasks = taskStore.items;
		boardColumns = groupBy === 'status' ? buildStatusColumns(tasks) : buildProjectColumns(tasks);
	}

	const totalPages = $derived(Math.max(1, Math.ceil(taskStore.count / perPage)));

	// ---------- helpers ----------

	function formatStatus(s: string): string {
		return s.split('_').map((w) => w.charAt(0).toUpperCase() + w.slice(1)).join(' ');
	}

	function formatPriority(p: string): string {
		return p.charAt(0).toUpperCase() + p.slice(1);
	}

	function toFilterOp(op: 'is' | 'is_not', values: string[]): FilterOp | undefined {
		if (values.length === 0) return undefined;
		return { values, not: op === 'is_not' };
	}

	function getFilters(): TaskFilters {
		const f: TaskFilters = { parent_id: null };
		const skipStatus = viewMode === 'board' && groupBy === 'status';
		const skipProject = viewMode === 'board' && groupBy === 'project';
		if (!skipStatus) f.status = toFilterOp(statusOp, statusSelected);
		f.priority = toFilterOp(priorityOp, prioritySelected);
		f.type = toFilterOp(typeOp, typeSelected);
		if (!skipProject) f.project_id = toFilterOp(projectOp, projectSelected);
		if (searchQuery) f.search = searchQuery;
		return f;
	}

	function syncUrl() {
		const url = new URL(window.location.href);
		const set = (k: string, v: string) => (v ? url.searchParams.set(k, v) : url.searchParams.delete(k));
		set('view', viewMode);
		set('group', groupBy);
		set('status', encodeFilterParam(statusOp, statusSelected));
		set('priority', encodeFilterParam(priorityOp, prioritySelected));
		set('type', encodeFilterParam(typeOp, typeSelected));
		set('project', encodeFilterParam(projectOp, projectSelected));
		set('q', searchQuery);
		if (selectedTaskId) url.searchParams.set('task', selectedTaskId);
		else url.searchParams.delete('task');
		replaceState(localizeHref(url.pathname + url.search), {});
		saveFiltersToStorage();
	}

	async function applyFilters() {
		currentPage = 1;
		await taskStore.loadAll(getFilters(), 1, perPage);
		if (viewMode === 'board') rebuildBoard();
		syncUrl();
	}

	function clearFilters() {
		statusOp = 'is'; statusSelected = [];
		priorityOp = 'is'; prioritySelected = [];
		typeOp = 'is'; typeSelected = [];
		projectOp = 'is'; projectSelected = [];
		searchQuery = '';
		applyFilters();
	}

	async function setView(v: ViewMode) {
		viewMode = v;
		localStorage.setItem('tasks-view', v);
		// Board doesn't support "none" grouping — fall back to "status"
		if (v === 'board' && groupBy === 'none') {
			groupBy = 'status';
			localStorage.setItem('tasks-group', 'status');
		}
		await taskStore.loadAll(getFilters(), currentPage, perPage);
		if (v === 'board') rebuildBoard();
		syncUrl();
	}

	async function setGroupBy(g: GroupBy) {
		groupBy = g;
		localStorage.setItem('tasks-group', g);
		await taskStore.loadAll(getFilters(), currentPage, perPage);
		if (viewMode === 'board') rebuildBoard();
		syncUrl();
	}

	function selectTask(id: string | null) {
		selectedTaskId = id;
		syncUrl();
	}

	async function goToPage(p: number) {
		if (p < 1 || p > totalPages) return;
		currentPage = p;
		await taskStore.loadAll(getFilters(), p, perPage);
		if (viewMode === 'board') rebuildBoard();
	}

	// ---------- Kanban DnD ----------

	function handleConsider(colIndex: number, e: CustomEvent<{ items: (Task & { id: string })[] }>) {
		boardColumns[colIndex].items = e.detail.items;
	}

	async function handleFinalize(colIndex: number, colKey: string, e: CustomEvent<{ items: (Task & { id: string })[] }>) {
		boardColumns[colIndex].items = e.detail.items;

		// Collect tasks that actually moved into this column
		const movedTasks: { id: string; field: string; value: unknown }[] = [];

		if (groupBy === 'status') {
			for (const item of e.detail.items) {
				if (item.status !== colKey) {
					item.status = colKey; // update local copy
					movedTasks.push({ id: item.id, field: 'status', value: colKey });
				}
			}
		} else {
			const newProjectId = colKey === '__none__' ? null : colKey;
			for (const item of e.detail.items) {
				const currentPid = item.project_id ?? '__none__';
				if (currentPid !== colKey) {
					item.project_id = newProjectId!;
					movedTasks.push({ id: item.id, field: 'project_id', value: newProjectId });
				}
			}
		}

		// Persist each move directly via API (bypass store to avoid $effect rebuild)
		for (const move of movedTasks) {
			try {
				await api.tasks.update(move.id, { [move.field]: move.value });
			} catch (err) {
				console.error('[Tasks board] Failed to persist move:', err);
				// Reload from DB to get back to a consistent state
				await taskStore.loadAll(getFilters(), currentPage, perPage);
				rebuildBoard();
				return;
			}
		}

		// Sync store items to match board state (so list view stays consistent)
		if (movedTasks.length > 0) {
			const moveMap = new Map(movedTasks.map((m) => [m.id, { [m.field]: m.value }]));
			taskStore.items = taskStore.items.map((t) => {
				const patch = moveMap.get(t.id);
				return patch ? { ...t, ...patch } : t;
			});
		}
	}

	// ---------- sync board with store ----------

	// Rebuild board columns whenever taskStore.items changes (e.g. panel edits)
	$effect(() => {
		const _ = taskStore.items;   // track dependency
		if (viewMode === 'board' && !initialLoading) rebuildBoard();
	});

	// ---------- keyboard nav ----------

	$effect(() => {
		if (!selectedTaskId) return;
		function handleKeydown(e: KeyboardEvent) {
			const tag = (e.target as HTMLElement)?.tagName;
			if (tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT') return;
			if (e.key !== 'ArrowDown' && e.key !== 'ArrowUp') return;
			e.preventDefault();
			const items = taskStore.items;
			const idx = items.findIndex((t) => t.id === selectedTaskId);
			if (idx === -1) return;
			const next = e.key === 'ArrowDown' ? Math.min(idx + 1, items.length - 1) : Math.max(idx - 1, 0);
			if (next !== idx) {
				selectTask(items[next].id);
				requestAnimationFrame(() => {
					document.querySelector(`[data-task-id="${items[next].id}"]`)?.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
				});
			}
		}
		document.addEventListener('keydown', handleKeydown);
		return () => document.removeEventListener('keydown', handleKeydown);
	});

	// ---------- lifecycle ----------

	let searchTimeout: ReturnType<typeof setTimeout>;

	function onSearchInput(e: Event) {
		const val = (e.target as HTMLInputElement).value;
		searchQuery = val;
		clearTimeout(searchTimeout);
		searchTimeout = setTimeout(() => applyFilters(), 300);
	}

	onMount(async () => {
		orgStore.loadIfNeeded();
		projectStore.loadAll();
		await taskStore.loadAll(getFilters(), 1, perPage);
		initialLoading = false;
		if (viewMode === 'board') rebuildBoard();

		const taskParam = page.url.searchParams.get('task');
		if (taskParam) selectTask(taskParam);
	});
</script>

<div class="flex h-full">
<div class="flex min-w-0 flex-1 flex-col {viewMode === 'board' ? 'overflow-hidden' : 'overflow-y-auto'}">
	<!-- ===== HEADER ===== -->
	<div class="flex shrink-0 items-center justify-between border-b border-surface-border px-4 py-3">
		<div class="flex items-center gap-2">
			<!-- View toggle -->
			<div class="flex items-center border border-surface-border">
				<button
					class="flex h-[34px] items-center gap-1.5 px-2.5 text-xs transition-colors {viewMode === 'list' ? 'bg-accent text-white' : 'bg-surface text-sidebar-text hover:bg-surface-hover'}"
					onclick={() => setView('list')}
				>
					<LayoutList size={14} />
					List
				</button>
				<button
					class="flex h-[34px] items-center gap-1.5 px-2.5 text-xs transition-colors {viewMode === 'board' ? 'bg-accent text-white' : 'bg-surface text-sidebar-text hover:bg-surface-hover'}"
					onclick={() => setView('board')}
				>
					<Columns3 size={14} />
					Board
				</button>
			</div>

			<!-- Group-by -->
			<div class="flex items-center border border-surface-border">
				{#each GROUP_OPTIONS as g (g)}
					{#if !(viewMode === 'board' && g === 'none')}
						<button
							class="flex h-[34px] items-center px-2.5 text-xs transition-colors {groupBy === g ? 'bg-accent text-white' : 'bg-surface text-sidebar-text hover:bg-surface-hover'}"
							onclick={() => setGroupBy(g)}
						>
							{formatStatus(g)}
						</button>
					{/if}
				{/each}
			</div>

			<!-- Search -->
			<div class="relative flex items-center">
				<Search size={14} class="absolute left-2.5 text-sidebar-icon pointer-events-none" />
				<input
					type="text"
					placeholder="Search tasks..."
					value={searchQuery}
					oninput={onSearchInput}
					class="h-[34px] border border-surface-border bg-surface pl-8 pr-7 text-xs text-sidebar-text transition-colors placeholder:text-muted hover:border-sidebar-icon/30 focus:border-accent focus:outline-none w-48"
				/>
				{#if searchQuery}
					<button
						class="absolute right-2 text-sidebar-icon hover:text-sidebar-text"
						onclick={() => { searchQuery = ''; applyFilters(); }}
					>
						<X size={12} />
					</button>
				{/if}
			</div>

			<!-- Filter toggle -->
			<div class="relative shrink-0">
				<button
					class="flex h-[34px] w-[34px] items-center justify-center border border-surface-border bg-surface transition-colors hover:border-sidebar-icon/30 hover:bg-surface-hover {filtersVisible ? 'text-accent' : 'text-sidebar-icon'}"
					onclick={() => (filtersVisible = !filtersVisible)}
					title={filtersVisible ? 'Hide filters' : 'Show filters'}
				>
					<ListFilter size={16} />
				</button>
				{#if activeFiltersCount > 0}
					<span
						class="absolute -top-1.5 -right-1.5 flex h-4 min-w-4 items-center justify-center bg-accent px-1 text-[10px] leading-none font-medium text-white"
					>
						{activeFiltersCount > 9 ? '9+' : activeFiltersCount}
					</span>
				{/if}
			</div>
		</div>

		<button
			class="bg-accent px-4 py-2 text-xs font-medium text-white shadow-sm transition-colors hover:bg-accent/90"
			onclick={() => { createPrefill = {}; createModalOpen = true; }}
		>
			New Task
		</button>
	</div>

	<!-- ===== FILTERS ===== -->
	{#if filtersVisible}
		<div class="shrink-0 border-b border-surface-border bg-surface/40 px-4 py-4">
			<div class="mb-3 flex items-center justify-between">
				<span class="text-[11px] font-medium uppercase tracking-wider text-sidebar-icon">Filters</span>
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
				{#if !(viewMode === 'board' && groupBy === 'status')}
					<FilterDropdown
						label="Status"
						options={TASK_STATUSES.map((s) => ({ value: s, label: formatStatus(s) }))}
						operator={statusOp}
						selected={statusSelected}
						onchange={(op, sel) => { statusOp = op; statusSelected = sel; applyFilters(); }}
					/>
				{/if}
				<FilterDropdown
					label="Priority"
					options={TASK_PRIORITIES.map((p) => ({ value: p, label: formatPriority(p) }))}
					operator={priorityOp}
					selected={prioritySelected}
					onchange={(op, sel) => { priorityOp = op; prioritySelected = sel; applyFilters(); }}
				/>
				<FilterDropdown
					label="Type"
					options={TASK_TYPES.map((t) => ({ value: t, label: formatStatus(t) }))}
					operator={typeOp}
					selected={typeSelected}
					onchange={(op, sel) => { typeOp = op; typeSelected = sel; applyFilters(); }}
				/>
				{#if !(viewMode === 'board' && groupBy === 'project')}
				<FilterDropdown
					label="Project"
					searchable
					options={projects.map((p) => ({ value: p.id, label: p.name, color: p.color ?? 'var(--color-accent)', subtitle: orgNameMap[p.organization_id] }))}
					operator={projectOp}
					selected={projectSelected}
					onchange={(op, sel) => { projectOp = op; projectSelected = sel; applyFilters(); }}
				/>
				{/if}
			</div>
		</div>
	{/if}

	<!-- ===== CONTENT ===== -->
	{#if initialLoading}
		<p class="px-4 py-12 text-center text-sm text-muted">Loading...</p>
	{:else if taskStore.error}
		<p class="px-4 py-12 text-center text-sm text-red-500">{taskStore.error}</p>
	{:else if viewMode === 'list'}
		<!-- LIST VIEW -->
		{#if taskStore.items.length === 0}
			<p class="px-4 py-12 text-center text-sm text-muted">
				{hasActiveFilters ? 'No tasks match your filters.' : 'No tasks yet.'}
			</p>
		{:else if listGroups}
			<!-- Grouped list -->
			<div>
				{#each listGroups as group (group.key)}
					<div class="flex items-center gap-2 border-b border-surface-border bg-surface-hover/50 px-4 py-2">
						{#if group.color}
							<span class="h-2 w-2 shrink-0 rounded-full" style="background-color: {group.color}"></span>
						{/if}
						<span class="text-[11px] font-semibold uppercase tracking-wider text-muted">{group.label}</span>
						<span class="text-[10px] text-muted/60">({group.tasks.length})</span>
					</div>
					{#each group.tasks as task (task.id)}
						<TaskRow
							{task}
							selected={task.id === selectedTaskId}
							onclick={() => selectTask(task.id)}
						/>
					{/each}
				{/each}
			</div>
		{:else}
			<!-- Flat list -->
			<div>
				{#each taskStore.items as task (task.id)}
					<TaskRow
						{task}
						selected={task.id === selectedTaskId}
						onclick={() => selectTask(task.id)}
					/>
				{/each}
			</div>

			<!-- Pagination -->
			<div class="flex items-center justify-between border-t border-surface-border px-4 py-3">
				<span class="text-xs text-muted">{taskStore.count} task{taskStore.count === 1 ? '' : 's'}</span>
				{#if totalPages > 1}
					<div class="flex items-center gap-2">
						<button
							class="flex items-center justify-center border border-surface-border bg-surface p-1.5 text-sidebar-icon transition-colors hover:bg-surface-hover disabled:opacity-40 disabled:cursor-not-allowed"
							disabled={currentPage <= 1}
							onclick={() => goToPage(currentPage - 1)}
						>
							<ChevronLeft size={14} />
						</button>
						<span class="text-xs text-sidebar-text">
							Page {currentPage} of {totalPages}
						</span>
						<button
							class="flex items-center justify-center border border-surface-border bg-surface p-1.5 text-sidebar-icon transition-colors hover:bg-surface-hover disabled:opacity-40 disabled:cursor-not-allowed"
							disabled={currentPage >= totalPages}
							onclick={() => goToPage(currentPage + 1)}
						>
							<ChevronRight size={14} />
						</button>
					</div>
				{/if}
			</div>
		{/if}
	{:else}
		<!-- BOARD VIEW -->
		<div class="flex min-h-0 flex-1 gap-0 overflow-x-auto">
			{#each boardColumns as col, colIndex (col.key)}
				<div class="flex w-72 min-w-[18rem] shrink-0 flex-col border-r border-surface-border max-h-full last:border-r-0">
					<!-- Column header -->
					<div class="flex items-center gap-2 px-3 py-2.5 border-b border-surface-border">
						{#if groupBy === 'project' && col.key !== '__none__'}
							<span class="h-2 w-2 shrink-0 rounded-full" style="background-color: {col.color}"></span>
						{/if}
						<span class="text-[11px] font-semibold uppercase tracking-wider text-muted truncate">{col.label}</span>
						<span class="ml-auto shrink-0 text-[10px] text-muted">{col.items.length}</span>
					</div>

					<!-- Create task shortcut -->
					<button
						class="flex w-full items-center justify-center gap-1.5 border-b border-dashed border-surface-border px-3 py-2 text-[11px] text-muted transition-colors hover:text-accent shrink-0"
						onclick={() => {
							createPrefill = groupBy === 'status'
								? { status: col.key }
								: { projectId: col.key !== '__none__' ? col.key : undefined };
							createModalOpen = true;
						}}
					>
						<Plus size={12} />
						Create task
					</button>

					<!-- Cards container -->
					<div
						class="flex-1 overflow-y-auto p-2 min-h-[60px] scrollbar-none"
						style="-ms-overflow-style: none; scrollbar-width: none;"
						use:dndzone={{ items: col.items, flipDurationMs: 200, dropTargetStyle: { outline: '2px solid var(--color-accent)', outlineOffset: '-2px' } }}
						onconsider={(e) => handleConsider(colIndex, e)}
						onfinalize={(e) => handleFinalize(colIndex, col.key, e)}
					>
						{#each col.items as task (task.id)}
							{@const TypeIcon = typeIcons[task.type] ?? defaultTypeIcon}
							<button
								class="mb-2 w-full cursor-pointer border border-surface-border px-3.5 py-3 text-left transition-colors hover:bg-surface-hover last:mb-0 {selectedTaskId === task.id ? 'bg-accent/8' : ''}"
								onclick={() => selectTask(task.id)}
							>
								<!-- Card top row: type icon + short_id -->
								<div class="mb-2 flex items-center gap-2">
									<span class="text-muted"><TypeIcon size={12} /></span>
									<span class="text-[10px] font-medium text-accent">{task.short_id || '—'}</span>

									<!-- Assignee avatars -->
									{#if task.assignments?.length}
										<div class="ml-auto flex -space-x-1.5">
											{#each task.assignments.slice(0, 3) as a (a.user_id)}
												{#if a.user.avatar_url}
													<img src={a.user.avatar_url} alt={a.user.full_name} class="h-4 w-4 rounded-full object-cover" />
												{:else}
													<span class="flex h-4 w-4 items-center justify-center rounded-full bg-accent/15 text-[8px] font-medium text-accent">
														{a.user.full_name.charAt(0)}
													</span>
												{/if}
											{/each}
											{#if task.assignments.length > 3}
												<span class="flex h-4 w-4 items-center justify-center rounded-full bg-surface-hover text-[7px] text-muted">
													+{task.assignments.length - 3}
												</span>
											{/if}
										</div>
									{/if}
								</div>

								<!-- Title -->
								<p class="mb-2.5 line-clamp-2 text-xs leading-snug text-sidebar-text">{task.title}</p>

								<!-- Bottom: priority + project/status -->
								<div class="flex items-center gap-2">
									<span class="inline-flex rounded-sm px-1.5 py-0.5 text-[10px] font-medium {priorityColors[task.priority] ?? priorityColors.none}">
										{formatPriority(task.priority)}
									</span>

									{#if groupBy === 'status' && task.project}
										<span class="flex items-center gap-1 text-[10px] text-muted truncate">
											<span class="h-1.5 w-1.5 shrink-0 rounded-full" style="background-color: {task.project.color ?? 'var(--color-accent)'}"></span>
											{task.project.identifier}
										</span>
									{:else if groupBy === 'project'}
										<span class="inline-flex rounded-sm px-1.5 py-0.5 text-[10px] font-medium {statusColors[task.status] ?? statusColors.backlog}">
											{formatStatus(task.status)}
										</span>
									{/if}
								</div>
							</button>
						{/each}
					</div>
				</div>
			{/each}
		</div>
	{/if}
</div>

<!-- ===== TASK DETAIL PANEL ===== -->
{#if selectedTaskId}
	<TaskDetailPanel
		taskId={selectedTaskId}
		onClose={() => selectTask(null)}
	/>
{/if}
</div>

<!-- ===== CREATE MODAL ===== -->
{#if createModalOpen}
	<CreateTaskModal
		projectId={createPrefill.projectId}
		prefillStatus={createPrefill.status}
		onClose={() => (createModalOpen = false)}
		onCreated={async () => { createModalOpen = false; await taskStore.loadAll(getFilters(), currentPage, perPage); if (viewMode === 'board') rebuildBoard(); }}
	/>
{/if}

<style>
	.scrollbar-none::-webkit-scrollbar {
		display: none;
	}
</style>
