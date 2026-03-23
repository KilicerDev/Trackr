<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/state';
	import { replaceState } from '$app/navigation';
	import { dndzone } from 'svelte-dnd-action';
	import { taskStore, type Task } from '$lib/stores/tasks.svelte';
	import { projectStore } from '$lib/stores/projects.svelte';
	import { auth } from '$lib/stores/auth.svelte';
	import { clickOutside } from '$lib/actions/clickOutside';
	import { localizeHref } from '$lib/paraglide/runtime';
	import { typeIcons, defaultTypeIcon } from '$lib/config/task-icons';
	import { api } from '$lib/api';
	import type { TaskFilters } from '$lib/api/tasks';
	import TaskRow from '$lib/components/TaskRow.svelte';
	import TaskDetailPanel from '$lib/components/TaskDetailPanel.svelte';
	import CreateTaskModal from '$lib/components/CreateTaskModal.svelte';
	import {
		ListFilter,
		LayoutList,
		Columns3,
		ChevronLeft,
		ChevronRight,
		Search,
		X
	} from '@lucide/svelte';

	const TASK_STATUSES = ['backlog', 'todo', 'in_progress', 'in_review', 'done', 'cancelled'] as const;
	const TASK_PRIORITIES = ['none', 'low', 'medium', 'high', 'urgent'] as const;
	const TASK_TYPES = ['task', 'bug', 'feature', 'improvement', 'epic'] as const;
	const GROUP_OPTIONS = ['status', 'project'] as const;

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

	const initView = (page.url.searchParams.get('view') as ViewMode) ?? localStorage.getItem('tasks-view') ?? 'list';
	const initGroup = (page.url.searchParams.get('group') as GroupBy) ?? localStorage.getItem('tasks-group') ?? 'status';

	let viewMode = $state<ViewMode>(initView === 'board' ? 'board' : 'list');
	let groupBy = $state<GroupBy>(GROUP_OPTIONS.includes(initGroup as GroupBy) ? (initGroup as GroupBy) : 'status');

	let statusFilter = $state(page.url.searchParams.get('status') ?? '');
	let priorityFilter = $state(page.url.searchParams.get('priority') ?? '');
	let typeFilter = $state(page.url.searchParams.get('type') ?? '');
	let projectFilter = $state(page.url.searchParams.get('project') ?? '');
	let searchQuery = $state(page.url.searchParams.get('q') ?? '');

	let filtersVisible = $state(false);
	let filterDropdownOpen = $state<string | null>(null);
	let createModalOpen = $state(false);
	let selectedTaskId = $state<string | null>(page.url.searchParams.get('task') ?? null);
	let currentPage = $state(1);
	const perPage = 50;

	// ---------- derived ----------

	const projects = $derived(projectStore.items);

	const hasActiveFilters = $derived(
		!!(statusFilter || priorityFilter || typeFilter || projectFilter || searchQuery)
	);

	const activeFiltersCount = $derived(
		[statusFilter, priorityFilter, typeFilter, projectFilter, searchQuery].filter(Boolean).length
	);

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

		for (const p of projects) {
			if (!map.has(p.id)) {
				map.set(p.id, { key: p.id, label: p.name, color: p.color ?? 'var(--color-muted)', items: [] });
				order.push(p.id);
			}
		}

		return order.map((k) => map.get(k)!);
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

	function getFilters(): TaskFilters {
		const f: TaskFilters = { parent_id: null };
		// In board mode, skip the filter that matches the grouping dimension —
		// columns already represent that axis, so filtering would hide moved items.
		const skipStatus = viewMode === 'board' && groupBy === 'status';
		const skipProject = viewMode === 'board' && groupBy === 'project';
		if (statusFilter && !skipStatus) f.status = statusFilter;
		if (priorityFilter) f.priority = priorityFilter;
		if (typeFilter) f.type = typeFilter;
		if (projectFilter && !skipProject) f.project_id = projectFilter;
		if (searchQuery) f.search = searchQuery;
		return f;
	}

	function syncUrl() {
		const url = new URL(window.location.href);
		const set = (k: string, v: string) => (v ? url.searchParams.set(k, v) : url.searchParams.delete(k));
		set('view', viewMode);
		set('group', groupBy);
		set('status', statusFilter);
		set('priority', priorityFilter);
		set('type', typeFilter);
		set('project', projectFilter);
		set('q', searchQuery);
		if (selectedTaskId) url.searchParams.set('task', selectedTaskId);
		else url.searchParams.delete('task');
		replaceState(localizeHref(url.pathname + url.search), {});
	}

	async function applyFilters() {
		currentPage = 1;
		await taskStore.loadAll(getFilters(), 1, perPage);
		if (viewMode === 'board') rebuildBoard();
		syncUrl();
	}

	function clearFilters() {
		statusFilter = '';
		priorityFilter = '';
		typeFilter = '';
		projectFilter = '';
		searchQuery = '';
		filterDropdownOpen = null;
		applyFilters();
	}

	async function setView(v: ViewMode) {
		viewMode = v;
		localStorage.setItem('tasks-view', v);
		// Filters change based on view mode, so reload
		await taskStore.loadAll(getFilters(), currentPage, perPage);
		if (v === 'board') rebuildBoard();
		syncUrl();
	}

	async function setGroupBy(g: GroupBy) {
		groupBy = g;
		localStorage.setItem('tasks-group', g);
		// Filters change based on groupBy, so reload
		await taskStore.loadAll(getFilters(), currentPage, perPage);
		rebuildBoard();
		syncUrl();
	}

	function selectTask(id: string | null) {
		selectedTaskId = id;
		if (id) {
			taskStore.loadById(id);
		}
		syncUrl();
	}

	async function goToPage(p: number) {
		if (p < 1 || p > totalPages) return;
		currentPage = p;
		await taskStore.loadAll(getFilters(), p, perPage);
		if (viewMode === 'board') rebuildBoard();
	}

	function openFilterDropdown(key: string) {
		filterDropdownOpen = filterDropdownOpen === key ? null : key;
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

	// ---------- shared css ----------

	const filterLabelClass = 'text-[11px] font-medium uppercase tracking-wider text-sidebar-icon';
	const dropdownBtnClass =
		'flex min-w-[6.5rem] cursor-pointer items-center justify-between gap-2 border border-surface-border bg-surface px-3 py-2 text-xs text-sidebar-text shadow-sm transition-colors hover:border-sidebar-icon/30 hover:bg-surface-hover';
	const dropdownPanelClass =
		'absolute left-0 z-20 mt-1.5 max-h-56 min-w-[10rem] overflow-y-auto border border-surface-border bg-surface py-1 shadow-xl';

	// ---------- lifecycle ----------

	let searchTimeout: ReturnType<typeof setTimeout>;

	function onSearchInput(e: Event) {
		const val = (e.target as HTMLInputElement).value;
		searchQuery = val;
		clearTimeout(searchTimeout);
		searchTimeout = setTimeout(() => applyFilters(), 300);
	}

	onMount(async () => {
		projectStore.loadAll();
		await taskStore.loadAll(getFilters(), 1, perPage);
		if (viewMode === 'board') rebuildBoard();

		const taskParam = page.url.searchParams.get('task');
		if (taskParam) selectTask(taskParam);
	});
</script>

<div class="flex h-full">
<div class="flex min-w-0 flex-1 flex-col {viewMode === 'board' ? 'overflow-hidden' : 'overflow-y-auto'}"
	use:clickOutside={{
		onClickOutside: () => { filterDropdownOpen = null; },
		enabled: filterDropdownOpen !== null
	}}
>
	<!-- ===== HEADER ===== -->
	<div class="flex shrink-0 items-center justify-between border-b border-surface-border px-4 py-3">
		<div class="flex items-center gap-2">
			<!-- View toggle -->
			<div class="flex items-center border border-surface-border">
				<button
					class="flex items-center gap-1.5 px-2.5 py-2 text-xs transition-colors {viewMode === 'list' ? 'bg-accent text-white' : 'bg-surface text-sidebar-text hover:bg-surface-hover'}"
					onclick={() => setView('list')}
				>
					<LayoutList size={14} />
					List
				</button>
				<button
					class="flex items-center gap-1.5 px-2.5 py-2 text-xs transition-colors {viewMode === 'board' ? 'bg-accent text-white' : 'bg-surface text-sidebar-text hover:bg-surface-hover'}"
					onclick={() => setView('board')}
				>
					<Columns3 size={14} />
					Board
				</button>
			</div>

			<!-- Group-by (only visible in board mode) -->
			{#if viewMode === 'board'}
				<div class="flex items-center border border-surface-border">
					{#each GROUP_OPTIONS as g (g)}
						<button
							class="px-2.5 py-2 text-xs transition-colors {groupBy === g ? 'bg-accent text-white' : 'bg-surface text-sidebar-text hover:bg-surface-hover'}"
							onclick={() => setGroupBy(g)}
						>
							{formatStatus(g)}
						</button>
					{/each}
				</div>
			{/if}

			<!-- Search -->
			<div class="relative flex items-center">
				<Search size={14} class="absolute left-2.5 text-sidebar-icon pointer-events-none" />
				<input
					type="text"
					placeholder="Search tasks..."
					value={searchQuery}
					oninput={onSearchInput}
					class="border border-surface-border bg-surface py-2 pl-8 pr-7 text-xs text-sidebar-text shadow-sm transition-colors placeholder:text-muted hover:border-sidebar-icon/30 focus:border-accent focus:outline-none w-48"
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
					class="flex items-center justify-center border border-surface-border bg-surface p-2 shadow-sm transition-colors hover:border-sidebar-icon/30 hover:bg-surface-hover {filtersVisible ? 'text-accent' : 'text-sidebar-icon'}"
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
			onclick={() => (createModalOpen = true)}
		>
			New Task
		</button>
	</div>

	<!-- ===== FILTERS ===== -->
	{#if filtersVisible}
		<div class="shrink-0 border-b border-surface-border bg-surface/40 px-4 py-4">
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
				<!-- Status -->
				<div class="flex flex-col gap-1.5">
					<span class={filterLabelClass}>Status</span>
					<div class="relative">
						<button class={dropdownBtnClass} onclick={() => openFilterDropdown('status')}>
							<span class="truncate">{statusFilter ? formatStatus(statusFilter) : 'All'}</span>
							<svg class="h-4 w-4 shrink-0 text-sidebar-icon transition-transform {filterDropdownOpen === 'status' ? 'rotate-180' : ''}" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" /></svg>
						</button>
						{#if filterDropdownOpen === 'status'}
							<div class={dropdownPanelClass}>
								<button class="flex w-full items-center px-4 py-2.5 text-left text-xs transition-colors hover:bg-surface-hover {!statusFilter ? 'font-medium text-accent' : 'text-sidebar-text'}"
									onmousedown={(e) => { e.preventDefault(); statusFilter = ''; filterDropdownOpen = null; applyFilters(); }}>All</button>
								{#each TASK_STATUSES as s (s)}
									<button class="flex w-full items-center px-4 py-2.5 text-left text-xs whitespace-nowrap transition-colors hover:bg-surface-hover {statusFilter === s ? 'font-medium text-accent' : 'text-sidebar-text'}"
										onmousedown={(e) => { e.preventDefault(); statusFilter = s; filterDropdownOpen = null; applyFilters(); }}>{formatStatus(s)}</button>
								{/each}
							</div>
						{/if}
					</div>
				</div>

				<!-- Priority -->
				<div class="flex flex-col gap-1.5">
					<span class={filterLabelClass}>Priority</span>
					<div class="relative">
						<button class={dropdownBtnClass} onclick={() => openFilterDropdown('priority')}>
							<span class="truncate">{priorityFilter ? formatPriority(priorityFilter) : 'All'}</span>
							<svg class="h-4 w-4 shrink-0 text-sidebar-icon transition-transform {filterDropdownOpen === 'priority' ? 'rotate-180' : ''}" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" /></svg>
						</button>
						{#if filterDropdownOpen === 'priority'}
							<div class={dropdownPanelClass}>
								<button class="flex w-full items-center px-4 py-2.5 text-left text-xs transition-colors hover:bg-surface-hover {!priorityFilter ? 'font-medium text-accent' : 'text-sidebar-text'}"
									onmousedown={(e) => { e.preventDefault(); priorityFilter = ''; filterDropdownOpen = null; applyFilters(); }}>All</button>
								{#each TASK_PRIORITIES as p (p)}
									<button class="flex w-full items-center px-4 py-2.5 text-left text-xs transition-colors hover:bg-surface-hover {priorityFilter === p ? 'font-medium text-accent' : 'text-sidebar-text'}"
										onmousedown={(e) => { e.preventDefault(); priorityFilter = p; filterDropdownOpen = null; applyFilters(); }}>{formatPriority(p)}</button>
								{/each}
							</div>
						{/if}
					</div>
				</div>

				<!-- Type -->
				<div class="flex flex-col gap-1.5">
					<span class={filterLabelClass}>Type</span>
					<div class="relative">
						<button class={dropdownBtnClass} onclick={() => openFilterDropdown('type')}>
							<span class="truncate">{typeFilter ? formatStatus(typeFilter) : 'All'}</span>
							<svg class="h-4 w-4 shrink-0 text-sidebar-icon transition-transform {filterDropdownOpen === 'type' ? 'rotate-180' : ''}" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" /></svg>
						</button>
						{#if filterDropdownOpen === 'type'}
							<div class={dropdownPanelClass}>
								<button class="flex w-full items-center px-4 py-2.5 text-left text-xs transition-colors hover:bg-surface-hover {!typeFilter ? 'font-medium text-accent' : 'text-sidebar-text'}"
									onmousedown={(e) => { e.preventDefault(); typeFilter = ''; filterDropdownOpen = null; applyFilters(); }}>All</button>
								{#each TASK_TYPES as t (t)}
									<button class="flex w-full items-center px-4 py-2.5 text-left text-xs transition-colors hover:bg-surface-hover {typeFilter === t ? 'font-medium text-accent' : 'text-sidebar-text'}"
										onmousedown={(e) => { e.preventDefault(); typeFilter = t; filterDropdownOpen = null; applyFilters(); }}>{formatStatus(t)}</button>
								{/each}
							</div>
						{/if}
					</div>
				</div>

				<!-- Project -->
				<div class="flex flex-col gap-1.5">
					<span class={filterLabelClass}>Project</span>
					<div class="relative">
						<button class="{dropdownBtnClass} min-w-[8rem]" onclick={() => openFilterDropdown('project')}>
							<span class="truncate">{projectFilter ? (projects.find((p) => p.id === projectFilter)?.name ?? '—') : 'All'}</span>
							<svg class="h-4 w-4 shrink-0 text-sidebar-icon transition-transform {filterDropdownOpen === 'project' ? 'rotate-180' : ''}" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" /></svg>
						</button>
						{#if filterDropdownOpen === 'project'}
							<div class="{dropdownPanelClass} min-w-[14rem]">
								<button class="flex w-full items-center px-4 py-2.5 text-left text-xs transition-colors hover:bg-surface-hover {!projectFilter ? 'font-medium text-accent' : 'text-sidebar-text'}"
									onmousedown={(e) => { e.preventDefault(); projectFilter = ''; filterDropdownOpen = null; applyFilters(); }}>All</button>
								{#each projects as p (p.id)}
									<button class="flex w-full items-center gap-2 px-4 py-2.5 text-left text-xs transition-colors hover:bg-surface-hover {projectFilter === p.id ? 'font-medium text-accent' : 'text-sidebar-text'}"
										onmousedown={(e) => { e.preventDefault(); projectFilter = p.id; filterDropdownOpen = null; applyFilters(); }}>
										<span class="h-2 w-2 shrink-0 rounded-full" style="background-color: {p.color ?? 'var(--color-accent)'}"></span>
										{p.name}
									</button>
								{/each}
							</div>
						{/if}
					</div>
				</div>
			</div>
		</div>
	{/if}

	<!-- ===== CONTENT ===== -->
	{#if taskStore.loading}
		<p class="px-4 py-12 text-center text-sm text-muted">Loading...</p>
	{:else if taskStore.error}
		<p class="px-4 py-12 text-center text-sm text-red-500">{taskStore.error}</p>
	{:else if viewMode === 'list'}
		<!-- LIST VIEW -->
		{#if taskStore.items.length === 0}
			<p class="px-4 py-12 text-center text-sm text-muted">
				{hasActiveFilters ? 'No tasks match your filters.' : 'No tasks yet.'}
			</p>
		{:else}
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
				<div class="flex w-60 min-w-[15rem] shrink-0 flex-col border-r border-surface-border max-h-full last:border-r-0">
					<!-- Column header -->
					<div class="flex items-center gap-2 px-3 py-2.5 border-b border-surface-border">
						{#if groupBy === 'project' && col.key !== '__none__'}
							<span class="h-2 w-2 shrink-0 rounded-full" style="background-color: {col.color}"></span>
						{/if}
						<span class="text-[11px] font-semibold uppercase tracking-wider text-muted truncate">{col.label}</span>
						<span class="ml-auto shrink-0 text-[10px] text-muted">{col.items.length}</span>
					</div>

					<!-- Cards container -->
					<div
						class="flex-1 overflow-y-auto px-2 py-2 min-h-[60px]"
						use:dndzone={{ items: col.items, flipDurationMs: 200, dropTargetStyle: { outline: '2px solid var(--color-accent)', outlineOffset: '-2px' } }}
						onconsider={(e) => handleConsider(colIndex, e)}
						onfinalize={(e) => handleFinalize(colIndex, col.key, e)}
					>
						{#each col.items as task (task.id)}
							{@const TypeIcon = typeIcons[task.type] ?? defaultTypeIcon}
							<button
								class="mb-1.5 w-full cursor-pointer rounded-sm px-3 py-2.5 text-left transition-colors hover:bg-surface-hover {selectedTaskId === task.id ? 'bg-accent/8' : ''}"
								onclick={() => selectTask(task.id)}
							>
								<!-- Card top row: type icon + short_id -->
								<div class="mb-1 flex items-center gap-2">
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
								<p class="mb-1.5 line-clamp-2 text-xs leading-snug text-sidebar-text">{task.title}</p>

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
		onClose={() => (createModalOpen = false)}
		onCreated={() => { createModalOpen = false; taskStore.loadAll(getFilters(), currentPage, perPage); }}
	/>
{/if}
