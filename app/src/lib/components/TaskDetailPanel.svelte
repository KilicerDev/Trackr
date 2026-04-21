<script lang="ts">
	import { X, Send, Trash2, Clock, Plus, Paperclip, MessageSquare, Info } from '@lucide/svelte';
	import { api } from '$lib/api';
	import { taskStore } from '$lib/stores/tasks.svelte';
	import type { Task } from '$lib/stores/tasks.svelte';
	import { auth } from '$lib/stores/auth.svelte';
	import ConfirmDialog from './ConfirmDialog.svelte';
	import { typeIcons, defaultTypeIcon } from '$lib/config/task-icons';
	import { taskStatusIcons, defaultStatusIcon } from '$lib/config/status-icons';
	import { priorityIcons, defaultPriorityIcon } from '$lib/config/priority-icons';
	import type { Attachment } from '$lib/api/attachments';
	import type { Tag } from '$lib/api/tags';
	import AttachmentUploadZone from './AttachmentUploadZone.svelte';
	import AttachmentGrid from './AttachmentGrid.svelte';
	import AttachmentCompact from './AttachmentCompact.svelte';

	const TASK_STATUSES = ['backlog', 'todo', 'in_progress', 'paused', 'in_review', 'done', 'cancelled'] as const;
	const TASK_PRIORITIES = ['urgent', 'high', 'medium', 'low', 'none'] as const;
	const TASK_TYPES = ['task', 'bug', 'feature', 'improvement', 'epic'] as const;

	type Member = {
		user_id: string;
		user: { id: string; full_name: string; avatar_url: string | null; is_active: boolean; deleted_at: string | null };
	};

	type Comment = {
		id: string;
		content: string;
		created_at: string;
		attachment_ids: string[];
		user: { id: string; full_name: string; username: string; avatar_url: string | null } | null;
	};

	type WorkLog = {
		id: string;
		minutes: number;
		description: string | null;
		logged_at: string;
		created_at: string;
		user_id: string;
		user: { id: string; full_name: string; avatar_url: string | null } | null;
	};

	interface Props {
		taskId: string;
		members?: Member[];
		initialTab?: 'details' | 'comments' | 'time';
		onClose: () => void;
		onUpdate?: () => void;
		onTabChange?: (tab: 'details' | 'comments' | 'time') => void;
	}

	let { taskId, members: membersProp = [], initialTab = 'details', onClose, onUpdate, onTabChange }: Props = $props();

	let fetchedMembers = $state<Member[]>([]);
	let members = $derived(membersProp.length > 0 ? membersProp : fetchedMembers);

	let task = $state<Task | null>(null);
	let comments = $state<Comment[]>([]);
	let loading = $state(true);
	let error = $state<string | null>(null);
	let openDropdown = $state<string | null>(null);

	let editingTitle = $state(false);
	let titleDraft = $state('');
	let savingTitle = $state(false);

	let editingDescription = $state(false);
	let descriptionDraft = $state('');
	let savingDescription = $state(false);

	let commentBody = $state('');
	let sendingComment = $state(false);

	let confirmDeleteOpen = $state(false);
	let deleting = $state(false);
	let activeTab = $state<'details' | 'comments' | 'time'>(initialTab);

	let taskAttachments = $state<Attachment[]>([]);
	let commentAttachmentIds = $state<Record<string, string[]>>({});
	let uploadingFiles = $state(false);
	let commentPendingFiles = $state<File[]>([]);

	let workLogs = $state<WorkLog[]>([]);
	let wlHours = $state('');
	let wlMinutes = $state('');
	let wlDescription = $state('');
	let wlDate = $state(new Date().toISOString().slice(0, 10));
	let addingWorkLog = $state(false);

	let parentTaskData = $state<{ id: string; title: string; short_id: string } | null>(null);
	let parentCandidates = $state<Task[]>([]);
	let loadingParents = $state(false);

	// Tags
	const TAG_COLORS = ['#10b981', '#3b82f6', '#8b5cf6', '#f59e0b', '#ef4444', '#ec4899', '#06b6d4', '#84cc16', '#f97316', '#6366f1'];
	let taskTags = $state<{ id: string; name: string; color: string }[]>([]);
	let projectTags = $state<Tag[]>([]);
	let tagDropdownOpen = $state(false);
	let tagSearch = $state('');
	let loadingProjectTags = $state(false);

	const currentTaskStatus = $derived(task ? (taskStatusIcons[task.status] ?? defaultStatusIcon) : defaultStatusIcon);
	const CurrentTaskStatusIcon = $derived(currentTaskStatus.icon);
	const currentTaskPriority = $derived(task ? (priorityIcons[task.priority] ?? defaultPriorityIcon) : defaultPriorityIcon);
	const CurrentTaskPriorityIcon = $derived(currentTaskPriority.icon);

	const filteredProjectTags = $derived(
		projectTags
			.filter((t) => !taskTags.some((tt) => tt.id === t.id))
			.filter((t) => !tagSearch || t.name.toLowerCase().includes(tagSearch.toLowerCase()))
	);

	const tagSearchExactMatch = $derived(
		projectTags.some((t) => t.name.toLowerCase() === tagSearch.trim().toLowerCase())
	);

	async function loadProjectTags() {
		if (!task) return;
		loadingProjectTags = true;
		try {
			projectTags = await api.tags.getByProject(task.project_id);
		} catch {
			projectTags = [];
		} finally {
			loadingProjectTags = false;
		}
	}

	function syncTagsToStore() {
		if (!task) return;
		const tagsPayload = taskTags.map((t) => ({ id: crypto.randomUUID(), tag: { id: t.id, name: t.name, color: t.color } }));
		const existing = taskStore.items.find((i) => i.id === task!.id) as Record<string, unknown> | undefined;
		if (existing) existing.tags = tagsPayload;
	}

	async function addTagToTask(tag: { id: string; name: string; color: string }) {
		if (!task) return;
		taskTags = [...taskTags, tag];
		tagSearch = '';
		syncTagsToStore();
		try {
			await api.tags.addToTask(task.id, tag.id);
		} catch {
			taskTags = taskTags.filter((t) => t.id !== tag.id);
			syncTagsToStore();
		}
	}

	async function removeTagFromTask(tagId: string) {
		if (!task) return;
		const prev = taskTags;
		taskTags = taskTags.filter((t) => t.id !== tagId);
		syncTagsToStore();
		try {
			await api.tags.removeFromTask(task.id, tagId);
		} catch {
			taskTags = prev;
			syncTagsToStore();
		}
	}

	async function createAndAddTag() {
		if (!task) return;
		const name = tagSearch.trim();
		if (!name) return;
		const color = TAG_COLORS[projectTags.length % TAG_COLORS.length];
		try {
			const tag = await api.tags.create({ project_id: task.project_id, name, color });
			projectTags = [...projectTags, tag];
			await addTagToTask({ id: tag.id, name: tag.name, color: tag.color });
		} catch {
			/* ignore - likely duplicate */
		}
	}

	async function loadParentCandidates() {
		if (parentCandidates.length > 0) return;
		if (!task) return;
		loadingParents = true;
		try {
			const { data } = await api.tasks.getAll({ project_id: task.project_id }, 1, 500);
			parentCandidates = data as Task[];
		} catch {
			parentCandidates = [];
		} finally {
			loadingParents = false;
		}
	}

	let totalMinutes = $derived(workLogs.reduce((sum, wl) => sum + Number(wl.minutes), 0));

	function formatMinutes(m: number): string {
		const h = Math.floor(m / 60);
		const rem = m % 60;
		if (h > 0 && rem > 0) return `${h}h ${rem}m`;
		if (h > 0) return `${h}h`;
		return `${rem}m`;
	}

	let commentsContainer: HTMLDivElement | undefined = $state();

	const statusColors: Record<string, string> = {
		backlog: 'bg-gray-100 text-gray-600 dark:bg-surface-hover dark:text-sidebar-text',
		todo: 'bg-gray-100 text-gray-700 dark:bg-surface-hover dark:text-sidebar-text',
		in_progress: 'bg-pink-100 text-pink-700 dark:bg-pink-950/60 dark:text-pink-300',
		in_review: 'bg-purple-100 text-purple-700 dark:bg-purple-950/60 dark:text-purple-300',
		done: 'bg-green-100 text-green-700 dark:bg-green-950/60 dark:text-green-300',
		cancelled: 'bg-gray-100 text-gray-400 dark:bg-surface-hover dark:text-muted'
	};

	$effect(() => {
		const id = taskId;
		loadTask(id);
	});

	$effect(() => {
		function handleKeydown(e: KeyboardEvent) {
			if (e.key === 'Escape') {
				if (document.querySelector('[data-attachment-preview]')) return;
				if (openDropdown) {
					openDropdown = null;
				} else {
					onClose();
				}
			}
		}
		document.addEventListener('keydown', handleKeydown);
		return () => document.removeEventListener('keydown', handleKeydown);
	});

	$effect(() => {
		if (!openDropdown && !tagDropdownOpen) return;
		function handleClick(e: MouseEvent) {
			const target = e.target as HTMLElement;
			if (!target.closest('[data-dropdown]')) {
				openDropdown = null;
				tagDropdownOpen = false;
				tagSearch = '';
			}
		}
		document.addEventListener('mousedown', handleClick);
		return () => document.removeEventListener('mousedown', handleClick);
	});

	async function loadTask(id: string) {
		loading = true;
		error = null;
		openDropdown = null;
		editingTitle = false;
		editingDescription = false;
		commentBody = '';
		parentCandidates = [];
		projectTags = [];
		try {
			const [t, c, wl] = await Promise.all([
				api.tasks.getById(id),
				api.tasks.getComments(id),
				api.tasks.getWorkLogs(id)
			]);
			task = t as Task;
			comments = c as Comment[];
			workLogs = wl as WorkLog[];
			titleDraft = task.title;
			descriptionDraft = (task.description as string) ?? '';
			// Extract tags from task data (loaded via TASK_SELECT join)
			const rawTags = (task as Record<string, unknown>).tags as { id: string; tag: { id: string; name: string; color: string } }[] | undefined;
			taskTags = rawTags?.map((tt) => tt.tag).filter(Boolean) ?? [];
			// Fetch project members if not provided via prop
			if (membersProp.length === 0 && task.project_id) {
				try {
					const proj = await api.projects.getById(task.project_id);
					fetchedMembers = (proj?.members ?? []).map((m: any) => ({
						user_id: m.user_id,
						user: { id: m.user.id, full_name: m.user.full_name, avatar_url: m.user.avatar_url, is_active: m.user.is_active, deleted_at: m.user.deleted_at }
					}));
				} catch {
					fetchedMembers = [];
				}
			}
			// Load parent task data if it has a parent
			const pid = task.parent_id as string | null | undefined;
			if (pid) {
				try {
					const p = await api.tasks.getById(pid);
					parentTaskData = p ? { id: p.id, title: p.title, short_id: p.short_id } : null;
				} catch {
					parentTaskData = null;
				}
			} else {
				parentTaskData = null;
			}
			// Restore comment → attachment mapping from persisted data
			const map: Record<string, string[]> = {};
			for (const cm of comments) {
				if (cm.attachment_ids && cm.attachment_ids.length > 0) {
					map[cm.id] = cm.attachment_ids;
				}
			}
			commentAttachmentIds = map;
			// Load attachments separately so failures don't block task loading
			try {
				taskAttachments = await api.attachments.list('task', id);
			} catch {
				taskAttachments = [];
			}
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to load task';
		} finally {
			loading = false;
			scrollCommentsToBottom();
		}
	}

	async function handleTaskFileUpload(files: File[]) {
		if (!task || !auth.user || uploadingFiles) return;
		uploadingFiles = true;
		try {
			// Resolve org_id from project (not included in TASK_SELECT project relation)
			const project = await api.projects.getById(task.project_id as string);
			const orgId = (project as Record<string, unknown>)?.organization_id as string;
			if (!orgId) return;
			for (const file of files) {
				const att = await api.attachments.upload(file, 'task', task.id, orgId, auth.user!.id);
				taskAttachments = [att, ...taskAttachments];
			}
		} catch {
			/* silent */
		} finally {
			uploadingFiles = false;
		}
	}

	async function handleRemoveAttachment(att: Attachment) {
		try {
			await api.attachments.remove(att.id, att.storage_path);
			taskAttachments = taskAttachments.filter((a) => a.id !== att.id);
		} catch {
			/* silent */
		}
	}

	function getCommentAttachments(commentId: string): Attachment[] {
		const ids = commentAttachmentIds[commentId];
		if (!ids || ids.length === 0) return [];
		return taskAttachments.filter((a) => ids.includes(a.id));
	}

	function scrollCommentsToBottom() {
		requestAnimationFrame(() => {
			if (commentsContainer) {
				commentsContainer.scrollTop = commentsContainer.scrollHeight;
			}
		});
	}

	async function updateField(field: string, value: unknown) {
		if (!task) return;
		const prev = { ...task };
		(task as Record<string, unknown>)[field] = value;
		openDropdown = null;

		try {
			const updated = await taskStore.update(task.id, { [field]: value });
			if (updated) task = updated;
			if (field === 'parent_id') await loadTask(task!.id);
			onUpdate?.();
		} catch {
			task = prev;
		}
	}

	async function saveTitle() {
		if (!task || savingTitle || !titleDraft.trim()) return;
		savingTitle = true;
		try {
			const updated = await taskStore.update(task.id, { title: titleDraft.trim() });
			if (updated) task = updated;
			editingTitle = false;
		} catch {
			/* keep editing */
		} finally {
			savingTitle = false;
		}
	}

	async function saveDescription() {
		if (!task || savingDescription) return;
		savingDescription = true;
		try {
			const updated = await taskStore.update(task.id, {
				description: descriptionDraft.trim() || null
			});
			if (updated) task = updated;
			editingDescription = false;
		} catch {
			/* keep editing */
		} finally {
			savingDescription = false;
		}
	}

	async function handleDateChange(field: 'start_at' | 'end_at', value: string) {
		await updateField(field, value ? `${value}T00:00:00.000Z` : null);
	}

	async function sendComment() {
		if (!task || !commentBody.trim() || sendingComment || !auth.user) return;
		sendingComment = true;
		try {
			const c = (await api.tasks.addComment(task.id, auth.user.id, commentBody.trim())) as Comment;
			comments = [...comments, c];
			// Upload pending files to the task, but remember which belong to this comment
			if (commentPendingFiles.length > 0) {
				const uploadedIds: string[] = [];
				try {
					const project = await api.projects.getById(task.project_id as string);
					const orgId = (project as Record<string, unknown>)?.organization_id as string;
					if (orgId) {
						for (const file of commentPendingFiles) {
							try {
								const att = await api.attachments.upload(file, 'task', task.id, orgId, auth.user!.id);
								taskAttachments = [att, ...taskAttachments];
								uploadedIds.push(att.id);
							} catch {
								/* silent */
							}
						}
					}
				} catch {
					/* silent */
				}
				if (uploadedIds.length > 0) {
					commentAttachmentIds = { ...commentAttachmentIds, [c.id]: uploadedIds };
					// Persist to DB
					api.tasks.updateCommentAttachments(c.id, uploadedIds).catch(() => {});
				}
			}
			commentBody = '';
			commentPendingFiles = [];
			scrollCommentsToBottom();
		} catch {
			/* keep text */
		} finally {
			sendingComment = false;
		}
	}

	async function addWorkLog() {
		if (!task || addingWorkLog || !auth.user) return;
		const h = parseInt(wlHours || '0', 10) || 0;
		const m = parseInt(wlMinutes || '0', 10) || 0;
		const totalMins = h * 60 + m;
		if (totalMins <= 0) return;
		addingWorkLog = true;
		try {
			const entry = (await api.tasks.addWorkLog(
				task.id,
				auth.user.id,
				totalMins,
				wlDescription.trim() || undefined,
				wlDate || undefined
			)) as WorkLog;
			workLogs = [entry, ...workLogs];
			wlHours = '';
			wlMinutes = '';
			wlDescription = '';
			wlDate = new Date().toISOString().slice(0, 10);
		} catch {
			/* keep form state */
		} finally {
			addingWorkLog = false;
		}
	}

	async function deleteWorkLog(id: string) {
		const prev = workLogs;
		workLogs = workLogs.filter((wl) => wl.id !== id);
		try {
			await api.tasks.deleteWorkLog(id);
		} catch {
			workLogs = prev;
		}
	}

	async function confirmDelete() {
		if (!task || deleting) return;
		deleting = true;
		try {
			await taskStore.remove(task.id);
			confirmDeleteOpen = false;
			onClose();
		} finally {
			deleting = false;
		}
	}

	function displayName(val: string): string {
		return val
			.split('_')
			.map((w) => w.charAt(0).toUpperCase() + w.slice(1))
			.join(' ');
	}

	function formatDate(dateStr: unknown): string {
		if (!dateStr || typeof dateStr !== 'string') return '—';
		const d = new Date(dateStr);
		if (isNaN(d.getTime())) return '—';
		return d.toLocaleDateString('de-DE', { day: '2-digit', month: '2-digit', year: 'numeric' });
	}

	function formatDateTime(dateStr: unknown): string {
		if (!dateStr || typeof dateStr !== 'string') return '—';
		const d = new Date(dateStr);
		if (isNaN(d.getTime())) return '—';
		return (
			d.toLocaleDateString('de-DE', { day: '2-digit', month: '2-digit', year: 'numeric' }) +
			' ' +
			d.toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' })
		);
	}

	function toInputDate(dateStr: unknown): string {
		if (!dateStr || typeof dateStr !== 'string') return '';
		const d = new Date(dateStr);
		if (isNaN(d.getTime())) return '';
		return d.toISOString().slice(0, 10);
	}

	const displayId = $derived(
		task?.short_id
			? task.short_id
			: task?.project?.identifier
				? `${task.project.identifier}-?`
				: '—'
	);

	const CurrentTypeIcon = $derived(typeIcons[task?.type ?? ''] ?? defaultTypeIcon);

	const parentTask = $derived(task?.parent_id ? parentTaskData : null);

	const descendantIds = $derived.by(() => {
		if (!task) return new Set<string>();
		const ids = new Set<string>();
		const source = parentCandidates.length > 0 ? parentCandidates : taskStore.items;
		function collect(parentId: string) {
			for (const t of source) {
				const pid = (t.parent_id as string | null) ?? null;
				if (pid === parentId && !ids.has(t.id)) {
					ids.add(t.id);
					collect(t.id);
				}
			}
		}
		collect(task.id);
		return ids;
	});

	const labelClass = 'text-xs font-medium uppercase tracking-[0.08em] text-muted/50';
	const propBtnClass =
		'flex w-full cursor-pointer items-center justify-between gap-2 rounded-sm bg-surface-hover/40 px-2.5 py-1.5 text-base text-sidebar-text transition-all duration-150 hover:bg-surface-hover/60';
	const dateInputClass =
		'date-clean w-full cursor-pointer rounded-sm bg-surface-hover/40 px-2.5 py-1.5 text-base text-sidebar-text outline-none transition-all duration-150 hover:bg-surface-hover/60';
	const dropdownPanelClass =
		'absolute left-0 z-30 mt-1.5 w-full rounded-md border border-surface-border bg-surface py-1 shadow-lg shadow-black/15 ring-1 ring-white/[0.07] animate-dropdown-in';
	const dropdownPanelScrollClass = `${dropdownPanelClass} max-h-48 overflow-y-auto`;
	const dropdownItemBase =
		'flex w-full items-center px-2.5 py-1.5 text-left text-sm transition-colors hover:bg-surface-hover/60';

	const chevronSvg = `<svg class="h-3.5 w-3.5 shrink-0 text-muted/40" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/></svg>`;
