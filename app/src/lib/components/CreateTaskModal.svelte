<script lang="ts">
	import Modal from '$lib/components/Modal.svelte';
	import { taskStore } from '$lib/stores/tasks.svelte';
	import { notifications } from '$lib/stores/notifications.svelte';
	import { auth } from '$lib/stores/auth.svelte';
	import { typeIcons, defaultTypeIcon } from '$lib/config/task-icons';
	import { projectStore, type Project } from '$lib/stores/projects.svelte';
	import { orgStore } from '$lib/stores/organizations.svelte';
	import { api } from '$lib/api';
	import type { Tag } from '$lib/api/tags';
	import { X, Paperclip, Plus } from '@lucide/svelte';
	import AttachmentUploadZone from './AttachmentUploadZone.svelte';

	const TASK_PRIORITIES = ['urgent', 'high', 'medium', 'low', 'none'] as const;
	const TASK_TYPES = ['task', 'bug', 'feature', 'improvement', 'epic'] as const;
	const TASK_STATUSES = ['backlog', 'todo', 'in_progress', 'in_review', 'done'] as const;

	interface Props {
		projectId?: string;
		onClose: () => void;
		onCreated?: (taskId: string) => void;
		supportTicketId?: string;
		prefillTitle?: string;
		prefillDescription?: string;
		prefillPriority?: string;
		prefillStatus?: string;
	}

	let { projectId, onClose, onCreated, supportTicketId, prefillTitle, prefillDescription, prefillPriority, prefillStatus }: Props = $props();

	let selectedProjectId = $state(projectId ?? '');
	let title = $state(prefillTitle ?? '');
	let description = $state(prefillDescription ?? '');
	let priority = $state<string>(prefillPriority ?? 'medium');
	let type = $state<string>('task');
	let status = $state<string>(prefillStatus ?? 'todo');

	const needsProjectSelector = $derived(!projectId);
	const projects = $derived(projectStore.items);
	const orgNameMap = $derived(Object.fromEntries(orgStore.all.map((o) => [o.id, o.name])));

	$effect(() => {
		if (needsProjectSelector && projects.length === 0) {
			projectStore.loadAll();
		}
	});
	let parentId = $state<string>('');
	let startAt = $state('');
	let endAt = $state('');
	let submitting = $state(false);
	let pendingFiles = $state<File[]>([]);

	// Tags
	const TAG_COLORS = ['#10b981', '#3b82f6', '#8b5cf6', '#f59e0b', '#ef4444', '#ec4899', '#06b6d4', '#84cc16', '#f97316', '#6366f1'];
	let selectedTags = $state<{ id: string; name: string; color: string }[]>([]);
	let projectTagsList = $state<Tag[]>([]);
	let tagSearch = $state('');
	let tagDropdownOpen = $state(false);

	const filteredTags = $derived(
		projectTagsList
			.filter((t) => !selectedTags.some((s) => s.id === t.id))
			.filter((t) => !tagSearch || t.name.toLowerCase().includes(tagSearch.toLowerCase()))
	);
	const tagExactMatch = $derived(
		projectTagsList.some((t) => t.name.toLowerCase() === tagSearch.trim().toLowerCase())
	);

	$effect(() => {
		const pid = resolvedProjectId;
		selectedTags = [];
		projectTagsList = [];
		if (pid) {
			api.tags.getByProject(pid).then((t) => { projectTagsList = t; }).catch(() => {});
		}
	});

	async function createTag() {
		const name = tagSearch.trim();
		if (!name || !resolvedProjectId) return;
		const color = TAG_COLORS[projectTagsList.length % TAG_COLORS.length];
		try {
			const tag = await api.tags.create({ project_id: resolvedProjectId, name, color });
			projectTagsList = [...projectTagsList, tag];
			selectedTags = [...selectedTags, { id: tag.id, name: tag.name, color: tag.color }];
			tagSearch = '';
		} catch { /* ignore */ }
	}

	const parentOptions = $derived(
		taskStore.items
			.filter((t) => !resolvedProjectId || t.project_id === resolvedProjectId)
			.map((t) => ({
				id: t.id,
				label: `${t.short_id}  ${t.title}`
			}))
	);
	const selectedParentLabel = $derived(
		parentOptions.find((p) => p.id === parentId)?.label ?? 'None'
	);

	let openDropdown = $state<string | null>(null);

	const resolvedProjectId = $derived(projectId ?? selectedProjectId);
	const canSubmit = $derived(!!title.trim() && !!resolvedProjectId);
	const SelectedTypeIcon = $derived(typeIcons[type] ?? defaultTypeIcon);

	function toggleDropdown(key: string) {
		openDropdown = openDropdown === key ? null : key;
	}

	$effect(() => {
		if (openDropdown === null && !tagDropdownOpen) return;
		function onMouseDown(e: MouseEvent) {
			const target = e.target as HTMLElement;
			if (!target.closest('[data-dropdown]')) {
				openDropdown = null;
				tagDropdownOpen = false;
				tagSearch = '';
			}
		}
		document.addEventListener('mousedown', onMouseDown);
		return () => document.removeEventListener('mousedown', onMouseDown);
	});

	async function handleSubmit(e: Event) {
		e.preventDefault();
		if (!canSubmit || submitting || !auth.user) return;
		submitting = true;
		const n = notifications.action('Creating task');
		try {
			const task = await taskStore.create({
				title: title.trim(),
				description: description.trim() || undefined,
				project_id: resolvedProjectId,
				priority,
				type,
				status,
				parent_id: parentId || undefined,
				support_ticket_id: supportTicketId || undefined,
				start_at: startAt ? `${startAt}T00:00:00.000Z` : undefined,
				end_at: endAt ? `${endAt}T00:00:00.000Z` : undefined,
				created_by: auth.user.id
			});
			// Upload pending files
			if (task && pendingFiles.length > 0) {
				const project = await api.projects.getById(resolvedProjectId);
				const orgId = (project as Record<string, unknown>)?.organization_id as string;
				if (orgId) {
					for (const file of pendingFiles) {
						try {
							await api.attachments.upload(file, 'task', task.id, orgId, auth.user!.id);
						} catch {
							/* silent - task was created, attachment upload is best-effort */
						}
					}
				}
			}
			// Assign tags
			if (task && selectedTags.length > 0) {
				for (const tag of selectedTags) {
					try { await api.tags.addToTask(task.id, tag.id); } catch { /* silent */ }
				}
			}
			n.success('Task created');
			onClose();
			if (task) onCreated?.(task.id);
		} catch (err) {
			n.error('Failed', err instanceof Error ? err.message : 'Failed to create task');
		} finally {
			submitting = false;
		}
	}

	function displayName(val: string): string {
		return val
			.split('_')
			.map((w) => w.charAt(0).toUpperCase() + w.slice(1))
			.join(' ');
	}

	const labelClass = 'mb-1.5 block text-[11px] font-medium uppercase tracking-wider text-sidebar-icon';
	const inputClass =
		'w-full border border-surface-border bg-surface px-3 py-2 text-xs text-sidebar-text outline-none transition-colors placeholder:text-sidebar-icon/70 focus:border-sidebar-icon/30 hover:border-sidebar-icon/30';
	const dropdownBtnClass =
		'flex w-full cursor-pointer items-center justify-between gap-2 border border-surface-border bg-surface px-3 py-2 text-xs text-sidebar-text transition-colors hover:border-sidebar-icon/30 hover:bg-surface-hover';
	const dropdownPanelClass =
		'absolute left-0 z-20 mt-1.5 max-h-56 w-full min-w-[10rem] overflow-y-auto border border-surface-border bg-surface py-1';
	const dropdownItemBase =
		'flex w-full items-center px-4 py-2.5 text-left text-xs transition-colors hover:bg-surface-hover';
	const chevronSvg = `<svg class="h-4 w-4 shrink-0 text-sidebar-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/></svg>`;
