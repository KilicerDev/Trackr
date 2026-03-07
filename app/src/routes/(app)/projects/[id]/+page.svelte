<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { replaceState, afterNavigate } from '$app/navigation';
	import { projectStore } from '$lib/stores/projects.svelte';
	import { taskStore } from '$lib/stores/tasks.svelte';
	import { notifications } from '$lib/stores/notifications.svelte';
	import { auth } from '$lib/stores/auth.svelte';
	import { api } from '$lib/api';
	import type { Role } from '$lib/api/roles';
	import TaskRow from '$lib/components/TaskRow.svelte';
	import { ArrowLeft, Users, User, Check, X, Plus } from '@lucide/svelte';
	import TaskDetailPanel from '$lib/components/TaskDetailPanel.svelte';
	import CreateTaskModal from '$lib/components/CreateTaskModal.svelte';
	import { localizeHref } from '$lib/paraglide/runtime';
	import { SvelteMap } from 'svelte/reactivity';

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

	type OrgMember = {
		user_id: string;
		user: { id: string; full_name: string; email: string; avatar_url: string | null };
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
		function walk(parentId: string | null, depth: number) {
			const children = childrenMap.get(parentId);
			if (!children) return;
			for (const child of children) {
				result.push({ task: child, depth });
				walk(child.id, depth + 1);
			}
		}
		walk(null, 0);
		return result;
	});

	let selectedTaskId = $state<string | null>(null);

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
	let roles = $state<Role[]>([]);
	let addMemberUserId = $state('');
	let addMemberRoleId = $state('');
	let addingMember = $state(false);

	const availableMembers = $derived(
		orgMembers.filter(
			(om) =>
				!project?.members?.some((pm) => pm.user_id === om.user_id) &&
				(!addMemberRoleId || om.role?.id === addMemberRoleId)
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

	async function addMember() {
		if (!project || !addMemberUserId || !addMemberRoleId || addingMember) return;
		addingMember = true;
		const n = notifications.action('Adding member');
		try {
			await api.projects.addMember(project.id, addMemberUserId, addMemberRoleId);
			await projectStore.loadById(project.id);
			addMemberUserId = '';
			addMemberRoleId = '';
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
		await Promise.all([taskStore.load({ project_id: id }), projectStore.loadById(id)]);

		const orgId = projectStore.activeProject?.organization_id;
		if (orgId) {
			const [m, r] = await Promise.all([
				api.members.getAll(orgId).catch(() => []),
				api.roles.getAll(orgId).catch(() => [])
			]);
			orgMembers = m as OrgMember[];
			roles = r as Role[];
		}

		const taskParam = new URL(window.location.href).searchParams.get('task');
		if (taskParam) selectTask(taskParam);
	});

	afterNavigate(({ to }) => {
		const taskParam = to?.url.searchParams.get('task') ?? null;
		if (taskParam) selectedTaskId = taskParam;
	});
</script>

<div class="mx-auto w-full max-w-[1200px]">
	<div class="flex items-center gap-3 border-b border-surface-border px-4 py-3">
		<a
			href={localizeHref('/projects' + (project?.organization_id ? `?org=${project.organization_id}` : ''))}
			class="flex items-center gap-1 text-xs text-muted transition-colors hover:text-sidebar-text"
		>
			<ArrowLeft size={14} />
			Projects
		</a>
	</div>

	{#if projectStore.loading && !project}
		<p class="px-4 py-12 text-center text-sm text-muted">Loading...</p>
	{:else if projectStore.error}
		<p class="px-4 py-12 text-center text-sm text-red-500">{projectStore.error}</p>
	{:else if project}
		<div class="border-b border-surface-border px-4 py-6">
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
										class="absolute left-0 z-20 mt-2 flex gap-1.5 border border-surface-border bg-surface p-2.5 shadow-xl"
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

						<span class="text-[11px] font-semibold tracking-wider text-muted">
							{project.identifier}
						</span>

						<!-- Status dropdown -->
						{#if canUpdateProject}
							<div class="relative" data-dropdown>
								<button
									class="cursor-pointer px-2 py-0.5 text-[10px] font-medium transition-colors hover:opacity-80 {statusColors[
										project.status
									] ?? 'bg-gray-100 text-gray-500 dark:bg-surface-hover dark:text-muted'}"
									onclick={() => (openDropdown = openDropdown === 'status' ? null : 'status')}
								>
									{formatStatus(project.status)}
								</button>
								{#if openDropdown === 'status'}
									<div
										class="absolute left-0 z-20 mt-1.5 min-w-[140px] border border-surface-border bg-surface py-1 shadow-xl"
									>
										{#each PROJECT_STATUSES as s (s)}
											<button
												class="flex w-full items-center px-4 py-2 text-left text-xs transition-colors hover:bg-surface-hover {project.status ===
												s
													? 'font-medium text-accent'
													: 'text-sidebar-text'}"
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
								class="px-2 py-0.5 text-[10px] font-medium {statusColors[project.status] ?? 'bg-gray-100 text-gray-500 dark:bg-surface-hover dark:text-muted'}"
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
								class="flex-1 border border-surface-border bg-surface px-2 py-1 text-lg font-semibold text-sidebar-text outline-none focus:border-sidebar-icon/30"
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
							class="mt-1 cursor-pointer text-left text-lg font-semibold text-sidebar-text transition-colors hover:text-accent"
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
								class="w-full resize-none border border-surface-border bg-surface px-3 py-2 text-xs leading-relaxed text-sidebar-text outline-none focus:border-sidebar-icon/30"
								onkeydown={(e) => {
									if (e.key === 'Escape') editingDescription = false;
								}}
							></textarea>
							<div class="mt-1.5 flex gap-2">
								<button
									class="bg-accent px-3 py-1.5 text-[11px] font-medium text-white transition-colors hover:bg-accent/90 disabled:opacity-50"
									disabled={savingField}
									onclick={saveDescription}
								>
									{savingField ? 'Saving…' : 'Save'}
								</button>
								<button
									class="border border-surface-border bg-surface px-3 py-1.5 text-[11px] font-medium text-sidebar-text transition-colors hover:bg-surface-hover"
									onclick={() => (editingDescription = false)}
								>
									Cancel
								</button>
							</div>
						</div>
					{:else if canUpdateProject}
						<button
							class="mt-1.5 cursor-pointer text-left text-xs leading-relaxed text-muted transition-colors hover:text-sidebar-text"
							onclick={startEditDescription}
						>
							{project.description || 'Add a description…'}
						</button>
					{:else}
						<p class="mt-1.5 text-xs leading-relaxed text-muted">
							{project.description || 'No description.'}
						</p>
					{/if}
				</div>
			</div>

			<!-- Info row: owner, dates, members -->
			<div class="mt-4 flex flex-wrap items-center gap-10 text-xs text-muted">
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
									class="border border-surface-border bg-surface px-2 py-1 text-xs text-sidebar-text outline-none hover:border-sidebar-icon/30"
									onchange={(e) => handleDateChange('start_at', (e.target as HTMLInputElement).value)}
								/>
							</label>
						{:else}
							<p class="text-xs text-sidebar-text">{formatDate(project.start_at)}</p>
						{/if}
					</div>
					<div>
						<span class="text-sidebar-icon">End</span>
						{#if canUpdateProject}
							<label class="flex items-center gap-1">
								<input
									type="date"
									value={toInputDate(project.end_at)}
									class="border border-surface-border bg-surface px-2 py-1 text-xs text-sidebar-text outline-none hover:border-sidebar-icon/30"
									onchange={(e) => handleDateChange('end_at', (e.target as HTMLInputElement).value)}
								/>
							</label>
						{:else}
							<p class="text-xs text-sidebar-text">{formatDate(project.end_at)}</p>
						{/if}
					</div>
				</div>
			</div>
		</div>

		<!-- Members -->
		<div class="border-b border-surface-border px-4 py-4">
			<div class="mb-3 flex items-center justify-between">
				<h2 class="text-[11px] font-medium tracking-wider text-sidebar-icon uppercase">Members</h2>
				{#if canManageProject}
				<div class="relative" data-dropdown>
					<button
						class="flex items-center gap-1 text-[11px] font-medium text-accent transition-colors hover:text-accent/80"
						onclick={() => (openDropdown = openDropdown === 'add-member' ? null : 'add-member')}
					>
						<Plus size={13} /> Add
					</button>
					{#if openDropdown === 'add-member'}
						<div
							class="absolute right-0 z-20 mt-1.5 w-[260px] border border-surface-border bg-surface shadow-xl"
						>
							{#if addMemberRoleId}
								<div class="border-b border-surface-border px-3 py-2">
									<span class="text-[10px] font-medium tracking-wider text-sidebar-icon uppercase"
										>Select user</span
									>
								</div>
								<div class="max-h-56 overflow-y-auto py-1">
									{#each availableMembers as om (om.user_id)}
										<button
											class="flex w-full items-center gap-2 px-3 py-2 text-left text-xs transition-colors hover:bg-surface-hover"
											disabled={addingMember}
											onmousedown={(e) => {
												e.preventDefault();
												addMemberUserId = om.user_id;
												addMember();
											}}
										>
											{#if om.user.avatar_url}
												<img
													src={om.user.avatar_url}
													alt={om.user.full_name}
													class="h-5 w-5 rounded-full object-cover"
												/>
											{:else}
												<span
													class="flex h-5 w-5 items-center justify-center rounded-full bg-accent/20 text-[9px] font-medium text-accent"
												>
													{om.user.full_name.charAt(0)}
												</span>
											{/if}
											<span class="truncate text-sidebar-text">{om.user.full_name}</span>
										</button>
									{:else}
										<p class="px-3 py-3 text-xs text-muted">No more users available.</p>
									{/each}
								</div>
								<button
									class="w-full border-t border-surface-border px-3 py-2 text-left text-[11px] text-muted transition-colors hover:bg-surface-hover"
									onmousedown={(e) => {
										e.preventDefault();
										e.stopPropagation();
										addMemberRoleId = '';
									}}
								>
									&larr; Back to roles
								</button>
							{:else}
								<div class="border-b border-surface-border px-3 py-2">
									<span class="text-[10px] font-medium tracking-wider text-sidebar-icon uppercase"
										>Select role first</span
									>
								</div>
								<div class="max-h-56 overflow-y-auto py-1">
									{#each roles as role (role.id)}
										<button
											class="flex w-full items-center px-3 py-2 text-left text-xs text-sidebar-text transition-colors hover:bg-surface-hover"
											onmousedown={(e) => {
												e.preventDefault();
												e.stopPropagation();
												addMemberRoleId = role.id;
											}}
										>
											{role.name}
										</button>
									{:else}
										<p class="px-3 py-3 text-xs text-muted">No roles found.</p>
									{/each}
								</div>
							{/if}
						</div>
					{/if}
				</div>
				{/if}
			</div>

			{#if project.members && project.members.length > 0}
				<div class="flex flex-wrap gap-3">
					{#each project.members as member (member.user_id)}
						<div
							class="group flex items-center gap-2 border border-surface-border bg-surface px-3 py-2"
						>
							{#if member.user.avatar_url}
								<img
									src={member.user.avatar_url}
									alt={member.user.full_name}
									class="h-6 w-6 rounded-full object-cover"
								/>
							{:else}
								<div
									class="flex h-6 w-6 items-center justify-center rounded-full bg-accent/20 text-[10px] font-medium text-accent"
								>
									{member.user.full_name.charAt(0)}
								</div>
							{/if}
							<div class="min-w-0">
								<p class="truncate text-xs font-medium text-sidebar-text">
									{member.user.full_name}
								</p>
								{#if member.role}
									<p class="text-[10px] text-muted">{member.role.name}</p>
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
				<p class="text-xs text-muted">No members yet.</p>
			{/if}
		</div>

		<!-- Tasks -->
		<div class="flex items-center justify-between px-4 pt-4 pb-2">
			<h2 class="text-[11px] font-medium tracking-wider text-sidebar-icon uppercase">
				Tasks
				{#if taskStore.count > 0}
					<span class="ml-1 text-muted">({taskStore.count})</span>
				{/if}
			</h2>
			{#if canCreateTask}
				<button
					class="flex items-center gap-1 text-[11px] font-medium text-accent transition-colors hover:text-accent/80"
					onclick={() => (createModalOpen = true)}
				>
					<Plus size={13} /> Add
				</button>
			{/if}
		</div>

		{#if taskStore.loading}
			<p class="px-4 py-8 text-center text-sm text-muted">Loading tasks...</p>
		{:else if taskStore.error}
			<p class="px-4 py-8 text-center text-sm text-red-500">{taskStore.error}</p>
		{:else if taskTree.length === 0}
			<p class="px-4 py-8 text-center text-sm text-muted">No tasks in this project yet.</p>
		{:else}
			<div>
				{#each taskTree as { task, depth } (task.id)}
					<TaskRow {task} {depth} onclick={() => selectTask(task.id)} />
				{/each}
			</div>
		{/if}
	{/if}
</div>

{#if createModalOpen && project}
	<CreateTaskModal
		projectId={project.id}
		onClose={() => (createModalOpen = false)}
		onCreated={(id) => selectTask(id)}
	/>
{/if}

{#if selectedTaskId}
	<TaskDetailPanel
		taskId={selectedTaskId}
		members={(project?.members ?? []).map((m) => ({
			user_id: m.user_id,
			user: { id: m.user.id, full_name: m.user.full_name, avatar_url: m.user.avatar_url }
		}))}
		onClose={() => selectTask(null)}
	/>
{/if}