</script>

<div class="flex h-full w-[420px] shrink-0 flex-col border-l border-surface-border bg-surface">
		{#if loading}
			<div class="flex flex-1 items-center justify-center">
				<p class="text-sm text-muted">Loading...</p>
			</div>
		{:else if error || !task}
			<div class="flex flex-1 flex-col items-center justify-center gap-3">
				<p class="text-sm text-red-400">{error ?? 'Task not found'}</p>
				<button
					class="rounded-sm px-3 py-1.5 text-sm font-medium text-muted transition-colors hover:bg-surface-hover hover:text-sidebar-text"
					onclick={onClose}
				>
					Close
				</button>
			</div>
		{:else}
			<!-- Header -->
			<div class="shrink-0 px-4 pt-4 pb-0">
				<div class="flex items-start justify-between gap-3">
					<div class="flex items-center gap-2">
						<span class="flex items-center gap-1 rounded bg-accent/8 px-1.5 py-0.5 text-accent">
							<CurrentTypeIcon size={12} />
							<span class="font-mono text-xs font-semibold">{displayId}</span>
						</span>
						{#if task.project}
							<span class="text-xs text-muted/50">{task.project.name}</span>
						{/if}
					</div>
					<div class="flex shrink-0 items-center gap-0.5">
						<button
							class="flex h-6 w-6 items-center justify-center rounded-sm text-muted/40 transition-all duration-150 hover:bg-surface-hover hover:text-red-400"
							onclick={() => (confirmDeleteOpen = true)}
							aria-label="Delete task"
						>
							<Trash2 size={12} />
						</button>
						<button
							class="flex h-6 w-6 items-center justify-center rounded-sm text-muted/40 transition-all duration-150 hover:bg-surface-hover hover:text-sidebar-text"
							onclick={onClose}
							aria-label="Close"
						>
							<X size={12} />
						</button>
					</div>
				</div>
				{#if editingTitle}
					<div class="mt-2 flex items-center gap-2">
						<input
							type="text"
							bind:value={titleDraft}
							class="flex-1 rounded-sm bg-transparent text-lg font-semibold text-sidebar-text outline-none placeholder:text-muted/30"
							onkeydown={(e) => {
								if (e.key === 'Enter') saveTitle();
								if (e.key === 'Escape') editingTitle = false;
							}}
						/>
						<button
							class="rounded-sm bg-accent px-2 py-0.5 text-xs font-medium text-white transition-colors hover:bg-accent/90 disabled:opacity-50"
							disabled={savingTitle}
							onclick={saveTitle}
						>{savingTitle ? '...' : 'Save'}</button>
						<button
							class="text-xs text-muted hover:text-sidebar-text"
							onclick={() => (editingTitle = false)}
						>Cancel</button>
					</div>
				{:else}
					<button
						class="mt-1.5 mb-3 block cursor-pointer text-left text-lg font-semibold leading-snug text-sidebar-text transition-colors hover:text-accent"
						onclick={() => { titleDraft = task?.title ?? ''; editingTitle = true; }}
					>
						{task.title}
					</button>
				{/if}
			</div>

			<!-- Tab bar -->
			<div class="flex shrink-0 items-center gap-0.5 border-b border-surface-border px-4">
				<button
					class="flex items-center gap-1.5 border-b-2 px-2 py-1.5 text-sm font-medium transition-colors {activeTab === 'details' ? 'border-accent text-sidebar-text' : 'border-transparent text-muted hover:text-sidebar-text'}"
					onclick={() => { activeTab = 'details'; onTabChange?.('details'); }}
				>
					<Info size={12} />
					Details
				</button>
				<button
					class="flex items-center gap-1.5 border-b-2 px-2 py-1.5 text-sm font-medium transition-colors {activeTab === 'comments' ? 'border-accent text-sidebar-text' : 'border-transparent text-muted hover:text-sidebar-text'}"
					onclick={() => { activeTab = 'comments'; onTabChange?.('comments'); }}
				>
					<MessageSquare size={12} />
					Comments
					{#if comments.length > 0}
						<span class="text-2xs font-semibold text-accent">{comments.length}</span>
					{/if}
				</button>
				<button
					class="flex items-center gap-1.5 border-b-2 px-2 py-1.5 text-sm font-medium transition-colors {activeTab === 'time' ? 'border-accent text-sidebar-text' : 'border-transparent text-muted hover:text-sidebar-text'}"
					onclick={() => { activeTab = 'time'; onTabChange?.('time'); }}
				>
					<Clock size={12} />
					Time
					{#if totalMinutes > 0}
						<span class="font-mono text-2xs text-muted/40">{formatMinutes(totalMinutes)}</span>
					{/if}
				</button>
			</div>

			<!-- Scrollable content -->
			<div class="flex-1 overflow-y-auto pt-2">
			  {#if activeTab === 'details'}
				<!-- Properties -->
				<div class="mx-3 mt-2 mb-2 rounded border border-surface-border/40 bg-surface/40 px-3 py-2.5">
					<span class="{labelClass} mb-3 block">Properties</span>
					<div class="grid grid-cols-2 gap-x-3 gap-y-2.5">
						<!-- Status -->
						<div>
							<span class="mb-1 block text-xs text-muted/50">Status</span>
							<div class="relative" data-dropdown>
								<button class={propBtnClass} onclick={() => (openDropdown = openDropdown === 'status' ? null : 'status')}>
									<span class="flex items-center gap-1.5 truncate">
										<CurrentTaskStatusIcon size={15} class={currentTaskStatus.className} />
										<span class="truncate">{displayName(task.status)}</span>
									</span>
									{@html chevronSvg}
								</button>
								{#if openDropdown === 'status'}
									<div class={dropdownPanelClass}>{#each TASK_STATUSES as s (s)}{@const info = taskStatusIcons[s] ?? defaultStatusIcon}{@const StatusIcon = info.icon}<button class="{dropdownItemBase} {task.status === s ? 'font-medium text-accent' : 'text-sidebar-text'}" onmousedown={(e) => { e.preventDefault(); updateField('status', s); }}><span class="mr-1.5"><StatusIcon size={15} class={info.className} /></span>{displayName(s)}</button>{/each}</div>
								{/if}
							</div>
						</div>

						<!-- Priority -->
						<div>
							<span class="mb-1 block text-xs text-muted/50">Priority</span>
							<div class="relative" data-dropdown>
								<button class={propBtnClass} onclick={() => (openDropdown = openDropdown === 'priority' ? null : 'priority')}>
									<span class="flex items-center gap-1.5 truncate">
										<CurrentTaskPriorityIcon size={15} class={currentTaskPriority.className} />
										<span class="truncate">{displayName(task.priority)}</span>
									</span>
									{@html chevronSvg}
								</button>
								{#if openDropdown === 'priority'}
									<div class={dropdownPanelClass}>{#each TASK_PRIORITIES as p (p)}{@const info = priorityIcons[p] ?? defaultPriorityIcon}{@const PriorityIcon = info.icon}<button class="{dropdownItemBase} {task.priority === p ? 'font-medium text-accent' : 'text-sidebar-text'}" onmousedown={(e) => { e.preventDefault(); updateField('priority', p); }}><span class="mr-1.5"><PriorityIcon size={15} class={info.className} /></span>{displayName(p)}</button>{/each}</div>
								{/if}
							</div>
						</div>

						<!-- Type -->
						<div>
							<span class="mb-1 block text-xs text-muted/50">Type</span>
							<div class="relative" data-dropdown>
								<button class={propBtnClass} onclick={() => (openDropdown = openDropdown === 'type' ? null : 'type')}>
									<span class="flex items-center gap-1.5 truncate">
										<CurrentTypeIcon size={13} />
										<span class="truncate">{displayName(task.type)}</span>
									</span>
									{@html chevronSvg}
								</button>
								{#if openDropdown === 'type'}
									<div class={dropdownPanelClass}>{#each TASK_TYPES as t (t)}{@const TypeIcon = typeIcons[t] ?? defaultTypeIcon}<button class="{dropdownItemBase} {task.type === t ? 'font-medium text-accent' : 'text-sidebar-text'}" onmousedown={(e) => { e.preventDefault(); updateField('type', t); }}><span class="mr-1.5"><TypeIcon size={12} /></span>{displayName(t)}</button>{/each}</div>
								{/if}
							</div>
						</div>

						<!-- Parent -->
						<div>
							<span class="mb-1 block text-xs text-muted/50">Parent</span>
							<div class="relative" data-dropdown>
								{#if parentTask}
									<div class="group flex w-full items-center justify-between gap-1.5 rounded-sm bg-surface-hover/40 px-2.5 py-1.5">
										<button class="flex min-w-0 flex-1 items-center gap-1.5 text-base transition-colors hover:text-accent" onclick={() => { const next = openDropdown === 'parent' ? null : 'parent'; openDropdown = next; if (next) loadParentCandidates(); }}>
											<span class="shrink-0 font-mono text-xs text-accent">{parentTask.short_id}</span>
											<span class="truncate text-sidebar-text">{parentTask.title}</span>
										</button>
										<button class="shrink-0 text-muted/20 opacity-0 transition-opacity group-hover:opacity-100 hover:text-red-400" onclick={() => updateField('parent_id', null)} aria-label="Remove parent"><X size={10} /></button>
									</div>
								{:else}
									<button class={propBtnClass} onclick={() => { const next = openDropdown === 'parent' ? null : 'parent'; openDropdown = next; if (next) loadParentCandidates(); }}>
										<span class="truncate text-muted/30">None</span>
										{@html chevronSvg}
									</button>
								{/if}
								{#if openDropdown === 'parent'}
									<div class={dropdownPanelScrollClass}>
										{#if loadingParents}<p class="px-3 py-2 text-sm text-muted">Loading...</p>{/if}
										{#each parentCandidates.filter((t) => t.id !== task?.id && !descendantIds.has(t.id)) as t (t.id)}
											<button class="{dropdownItemBase} text-sidebar-text" onmousedown={(e) => { e.preventDefault(); updateField('parent_id', t.id); }}>
												<span class="mr-2 shrink-0 font-mono text-xs text-accent">{t.short_id}</span>
												<span class="truncate">{t.title}</span>
											</button>
										{:else}<p class="px-3 py-2 text-sm text-muted">No tasks</p>{/each}
									</div>
								{/if}
							</div>
						</div>

						<!-- Start date -->
						<div>
							<span class="mb-1 block text-xs text-muted/50">Start date</span>
							{#key task.start_at}
								<input
									type="date"
									value={toInputDate(task.start_at)}
									class={dateInputClass}
									onchange={(e) => handleDateChange('start_at', (e.target as HTMLInputElement).value)}
								/>
							{/key}
						</div>

						<!-- End date -->
						<div>
							<span class="mb-1 block text-xs text-muted/50">End date</span>
							{#key task.end_at}
								<input
									type="date"
									value={toInputDate(task.end_at)}
									class={dateInputClass}
									onchange={(e) => handleDateChange('end_at', (e.target as HTMLInputElement).value)}
								/>
							{/key}
						</div>
					</div>
				</div>

				<!-- Tags -->
				<div class="mx-3 mb-2 rounded border border-surface-border/40 bg-surface/40 px-3 py-2.5">
					<div class="mb-2 flex items-center justify-between">
						<span class={labelClass}>Tags</span>
						<button
							class="text-sm text-sidebar-icon transition-colors hover:text-accent"
							onclick={() => {
								tagDropdownOpen = !tagDropdownOpen;
								tagSearch = '';
								if (tagDropdownOpen) loadProjectTags();
							}}
						>
							+ Add
						</button>
					</div>
					{#if taskTags.length > 0}
						<div class="mb-2 flex flex-wrap gap-1.5">
							{#each taskTags as tag (tag.id)}
								<span
									class="group inline-flex items-center gap-1 rounded-sm px-2 py-0.5 text-sm font-medium"
									style="background-color: {tag.color}15; color: {tag.color}; border: 1px solid {tag.color}30"
								>
									{tag.name}
									<button
										class="opacity-0 transition-opacity group-hover:opacity-100 hover:brightness-75"
										onclick={() => removeTagFromTask(tag.id)}
										aria-label="Remove tag {tag.name}"
									>
										<X size={10} />
									</button>
								</span>
							{/each}
						</div>
					{:else if !tagDropdownOpen}
						<p class="text-base text-muted">No tags</p>
					{/if}
					{#if tagDropdownOpen}
						<div class="relative" data-dropdown>
							<input
								type="text"
								bind:value={tagSearch}
								placeholder="Search or create tag..."
								class="w-full border border-surface-border bg-surface px-3 py-1.5 text-base text-sidebar-text outline-none transition-colors placeholder:text-muted focus:border-accent/40"
								onkeydown={(e) => {
									if (e.key === 'Escape') { tagDropdownOpen = false; tagSearch = ''; }
									if (e.key === 'Enter' && tagSearch.trim() && !tagSearchExactMatch) { createAndAddTag(); }
								}}
							/>
							<div class="absolute left-0 right-0 z-20 mt-1 max-h-40 overflow-y-auto rounded-md border border-surface-border bg-surface py-1 shadow-lg shadow-black/15 ring-1 ring-white/[0.07] animate-dropdown-in">
								{#if loadingProjectTags}
									<p class="px-3 py-2 text-base text-muted">Loading...</p>
								{/if}
								{#each filteredProjectTags as tag (tag.id)}
									<button
										class="flex w-full items-center gap-2 px-3 py-1.5 text-left text-base text-sidebar-text transition-colors hover:bg-surface-hover"
										onmousedown={(e) => {
											e.preventDefault();
											addTagToTask({ id: tag.id, name: tag.name, color: tag.color });
										}}
									>
										<span class="h-2.5 w-2.5 shrink-0 rounded-full" style="background-color: {tag.color}"></span>
										{tag.name}
									</button>
								{:else}
									{#if !loadingProjectTags && !tagSearch.trim()}
										<p class="px-3 py-2 text-base text-muted">No tags yet</p>
									{/if}
								{/each}
								{#if tagSearch.trim() && !tagSearchExactMatch}
									<button
										class="flex w-full items-center gap-2 border-t border-surface-border px-3 py-1.5 text-left text-base text-accent transition-colors hover:bg-surface-hover"
										onmousedown={(e) => {
											e.preventDefault();
											createAndAddTag();
										}}
									>
										<Plus size={12} />
										Create "{tagSearch.trim()}"
									</button>
								{/if}
							</div>
						</div>
					{/if}
				</div>

				<!-- Assignees -->
				<div class="mx-3 mb-2 rounded border border-surface-border/40 bg-surface/40 px-3 py-2.5">
					<div class="mb-2 flex items-center justify-between">
						<span class={labelClass}>Assignees</span>
						{#if members.length > 0}
							<div class="relative" data-dropdown>
								<button
									class="text-sm text-sidebar-icon transition-colors hover:text-accent"
									onclick={() => (openDropdown = openDropdown === 'assign' ? null : 'assign')}
								>
									+ Add
								</button>
								{#if openDropdown === 'assign'}
									<div
										class="absolute right-0 z-20 mt-1 max-h-48 w-[200px] overflow-y-auto rounded-md border border-surface-border bg-surface py-1 shadow-lg shadow-black/15 ring-1 ring-white/[0.07] animate-dropdown-in"
									>
										{#each members.filter((m) => m.user.is_active && !m.user.deleted_at && !task?.assignments?.some((a) => a.user_id === m.user_id)) as m (m.user_id)}
											<button
												class="flex w-full items-center gap-2 px-3 py-2 text-left text-base text-sidebar-text transition-colors hover:bg-surface-hover"
												onmousedown={async (e) => {
													e.preventDefault();
													openDropdown = null;
													if (!task || !auth.user) return;
													try {
														await api.tasks.assign(task.id, m.user_id, auth.user.id);
														// Optimistic local update — avoid full reload flash
														task = {
															...task,
															assignments: [
																...(task.assignments ?? []),
																{ user_id: m.user_id, role: 'assignee', user: { ...m.user } }
															]
														} as Task;
														onUpdate?.();
													} catch {
														/* */
													}
												}}
											>
												{#if m.user.avatar_url}
													<img src={m.user.avatar_url} alt={m.user.full_name} class="h-5 w-5 rounded-full object-cover" />
												{:else}
													<span class="flex h-5 w-5 items-center justify-center rounded-full bg-accent/20 text-2xs font-medium text-accent">
														{m.user.full_name.charAt(0)}
													</span>
												{/if}
												{m.user.full_name}
											</button>
										{:else}
											<p class="px-3 py-2 text-base text-muted">All members assigned</p>
										{/each}
									</div>
								{/if}
							</div>
						{/if}
					</div>
					{#if task.assignments && task.assignments.length > 0}
						<div class="space-y-1.5">
							{#each task.assignments as a (a.user_id)}
								<div class="group flex items-center justify-between gap-2">
									<div class="flex items-center gap-2">
										{#if a.user.avatar_url}
											<img src={a.user.avatar_url} alt={a.user.full_name} class="h-5 w-5 rounded-full object-cover" />
										{:else}
											<span class="flex h-5 w-5 items-center justify-center rounded-full bg-accent/20 text-2xs font-medium text-accent">
												{a.user.full_name.charAt(0)}
											</span>
										{/if}
										<span class="text-base text-sidebar-text">{a.user.full_name}</span>
									</div>
									<button
										class="p-0.5 text-muted opacity-0 transition-opacity group-hover:opacity-100 hover:text-red-500"
										onclick={async () => {
											if (!task) return;
											const userId = a.user_id;
											try {
												await api.tasks.unassign(task.id, userId);
												// Optimistic local update — avoid full reload flash
												task = {
													...task,
													assignments: (task.assignments ?? []).filter((x) => x.user_id !== userId)
												} as Task;
												onUpdate?.();
											} catch {
												/* */
											}
										}}
										aria-label="Remove {a.user.full_name}"
									>
										<X size={12} />
									</button>
								</div>
							{/each}
						</div>
					{:else}
						<p class="text-base text-muted">No assignees</p>
					{/if}
				</div>

				<!-- Description -->
				<div class="mx-3 mb-2 rounded border border-surface-border/40 bg-surface/40 px-3 py-2.5">
					<div class="mb-2 flex items-center justify-between">
						<span class={labelClass}>Description</span>
						{#if !editingDescription}
							<button
								class="text-sm text-sidebar-icon transition-colors hover:text-accent"
								onclick={() => {
									descriptionDraft = (task?.description as string) ?? '';
									editingDescription = true;
								}}>Edit</button
							>
						{/if}
					</div>
					{#if editingDescription}
						<textarea
							bind:value={descriptionDraft}
							rows="4"
							class="w-full resize-none rounded-sm bg-surface-hover/40 px-2.5 py-1.5 text-base text-sidebar-text outline-none transition-all duration-150 placeholder:text-muted/30 focus:bg-surface-hover/60"
							placeholder="Add a description..."
						></textarea>
						<div class="mt-2 flex justify-end gap-2">
							<button
								class="flex h-7 items-center rounded-sm px-2.5 text-sm font-medium text-muted transition-all duration-150 hover:text-sidebar-text"
								onclick={() => (editingDescription = false)}>Cancel</button
							>
							<button
								class="flex h-7 items-center rounded-sm bg-accent px-2.5 text-sm font-medium text-white transition-all duration-150 hover:bg-accent/90 disabled:opacity-30"
								disabled={savingDescription}
								onclick={saveDescription}>{savingDescription ? 'Saving...' : 'Save'}</button
							>
						</div>
					{:else}
						<p class="whitespace-pre-wrap text-base text-sidebar-text">
							{(task.description as string) || 'No description'}
						</p>
					{/if}
				</div>

				<!-- Attachments -->
				<div class="mx-3 mb-2 rounded border border-surface-border/40 bg-surface/40 px-3 py-2.5">
					<span class="{labelClass} mb-2 block">Attachments ({taskAttachments.length})</span>
					<div class="flex flex-wrap gap-2">
						{#if taskAttachments.length > 0}
							<AttachmentGrid
								attachments={taskAttachments}
								canDelete={true}
								onRemove={handleRemoveAttachment}
							/>
						{/if}
						<AttachmentUploadZone
							onFilesSelected={handleTaskFileUpload}
							disabled={uploadingFiles}
						/>
					</div>
					{#if uploadingFiles}
						<p class="mt-1.5 text-xs text-muted/40">Uploading...</p>
					{/if}
				</div>

				<!-- Info -->
				<div class="mx-3 mb-2 rounded border border-surface-border/40 bg-surface/40 px-3 py-2.5">
					<span class="{labelClass} mb-2 block">Details</span>
					<div class="grid grid-cols-2 gap-x-3 gap-y-2 text-sm">
						<div>
							<span class="text-muted/60">Created by</span>
							<p class="mt-0.5 text-sidebar-text">
								{#if task.created_by_user}
									{task.created_by_user.full_name}
								{:else}
									—
								{/if}
							</p>
						</div>
						<div>
							<span class="text-muted/60">Project</span>
							<p class="mt-0.5 text-sidebar-text">{task.project?.name ?? '—'}</p>
						</div>
						<div>
							<span class="text-muted/60">Created</span>
							<p class="mt-0.5 font-mono text-sidebar-text">{formatDateTime(task.created_at)}</p>
						</div>
						<div>
							<span class="text-muted/60">Updated</span>
							<p class="mt-0.5 font-mono text-sidebar-text">{formatDateTime(task.updated_at)}</p>
						</div>
					</div>
				</div>

			  {:else if activeTab === 'comments'}
				<!-- Comments tab -->
				<!-- Compose at top -->
				<div class="mx-3 mt-2 mb-2 rounded border border-surface-border/40 bg-surface/40 px-3 py-2.5">
					{#if commentPendingFiles.length > 0}
						<div class="mb-2 flex flex-wrap gap-1">
							{#each commentPendingFiles as file, i (file.name + i)}
								<span class="flex items-center gap-1 rounded bg-surface-hover px-1.5 py-0.5 text-2xs text-sidebar-text">
									<Paperclip size={9} />
									<span class="max-w-[80px] truncate">{file.name}</span>
									<button class="text-muted hover:text-red-400" onclick={() => { commentPendingFiles = commentPendingFiles.filter((_, idx) => idx !== i); }}>
										<X size={9} />
									</button>
								</span>
							{/each}
						</div>
					{/if}
					<div class="flex gap-1.5">
						<textarea
							bind:value={commentBody}
							rows="2"
							class="flex-1 resize-none rounded-sm bg-surface-hover/40 px-3 py-2 text-base text-sidebar-text outline-none transition-all duration-150 placeholder:text-muted/30 focus:bg-surface-hover/60"
							placeholder="Write a comment..."
							onkeydown={(e) => {
								if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) {
									e.preventDefault();
									sendComment();
								}
							}}
						></textarea>
						<div class="flex shrink-0 flex-col gap-1">
							<AttachmentUploadZone
								compact
								onFilesSelected={(files) => { commentPendingFiles = [...commentPendingFiles, ...files]; }}
							/>
							<button
								class="flex flex-1 items-center justify-center rounded-sm bg-accent px-2.5 text-white transition-colors hover:bg-accent/90 disabled:opacity-30"
								disabled={!commentBody.trim() || sendingComment}
								onclick={sendComment}
								aria-label="Send comment"
							>
								<Send size={12} />
							</button>
						</div>
					</div>
				</div>

				<!-- Comment list (newest first) -->
				<div
					bind:this={commentsContainer}
					class="space-y-0 divide-y divide-surface-border/30"
				>
					{#if comments.length === 0}
						<p class="py-12 text-center text-sm text-muted/40">No comments yet</p>
					{/if}
					{#each [...comments].reverse() as c (c.id)}
						<div class="px-4 py-3">
							<div class="mb-1 flex items-center gap-2">
								<span class="text-sm font-medium text-sidebar-text">
									{c.user?.full_name ?? 'Unknown'}
								</span>
								<span class="font-mono text-2xs text-muted/30">{formatDate(c.created_at)}</span>
							</div>
							<p class="whitespace-pre-wrap text-base leading-relaxed text-sidebar-text/70">{c.content}</p>
							{#if getCommentAttachments(c.id).length > 0}
								<div class="mt-1.5">
									<AttachmentCompact attachments={getCommentAttachments(c.id)} />
								</div>
							{/if}
						</div>
					{/each}
				</div>

			  {:else}
				<!-- Time tab -->
				<!-- Log form at top -->
				<div class="mx-3 mt-2 mb-2 rounded border border-surface-border/40 bg-surface/40 px-3 py-2.5">
					<div class="space-y-2">
						<div class="flex items-center gap-2">
							<div class="flex items-center gap-1 rounded-sm bg-surface-hover/40 px-2 py-1">
								<input
									type="text"
									inputmode="numeric"
									bind:value={wlHours}
									placeholder="0"
									class="w-6 bg-transparent text-center text-base text-sidebar-text outline-none placeholder:text-muted/30"
								/>
								<span class="text-xs text-muted/40">h</span>
							</div>
							<div class="flex items-center gap-1 rounded-sm bg-surface-hover/40 px-2 py-1">
								<input
									type="text"
									inputmode="numeric"
									bind:value={wlMinutes}
									placeholder="0"
									class="w-6 bg-transparent text-center text-base text-sidebar-text outline-none placeholder:text-muted/30"
								/>
								<span class="text-xs text-muted/40">m</span>
							</div>
							<input
								type="date"
								bind:value={wlDate}
								class="ml-auto rounded-sm bg-surface-hover/40 px-2 py-1 text-sm text-muted outline-none"
							/>
						</div>
						<textarea
							bind:value={wlDescription}
							rows="2"
							placeholder="What did you work on..."
							class="w-full resize-none rounded-sm bg-surface-hover/40 px-2.5 py-1.5 text-base text-sidebar-text outline-none placeholder:text-muted/30 focus:bg-surface-hover/60"
						></textarea>
						<button
							class="flex h-7 w-full items-center justify-center rounded-sm bg-accent text-sm font-medium text-white transition-colors hover:bg-accent/90 disabled:opacity-30"
							disabled={addingWorkLog || (!wlHours && !wlMinutes)}
							onclick={addWorkLog}
						>
							Log time
						</button>
					</div>
				</div>

				<!-- Log entries (newest first) -->
				<div class="divide-y divide-surface-border/30">
					{#if workLogs.length === 0}
						<p class="py-12 text-center text-sm text-muted/40">No time logged yet</p>
					{/if}
					{#each workLogs as wl (wl.id)}
						<div class="group flex items-start gap-3 px-4 py-2.5">
							<span class="mt-0.5 font-mono text-base font-semibold text-accent">{formatMinutes(Number(wl.minutes))}</span>
							<div class="min-w-0 flex-1">
								{#if wl.description}
									<p class="text-base text-sidebar-text/70">{wl.description}</p>
								{/if}
								<div class="mt-0.5 flex items-center gap-2">
									<span class="text-xs text-muted/40">{wl.user?.full_name ?? 'Unknown'}</span>
									<span class="font-mono text-2xs text-muted/30">{formatDate(wl.logged_at)}</span>
								</div>
							</div>
							{#if auth.user && wl.user_id === auth.user.id}
								<button
									class="mt-0.5 shrink-0 text-muted/20 opacity-0 transition-opacity group-hover:opacity-100 hover:text-red-400"
									onclick={() => deleteWorkLog(wl.id)}
									aria-label="Delete"
								>
									<Trash2 size={11} />
								</button>
							{/if}
						</div>
					{/each}
				</div>
			  {/if}
			</div>
		{/if}
</div>

<ConfirmDialog
	open={confirmDeleteOpen}
	title="Delete Task"
	message="Are you sure you want to delete this task? This action cannot be undone."
	confirmLabel="Delete"
	loading={deleting}
	destructive={true}
	onConfirm={confirmDelete}
	onCancel={() => (confirmDeleteOpen = false)}
/>

<style>
	:global(.date-clean::-webkit-calendar-picker-indicator) {
		opacity: 0;
		width: 20px;
		cursor: pointer;
	}
	:global(.date-clean) {
		cursor: pointer;
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