</script>

<Modal open={true} {onClose}>
	<div>
		<div class="border-b border-surface-border px-4 py-3">
			<h2 class="text-sm font-semibold text-sidebar-text">Create task</h2>
		</div>
		<div class="p-4">
			<form onsubmit={handleSubmit} class="space-y-4">
				<div>
					<label for="create-task-title" class={labelClass}>Title</label>
					<input
						id="create-task-title"
						type="text"
						required
						bind:value={title}
						class={inputClass}
						placeholder="What needs to be done?"
					/>
				</div>

				<div>
					<label for="create-task-description" class={labelClass}>Description</label>
					<textarea
						id="create-task-description"
						bind:value={description}
						rows="3"
						class="{inputClass} resize-none"
						placeholder="Optional details"
					></textarea>
				</div>

				<!-- Project selector (shown when no projectId prop) -->
				{#if needsProjectSelector}
					<div>
						<span class={labelClass}>Project</span>
						<div class="relative" data-dropdown>
							<button
								type="button"
								class={dropdownBtnClass}
								onclick={() => toggleDropdown('project')}
							>
							<span class="truncate">{projects.find((p) => p.id === selectedProjectId)?.name ?? 'Select project'}</span>
							{@html chevronSvg}
							</button>
							{#if openDropdown === 'project'}
								<div class={dropdownPanelClass}>
									{#each projects as p (p.id)}
										<button
											type="button"
											class="{dropdownItemBase} {selectedProjectId === p.id ? 'font-medium text-accent' : 'text-sidebar-text'}"
											onmousedown={(e) => { e.preventDefault(); selectedProjectId = p.id; openDropdown = null; }}
										>
											<span class="flex flex-col items-start">
												<span>{p.name}</span>
												{#if orgNameMap[p.organization_id]}
													<span class="text-[10px] text-accent/50">{orgNameMap[p.organization_id]}</span>
												{/if}
											</span>
										</button>
									{/each}
								</div>
							{/if}
						</div>
					</div>
				{/if}

				<!-- Parent task -->
				{#if parentOptions.length > 0}
					<div>
						<span class={labelClass}>Parent Task</span>
						<div class="relative" data-dropdown>
							<button
								type="button"
								class={dropdownBtnClass}
								onclick={() => toggleDropdown('parent')}
							>
							<span class="truncate">{selectedParentLabel}</span>
							{@html chevronSvg}
							</button>
							{#if openDropdown === 'parent'}
								<div class={dropdownPanelClass}>
									<button
										type="button"
										class="{dropdownItemBase} {!parentId ? 'font-medium text-accent' : 'text-sidebar-text'}"
										onmousedown={(e) => { e.preventDefault(); parentId = ''; openDropdown = null; }}
									>
										None
									</button>
									{#each parentOptions as p (p.id)}
										<button
											type="button"
											class="{dropdownItemBase} {parentId === p.id ? 'font-medium text-accent' : 'text-sidebar-text'}"
											onmousedown={(e) => { e.preventDefault(); parentId = p.id; openDropdown = null; }}
										>
											{p.label}
										</button>
									{/each}
								</div>
							{/if}
						</div>
					</div>
				{/if}

				<div class="grid grid-cols-3 gap-3">
					<!-- Type -->
					<div>
						<span class={labelClass}>Type</span>
						<div class="relative" data-dropdown>
							<button
								type="button"
								class={dropdownBtnClass}
								onclick={() => toggleDropdown('type')}
							>
							<span class="flex items-center gap-1.5 truncate">
								<SelectedTypeIcon size={14} />
								{displayName(type)}
							</span>
								{@html chevronSvg}
							</button>
							{#if openDropdown === 'type'}
								<div class={dropdownPanelClass}>
								{#each TASK_TYPES as t (t)}
									{@const TypeIcon = typeIcons[t] ?? defaultTypeIcon}
									<button
										type="button"
										class="{dropdownItemBase} {type === t ? 'font-medium text-accent' : 'text-sidebar-text'}"
										onmousedown={(e) => { e.preventDefault(); type = t; openDropdown = null; }}
									>
									<span class="mr-2"><TypeIcon size={14} /></span>
									{displayName(t)}
									</button>
								{/each}
								</div>
							{/if}
						</div>
					</div>

					<!-- Priority -->
					<div>
						<span class={labelClass}>Priority</span>
						<div class="relative" data-dropdown>
							<button
								type="button"
								class={dropdownBtnClass}
								onclick={() => toggleDropdown('priority')}
							>
							<span class="truncate">{displayName(priority)}</span>
							{@html chevronSvg}
							</button>
							{#if openDropdown === 'priority'}
								<div class={dropdownPanelClass}>
									{#each TASK_PRIORITIES as p (p)}
										<button
											type="button"
											class="{dropdownItemBase} {priority === p ? 'font-medium text-accent' : 'text-sidebar-text'}"
											onmousedown={(e) => { e.preventDefault(); priority = p; openDropdown = null; }}
										>
											{displayName(p)}
										</button>
									{/each}
								</div>
							{/if}
						</div>
					</div>

					<!-- Status -->
					<div>
						<span class={labelClass}>Status</span>
						<div class="relative" data-dropdown>
							<button
								type="button"
								class={dropdownBtnClass}
								onclick={() => toggleDropdown('status')}
							>
							<span class="truncate">{displayName(status)}</span>
							{@html chevronSvg}
							</button>
							{#if openDropdown === 'status'}
								<div class={dropdownPanelClass}>
									{#each TASK_STATUSES as s (s)}
										<button
											type="button"
											class="{dropdownItemBase} {status === s ? 'font-medium text-accent' : 'text-sidebar-text'}"
											onmousedown={(e) => { e.preventDefault(); status = s; openDropdown = null; }}
										>
											{displayName(s)}
										</button>
									{/each}
								</div>
							{/if}
						</div>
					</div>
				</div>

				<div class="grid grid-cols-2 gap-3">
					<div>
						<label for="create-task-start" class={labelClass}>Start Date</label>
						<input
							id="create-task-start"
							type="date"
							bind:value={startAt}
							class={inputClass}
						/>
					</div>
					<div>
						<label for="create-task-end" class={labelClass}>End Date</label>
						<input
							id="create-task-end"
							type="date"
							bind:value={endAt}
							class={inputClass}
						/>
					</div>
				</div>

				<!-- Tags -->
				{#if resolvedProjectId}
					<div>
						<span class={labelClass}>Tags</span>
						{#if selectedTags.length > 0}
							<div class="mb-2 flex flex-wrap gap-1.5">
								{#each selectedTags as tag (tag.id)}
									<span
										class="inline-flex items-center gap-1 px-2 py-0.5 text-[11px] font-medium"
										style="background-color: {tag.color}15; color: {tag.color}; border: 1px solid {tag.color}30"
									>
										{tag.name}
										<button
											type="button"
											class="hover:brightness-75"
											onclick={() => { selectedTags = selectedTags.filter((t) => t.id !== tag.id); }}
										>
											<X size={10} />
										</button>
									</span>
								{/each}
							</div>
						{/if}
						<div class="relative" data-dropdown>
							<input
								type="text"
								bind:value={tagSearch}
								placeholder="Search or create tag..."
								class={inputClass}
								onfocus={() => { tagDropdownOpen = true; }}
								onkeydown={(e) => {
									if (e.key === 'Escape') { tagDropdownOpen = false; tagSearch = ''; }
									if (e.key === 'Enter' && tagSearch.trim() && !tagExactMatch) { e.preventDefault(); createTag(); }
								}}
							/>
							{#if tagDropdownOpen}
								<div class="absolute left-0 z-20 mt-1 max-h-40 w-full overflow-y-auto border border-surface-border bg-surface py-1 shadow-xl">
									{#each filteredTags as tag (tag.id)}
										<button
											type="button"
											class="flex w-full items-center gap-2 px-3 py-1.5 text-left text-xs text-sidebar-text transition-colors hover:bg-surface-hover"
											onmousedown={(e) => {
												e.preventDefault();
												selectedTags = [...selectedTags, { id: tag.id, name: tag.name, color: tag.color }];
												tagSearch = '';
											}}
										>
											<span class="h-2.5 w-2.5 shrink-0 rounded-full" style="background-color: {tag.color}"></span>
											{tag.name}
										</button>
									{:else}
										{#if !tagSearch.trim()}
											<p class="px-3 py-2 text-xs text-muted">No tags yet</p>
										{/if}
									{/each}
									{#if tagSearch.trim() && !tagExactMatch}
										<button
											type="button"
											class="flex w-full items-center gap-2 border-t border-surface-border px-3 py-1.5 text-left text-xs text-accent transition-colors hover:bg-surface-hover"
											onmousedown={(e) => {
												e.preventDefault();
												createTag();
											}}
										>
											<Plus size={12} />
											Create "{tagSearch.trim()}"
										</button>
									{/if}
								</div>
							{/if}
						</div>
					</div>
				{/if}

				<div>
					<span class={labelClass}>Attachments</span>
					<AttachmentUploadZone
						onFilesSelected={(files) => { pendingFiles = [...pendingFiles, ...files]; }}
						disabled={submitting}
					/>
					{#if pendingFiles.length > 0}
						<div class="mt-2 flex flex-wrap gap-1">
							{#each pendingFiles as file, i (file.name + i)}
								<span class="flex items-center gap-1 border border-surface-border bg-surface px-2 py-0.5 text-[10px] text-sidebar-text">
									<Paperclip size={10} />
									<span class="max-w-[120px] truncate">{file.name}</span>
									<button type="button" class="text-muted hover:text-red-500" onclick={() => { pendingFiles = pendingFiles.filter((_, idx) => idx !== i); }}>
										<X size={10} />
									</button>
								</span>
							{/each}
						</div>
					{/if}
				</div>

				<div class="flex justify-end gap-2 border-t border-surface-border pt-4">
					<button
						type="button"
						class="border border-surface-border bg-surface px-4 py-2 text-xs font-medium text-sidebar-text transition-colors hover:border-sidebar-icon/30 hover:bg-surface-hover"
						onclick={onClose}
					>
						Cancel
					</button>
					<button
						type="submit"
						disabled={!canSubmit || submitting}
						class="bg-accent px-4 py-2 text-xs font-medium text-white transition-colors hover:bg-accent/90 disabled:opacity-50"
					>
						{submitting ? 'Creating…' : 'Create task'}
					</button>
				</div>
			</form>
		</div>
	</div>
</Modal>
