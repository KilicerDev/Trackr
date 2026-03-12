<script lang="ts">
	import { X, Send, Trash2, Clock, Plus } from '@lucide/svelte';
	import { api } from '$lib/api';
	import { taskStore } from '$lib/stores/tasks.svelte';
	import type { Task } from '$lib/stores/tasks.svelte';
	import { auth } from '$lib/stores/auth.svelte';
	import ConfirmDialog from './ConfirmDialog.svelte';
	import { typeIcons, defaultTypeIcon } from '$lib/config/task-icons';

	const TASK_STATUSES = ['backlog', 'todo', 'in_progress', 'in_review', 'done', 'cancelled'] as const;
	const TASK_PRIORITIES = ['urgent', 'high', 'medium', 'low', 'none'] as const;
	const TASK_TYPES = ['task', 'bug', 'feature', 'improvement', 'epic'] as const;

	type Member = {
		user_id: string;
		user: { id: string; full_name: string; avatar_url: string | null };
	};

	type Comment = {
		id: string;
		content: string;
		created_at: string;
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
		onClose: () => void;
	}

	let { taskId, members = [], onClose }: Props = $props();

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

	let workLogs = $state<WorkLog[]>([]);
	let wlHours = $state('');
	let wlMinutes = $state('');
	let wlDescription = $state('');
	let wlDate = $state(new Date().toISOString().slice(0, 10));
	let addingWorkLog = $state(false);

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

	async function loadTask(id: string) {
		loading = true;
		error = null;
		openDropdown = null;
		editingTitle = false;
		editingDescription = false;
		commentBody = '';
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
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to load task';
		} finally {
			loading = false;
			scrollCommentsToBottom();
		}
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
			commentBody = '';
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

	const labelClass = 'text-[11px] font-medium uppercase tracking-wider text-sidebar-icon';
	const propBtnClass =
		'flex w-full cursor-pointer items-center justify-between gap-2 border border-surface-border bg-surface px-3 py-1.5 text-xs text-sidebar-text transition-colors hover:border-sidebar-icon/30 hover:bg-surface-hover';
	const dropdownPanelClass =
		'absolute left-0 z-30 mt-1 max-h-48 w-full overflow-y-auto border border-surface-border bg-surface py-1 shadow-xl';
	const dropdownItemBase =
		'flex w-full items-center px-4 py-2 text-left text-xs transition-colors hover:bg-surface-hover';

	const chevronSvg = `<svg class="h-3.5 w-3.5 shrink-0 text-sidebar-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/></svg>`;
</script>

