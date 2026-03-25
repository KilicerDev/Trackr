<script lang="ts">
	import { onMount } from 'svelte';
	import { browser } from '$app/environment';
	import { page } from '$app/stores';
	import { replaceState, afterNavigate } from '$app/navigation';
	import { projectStore } from '$lib/stores/projects.svelte';
	import { taskStore } from '$lib/stores/tasks.svelte';
	import { notifications } from '$lib/stores/notifications.svelte';
	import { auth } from '$lib/stores/auth.svelte';
	import { api } from '$lib/api';
	import { dndzone } from 'svelte-dnd-action';
	import type { TaskFilters, FilterOp } from '$lib/api/tasks';
	import type { Task } from '$lib/stores/tasks.svelte';
	import TaskRow from '$lib/components/TaskRow.svelte';
	import { ArrowLeft, Users, User, Check, X, Plus, LayoutList, Columns3, ListFilter, Info, Paperclip, SquareCheckBig } from '@lucide/svelte';
	import TaskDetailPanel from '$lib/components/TaskDetailPanel.svelte';
	import CreateTaskModal from '$lib/components/CreateTaskModal.svelte';
	import FilterDropdown from '$lib/components/FilterDropdown.svelte';
	import { typeIcons, defaultTypeIcon } from '$lib/config/task-icons';
	import { localizeHref } from '$lib/paraglide/runtime';
	import { SvelteMap } from 'svelte/reactivity';
	import type { Attachment } from '$lib/api/attachments';
	import AttachmentUploadZone from '$lib/components/AttachmentUploadZone.svelte';
	import AttachmentList from '$lib/components/AttachmentList.svelte';

	const PROJECT_STATUSES = ['planning', 'active', 'paused', 'completed', 'archived'] as const;
	const PRESET_COLORS = [
		'#10b981',
		'#3b82f6',
		'#8b5cf6',
		'#f59e0b',
		'#ef4444',
		'#ec4899',
		'#06b6d4',
		'#84cc16',
		'#f97316',
		'#6366f1'
	];

	const statusColors: Record<string, string> = {
		planning: 'bg-blue-100 text-blue-700 dark:bg-blue-950/60 dark:text-blue-300',
		active: 'bg-green-100 text-green-700 dark:bg-green-950/60 dark:text-green-300',
		paused: 'bg-yellow-100 text-yellow-700 dark:bg-yellow-950/60 dark:text-yellow-300',
		completed: 'bg-purple-100 text-purple-700 dark:bg-purple-950/60 dark:text-purple-300',
		archived: 'bg-gray-100 text-gray-500 dark:bg-surface-hover dark:text-muted'
	};

	const TASK_STATUSES = ['backlog', 'todo', 'in_progress', 'in_review', 'done', 'cancelled'] as const;
	const TASK_PRIORITIES = ['none', 'low', 'medium', 'high', 'urgent'] as const;
	const TASK_TYPES = ['task', 'bug', 'feature', 'improvement', 'epic'] as const;
	const TASK_GROUP_OPTIONS = ['none', 'status'] as const;

	type TaskViewMode = 'list' | 'board';
	type TaskGroupBy = (typeof TASK_GROUP_OPTIONS)[number];

	const priorityColors: Record<string, string> = {
		urgent: 'bg-red-100 text-red-700 dark:bg-red-950/60 dark:text-red-300',
		high: 'bg-orange-100 text-orange-700 dark:bg-orange-950/60 dark:text-orange-300',
		medium: 'bg-yellow-100 text-yellow-700 dark:bg-yellow-950/60 dark:text-yellow-300',
		low: 'bg-blue-100 text-blue-700 dark:bg-blue-950/60 dark:text-blue-300',
		none: 'bg-gray-100 text-gray-500 dark:bg-surface-hover dark:text-muted'
	};

	const taskStatusColors: Record<string, string> = {
		backlog: 'bg-gray-100 text-gray-600 dark:bg-surface-hover dark:text-sidebar-text',
		todo: 'bg-gray-100 text-gray-700 dark:bg-surface-hover dark:text-sidebar-text',
		in_progress: 'bg-pink-100 text-pink-700 dark:bg-pink-950/60 dark:text-pink-300',
		in_review: 'bg-purple-100 text-purple-700 dark:bg-purple-950/60 dark:text-purple-300',
		done: 'bg-green-100 text-green-700 dark:bg-green-950/60 dark:text-green-300',
		cancelled: 'bg-gray-100 text-gray-400 dark:bg-surface-hover dark:text-muted'
	};

	// Task filter & view state
	let taskViewMode = $state<TaskViewMode>((browser ? localStorage.getItem('project-tasks-view') : null) as TaskViewMode ?? 'list');
	let taskGroupBy = $state<TaskGroupBy>((browser ? localStorage.getItem('project-tasks-group') : null) as TaskGroupBy ?? 'none');
	let taskStatusOp = $state<'is' | 'is_not'>('is_not');
	let taskStatusSelected = $state<string[]>(['done', 'cancelled']);
	let taskPriorityOp = $state<'is' | 'is_not'>('is');
	let taskPrioritySelected = $state<string[]>([]);
	let taskTypeOp = $state<'is' | 'is_not'>('is');
	let taskTypeSelected = $state<string[]>([]);
	let taskFiltersVisible = $state(false);

	function formatTaskStatus(s: string): string {
		return s.split('_').map((w) => w.charAt(0).toUpperCase() + w.slice(1)).join(' ');
	}

	function formatPriority(p: string): string {
		return p.charAt(0).toUpperCase() + p.slice(1);
	}

	function toFilterOp(op: 'is' | 'is_not', values: string[]): FilterOp | undefined {
		if (values.length === 0) return undefined;
		return { values, not: op === 'is_not' };
	}

	function getTaskFilters(): TaskFilters {
		const id = $page.params.id!;
		const f: TaskFilters = { project_id: id };
		const skipStatus = taskViewMode === 'board' && taskGroupBy === 'status';
		if (!skipStatus) f.status = toFilterOp(taskStatusOp, taskStatusSelected);
		f.priority = toFilterOp(taskPriorityOp, taskPrioritySelected);
		f.type = toFilterOp(taskTypeOp, taskTypeSelected);
		return f;
	}

	async function applyTaskFilters() {
		await taskStore.load(getTaskFilters());
		if (taskViewMode === 'board') rebuildTaskBoard();
	}

	function clearTaskFilters() {
		taskStatusOp = 'is'; taskStatusSelected = [];
		taskPriorityOp = 'is'; taskPrioritySelected = [];
		taskTypeOp = 'is'; taskTypeSelected = [];
		applyTaskFilters();
	}

	function setTaskView(v: TaskViewMode) {
		taskViewMode = v;
		localStorage.setItem('project-tasks-view', v);
		if (v === 'board' && taskGroupBy === 'none') {
			taskGroupBy = 'status';
			localStorage.setItem('project-tasks-group', 'status');
		}
		applyTaskFilters();
	}

	function setTaskGroupBy(g: TaskGroupBy) {
		taskGroupBy = g;
		localStorage.setItem('project-tasks-group', g);
		applyTaskFilters();
	}

	const taskFilterCount = $derived(
		[taskStatusSelected.length, taskPrioritySelected.length, taskTypeSelected.length].filter(Boolean).length
	);

	// Kanban board for project tasks
	type BoardColumn = { key: string; label: string; items: (Task & { id: string })[] };
	let taskBoardColumns = $state<BoardColumn[]>([]);

	function rebuildTaskBoard() {
		taskBoardColumns = TASK_STATUSES.map((s) => ({
			key: s,
			label: formatTaskStatus(s),
			items: taskStore.items.filter((t) => t.status === s).map((t) => ({ ...t, id: t.id }))
		}));
	}

	function handleTaskConsider(colIndex: number, e: CustomEvent<{ items: (Task & { id: string })[] }>) {
		taskBoardColumns[colIndex].items = e.detail.items;
	}

	async function handleTaskFinalize(colIndex: number, colKey: string, e: CustomEvent<{ items: (Task & { id: string })[] }>) {
		taskBoardColumns[colIndex].items = e.detail.items;
		const moved: { id: string; status: string }[] = [];
		for (const item of e.detail.items) {
			if (item.status !== colKey) {
				item.status = colKey;
				moved.push({ id: item.id, status: colKey });
			}
		}
		for (const m of moved) {
			try {
				await api.tasks.update(m.id, { status: m.status });
			} catch {
				await taskStore.load(getTaskFilters());
				rebuildTaskBoard();
				return;
			}
		}
	}

	type OrgMember = {
		user_id: string;
		user: { id: string; full_name: string; email: string; avatar_url: string | null; is_active: boolean; deleted_at: string | null };
		role: { id: string; name: string; slug: string } | null;
	};

	const project = $derived(projectStore.activeProject);
	const canUpdateProject = $derived(auth.can('projects', 'update'));
	const canManageProject = $derived(auth.can('projects', 'manage'));
	const canCreateTask = $derived(auth.can('tasks', 'create'));

	type TaskWithDepth = { task: (typeof taskStore.items)[number]; depth: number };
	const taskTree = $derived.by(() => {
		const items = taskStore.items;
		const childrenMap = new SvelteMap<string | null, typeof items>();
		for (const t of items) {
			const pid = (t.parent_id as string | null) ?? null;
			let list = childrenMap.get(pid);
			if (!list) {
				list = [];
				childrenMap.set(pid, list);
			}
			list.push(t);
		}
		const result: TaskWithDepth[] = [];
		const visited = new Set<string>();
		function walk(parentId: string | null, depth: number) {
			const children = childrenMap.get(parentId);
			if (!children) return;
			for (const child of children) {
				if (visited.has(child.id)) continue;
				visited.add(child.id);
				result.push({ task: child, depth });
				walk(child.id, depth + 1);
			}
		}
		walk(null, 0);
		// Recovery: show cycle/orphan tasks at root level
		for (const t of items) {
			if (!visited.has(t.id)) {
				visited.add(t.id);
				result.push({ task: t, depth: 0 });
				walk(t.id, 1);
			}
		}
		return result;
	});

	let selectedTaskId = $state<string | null>(null);
	let projectTab = $state<'tasks' | 'details' | 'attachments'>('tasks');
	let boardEl = $state<HTMLDivElement | undefined>(undefined);

	$effect(() => {
		if (!boardEl) return;
		const top = boardEl.getBoundingClientRect().top;
		boardEl.style.setProperty('--board-top', `${top}px`);
	});

	function selectTask(id: string | null) {
		selectedTaskId = id;
		const url = new URL(window.location.href);
		if (id) {
			url.searchParams.set('task', id);
		} else {
			url.searchParams.delete('task');
		}
		replaceState(localizeHref(url.pathname + url.search), {});
	}

	let createModalOpen = $state(false);
	let openDropdown = $state<string | null>(null);
	let editingName = $state(false);
	let nameDraft = $state('');
	let editingDescription = $state(false);
	let descriptionDraft = $state('');
	let savingField = $state(false);

	let orgMembers = $state<OrgMember[]>([]);
	let addingMember = $state(false);
	let projectAttachments = $state<Attachment[]>([]);
	let uploadingFiles = $state(false);

	const PROJECT_ASSIGNABLE_ROLES = ['owner', 'admin', 'manager', 'agent'];

	const availableMembers = $derived(
		orgMembers.filter(
			(om) =>
				!project?.members?.some((pm) => pm.user_id === om.user_id) &&
				om.role &&
				PROJECT_ASSIGNABLE_ROLES.includes(om.role.slug)
		)
	);

	function formatDate(dateStr: string | null | unknown): string {
		if (!dateStr || typeof dateStr !== 'string') return '—';
		const d = new Date(dateStr);
		if (isNaN(d.getTime())) return '—';
		return d.toLocaleDateString('de-DE', { day: '2-digit', month: '2-digit', year: 'numeric' });
	}

	function toInputDate(dateStr: string | null | unknown): string {
		if (!dateStr || typeof dateStr !== 'string') return '';
		const d = new Date(dateStr);
		if (isNaN(d.getTime())) return '';
		return d.toISOString().slice(0, 10);
	}

	function formatStatus(status: string): string {
		return status.charAt(0).toUpperCase() + status.slice(1);
	}

	$effect(() => {
		if (!openDropdown) return;
		function handleClick(e: MouseEvent) {
			const target = e.target as HTMLElement;
			if (!target.closest('[data-dropdown]')) {
				openDropdown = null;
			}
		}
		document.addEventListener('mousedown', handleClick);
		return () => document.removeEventListener('mousedown', handleClick);
	});

	async function updateField(field: string, value: unknown) {
		if (!project) return;
		openDropdown = null;
		try {
			await projectStore.update(project.id, { [field]: value });
		} catch {
			notifications.add('error', `Failed to update ${field}`);
		}
	}

	function startEditName() {
		if (!project) return;
		nameDraft = project.name;
		editingName = true;
	}

	async function saveName() {
		if (!project || savingField || !nameDraft.trim()) return;
		savingField = true;
		try {
			await projectStore.update(project.id, { name: nameDraft.trim() });
			editingName = false;
		} catch {
			notifications.add('error', 'Failed to update name');
		} finally {
			savingField = false;
		}
	}

	function startEditDescription() {
		if (!project) return;
		descriptionDraft = project.description ?? '';
		editingDescription = true;
	}

	async function saveDescription() {
		if (!project || savingField) return;
		savingField = true;
		try {
			await projectStore.update(project.id, {
				description: descriptionDraft.trim() || null
			});
			editingDescription = false;
		} catch {
			notifications.add('error', 'Failed to update description');
		} finally {
			savingField = false;
		}
	}

	async function handleDateChange(field: 'start_at' | 'end_at', value: string) {
		await updateField(field, value ? `${value}T00:00:00.000Z` : null);
	}

	async function addMember(userId: string, roleId: string) {
		if (!project || !userId || !roleId || addingMember) return;
		addingMember = true;
		const n = notifications.action('Adding member');
		try {
			await api.projects.addMember(project.id, userId, roleId);
			await projectStore.loadById(project.id);
			openDropdown = null;
			n.success('Member added');
		} catch (e) {
			n.error('Failed', e instanceof Error ? e.message : 'Could not add member');
		} finally {
			addingMember = false;
		}
	}

	async function removeMember(userId: string) {
		if (!project) return;
		const n = notifications.action('Removing member');
		try {
			await api.projects.removeMember(project.id, userId);
			await projectStore.loadById(project.id);
			n.success('Member removed');
		} catch (e) {
			n.error('Failed', e instanceof Error ? e.message : 'Could not remove member');
		}
	}

	onMount(async () => {
		const id = $page.params.id!;
		await Promise.all([
			taskStore.load(getTaskFilters()),
			projectStore.loadById(id),
			api.attachments.list('project', id).then((att) => { projectAttachments = att; }).catch(() => {})
		]);
		if (taskViewMode === 'board') rebuildTaskBoard();

		const orgId = projectStore.activeProject?.organization_id;
		if (orgId) {
			orgMembers = (await api.members.getAll(orgId).catch(() => [])) as OrgMember[];
		}

		const taskParam = new URL(window.location.href).searchParams.get('task');
		if (taskParam) selectTask(taskParam);
	});

	$effect(() => {
		if (taskViewMode === 'board' && !taskStore.loading) {
			taskStore.items;
			rebuildTaskBoard();
		}
	});

	async function handleProjectFileUpload(files: File[]) {
		if (!project || !auth.user || uploadingFiles) return;
		uploadingFiles = true;
		try {
			for (const file of files) {
				const att = await api.attachments.upload(file, 'project', project.id, project.organization_id, auth.user!.id);
				projectAttachments = [att, ...projectAttachments];
			}
		} catch {
			/* silent */
		} finally {
			uploadingFiles = false;
		}
	}

	async function handleRemoveProjectAttachment(att: Attachment) {
		try {
			await api.attachments.remove(att.id, att.storage_path);
			projectAttachments = projectAttachments.filter((a) => a.id !== att.id);
		} catch {
			/* silent */
		}
	}

	afterNavigate(({ to }) => {
		const taskParam = to?.url.searchParams.get('task') ?? null;
		if (taskParam) selectedTaskId = taskParam;
	});

	$effect(() => {
		if (!selectedTaskId) return;
		function handleKeydown(e: KeyboardEvent) {
			const tag = (e.target as HTMLElement)?.tagName;
			if (tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT') return;
			if (e.key !== 'ArrowDown' && e.key !== 'ArrowUp') return;
			e.preventDefault();
			const idx = taskTree.findIndex(({ task }) => task.id === selectedTaskId);
			if (idx === -1) return;
			const next = e.key === 'ArrowDown'
				? Math.min(idx + 1, taskTree.length - 1)
				: Math.max(idx - 1, 0);
			if (next !== idx) {
				selectTask(taskTree[next].task.id);
				requestAnimationFrame(() => {
					document.querySelector(`[data-task-id="${taskTree[next].task.id}"]`)
						?.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
				});
			}
		}
		document.addEventListener('keydown', handleKeydown);
		return () => document.removeEventListener('keydown', handleKeydown);
	});
</script>

<div class="flex h-full">
<div class="min-w-0 flex-1 flex flex-col overflow-hidden">
<div class="mx-auto w-full flex flex-col flex-1 min-h-0">
	<div class="flex shrink-0 items-center gap-3 px-3 py-1.5">
		<button
			onclick={() => history.back()}
			class="flex h-7 cursor-pointer items-center gap-1 rounded-sm px-2 text-sm text-muted transition-all duration-150 hover:text-sidebar-text"
		>
			<ArrowLeft size={14} />
			Projects
		</button>
	</div>

	{#if projectStore.loading && !project}
		<p class="px-4 py-12 text-center text-sm text-muted">Loading...</p>
	{:else if projectStore.error}
		<p class="px-4 py-12 text-center text-sm text-red-500">{projectStore.error}</p>
	{:else if project}
		<!-- Project details — scrollable, shrinks when board needs space -->
		<div class="shrink overflow-y-auto min-h-0">
		<div class="px-3 py-4">
			<div class="flex items-start justify-between gap-4">
				<div class="min-w-0 flex-1">
					<!-- Identifier + Status + Color -->
					<div class="flex items-center gap-2">
						<!-- Color picker -->
						{#if canUpdateProject}
							<div class="relative" data-dropdown>
								<button
									class="inline-block h-3 w-3 shrink-0 cursor-pointer rounded-full transition-transform hover:scale-125"
									style="background-color: {project.color ?? '#6366f1'}"
									onclick={() => (openDropdown = openDropdown === 'color' ? null : 'color')}
									aria-label="Change color"
								></button>
								{#if openDropdown === 'color'}
									<div
										class="absolute left-0 z-20 mt-2 flex gap-1.5 rounded-md border border-surface-border/70 bg-surface p-2.5 shadow-lg shadow-black/20"
									>
										{#each PRESET_COLORS as c (c)}
											<button
												class="h-5 w-5 rounded-full border-2 transition-transform hover:scale-110 {project.color ===
												c
													? 'scale-110 border-sidebar-text'
													: 'border-transparent'}"
												style="background-color: {c}"
												aria-label="Select color {c}"
												onmousedown={(e) => {
													e.preventDefault();
													updateField('color', c);
												}}
											></button>
										{/each}
									</div>
								{/if}
							</div>
						{:else}
							<span
								class="inline-block h-3 w-3 shrink-0 rounded-full"
								style="background-color: {project.color ?? '#6366f1'}"
							></span>
						{/if}

						<span class="text-sm font-semibold tracking-wider text-muted">
							{project.identifier}
						</span>

						<!-- Status dropdown -->
						{#if canUpdateProject}
							<div class="relative flex items-center" data-dropdown>
								<button
									class="inline-flex cursor-pointer items-center rounded-sm px-2 py-1 text-xs font-medium leading-none text-muted/50 transition-all duration-150 hover:text-sidebar-text"
									onclick={() => (openDropdown = openDropdown === 'status' ? null : 'status')}
								>
									{formatStatus(project.status)}
								</button>
								{#if openDropdown === 'status'}
									<div
										class="absolute top-full left-0 z-20 mt-1.5 min-w-[140px] origin-top-left animate-dropdown-in rounded-md border border-surface-border/70 bg-surface py-1 shadow-lg shadow-black/20"
									>
										{#each PROJECT_STATUSES as s (s)}
											<button
												class="flex w-full items-center px-2.5 py-1.5 text-left text-sm transition-colors hover:bg-surface-hover/60 {project.status ===
												s
													? 'font-medium text-accent'
													: 'text-muted'}"
												onmousedown={(e) => {
													e.preventDefault();
													updateField('status', s);
												}}
											>
												{formatStatus(s)}
											</button>
										{/each}
									</div>
								{/if}
							</div>
						{:else}
							<span
								class="inline-flex items-center rounded-sm px-2 py-1 text-xs font-medium leading-none text-muted/50"
							>
								{formatStatus(project.status)}
							</span>
						{/if}
					</div>

					<!-- Editable name -->
					{#if canUpdateProject && editingName}
						<div class="mt-1 flex items-center gap-2">
							<input
								type="text"
								bind:value={nameDraft}
								class="flex-1 rounded-sm bg-surface-hover/40 px-2.5 py-1.5 text-lg font-semibold text-sidebar-text outline-none focus:bg-surface-hover/60"
								onkeydown={(e) => {
									if (e.key === 'Enter') saveName();
									if (e.key === 'Escape') editingName = false;
								}}
							/>
							<button
								class="p-1 text-green-600 hover:text-green-500"
								onclick={saveName}
								aria-label="Save name"
							>
								<Check size={16} />
							</button>
							<button
								class="p-1 text-muted hover:text-sidebar-text"
								onclick={() => (editingName = false)}
								aria-label="Cancel editing name"
							>
								<X size={16} />
							</button>
						</div>
					{:else if canUpdateProject}
						<button
							class="mt-1 cursor-pointer text-left text-lg font-semibold text-sidebar-text transition-all duration-150 hover:text-accent"
							onclick={startEditName}
						>
							{project.name}
						</button>
					{:else}
						<h1 class="mt-1 text-lg font-semibold text-sidebar-text">
							{project.name}
						</h1>
					{/if}

					<!-- Editable description -->
					{#if canUpdateProject && editingDescription}
						<div class="mt-2">
							<textarea
								bind:value={descriptionDraft}
								rows="3"
								class="w-full resize-none rounded-sm bg-surface-hover/40 px-2.5 py-1.5 text-base leading-relaxed text-sidebar-text outline-none placeholder:text-muted/30 focus:bg-surface-hover/60"
								onkeydown={(e) => {
									if (e.key === 'Escape') editingDescription = false;
								}}
							></textarea>
							<div class="mt-1.5 flex gap-2">
								<button
									class="flex h-7 items-center rounded-sm bg-accent px-2.5 text-sm font-medium text-white transition-all duration-150 hover:bg-accent/90 disabled:opacity-30"
									disabled={savingField}
									onclick={saveDescription}
								>
									{savingField ? 'Saving…' : 'Save'}
								</button>
								<button
									class="flex h-7 items-center rounded-sm bg-surface-hover/40 px-2.5 text-sm font-medium text-sidebar-text transition-all duration-150 hover:bg-surface-hover/60"
									onclick={() => (editingDescription = false)}
								>
									Cancel
								</button>
							</div>
						</div>
					{:else if canUpdateProject}
						<button
							class="mt-1.5 cursor-pointer text-left text-sm leading-relaxed text-muted/50 transition-all duration-150 hover:text-sidebar-text"
							onclick={startEditDescription}
						>
							{project.description || 'Add a description…'}
						</button>
					{:else}
						<p class="mt-1.5 text-sm leading-relaxed text-muted/50">
							{project.description || 'No description.'}
						</p>
					{/if}
				</div>
			</div>

			<!-- Info row: owner, dates, members -->
			<div class="mt-4 flex flex-wrap items-center gap-10 text-base text-muted">
				<div class="flex flex-col gap-2">
					{#if project.owner}
						<span class="flex items-center gap-1.5">
							<User size={13} />
							<span class="text-sidebar-text">{project.owner.full_name}</span>
						</span>
					{/if}

					<span class="flex items-center gap-1.5">
						<Users size={13} />
						{project.members?.length ?? 0} member{(project.members?.length ?? 0) === 1 ? '' : 's'}
					</span>
				</div>

				<div class="flex items-center gap-5">
					<div>
						<span class="text-sidebar-icon">Start</span>
						{#if canUpdateProject}
							<label class="flex items-center gap-1">
								<input
									type="date"
									value={toInputDate(project.start_at)}
									class="rounded-sm bg-surface-hover/40 px-2.5 py-1.5 text-base text-sidebar-text outline-none focus:bg-surface-hover/60"
									onchange={(e) => handleDateChange('start_at', (e.target as HTMLInputElement).value)}
								/>
							</label>
						{:else}
							<p class="text-base text-sidebar-text">{formatDate(project.start_at)}</p>
						{/if}
					</div>
					<div>
						<span class="text-sidebar-icon">End</span>
						{#if canUpdateProject}
							<label class="flex items-center gap-1">
								<input
									type="date"
									value={toInputDate(project.end_at)}
									class="rounded-sm bg-surface-hover/40 px-2.5 py-1.5 text-base text-sidebar-text outline-none focus:bg-surface-hover/60"
									onchange={(e) => handleDateChange('end_at', (e.target as HTMLInputElement).value)}
								/>
							</label>
						{:else}
							<p class="text-base text-sidebar-text">{formatDate(project.end_at)}</p>
						{/if}
					</div>
				</div>
			</div>
		</div>

		<!-- Tab bar -->
		<div class="flex items-center gap-0.5 border-b border-surface-border px-4 mb-2">
			<button
				class="flex items-center gap-1.5 border-b-2 px-2 py-1.5 text-sm font-medium transition-colors {projectTab === 'tasks' ? 'border-accent text-sidebar-text' : 'border-transparent text-muted hover:text-sidebar-text'}"
				onclick={() => (projectTab = 'tasks')}
			>
				<SquareCheckBig size={12} />
				Tasks
				<span class="text-2xs text-muted/40">{taskStore.items.length}</span>
			</button>
			<button
				class="flex items-center gap-1.5 border-b-2 px-2 py-1.5 text-sm font-medium transition-colors {projectTab === 'details' ? 'border-accent text-sidebar-text' : 'border-transparent text-muted hover:text-sidebar-text'}"
				onclick={() => (projectTab = 'details')}
			>
				<Info size={12} />
				Details
			</button>
			<button
				class="flex items-center gap-1.5 border-b-2 px-2 py-1.5 text-sm font-medium transition-colors {projectTab === 'attachments' ? 'border-accent text-sidebar-text' : 'border-transparent text-muted hover:text-sidebar-text'}"
				onclick={() => (projectTab = 'attachments')}
			>
				<Paperclip size={12} />
				Files
				{#if projectAttachments.length > 0}
					<span class="text-2xs text-muted/40">{projectAttachments.length}</span>
				{/if}
			</button>
		</div>

		{#if projectTab === 'details'}
		<!-- Members -->
		<div class="mx-3 mb-2 rounded border border-surface-border/40 bg-surface/50 px-3 py-2.5">
			<div class="mb-3 flex items-center justify-between">
				<h2 class="text-xs font-medium tracking-[0.08em] text-muted/50 uppercase">Members</h2>
				{#if canManageProject}
				<div class="relative" data-dropdown>
					<button
						class="flex items-center gap-0.5 whitespace-nowrap text-sm text-muted/50 transition-colors hover:text-accent"
						onclick={() => (openDropdown = openDropdown === 'add-member' ? null : 'add-member')}
					>
						<Plus size={12} /> Add
					</button>
					{#if openDropdown === 'add-member'}
						<div
							class="absolute right-0 z-20 mt-1.5 w-[280px] rounded-md border border-surface-border/70 bg-surface shadow-lg shadow-black/20"
						>
							<div class="border-b border-surface-border px-3 py-2">
								<span class="text-xs font-medium tracking-[0.08em] text-muted/50 uppercase"
									>Add member</span
								>
							</div>
							<div class="max-h-64 overflow-y-auto py-1">
								{#each availableMembers as om (om.user_id)}
									<button
										class="flex w-full items-center gap-2.5 px-3 py-2 text-left transition-colors hover:bg-surface-hover"
										disabled={addingMember}
										onmousedown={(e) => {
											e.preventDefault();
											addMember(om.user_id, om.role!.id);
										}}
									>
										{#if om.user.avatar_url}
											<img
												src={om.user.avatar_url}
												alt={om.user.full_name}
												class="h-6 w-6 shrink-0 rounded-full object-cover"
											/>
										{:else}
											<span
												class="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-accent/20 text-2xs font-medium text-accent"
											>
												{om.user.full_name.charAt(0)}
											</span>
										{/if}
										<div class="min-w-0 flex-1">
											<div class="flex items-center gap-2">
												<span class="truncate text-base font-medium text-sidebar-text">{om.user.full_name}</span>
												<span class="shrink-0 rounded-sm bg-sidebar-icon/10 px-1.5 py-0.5 text-2xs font-medium text-sidebar-icon">{om.role!.name}</span>
											</div>
											<p class="truncate text-xs text-muted">{om.user.email}</p>
										</div>
									</button>
								{:else}
									<p class="px-3 py-3 text-base text-muted">No more users available.</p>
								{/each}
							</div>
						</div>
					{/if}
				</div>
				{/if}
			</div>

			{#if project.members && project.members.length > 0}
				<div class="flex flex-wrap gap-3">
					{#each project.members as member (member.user_id)}
						<div
							class="group flex items-center gap-2 rounded border border-surface-border/40 bg-surface/50 px-3 py-2"
						>
							{#if member.user.avatar_url}
								<img
									src={member.user.avatar_url}
									alt={member.user.full_name}
									class="h-6 w-6 rounded-full object-cover"
								/>
							{:else}
								<div
									class="flex h-6 w-6 items-center justify-center rounded-full bg-accent/20 text-xs font-medium text-accent"
								>
									{member.user.full_name.charAt(0)}
								</div>
							{/if}
							<div class="min-w-0">
								<p class="truncate text-base font-medium text-sidebar-text">
									{member.user.full_name}
								</p>
								{#if member.role}
									<p class="text-xs text-muted">{member.role.name}</p>
								{/if}
							</div>
							{#if canManageProject}
								<button
									class="ml-1 p-0.5 text-muted opacity-0 transition-opacity group-hover:opacity-100 hover:text-red-500"
									onclick={() => removeMember(member.user_id)}
									aria-label="Remove {member.user.full_name}"
								>
									<X size={13} />
								</button>
							{/if}
						</div>
					{/each}
				</div>
			{:else}
				<p class="text-base text-muted">No members yet.</p>
			{/if}
		</div>

		{:else if projectTab === 'attachments'}
		<!-- Attachments -->
		<div class="mx-3 mb-2 rounded border border-surface-border/40 bg-surface/50 px-3 py-2.5">
			<h2 class="mb-3 text-xs font-medium tracking-[0.08em] text-muted/50 uppercase">
				Attachments
				{#if projectAttachments.length > 0}
					<span class="ml-1 text-muted">({projectAttachments.length})</span>
				{/if}
			</h2>
			<AttachmentUploadZone
				onFilesSelected={handleProjectFileUpload}
				disabled={uploadingFiles}
			/>
			{#if uploadingFiles}
				<p class="mt-2 text-sm text-muted">Uploading...</p>
			{/if}
			{#if projectAttachments.length > 0}
				<div class="mt-3">
					<AttachmentList
						attachments={projectAttachments}
						canDelete={canUpdateProject}
						onRemove={handleRemoveProjectAttachment}
					/>
				</div>
			{/if}
		</div>

		{:else}
		<!-- Tasks section — fills remaining height -->
		<div class="flex flex-1 min-h-0 flex-col">
		<!-- Tasks header -->
		<div class="flex shrink-0 items-center justify-between px-3 py-1.5">
			<div class="flex items-center gap-2">
				<h2 class="text-xs font-medium tracking-[0.08em] text-muted/50 uppercase">
					Tasks
					{#if taskStore.count > 0}
						<span class="ml-1 text-muted">({taskStore.count})</span>
					{/if}
				</h2>

				<!-- View toggle -->
				<div class="flex items-center gap-0.5">
					<button
						class="flex h-7 items-center gap-1 rounded-sm px-2 text-sm font-medium transition-all duration-150 {taskViewMode === 'list' ? 'text-accent' : 'text-muted hover:text-sidebar-text'}"
						onclick={() => setTaskView('list')}
					>
						<LayoutList size={12} /> List
					</button>
					<button
						class="flex h-7 items-center gap-1 rounded-sm px-2 text-sm font-medium transition-all duration-150 {taskViewMode === 'board' ? 'text-accent' : 'text-muted hover:text-sidebar-text'}"
						onclick={() => setTaskView('board')}
					>
						<Columns3 size={12} /> Board
					</button>
				</div>

				<!-- Group-by (list only) -->
				{#if taskViewMode === 'list'}
					<div class="h-4 w-px bg-surface-border"></div>
				<div class="flex items-center gap-0.5">
						{#each TASK_GROUP_OPTIONS as g (g)}
							<button
								class="flex h-7 items-center rounded-sm px-2 text-sm font-medium transition-all duration-150 {taskGroupBy === g ? 'text-accent' : 'text-muted hover:text-sidebar-text'}"
								onclick={() => setTaskGroupBy(g)}
							>
								{formatTaskStatus(g)}
							</button>
						{/each}
					</div>
				{/if}

				<!-- Filter toggle -->
				<div class="relative shrink-0">
					<button
						class="flex h-7 w-7 items-center justify-center rounded-sm text-muted/40 transition-all duration-150 hover:bg-surface-hover/40 {taskFiltersVisible ? 'text-accent' : 'hover:text-sidebar-text'}"
						onclick={() => (taskFiltersVisible = !taskFiltersVisible)}
					>
						<ListFilter size={13} />
					</button>
					{#if taskFilterCount > 0}
						<span class="absolute -top-1.5 -right-1.5 flex h-3.5 min-w-3.5 items-center justify-center rounded-full bg-accent px-1 text-2xs font-semibold leading-none text-white">
							{taskFilterCount}
						</span>
					{/if}
				</div>
			</div>

			{#if canCreateTask}
				<button
					class="flex items-center gap-0.5 whitespace-nowrap text-sm text-muted/50 transition-colors hover:text-accent"
					onclick={() => (createModalOpen = true)}
				>
					<Plus size={12} /> Add
				</button>
			{/if}
		</div>

		<!-- Task filters -->
		{#if taskFiltersVisible}
			<div class="shrink-0 px-3 py-1.5">
				<div class="flex flex-wrap items-end gap-3">
					{#if !(taskViewMode === 'board')}
						<FilterDropdown
							label="Status"
							options={TASK_STATUSES.map((s) => ({ value: s, label: formatTaskStatus(s) }))}
							operator={taskStatusOp}
							selected={taskStatusSelected}
							onchange={(op, sel) => { taskStatusOp = op; taskStatusSelected = sel; applyTaskFilters(); }}
						/>
					{/if}
					<FilterDropdown
						label="Priority"
						options={TASK_PRIORITIES.map((p) => ({ value: p, label: formatPriority(p) }))}
						operator={taskPriorityOp}
						selected={taskPrioritySelected}
						onchange={(op, sel) => { taskPriorityOp = op; taskPrioritySelected = sel; applyTaskFilters(); }}
					/>
					<FilterDropdown
						label="Type"
						options={TASK_TYPES.map((t) => ({ value: t, label: formatTaskStatus(t) }))}
						operator={taskTypeOp}
						selected={taskTypeSelected}
						onchange={(op, sel) => { taskTypeOp = op; taskTypeSelected = sel; applyTaskFilters(); }}
					/>
					{#if taskFilterCount > 0}
						<button
							class="pb-0.5 text-sm text-sidebar-icon transition-colors hover:text-accent"
							onclick={clearTaskFilters}
						>
							Clear all
						</button>
					{/if}
				</div>
			</div>
		{/if}

		<!-- Task content -->
		{#if taskStore.loading}
			<p class="px-4 py-8 text-center text-sm text-muted">Loading tasks...</p>
		{:else if taskStore.error}
			<p class="px-4 py-8 text-center text-sm text-red-500">{taskStore.error}</p>
		{:else if taskViewMode === 'board'}
			<!-- Kanban -->
			<div class="flex gap-0 overflow-x-auto overflow-y-hidden" style="height: calc(100dvh - var(--board-top, 0px))" bind:this={boardEl}>
				{#each taskBoardColumns as col, colIndex (col.key)}
					<div class="flex w-64 min-w-[16rem] shrink-0 flex-col border-r border-surface-border/50 last:border-r-0 h-full bg-page-bg">
						<div class="flex items-center gap-2 px-3 py-2">
							<span class="text-sm font-medium text-muted truncate">{col.label}</span>
							<span class="ml-auto shrink-0 text-xs text-muted">{col.items.length}</span>
						</div>
						<div
							class="flex-1 overflow-y-auto p-1.5 min-h-[40px] scrollbar-none"
							style="-ms-overflow-style: none; scrollbar-width: none;"
							use:dndzone={{ items: col.items, flipDurationMs: 200, dropTargetStyle: { outline: '2px solid var(--color-accent)', outlineOffset: '-2px' } }}
							onconsider={(e) => handleTaskConsider(colIndex, e)}
							onfinalize={(e) => handleTaskFinalize(colIndex, col.key, e)}
						>
							{#each col.items as task (task.id)}
								{@const TypeIcon = typeIcons[task.type] ?? defaultTypeIcon}
								<button
									class="mb-1.5 w-full cursor-pointer rounded border border-surface-border/50 bg-surface/50 px-3 py-2.5 text-left transition-all duration-150 hover:bg-surface/80 last:mb-0 {selectedTaskId === task.id ? '!border-accent/50 !bg-accent/15' : ''}"
									onclick={() => selectTask(task.id)}
								>
									<div class="mb-1 flex items-center gap-1.5">
										<span class="text-muted"><TypeIcon size={11} /></span>
										<span class="font-mono text-xs text-muted/50">{task.short_id || '—'}</span>
									</div>
									<p class="mb-1.5 line-clamp-2 text-base leading-snug text-sidebar-text">{task.title}</p>
									<span class="text-xs {task.priority === 'urgent' ? 'text-red-400' : task.priority === 'high' ? 'text-orange-400' : task.priority === 'medium' ? 'text-yellow-500' : task.priority === 'low' ? 'text-blue-400' : 'text-muted/50'}">
										{formatPriority(task.priority)}
									</span>
								</button>
							{/each}
						</div>
					</div>
				{/each}
			</div>
		{:else if taskTree.length === 0}
			<p class="px-4 py-8 text-center text-sm text-muted">
				{taskFilterCount > 0 ? 'No tasks match your filters.' : 'No tasks in this project yet.'}
			</p>
		{:else if taskGroupBy === 'status'}
			<!-- Grouped by status list -->
			{@const groups = TASK_STATUSES.map((s) => ({ key: s, label: formatTaskStatus(s), tasks: taskTree.filter(({ task }) => task.status === s) })).filter((g) => g.tasks.length > 0)}
			<div class="space-y-1 p-3">
				{#each groups as group (group.key)}
					<button
						class="flex w-full items-center gap-1.5 px-1 py-1 text-left"
						onclick={() => {}}
					>
						<span class="text-sm font-medium text-muted">{group.label}</span>
						<span class="text-xs text-muted/30">{group.tasks.length}</span>
					</button>
					<div class="mb-2 overflow-hidden rounded border border-surface-border/50 bg-surface/50">
						{#each group.tasks as { task, depth }, i (task.id)}
							<TaskRow {task} {depth} selected={task.id === selectedTaskId} onclick={() => selectTask(task.id)} />
							{#if i < group.tasks.length - 1}
								<div class="mx-3 h-px bg-surface-border/30"></div>
							{/if}
						{/each}
					</div>
				{/each}
			</div>
		{:else}
			<!-- Flat list -->
			<div class="p-3">
				<div class="overflow-hidden rounded border border-surface-border/50 bg-surface/50">
					{#each taskTree as { task, depth }, i (task.id)}
						<TaskRow {task} {depth} selected={task.id === selectedTaskId} onclick={() => selectTask(task.id)} />
						{#if i < taskTree.length - 1}
							<div class="mx-3 h-px bg-surface-border/30"></div>
						{/if}
					{/each}
				</div>
			</div>
		{/if}
	</div>
{/if}
	</div>
	{/if}
</div>
</div>

{#if createModalOpen && project}
	<CreateTaskModal
		projectId={project.id}
		onClose={() => (createModalOpen = false)}
		onCreated={async (id) => { await taskStore.load(getTaskFilters()); if (taskViewMode === 'board') rebuildTaskBoard(); selectTask(id); }}
	/>
{/if}

{#if selectedTaskId}
	<TaskDetailPanel
		taskId={selectedTaskId}
		members={(project?.members ?? []).map((m) => ({
			user_id: m.user_id,
			user: { id: m.user.id, full_name: m.user.full_name, avatar_url: m.user.avatar_url, is_active: m.user.is_active, deleted_at: m.user.deleted_at }
		}))}
		onClose={() => selectTask(null)}
	/>
{/if}
</div>
