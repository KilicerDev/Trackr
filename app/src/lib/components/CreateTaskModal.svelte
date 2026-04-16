<script lang="ts">
	import Modal from '$lib/components/Modal.svelte';
	import { taskStore } from '$lib/stores/tasks.svelte';
	import { notifications } from '$lib/stores/notifications.svelte';
	import { auth } from '$lib/stores/auth.svelte';
	import { typeIcons, defaultTypeIcon } from '$lib/config/task-icons';
	import { taskStatusIcons, defaultStatusIcon } from '$lib/config/status-icons';
	import { priorityIcons, defaultPriorityIcon } from '$lib/config/priority-icons';
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

	// Assignees
	type ProjectMember = { user_id: string; user: { id: string; full_name: string; avatar_url: string | null; is_active: boolean; deleted_at: string | null } };
	let projectMembers = $state<ProjectMember[]>([]);
	let selectedAssignees = $state<ProjectMember[]>([]);
	let assigneeDropdownOpen = $state(false);

	const availableMembers = $derived(
		projectMembers
			.filter((m) => m.user.is_active && !m.user.deleted_at)
			.filter((m) => !selectedAssignees.some((a) => a.user_id === m.user_id))
	);

	$effect(() => {
		const pid = resolvedProjectId;
		selectedAssignees = [];
		projectMembers = [];
		if (pid) {
			const proj = projects.find((p) => p.id === pid) as Record<string, unknown> | undefined;
			if (proj?.members) {
				projectMembers = proj.members as ProjectMember[];
			} else {
				// Fallback: fetch project with members if not in store
				api.projects.getById(pid).then((p) => {
					const data = p as Record<string, unknown> | null;
					if (data?.members) projectMembers = data.members as ProjectMember[];
				}).catch(() => {});
			}
		}
	});

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

	// Project search combobox
	let projectSearch = $state('');
	let projectHighlightIndex = $state(0);
	const filteredProjects = $derived(
		projectSearch.trim()
			? projects.filter((p) =>
				p.name.toLowerCase().includes(projectSearch.trim().toLowerCase()) ||
				(orgNameMap[p.organization_id] ?? '').toLowerCase().includes(projectSearch.trim().toLowerCase())
			)
			: projects
	);

	const resolvedProjectId = $derived(projectId ?? selectedProjectId);
	const canSubmit = $derived(!!title.trim() && !!resolvedProjectId);
	const SelectedTypeIcon = $derived(typeIcons[type] ?? defaultTypeIcon);
	const selectedStatus = $derived(taskStatusIcons[status] ?? defaultStatusIcon);
	const SelectedStatusIcon = $derived(selectedStatus.icon);
	const selectedPriority = $derived(priorityIcons[priority] ?? defaultPriorityIcon);
	const SelectedPriorityIcon = $derived(selectedPriority.icon);

	function toggleDropdown(key: string) {
		openDropdown = openDropdown === key ? null : key;
	}

	$effect(() => {
		if (openDropdown === null && !tagDropdownOpen && !assigneeDropdownOpen) return;
		function onMouseDown(e: MouseEvent) {
			const target = e.target as HTMLElement;
			if (!target.closest('[data-dropdown]')) {
				openDropdown = null;
				tagDropdownOpen = false;
				assigneeDropdownOpen = false;
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
			// Assign users
			if (task && selectedAssignees.length > 0) {
				for (const member of selectedAssignees) {
					try { await api.tasks.assign(task.id, member.user_id, auth.user!.id); } catch { /* silent */ }
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

	import { labelClass, inputClass } from '$lib/styles/ui';
	const dropdownBtnClass =
		'flex w-full cursor-pointer items-center justify-between gap-2 rounded-sm bg-surface-hover/40 px-2.5 py-1.5 text-base text-sidebar-text transition-all duration-150 hover:bg-surface-hover/60';
	const dropdownPanelClass =
		'absolute left-0 z-20 mt-1.5 max-h-48 w-full min-w-[10rem] overflow-y-auto rounded-md border border-surface-border bg-surface py-1 shadow-lg shadow-black/15 ring-1 ring-white/[0.07] animate-dropdown-in';
	const dropdownItemBase =
		'flex w-full items-center px-2.5 py-1.5 text-left text-sm transition-colors hover:bg-surface-hover/60';
	const chevronSvg = `<svg class="h-3.5 w-3.5 shrink-0 text-muted/40" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/></svg>`;
</script>

<Modal open={true} {onClose}>
	<div>
		<div class="px-3 py-2.5">
			<h2 class="text-md font-semibold text-sidebar-text">Create task</h2>
		</div>
		<div class="p-3">
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
							<div class="relative">
								<input
									type="text"
									class={inputClass}
									placeholder="Select project"
									bind:value={projectSearch}
									onfocus={() => { openDropdown = 'project'; projectHighlightIndex = 0; projectSearch = ''; }}
									onkeydown={(e) => {
										if (openDropdown !== 'project') { openDropdown = 'project'; projectHighlightIndex = 0; }
										if (e.key === 'ArrowDown') {
											e.preventDefault();
											projectHighlightIndex = Math.min(projectHighlightIndex + 1, filteredProjects.length - 1);
										} else if (e.key === 'ArrowUp') {
											e.preventDefault();
											projectHighlightIndex = Math.max(projectHighlightIndex - 1, 0);
										} else if (e.key === 'Enter') {
											e.preventDefault();
											const p = filteredProjects[projectHighlightIndex];
											if (p) {
												selectedProjectId = p.id;
												projectSearch = p.name;
												openDropdown = null;
											}
										} else if (e.key === 'Escape') {
											openDropdown = null;
											(e.target as HTMLInputElement).blur();
										}
									}}
								/>
								{#if selectedProjectId && !projectSearch}
									<span class="pointer-events-none absolute inset-0 flex items-center px-2.5 text-base text-sidebar-text">
										{projects.find((p) => p.id === selectedProjectId)?.name ?? ''}
									</span>
								{/if}
							</div>
							{#if openDropdown === 'project'}
								<div class={dropdownPanelClass}>
									{#each filteredProjects as p, i (p.id)}
										<button
											type="button"
											class="{dropdownItemBase} {selectedProjectId === p.id ? 'font-medium text-accent' : 'text-sidebar-text'} {i === projectHighlightIndex ? 'bg-surface-hover/60' : ''}"
											onmousedown={(e) => { e.preventDefault(); selectedProjectId = p.id; projectSearch = p.name; openDropdown = null; }}
											onmouseenter={() => { projectHighlightIndex = i; }}
										>
											<span class="flex flex-col items-start">
												<span>{p.name}</span>
												{#if orgNameMap[p.organization_id]}
													<span class="text-xs text-accent/50">{orgNameMap[p.organization_id]}</span>
												{/if}
											</span>
										</button>
									{:else}
										<p class="px-2.5 py-1.5 text-sm text-muted">No projects found</p>
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
							<span class="flex items-center gap-1.5 truncate">
								<SelectedPriorityIcon size={16} class={selectedPriority.className} />
								{displayName(priority)}
							</span>
							{@html chevronSvg}
							</button>
							{#if openDropdown === 'priority'}
								<div class={dropdownPanelClass}>
									{#each TASK_PRIORITIES as p (p)}
										{@const info = priorityIcons[p] ?? defaultPriorityIcon}
										{@const PriorityIcon = info.icon}
										<button
											type="button"
											class="{dropdownItemBase} {priority === p ? 'font-medium text-accent' : 'text-sidebar-text'}"
											onmousedown={(e) => { e.preventDefault(); priority = p; openDropdown = null; }}
										>
											<span class="mr-2"><PriorityIcon size={16} class={info.className} /></span>
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
							<span class="flex items-center gap-1.5 truncate">
								<SelectedStatusIcon size={16} class={selectedStatus.className} />
								{displayName(status)}
							</span>
							{@html chevronSvg}
							</button>
							{#if openDropdown === 'status'}
								<div class={dropdownPanelClass}>
									{#each TASK_STATUSES as s (s)}
										{@const info = taskStatusIcons[s] ?? defaultStatusIcon}
										{@const StatusIcon = info.icon}
										<button
											type="button"
											class="{dropdownItemBase} {status === s ? 'font-medium text-accent' : 'text-sidebar-text'}"
											onmousedown={(e) => { e.preventDefault(); status = s; openDropdown = null; }}
										>
											<span class="mr-2"><StatusIcon size={16} class={info.className} /></span>
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

				<!-- Assignees & Tags side by side -->
				{#if resolvedProjectId}
					<div class="grid grid-cols-2 gap-3">
						<!-- Assignees -->
						{#if projectMembers.length > 0}
							<div>
								<span class={labelClass}>Assignees</span>
								<div class="relative" data-dropdown>
									<div class="flex flex-wrap items-center gap-2">
										{#each selectedAssignees as member (member.user_id)}
											<button
												type="button"
												class="group relative"
												title={member.user.full_name}
												onclick={() => { selectedAssignees = selectedAssignees.filter((a) => a.user_id !== member.user_id); }}
											>
												{#if member.user.avatar_url}
													<img src={member.user.avatar_url} alt={member.user.full_name} class="h-8 w-8 rounded-full object-cover ring-2 ring-surface" />
												{:else}
													<span class="flex h-8 w-8 items-center justify-center rounded-full bg-accent/20 text-sm font-semibold text-accent ring-2 ring-surface">
														{member.user.full_name.charAt(0).toUpperCase()}
													</span>
												{/if}
												<span class="absolute inset-0 flex items-center justify-center rounded-full bg-black/50 opacity-0 transition-opacity group-hover:opacity-100">
													<X size={12} class="text-white" />
												</span>
											</button>
										{/each}
										<button
											type="button"
											class="flex h-8 w-8 items-center justify-center rounded-full border border-dashed border-muted/30 text-muted/40 transition-colors hover:border-muted/50 hover:text-muted/60"
											title="Add assignee"
											onclick={() => { assigneeDropdownOpen = !assigneeDropdownOpen; }}
										>
											<Plus size={14} />
										</button>
									</div>
									{#if assigneeDropdownOpen}
										<div class="absolute left-0 z-20 mt-1.5 max-h-48 w-48 overflow-y-auto rounded-md border border-surface-border bg-surface py-1 shadow-lg shadow-black/15 ring-1 ring-white/[0.07] animate-dropdown-in">
											{#each projectMembers.filter((m) => m.user.is_active && !m.user.deleted_at) as member (member.user_id)}
												{@const isSelected = selectedAssignees.some((a) => a.user_id === member.user_id)}
												<button
													type="button"
													class="{dropdownItemBase} {isSelected ? 'text-accent' : 'text-sidebar-text'}"
													onmousedown={(e) => {
														e.preventDefault();
														if (isSelected) {
															selectedAssignees = selectedAssignees.filter((a) => a.user_id !== member.user_id);
														} else {
															selectedAssignees = [...selectedAssignees, member];
														}
													}}
												>
													{#if member.user.avatar_url}
														<img src={member.user.avatar_url} alt="" class="mr-2 h-5 w-5 rounded-full object-cover" />
													{:else}
														<span class="mr-2 flex h-5 w-5 items-center justify-center rounded-full bg-accent/20 text-[10px] font-semibold text-accent">
															{member.user.full_name.charAt(0).toUpperCase()}
														</span>
													{/if}
													<span class="flex-1 truncate">{member.user.full_name}</span>
													{#if isSelected}
														<svg class="ml-1 h-3.5 w-3.5 shrink-0 text-accent" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M5 13l4 4L19 7"/></svg>
													{/if}
												</button>
											{/each}
										</div>
									{/if}
								</div>
							</div>
						{/if}

						<!-- Tags -->
						<div>
							<span class={labelClass}>Tags</span>
							{#if selectedTags.length > 0}
								<div class="mb-2 flex flex-wrap gap-1.5">
									{#each selectedTags as tag (tag.id)}
										<span
											class="inline-flex items-center gap-1 rounded-sm px-2 py-0.5 text-sm font-medium"
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
									<div class="absolute left-0 z-20 mt-1.5 max-h-40 w-full overflow-y-auto rounded-md border border-surface-border bg-surface py-1 shadow-lg shadow-black/15 ring-1 ring-white/[0.07] animate-dropdown-in">
										{#each filteredTags as tag (tag.id)}
											<button
												type="button"
												class="flex w-full items-center gap-2 px-2.5 py-1.5 text-left text-sm text-sidebar-text transition-colors hover:bg-surface-hover/60"
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
												<p class="px-3 py-2 text-base text-muted">No tags yet</p>
											{/if}
										{/each}
										{#if tagSearch.trim() && !tagExactMatch}
											<button
												type="button"
												class="flex w-full items-center gap-2 border-t border-surface-border/30 px-2.5 py-1.5 text-left text-sm text-accent transition-colors hover:bg-surface-hover/60"
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
								<span class="flex items-center gap-1 rounded border border-surface-border/40 bg-surface/50 px-2 py-0.5 text-xs text-sidebar-text">
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

				<div class="flex justify-end gap-2 pt-3">
					<button
						type="button"
						class="flex h-7 items-center rounded-sm bg-surface-hover/40 px-2.5 text-sm font-medium text-sidebar-text transition-all duration-150 hover:bg-surface-hover/60"
						onclick={onClose}
					>
						Cancel
					</button>
					<button
						type="submit"
						disabled={!canSubmit || submitting}
						class="flex h-7 items-center gap-1 rounded-sm bg-accent px-2.5 text-sm font-medium text-white transition-all duration-150 hover:bg-accent/90 disabled:opacity-30"
					>
						{submitting ? 'Creating…' : 'Create task'}
					</button>
				</div>
			</form>
		</div>
	</div>
</Modal>