<div class="fixed inset-0 z-[60]" role="presentation">
	<button
		class="absolute inset-0 bg-black/30 transition-opacity"
		onclick={onClose}
		tabindex="-1"
		aria-label="Close panel"
	></button>

	<div
		class="absolute top-0 right-0 bottom-0 flex w-[480px] flex-col border-l border-surface-border bg-surface shadow-xl"
		role="dialog"
		aria-modal="true"
	>
		{#if loading}
			<div class="flex flex-1 items-center justify-center">
				<p class="text-sm text-muted">Loading...</p>
			</div>
		{:else if error || !task}
			<div class="flex flex-1 flex-col items-center justify-center gap-3">
				<p class="text-sm text-red-500">{error ?? 'Task not found'}</p>
				<button
					class="border border-surface-border bg-surface px-4 py-2 text-xs font-medium text-sidebar-text transition-colors hover:bg-surface-hover"
					onclick={onClose}
				>
					Close
				</button>
			</div>
		{:else}
			<!-- Header -->
			<div class="flex shrink-0 items-center justify-between border-b border-surface-border px-4 py-3">
				<div class="min-w-0 flex-1">
					<div class="flex items-center gap-2">
					<CurrentTypeIcon size={16} />
					<span class="text-xs font-medium text-accent">{displayId}</span>
				</div>
					{#if editingTitle}
						<div class="mt-1 flex items-center gap-2">
							<input
								type="text"
								bind:value={titleDraft}
								class="flex-1 border border-surface-border bg-surface px-2 py-1 text-sm font-semibold text-sidebar-text outline-none focus:border-sidebar-icon/30"
								onkeydown={(e) => {
									if (e.key === 'Enter') saveTitle();
									if (e.key === 'Escape') editingTitle = false;
								}}
							/>
							<button
								class="bg-accent px-2.5 py-1 text-[11px] font-medium text-white transition-colors hover:bg-accent/90 disabled:opacity-50"
								disabled={savingTitle}
								onclick={saveTitle}
							>
								{savingTitle ? '...' : 'Save'}
							</button>
							<button
								class="border border-surface-border bg-surface px-2.5 py-1 text-[11px] text-sidebar-text transition-colors hover:bg-surface-hover"
								onclick={() => (editingTitle = false)}
							>
								Cancel
							</button>
						</div>
					{:else}
						<button
							class="mt-0.5 cursor-pointer text-left text-sm font-semibold text-sidebar-text transition-colors hover:text-accent"
							onclick={() => {
								titleDraft = task?.title ?? '';
								editingTitle = true;
							}}
						>
							{task.title}
						</button>
					{/if}
				</div>
				<div class="ml-3 flex shrink-0 items-center gap-1">
					<button
						class="p-1 text-sidebar-icon transition-colors hover:text-red-500"
						onclick={() => (confirmDeleteOpen = true)}
						aria-label="Delete task"
					>
						<Trash2 size={16} />
					</button>
					<button
						class="p-1 text-sidebar-icon transition-colors hover:text-sidebar-text"
						onclick={onClose}
						aria-label="Close"
					>
						<X size={18} />
					</button>
				</div>
			</div>

			<!-- Scrollable content -->
			<div class="flex-1 overflow-y-auto">
				<!-- Properties -->
				<div class="border-b border-surface-border px-4 py-4">
					<span class="{labelClass} mb-3 block">Properties</span>
					<div class="grid grid-cols-2 gap-x-3 gap-y-2.5">
						<!-- Status -->
						<div>
							<span class="mb-1 block text-[10px] text-muted">Status</span>
							<div class="relative" data-dropdown>
								<button
									class={propBtnClass}
									onclick={() => (openDropdown = openDropdown === 'status' ? null : 'status')}
								>
									<span class="flex items-center gap-1.5 truncate">
										<span
											class="inline-block h-2 w-2 rounded-full {statusColors[task.status]?.split(' ')[0] ?? 'bg-gray-100'}"
										></span>
										{displayName(task.status)}
									</span>
								{@html chevronSvg}
							</button>
							{#if openDropdown === 'status'}
								<div class={dropdownPanelClass}>
									{#each TASK_STATUSES as s (s)}
											<button
												class="{dropdownItemBase} {task.status === s ? 'font-medium text-accent' : 'text-sidebar-text'}"
												onmousedown={(e) => {
													e.preventDefault();
													updateField('status', s);
												}}>{displayName(s)}</button
											>
										{/each}
									</div>
								{/if}
							</div>
						</div>

						<!-- Priority -->
						<div>
							<span class="mb-1 block text-[10px] text-muted">Priority</span>
							<div class="relative" data-dropdown>
								<button
									class={propBtnClass}
									onclick={() => (openDropdown = openDropdown === 'priority' ? null : 'priority')}
								>
									<span class="truncate">{displayName(task.priority)}</span>
								{@html chevronSvg}
							</button>
							{#if openDropdown === 'priority'}
								<div class={dropdownPanelClass}>
									{#each TASK_PRIORITIES as p (p)}
											<button
												class="{dropdownItemBase} {task.priority === p ? 'font-medium text-accent' : 'text-sidebar-text'}"
												onmousedown={(e) => {
													e.preventDefault();
													updateField('priority', p);
												}}>{displayName(p)}</button
											>
										{/each}
									</div>
								{/if}
							</div>
						</div>

						<!-- Type -->
						<div>
							<span class="mb-1 block text-[10px] text-muted">Type</span>
							<div class="relative" data-dropdown>
								<button
									class={propBtnClass}
									onclick={() => (openDropdown = openDropdown === 'type' ? null : 'type')}
								>
								<span class="flex items-center gap-1.5 truncate">
									<CurrentTypeIcon size={14} />
									{displayName(task.type)}
								</span>
								{@html chevronSvg}
							</button>
							{#if openDropdown === 'type'}
								<div class={dropdownPanelClass}>
								{#each TASK_TYPES as t (t)}
									{@const TypeIcon = typeIcons[t] ?? defaultTypeIcon}
										<button
											class="{dropdownItemBase} {task.type === t ? 'font-medium text-accent' : 'text-sidebar-text'}"
											onmousedown={(e) => {
												e.preventDefault();
												updateField('type', t);
											}}
										>
									<span class="mr-2"><TypeIcon size={14} /></span>
										{displayName(t)}
										</button>
									{/each}
									</div>
								{/if}
							</div>
						</div>

						<!-- Dates -->
						<div>
							<span class="mb-1 block text-[10px] text-muted">Start Date</span>
							<input
								type="date"
								value={toInputDate(task.start_at)}
								class="w-full border border-surface-border bg-surface px-3 py-1.5 text-xs text-sidebar-text outline-none transition-colors hover:border-sidebar-icon/30"
								onchange={(e) => handleDateChange('start_at', (e.target as HTMLInputElement).value)}
							/>
						</div>

						<div class="col-span-2 grid grid-cols-2 gap-x-3">
							<div>
								<span class="mb-1 block text-[10px] text-muted">End Date</span>
								<input
									type="date"
									value={toInputDate(task.end_at)}
									class="w-full border border-surface-border bg-surface px-3 py-1.5 text-xs text-sidebar-text outline-none transition-colors hover:border-sidebar-icon/30"
									onchange={(e) => handleDateChange('end_at', (e.target as HTMLInputElement).value)}
								/>
							</div>
						</div>
					</div>
				</div>

				<!-- Assignees -->
				<div class="border-b border-surface-border px-4 py-3">
					<div class="mb-2 flex items-center justify-between">
						<span class={labelClass}>Assignees</span>
						{#if members.length > 0}
							<div class="relative" data-dropdown>
								<button
									class="text-[11px] text-sidebar-icon transition-colors hover:text-accent"
									onclick={() => (openDropdown = openDropdown === 'assign' ? null : 'assign')}
								>
									+ Add
								</button>
								{#if openDropdown === 'assign'}
									<div
										class="absolute right-0 z-30 mt-1 max-h-48 w-[200px] overflow-y-auto border border-surface-border bg-surface py-1 shadow-xl"
									>
										{#each members.filter((m) => !task?.assignments?.some((a) => a.user_id === m.user_id)) as m (m.user_id)}
											<button
												class="flex w-full items-center gap-2 px-3 py-2 text-left text-xs text-sidebar-text transition-colors hover:bg-surface-hover"
												onmousedown={async (e) => {
													e.preventDefault();
													openDropdown = null;
													if (!task || !auth.user) return;
													try {
														await api.tasks.assign(task.id, m.user_id, auth.user.id);
														await loadTask(task.id);
													} catch {
														/* */
													}
												}}
											>
												{#if m.user.avatar_url}
													<img src={m.user.avatar_url} alt={m.user.full_name} class="h-5 w-5 rounded-full object-cover" />
												{:else}
													<span class="flex h-5 w-5 items-center justify-center rounded-full bg-accent/20 text-[9px] font-medium text-accent">
														{m.user.full_name.charAt(0)}
													</span>
												{/if}
												{m.user.full_name}
											</button>
										{:else}
											<p class="px-3 py-2 text-xs text-muted">All members assigned</p>
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
											<span class="flex h-5 w-5 items-center justify-center rounded-full bg-accent/20 text-[9px] font-medium text-accent">
												{a.user.full_name.charAt(0)}
											</span>
										{/if}
										<span class="text-xs text-sidebar-text">{a.user.full_name}</span>
									</div>
									<button
										class="p-0.5 text-muted opacity-0 transition-opacity group-hover:opacity-100 hover:text-red-500"
										onclick={async () => {
											if (!task) return;
											try {
												await api.tasks.unassign(task.id, a.user_id);
												await loadTask(task.id);
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
						<p class="text-xs text-muted">No assignees</p>
					{/if}
				</div>

				<!-- Description -->
				<div class="border-b border-surface-border px-4 py-3">
					<div class="mb-2 flex items-center justify-between">
						<span class={labelClass}>Description</span>
						{#if !editingDescription}
							<button
								class="text-[11px] text-sidebar-icon transition-colors hover:text-accent"
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
							class="w-full resize-none border border-surface-border bg-surface px-3 py-2 text-xs text-sidebar-text outline-none transition-colors placeholder:text-sidebar-icon/70 focus:border-sidebar-icon/30"
							placeholder="Add a description..."
						></textarea>
						<div class="mt-2 flex justify-end gap-2">
							<button
								class="border border-surface-border bg-surface px-3 py-1.5 text-xs text-sidebar-text transition-colors hover:bg-surface-hover"
								onclick={() => (editingDescription = false)}>Cancel</button
							>
							<button
								class="bg-accent px-3 py-1.5 text-xs font-medium text-white transition-colors hover:bg-accent/90 disabled:opacity-50"
								disabled={savingDescription}
								onclick={saveDescription}>{savingDescription ? 'Saving...' : 'Save'}</button
							>
						</div>
					{:else}
						<p class="whitespace-pre-wrap text-xs text-sidebar-text">
							{(task.description as string) || 'No description'}
						</p>
					{/if}
				</div>

				<!-- Info -->
				<div class="border-b border-surface-border px-4 py-3">
					<span class="{labelClass} mb-2 block">Details</span>
					<div class="grid grid-cols-2 gap-x-3 gap-y-1.5 text-xs">
						<div>
							<span class="text-muted">Created by</span>
							<p class="flex items-center gap-1 text-sidebar-text">
								{#if task.created_by_user}
									{task.created_by_user.full_name}
								{:else}
									—
								{/if}
							</p>
						</div>
						<div>
							<span class="text-muted">Project</span>
							<p class="text-sidebar-text">{task.project?.name ?? '—'}</p>
						</div>
						<div>
							<span class="text-muted">Created</span>
							<p class="text-sidebar-text">{formatDateTime(task.created_at)}</p>
						</div>
						<div>
							<span class="text-muted">Updated</span>
							<p class="text-sidebar-text">{formatDateTime(task.updated_at)}</p>
						</div>
					</div>
				</div>

				<!-- Work Log -->
				<div class="border-b border-surface-border px-4 py-3">
					<div class="mb-3 flex items-center gap-2">
						<span class={labelClass}>Work Log</span>
						{#if totalMinutes > 0}
							<span
								class="flex items-center gap-1 rounded-full bg-accent/10 px-2 py-0.5 text-[10px] font-medium text-accent"
							>
								<Clock size={10} />
								{formatMinutes(totalMinutes)}
							</span>
						{/if}
					</div>

					<div class="mb-3">
						<div class="mb-1 flex gap-2">
							<span class="w-14 text-[10px] text-muted">Hours</span>
							<span class="w-14 text-[10px] text-muted">Min</span>
							<span class="min-w-0 flex-1 text-[10px] text-muted">Description</span>
							<span class="w-[110px] text-[10px] text-muted">Date</span>
							<span class="w-[30px] shrink-0"></span>
						</div>
						<div class="flex items-stretch gap-2">
							<input
								type="number"
								step="1"
								min="0"
								bind:value={wlHours}
								placeholder="0"
								class="w-14 border border-surface-border bg-surface px-2 py-1.5 text-xs text-sidebar-text outline-none transition-colors placeholder:text-sidebar-icon/70 focus:border-sidebar-icon/30"
							/>
							<input
								type="number"
								step="5"
								min="0"
								max="59"
								bind:value={wlMinutes}
								placeholder="0"
								class="w-14 border border-surface-border bg-surface px-2 py-1.5 text-xs text-sidebar-text outline-none transition-colors placeholder:text-sidebar-icon/70 focus:border-sidebar-icon/30"
							/>
							<input
								type="text"
								bind:value={wlDescription}
								placeholder="What was done..."
								class="min-w-0 flex-1 border border-surface-border bg-surface px-2 py-1.5 text-xs text-sidebar-text outline-none transition-colors placeholder:text-sidebar-icon/70 focus:border-sidebar-icon/30"
							/>
							<input
								type="date"
								bind:value={wlDate}
								class="w-[110px] border border-surface-border bg-surface px-2 py-1.5 text-xs text-sidebar-text outline-none transition-colors focus:border-sidebar-icon/30"
							/>
							<button
								class="flex w-[30px] shrink-0 items-center justify-center bg-accent text-white transition-colors hover:bg-accent/90 disabled:opacity-50"
								disabled={addingWorkLog || (!wlHours && !wlMinutes)}
								onclick={addWorkLog}
								aria-label="Add work log"
							>
								<Plus size={14} />
							</button>
						</div>
					</div>

					<div class="max-h-[200px] space-y-2 overflow-y-auto">
						{#if workLogs.length === 0}
							<p class="py-3 text-center text-xs text-muted">No hours logged yet</p>
						{/if}
						{#each workLogs as wl (wl.id)}
							<div class="flex items-start justify-between gap-2 border border-surface-border bg-surface p-2.5">
								<div class="min-w-0 flex-1">
									<div class="flex items-center gap-2">
										<span class="text-xs font-medium text-sidebar-text">
											{wl.user?.full_name ?? 'Unknown'}
										</span>
										<span class="font-mono text-xs font-semibold text-accent">
											{formatMinutes(Number(wl.minutes))}
										</span>
									</div>
									{#if wl.description}
										<p class="mt-0.5 text-[11px] text-muted">{wl.description}</p>
									{/if}
								</div>
								<div class="flex shrink-0 items-center gap-2">
									<span class="text-[10px] text-muted">{formatDate(wl.logged_at)}</span>
									{#if auth.user && wl.user_id === auth.user.id}
										<button
											class="p-0.5 text-sidebar-icon transition-colors hover:text-red-500"
											onclick={() => deleteWorkLog(wl.id)}
											aria-label="Delete work log"
										>
											<Trash2 size={12} />
										</button>
									{/if}
								</div>
							</div>
						{/each}
					</div>
				</div>

				<!-- Comments -->
				<div class="flex flex-col px-4 py-3">
					<span class="{labelClass} mb-3 block">Comments ({comments.length})</span>
					<div
						bind:this={commentsContainer}
						class="max-h-[320px] space-y-3 overflow-y-auto"
					>
						{#if comments.length === 0}
							<p class="py-4 text-center text-xs text-muted">No comments yet</p>
						{/if}
						{#each comments as c (c.id)}
							<div class="border border-surface-border bg-surface p-3">
								<div class="mb-1.5 flex items-center justify-between">
									<span class="text-xs font-medium text-sidebar-text">
										{c.user?.full_name ?? 'Unknown'}
									</span>
									<span class="text-[10px] text-muted">{formatDate(c.created_at)}</span>
								</div>
								<p class="whitespace-pre-wrap text-xs text-sidebar-text">{c.content}</p>
							</div>
						{/each}
					</div>
				</div>
			</div>

			<!-- Comment compose -->
			<div class="shrink-0 border-t border-surface-border px-4 py-3">
				<div class="flex gap-2">
					<textarea
						bind:value={commentBody}
						rows="2"
						class="flex-1 resize-none border border-surface-border bg-surface px-3 py-2 text-xs text-sidebar-text outline-none transition-colors placeholder:text-sidebar-icon/70 focus:border-sidebar-icon/30"
						placeholder="Write a comment..."
						onkeydown={(e) => {
							if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) {
								e.preventDefault();
								sendComment();
							}
						}}
					></textarea>
					<button
						class="flex shrink-0 items-center justify-center bg-accent px-3 text-white transition-colors hover:bg-accent/90 disabled:opacity-50"
						disabled={!commentBody.trim() || sendingComment}
						onclick={sendComment}
						aria-label="Send comment"
					>
						<Send size={14} />
					</button>
				</div>
			</div>
		{/if}
	</div>
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
