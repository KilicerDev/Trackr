<svelte:head><title>Tasks – Trackr</title></svelte:head>

<script lang="ts">
	import { onMount } from 'svelte';
	import { slide, fly } from 'svelte/transition';
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
	import type { SavedView } from '$lib/api/views';
	import TaskRow from '$lib/components/TaskRow.svelte';
	import TaskDetailPanel from '$lib/components/TaskDetailPanel.svelte';
	import CreateTaskModal from '$lib/components/CreateTaskModal.svelte';
	import FilterDropdown from '$lib/components/FilterDropdown.svelte';
	import TaskBoardCard from '$lib/components/TaskBoardCard.svelte';
	import Modal from '$lib/components/Modal.svelte';
	import {
		ListFilter,
		LayoutList,
		Columns3,
		ChevronLeft,
		ChevronRight,
		ChevronDown,
		FolderOpen,
		Folder,
		Search,
		X,
		Plus,
		Bookmark,
		Pencil,
		Trash2,
		Check,
		EllipsisVertical
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
		const empty = !statusSelected.length && !prioritySelected.length
			&& !typeSelected.length && !projectSelected.length && !tagSelected.length && !searchQuery;
		if (empty) {
			localStorage.removeItem('tasks-filters');
		} else {
			localStorage.setItem('tasks-filters', JSON.stringify({
				statusOp, statusSelected, priorityOp, prioritySelected,
				typeOp, typeSelected, projectOp, projectSelected,
				tagOp, tagSelected, searchQuery
			}));
		}
	}

	function loadFiltersFromStorage() {
		if (!browser) return null;
		try {
			const raw = localStorage.getItem('tasks-filters');
			if (!raw) return null;
			const parsed = JSON.parse(raw);
			const hasValues = parsed.statusSelected?.length || parsed.prioritySelected?.length
				|| parsed.typeSelected?.length || parsed.projectSelected?.length
				|| parsed.tagSelected?.length || parsed.searchQuery;
			return hasValues ? parsed : null;
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

	// Tag filter (client-side only since tags are in a junction table)
	let tagOp = $state<'is' | 'is_not'>(storedFilters?.tagOp ?? 'is');
	let tagSelected = $state<string[]>(storedFilters?.tagSelected ?? []);

	let filtersVisible = $state(false);
	let createModalOpen = $state(false);
	let createPrefill = $state<{ projectId?: string; status?: string }>({});

	// ---------- saved views ----------
	let savedViews = $state<SavedView[]>([]);
	let activeViewId = $state<string | null>(null);
	let viewsDropdownOpen = $state(false);
	let saveModalOpen = $state(false);
	let saveViewName = $state('');
	let savingView = $state(false);
	let editingViewId = $state<string | null>(null);
	let editingViewName = $state('');
	let viewSubMenuId = $state<string | null>(null);
	let selectedTaskId = $state<string | null>(page.url.searchParams.get('task') ?? null);
	let currentPage = $state(1);
	const perPage = 50;
	let initialLoading = $state(true);
	let collapsedGroups = $state<Set<string>>(new Set());

	function toggleGroupCollapse(key: string) {
		const next = new Set(collapsedGroups);
		if (next.has(key)) next.delete(key);
		else next.add(key);
		collapsedGroups = next;
	}

	// ---------- derived ----------

	const projects = $derived(projectStore.items);
	const orgNameMap = $derived(Object.fromEntries(orgStore.all.map((o) => [o.id, o.name])));

	const hasActiveFilters = $derived(
		!!(statusSelected.length || prioritySelected.length || typeSelected.length || projectSelected.length || tagSelected.length || searchQuery)
	);

	const activeFiltersCount = $derived(
		[statusSelected.length, prioritySelected.length, typeSelected.length, projectSelected.length, tagSelected.length, searchQuery].filter(Boolean).length
	);

	// Tag options derived from loaded tasks
	const tagOptions = $derived.by(() => {
		const seen = new Map<string, { value: string; label: string; color: string }>();
		for (const t of taskStore.items) {
			const tags = (t as Record<string, unknown>).tags as { id: string; tag: { id: string; name: string; color: string } }[] | undefined;
			if (!tags) continue;
			for (const tt of tags) {
				if (tt.tag && !seen.has(tt.tag.id)) {
					seen.set(tt.tag.id, { value: tt.tag.id, label: tt.tag.name, color: tt.tag.color });
				}
			}
		}
		return Array.from(seen.values()).sort((a, b) => a.label.localeCompare(b.label));
	});

	// Client-side tag filter helper
	function passesTagFilter(task: Task): boolean {
		if (tagSelected.length === 0) return true;
		const tags = ((task as Record<string, unknown>).tags as { id: string; tag: { id: string; name: string; color: string } }[] | undefined) ?? [];
		const taskTagIds = tags.map((tt) => tt.tag?.id).filter(Boolean);
		if (tagOp === 'is') return tagSelected.some((id) => taskTagIds.includes(id));
		return !tagSelected.some((id) => taskTagIds.includes(id));
	}

	// List view grouping
	type ListGroup = { key: string; label: string; color?: string; tasks: Task[] };

	const listGroups = $derived.by((): ListGroup[] | null => {
		if (groupBy === 'none') return null;
		const items = tagSelected.length > 0 ? taskStore.items.filter(passesTagFilter) : taskStore.items;
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
		const tasks = tagSelected.length > 0 ? taskStore.items.filter(passesTagFilter) : taskStore.items;
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

	async function applyFilters(keepView = false) {
		if (!keepView) activeViewId = null;
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
		tagOp = 'is'; tagSelected = [];
		searchQuery = '';
		activeViewId = null;
		applyFilters();
	}

	// ---------- saved views logic ----------

	async function loadSavedViews() {
		try { savedViews = await api.views.getAll(); } catch { /* ignore */ }
	}

	function getCurrentViewState() {
		return {
			statusOp, statusSelected,
			priorityOp, prioritySelected,
			typeOp, typeSelected,
			projectOp, projectSelected,
			tagOp, tagSelected,
			searchQuery
		};
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
				group_by: groupBy
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
		typeOp = (f.typeOp as 'is' | 'is_not') ?? 'is';
		typeSelected = (f.typeSelected as string[]) ?? [];
		projectOp = (f.projectOp as 'is' | 'is_not') ?? 'is';
		projectSelected = (f.projectSelected as string[]) ?? [];
		tagOp = (f.tagOp as 'is' | 'is_not') ?? 'is';
		tagSelected = (f.tagSelected as string[]) ?? [];
		searchQuery = (f.searchQuery as string) ?? '';

		if (view.view_mode === 'board' || view.view_mode === 'list') viewMode = view.view_mode as ViewMode;
		if (['none', 'status', 'project'].includes(view.group_by)) groupBy = view.group_by as GroupBy;

		activeViewId = view.id;
		viewsDropdownOpen = false;
		viewSubMenuId = null;
		await applyFilters(true);
	}

	async function renameView(id: string) {
		const name = editingViewName.trim();
		if (!name) return;
		try {
			const updated = await api.views.update(id, { name });
			savedViews = savedViews.map((v) => (v.id === id ? updated : v));
		} catch (e) {
			console.error('Failed to rename view:', e);
		}
		editingViewId = null;
	}

	async function deleteView(id: string) {
		try {
			await api.views.delete(id);
			savedViews = savedViews.filter((v) => v.id !== id);
			if (activeViewId === id) activeViewId = null;
		} catch (e) {
			console.error('Failed to delete view:', e);
		}
		viewSubMenuId = null;
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
		viewSubMenuId = null;
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

	// Close views dropdown on outside click
	$effect(() => {
		if (!viewsDropdownOpen) return;
		function onMouseDown(e: MouseEvent) {
			const target = e.target as HTMLElement;
			if (!target.closest('[data-views-dropdown]')) {
				viewsDropdownOpen = false;
				viewSubMenuId = null;
				editingViewId = null;
			}
		}
		document.addEventListener('mousedown', onMouseDown);
		return () => document.removeEventListener('mousedown', onMouseDown);
	});

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
		loadSavedViews();
		await taskStore.loadAll(getFilters(), 1, perPage);
		initialLoading = false;
		if (viewMode === 'board') rebuildBoard();

		const taskParam = page.url.searchParams.get('task');
		if (taskParam) selectTask(taskParam);
	});
</script>

<div class="flex h-full overflow-hidden">
<div class="flex min-w-0 flex-1 flex-col {viewMode === 'board' ? 'overflow-hidden' : 'overflow-y-auto'}">
	<!-- ===== HEADER ===== -->
	<div class="flex shrink-0 items-center justify-between border-b border-surface-border px-3 py-1.5">
		<div class="flex items-center gap-1">
			<!-- View toggle -->
			<div class="flex items-center gap-0.5">
				<button
					class="flex h-7 items-center gap-1 rounded-sm px-2 text-sm leading-none font-medium transition-all duration-150 {viewMode === 'list' ? 'text-accent' : 'text-muted hover:text-sidebar-text'}"
					onclick={() => setView('list')}
				>
					<LayoutList size={13} />
					List
				</button>
				<button
					class="flex h-7 items-center gap-1 rounded-sm px-2 text-sm leading-none font-medium transition-all duration-150 {viewMode === 'board' ? 'text-accent' : 'text-muted hover:text-sidebar-text'}"
					onclick={() => setView('board')}
				>
					<Columns3 size={13} />
					Board
				</button>
			</div>

			<span class="mx-1 h-4 w-px bg-surface-border"></span>

			<!-- Group-by -->
			<div class="flex items-center gap-0.5">
				{#each GROUP_OPTIONS as g (g)}
					{#if !(viewMode === 'board' && g === 'none')}
						<button
							class="flex h-7 items-center rounded-sm px-2 text-sm font-medium transition-all duration-150 {groupBy === g ? 'text-accent' : 'text-muted hover:text-sidebar-text'}"
							onclick={() => setGroupBy(g)}
						>
							{formatStatus(g)}
						</button>
					{/if}
				{/each}
			</div>

			<span class="mx-1 h-4 w-px bg-surface-border"></span>

			<!-- Filter toggle -->
			<div class="relative shrink-0">
				<button
					class="flex h-7 w-7 items-center justify-center rounded-sm transition-all duration-150 hover:bg-surface-hover/50 {filtersVisible ? 'text-accent' : 'text-muted'}"
					onclick={() => (filtersVisible = !filtersVisible)}
					title={filtersVisible ? 'Hide filters' : 'Show filters'}
				>
					<ListFilter size={14} />
				</button>
				{#if activeFiltersCount > 0}
					<span
						class="absolute -top-1 -right-1 flex h-3.5 min-w-3.5 items-center justify-center rounded-full bg-accent px-0.5 text-3xs leading-none font-semibold text-white"
					>
						{activeFiltersCount > 9 ? '9+' : activeFiltersCount}
					</span>
				{/if}
			</div>

			<!-- Views dropdown -->
			<div class="relative shrink-0" data-views-dropdown>
				<button
					class="flex h-7 items-center gap-1 rounded-sm px-2 text-sm font-medium transition-all duration-150 hover:bg-surface-hover/50 {viewsDropdownOpen || activeViewId ? 'text-accent' : 'text-muted'}"
					onclick={() => { viewsDropdownOpen = !viewsDropdownOpen; viewSubMenuId = null; editingViewId = null; }}
					title="Saved views"
				>
					<Bookmark size={14} />
					{#if activeViewId}
						<span class="max-w-24 truncate">{savedViews.find((v) => v.id === activeViewId)?.name ?? 'View'}</span>
					{/if}
				</button>
				{#if viewsDropdownOpen}
					<div class="absolute left-0 top-full z-20 mt-1.5 w-52 origin-top-left animate-dropdown-in rounded-md border border-surface-border bg-surface py-1 shadow-lg shadow-black/15 ring-1 ring-white/[0.07]">
						<!-- Save current view -->
						<button
							class="flex w-full items-center gap-2 border-b border-surface-border/40 px-2.5 py-1.5 text-left text-sm text-muted transition-colors hover:bg-surface-hover/60 hover:text-sidebar-text"
							onclick={() => { saveModalOpen = true; saveViewName = ''; viewsDropdownOpen = false; }}
						>
							<Plus size={11} class="text-muted/40" />
							Save current view
						</button>

						{#if savedViews.length === 0}
							<p class="px-3 py-3 text-center text-xs text-muted/40">No saved views yet.</p>
						{:else}
							{#each savedViews as view (view.id)}
								<div class="group flex items-center justify-between transition-colors hover:bg-surface-hover/60">
									{#if editingViewId === view.id}
										<form class="flex min-w-0 flex-1 items-center gap-1 px-2.5 py-1" onsubmit={(e) => { e.preventDefault(); renameView(view.id); }}>
											<input
												type="text"
												bind:value={editingViewName}
												class="h-6 min-w-0 flex-1 rounded-sm border border-accent/40 bg-transparent px-2 text-sm text-sidebar-text outline-none focus:border-accent"
												onkeydown={(e) => { if (e.key === 'Escape') editingViewId = null; }}
											/>
											<button type="submit" class="shrink-0 text-accent hover:text-accent/80"><Check size={11} /></button>
											<button type="button" class="shrink-0 text-muted hover:text-sidebar-text" onclick={() => (editingViewId = null)}><X size={11} /></button>
										</form>
									{:else}
										<button
											class="flex flex-1 items-center gap-2 px-2.5 py-1.5 text-left text-sm transition-colors
												{activeViewId === view.id ? 'text-accent font-medium' : 'text-muted hover:text-sidebar-text'}"
											onclick={() => applySavedView(view)}
										>
											{#if activeViewId === view.id}<Check size={11} class="shrink-0" />{/if}
											<span class="truncate">{view.name}</span>
										</button>
										<div class="relative">
											<button
												class="shrink-0 px-1.5 py-1.5 text-muted/30 opacity-0 transition-opacity hover:text-sidebar-text group-hover:opacity-100
													{viewSubMenuId === view.id ? '!opacity-100' : ''}"
												onclick={(e) => { e.stopPropagation(); viewSubMenuId = viewSubMenuId === view.id ? null : view.id; }}
											>
												<EllipsisVertical size={12} />
											</button>
											{#if viewSubMenuId === view.id}
												<div class="absolute right-0 top-full z-30 mt-1 w-36 origin-top-right animate-dropdown-in rounded-md border border-surface-border bg-surface py-1 shadow-lg shadow-black/15 ring-1 ring-white/[0.07]">
													<button
														class="flex w-full items-center gap-2 px-2.5 py-1.5 text-left text-sm text-muted transition-colors hover:bg-surface-hover/60 hover:text-sidebar-text"
														onclick={() => { editingViewId = view.id; editingViewName = view.name; viewSubMenuId = null; }}
													>
														<Pencil size={11} /> Rename
													</button>
													<button
														class="flex w-full items-center gap-2 px-2.5 py-1.5 text-left text-sm text-muted transition-colors hover:bg-surface-hover/60 hover:text-sidebar-text"
														onclick={() => updateViewFilters(view.id)}
													>
														<Bookmark size={11} /> Update filters
													</button>
													<button
														class="flex w-full items-center gap-2 px-2.5 py-1.5 text-left text-sm text-red-400 transition-colors hover:bg-surface-hover/60"
														onclick={() => deleteView(view.id)}
													>
														<Trash2 size={11} /> Delete
													</button>
												</div>
											{/if}
										</div>
									{/if}
								</div>
							{/each}
						{/if}
					</div>
				{/if}
			</div>
		</div>

		<div class="flex items-center gap-1.5">
			<!-- Search -->
			<div class="relative flex items-center">
				<Search size={12} class="absolute left-2 text-muted pointer-events-none" />
				<input
					type="text"
					placeholder="Search..."
					value={searchQuery}
					oninput={onSearchInput}
					class="h-7 w-40 rounded-sm border border-transparent bg-surface-hover/50 pl-7 pr-6 text-sm text-sidebar-text transition-all duration-150 placeholder:text-muted/50 focus:w-56 focus:border-surface-border focus:bg-surface focus:outline-none"
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

			<button
				class="flex h-7 items-center justify-center gap-1 rounded-sm bg-accent px-2.5 text-sm leading-none font-medium text-white transition-all duration-150 hover:bg-accent/90"
				onclick={() => { createPrefill = {}; createModalOpen = true; }}
			>
				<Plus size={14} class="shrink-0" />
				New
			</button>
		</div>
	</div>

	<!-- ===== FILTERS ===== -->
	{#if filtersVisible}
		<div class="flex shrink-0 items-center gap-0.5 border-b border-surface-border px-3 py-1">
			<div class="flex flex-wrap items-center gap-0.5">
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
				{#if tagOptions.length > 0}
				<FilterDropdown
					label="Tags"
					searchable
					options={tagOptions}
					operator={tagOp}
					selected={tagSelected}
					onchange={(op, sel) => { tagOp = op; tagSelected = sel; if (viewMode === 'board') rebuildBoard(); syncUrl(); }}
				/>
				{/if}
			</div>
			{#if hasActiveFilters}
				<button
					class="ml-1 text-xs text-muted/40 transition-colors hover:text-accent"
					onclick={clearFilters}
				>
					Clear
				</button>
			{/if}
		</div>
	{/if}

	<!-- ===== CONTENT ===== -->
	{#if initialLoading}
		<p class="px-4 py-12 text-center text-lg text-muted">Loading...</p>
	{:else if taskStore.error}
		<p class="px-4 py-12 text-center text-lg text-red-500">{taskStore.error}</p>
	{:else if viewMode === 'list'}
		<!-- LIST VIEW -->
		{#if taskStore.items.length === 0}
			<div class="flex flex-col items-center gap-3 px-4 py-12">
				<p class="text-sm text-muted">{hasActiveFilters ? 'No tasks match your filters.' : 'No tasks yet.'}</p>
				{#if !hasActiveFilters}
					<button
						class="flex h-7 items-center justify-center gap-1 rounded-sm bg-accent px-2.5 text-sm leading-none font-medium text-white transition-all duration-150 hover:bg-accent/90"
						onclick={() => { createPrefill = {}; createModalOpen = true; }}
					>
						<Plus size={14} class="shrink-0" />
						New task
					</button>
				{/if}
			</div>
		{:else if listGroups}
			<!-- Grouped list -->
			<div class="space-y-1 p-3">
				{#each listGroups as group (group.key)}
					{@const isCollapsed = collapsedGroups.has(group.key)}
					<!-- Group header — plain, no background -->
					<button
						class="flex w-full items-center gap-1.5 px-1 py-1 text-left"
						onclick={() => toggleGroupCollapse(group.key)}
					>
						<ChevronDown size={10} class="shrink-0 text-muted/30 transition-transform duration-150 {isCollapsed ? '-rotate-90' : ''}" />
						{#if group.color}
							<span class="h-1.5 w-1.5 shrink-0 rounded-full" style="background-color: {group.color}"></span>
						{/if}
						<span class="text-sm font-medium text-muted">{group.label}</span>
						<span class="text-xs text-muted/30">{group.tasks.length}</span>
					</button>
					<!-- Task cards -->
					{#if !isCollapsed}
						<div transition:slide={{ duration: 150 }} class="mb-2 overflow-hidden rounded border border-surface-border/50 bg-surface/50">
							{#each group.tasks as task, i (task.id)}
								<TaskRow
									{task}
									selected={task.id === selectedTaskId}
									onclick={() => selectTask(task.id)}
								/>
								{#if i < group.tasks.length - 1}
									<div class="mx-3 h-px bg-surface-border/30"></div>
								{/if}
							{/each}
						</div>
					{/if}
				{/each}
			</div>
		{:else}
			<!-- Flat list -->
			<div>
				{#each (tagSelected.length > 0 ? taskStore.items.filter(passesTagFilter) : taskStore.items) as task (task.id)}
					<TaskRow
						{task}
						selected={task.id === selectedTaskId}
						onclick={() => selectTask(task.id)}
					/>
				{/each}
			</div>

			<!-- Pagination -->
			<div class="flex items-center justify-between border-t border-surface-border px-4 py-3">
				<span class="font-mono text-sm text-muted">{taskStore.count} task{taskStore.count === 1 ? '' : 's'}</span>
				{#if totalPages > 1}
					<div class="flex items-center gap-2">
						<button
							class="flex items-center justify-center border border-surface-border bg-surface p-1.5 text-sidebar-icon transition-colors hover:bg-surface-hover disabled:opacity-40 disabled:cursor-not-allowed focus-visible:ring-1 focus-visible:ring-accent/50 focus-visible:outline-none"
							disabled={currentPage <= 1}
							onclick={() => goToPage(currentPage - 1)}
						>
							<ChevronLeft size={14} />
						</button>
						<span class="text-base text-sidebar-text">
							Page {currentPage} of {totalPages}
						</span>
						<button
							class="flex items-center justify-center border border-surface-border bg-surface p-1.5 text-sidebar-icon transition-colors hover:bg-surface-hover disabled:opacity-40 disabled:cursor-not-allowed focus-visible:ring-1 focus-visible:ring-accent/50 focus-visible:outline-none"
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
				<div class="flex w-64 shrink-0 flex-col border-r border-surface-border/50 max-h-full last:border-r-0">
					<!-- Column header -->
					<div class="flex items-center gap-2 px-3 py-2">
						{#if groupBy === 'project' && col.key !== '__none__'}
							<span class="h-1.5 w-1.5 shrink-0 rounded-full" style="background-color: {col.color}"></span>
						{/if}
						<span class="text-sm font-medium text-muted truncate">{col.label}</span>
						<span class="text-xs text-muted/30">{col.items.length}</span>
					</div>

					<!-- Cards container -->
					<div
						class="flex-1 overflow-y-auto px-2 pb-2 min-h-[60px] scrollbar-none"
						style="-ms-overflow-style: none; scrollbar-width: none;"
						use:dndzone={{ items: col.items, flipDurationMs: 200, dropTargetStyle: { outline: '2px solid var(--color-accent)', outlineOffset: '-2px' } }}
						onconsider={(e) => handleConsider(colIndex, e)}
						onfinalize={(e) => handleFinalize(colIndex, col.key, e)}
					>
						{#each col.items as task (task.id)}
							<TaskBoardCard
								{task}
								selected={selectedTaskId === task.id}
								showProjectIdentifier={groupBy === 'status'}
								showStatus={groupBy === 'project'}
								onclick={() => selectTask(task.id)}
							/>
						{/each}

						<!-- Create task inline -->
						<button
							class="mt-0.5 flex w-full items-center justify-center gap-1 rounded py-1.5 text-sm text-muted/30 transition-colors hover:bg-surface-hover/30 hover:text-muted"
							onclick={() => {
								createPrefill = groupBy === 'status'
									? { status: col.key }
									: { projectId: col.key !== '__none__' ? col.key : undefined };
								createModalOpen = true;
							}}
						>
							<Plus size={11} />
						</button>
					</div>
				</div>
			{/each}
		</div>
	{/if}
</div>

<!-- ===== TASK DETAIL PANEL ===== -->
<div
	class="h-full shrink-0 overflow-hidden transition-[width] duration-200 ease-out"
	style="width: {selectedTaskId ? '420px' : '0px'}"
>
	{#if selectedTaskId}
		<div class="h-full w-[420px]">
			<TaskDetailPanel
				taskId={selectedTaskId}
				onClose={() => selectTask(null)}
				onUpdate={async () => { await taskStore.loadAll(getFilters(), currentPage, perPage); if (viewMode === 'board') rebuildBoard(); }}
			/>
		</div>
	{/if}
</div>
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

<!-- ===== SAVE VIEW MODAL ===== -->
<Modal open={saveModalOpen} onClose={() => (saveModalOpen = false)} maxWidth="max-w-sm">
	<div class="px-3 py-2.5 border-b border-surface-border">
		<h2 class="text-md font-semibold text-sidebar-text">Save view</h2>
	</div>
	<form onsubmit={(e) => { e.preventDefault(); saveCurrentView(); }} class="p-3 space-y-3">
		<div>
			<label for="view-name" class="mb-1.5 block text-xs font-medium uppercase tracking-[0.08em] text-muted/50">Name</label>
			<input
				id="view-name"
				type="text"
				bind:value={saveViewName}
				placeholder="e.g. My active bugs"
				class="w-full rounded-sm bg-surface-hover/40 px-2.5 py-1.5 text-base text-sidebar-text outline-none transition-all duration-150 placeholder:text-muted/30 focus:bg-surface-hover/60"
			/>
			<p class="mt-1.5 text-xs text-muted/40">Saves the current filters, view mode, and grouping.</p>
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
		from {
			opacity: 0;
			transform: scale(0.95) translateY(-4px);
		}
		to {
			opacity: 1;
			transform: scale(1) translateY(0);
		}
	}

	:global(.animate-dropdown-in) {
		animation: dropdown-in 150ms ease-out;
	}
</style>
