<svelte:head><title>Projects – Trackr</title></svelte:head>

<script lang="ts">
	import { onMount } from 'svelte';
	import { slide } from 'svelte/transition';
	import { page } from '$app/state';
	import { replaceState } from '$app/navigation';
	import { auth } from '$lib/stores/auth.svelte';
	import { projectStore } from '$lib/stores/projects.svelte';
	import { orgStore } from '$lib/stores/organizations.svelte';
	import { clickOutside } from '$lib/actions/clickOutside';
	import { localizeHref } from '$lib/paraglide/runtime';
	import { Users, ChevronDown } from '@lucide/svelte';
	import CreateProjectModal from '$lib/components/CreateProjectModal.svelte';

	let collapsedGroups = $state<Set<string>>(new Set());

	function toggleGroupCollapse(key: string) {
		const next = new Set(collapsedGroups);
		if (next.has(key)) next.delete(key);
		else next.add(key);
		collapsedGroups = next;
	}

	const PROJECT_STATUSES = ['planning', 'active', 'paused', 'completed', 'archived'] as const;

	const statusColors: Record<string, string> = {
		planning: 'bg-blue-100 text-blue-700 dark:bg-blue-950/60 dark:text-blue-300',
		active: 'bg-green-100 text-green-700 dark:bg-green-950/60 dark:text-green-300',
		paused: 'bg-yellow-100 text-yellow-700 dark:bg-yellow-950/60 dark:text-yellow-300',
		completed: 'bg-purple-100 text-purple-700 dark:bg-purple-950/60 dark:text-purple-300',
		archived: 'bg-gray-100 text-gray-500 dark:bg-surface-hover dark:text-muted'
	};

	const initStatus = page.url.searchParams.get('status') ?? '';
	const initOrg = page.url.searchParams.get('org') ?? null;

	let selectedOrgId = $state<string | null>(initOrg ?? projectStore.lastLoadedOrgId ?? '__all__');
	let orgDropdownOpen = $state(false);
	let statusFilter = $state<string>(
		(PROJECT_STATUSES as readonly string[]).includes(initStatus) ? initStatus : ''
	);
	let createModalOpen = $state(false);

	const ALL_ORGS = '__all__';
	const isAllOrgs = $derived(selectedOrgId === ALL_ORGS);

	const organizations = $derived(orgStore.all);
	const selectedOrg = $derived(
		isAllOrgs ? null : (organizations.find((o) => o.id === selectedOrgId) ?? null)
	);
	const orgDropdownLabel = $derived(
		isAllOrgs
			? 'All Organizations'
			: (selectedOrg?.name ?? (selectedOrgId ? 'Loading…' : 'Select Organization'))
	);

	const orgNameMap = $derived(
		Object.fromEntries(organizations.map((o) => [o.id, o.name]))
	);

	const filteredProjects = $derived(
		statusFilter
			? projectStore.items.filter((p) => p.status === statusFilter)
			: projectStore.items
	);

	const groupedProjects = $derived.by(() => {
		if (!isAllOrgs) return null;
		const groups: { orgId: string; orgName: string; projects: typeof filteredProjects }[] = [];
		const map = new Map<string, typeof filteredProjects>();
		const order: string[] = [];

		for (const p of filteredProjects) {
			const oid = p.organization_id;
			if (!map.has(oid)) {
				map.set(oid, []);
				order.push(oid);
			}
			map.get(oid)!.push(p);
		}

		for (const oid of order) {
			const first = map.get(oid)![0];
			const org = (first as Record<string, unknown>).organization as { name: string } | null;
			const orgName = orgNameMap[oid] ?? org?.name ?? 'Unknown';
			groups.push({ orgId: oid, orgName, projects: map.get(oid)! });
		}

		return groups;
	});

	function syncUrlParams() {
		const url = new URL(window.location.href);
		if (selectedOrgId) url.searchParams.set('org', selectedOrgId);
		else url.searchParams.delete('org');
		if (statusFilter) url.searchParams.set('status', statusFilter);
		else url.searchParams.delete('status');
		replaceState(localizeHref(url.pathname + url.search), {});
	}

	function selectOrg(orgId: string | null) {
		selectedOrgId = orgId;
		orgDropdownOpen = false;
		syncUrlParams();
		if (orgId === ALL_ORGS) {
			projectStore.loadAll();
		} else if (orgId) {
			projectStore.load(orgId);
		} else {
			projectStore.clear();
		}
	}

	function setStatusFilter(value: string) {
		statusFilter = value;
		syncUrlParams();
	}

	function formatDate(dateStr: string | null): string {
		if (!dateStr) return '—';
		const d = new Date(dateStr);
		if (isNaN(d.getTime())) return '—';
		return d.toLocaleDateString('de-DE', { day: '2-digit', month: '2-digit', year: 'numeric' });
	}

	function formatStatus(status: string): string {
		return status.charAt(0).toUpperCase() + status.slice(1);
	}

	const platformOrgId = $derived(orgStore.platformOrgId);

	onMount(async () => {
		await orgStore.loadIfNeeded();

		if (initOrg === ALL_ORGS || (!initOrg && !projectStore.lastLoadedOrgId)) {
			selectedOrgId = ALL_ORGS;
		} else if (initOrg && organizations.some((o) => o.id === initOrg)) {
			selectedOrgId = initOrg;
		} else if (!selectedOrgId || !organizations.some((o) => o.id === selectedOrgId)) {
			selectedOrgId = ALL_ORGS;
		}

		syncUrlParams();

		if (selectedOrgId === ALL_ORGS) {
			projectStore.loadAll();
		} else if (selectedOrgId) {
			projectStore.loadIfNeeded(selectedOrgId);
		}
	});
</script>

<div
	class="mx-auto w-full"
	use:clickOutside={{
		onClickOutside: () => {
			orgDropdownOpen = false;
		},
		enabled: orgDropdownOpen
	}}
>
	<div class="flex items-center justify-between px-3 py-1.5">
		<div class="flex items-center gap-1">
			<div class="relative">
				<button
					class="flex h-7 min-w-[11rem] cursor-pointer items-center justify-between gap-2 rounded-sm bg-surface-hover/40 px-2.5 text-sm font-medium text-sidebar-text transition-all duration-150 hover:bg-surface-hover/60"
					onclick={() => (orgDropdownOpen = !orgDropdownOpen)}
				>
					<span>{orgDropdownLabel}</span>
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
						class="flex w-full items-center gap-2 px-2.5 py-1.5 text-left text-sm transition-colors hover:bg-surface-hover/60 {isAllOrgs
							? 'font-medium text-accent'
							: 'text-muted'}"
						onmousedown={(e) => {
							e.preventDefault();
							selectOrg(ALL_ORGS);
						}}
					>
						<span class="whitespace-nowrap">All Organizations</span>
					</button>
					<div class="mx-2.5 my-1 h-px bg-surface-border/30"></div>
					{#each organizations as org (org.id)}
						<button
							class="flex w-full items-center gap-2 px-2.5 py-1.5 text-left text-sm transition-colors hover:bg-surface-hover/60 {!isAllOrgs && selectedOrgId ===
							org.id
								? 'font-medium text-accent'
								: 'text-muted'}"
							onmousedown={(e) => {
								e.preventDefault();
								selectOrg(org.id);
							}}
						>
							<span class="whitespace-nowrap">{org.name}</span>
							{#if org.id === platformOrgId}
								<span class="shrink-0 whitespace-nowrap rounded-sm bg-accent/15 px-1.5 py-0.5 text-2xs font-semibold uppercase tracking-wide text-accent">
									Internal
								</span>
							{/if}
						</button>
					{/each}
				</div>
			{/if}
			</div>

			<div class="h-4 w-px bg-surface-border"></div>
			<div class="flex items-center gap-0.5">
				<button
					class="flex h-7 items-center rounded-sm px-2 text-sm font-medium transition-all duration-150 {statusFilter === ''
						? 'text-accent'
						: 'text-muted hover:text-sidebar-text'}"
					onclick={() => setStatusFilter('')}
				>
					All
				</button>
				{#each PROJECT_STATUSES as s (s)}
					<button
						class="flex h-7 items-center rounded-sm px-2 text-sm font-medium transition-all duration-150 {statusFilter ===
						s
							? 'text-accent'
							: 'text-muted hover:text-sidebar-text'}"
						onclick={() => setStatusFilter(s)}
					>
						{formatStatus(s)}
					</button>
				{/each}
			</div>
		</div>

		{#if auth.can('projects', 'create') && !isAllOrgs}
			<button
				class="flex h-7 items-center gap-1 rounded-sm bg-accent px-2.5 text-sm font-medium text-white transition-all duration-150 hover:bg-accent/90"
				onclick={() => (createModalOpen = true)}
			>
				New Project
			</button>
		{/if}
	</div>

	{#if createModalOpen && selectedOrgId && !isAllOrgs}
		<CreateProjectModal
			organizationId={selectedOrgId}
			organizationName={selectedOrg?.name ?? ''}
			onClose={() => (createModalOpen = false)}
			onSuccess={() => {
				if (selectedOrgId) projectStore.load(selectedOrgId);
			}}
		/>
	{/if}

	{#snippet projectRow(project: typeof filteredProjects[number])}
		<a
			href={localizeHref(`/projects/${project.id}`)}
			class="group flex w-full items-center gap-4 px-3 py-[7px] transition-all duration-150 hover:bg-surface-hover/40"
		>
			<span
				class="h-1.5 w-1.5 shrink-0 rounded-full"
				style="background-color: {project.color ?? 'var(--color-accent)'}"
			></span>

			<span class="shrink-0 w-[60px] font-mono text-xs text-muted/50">
				{project.identifier}
			</span>

			<span class="min-w-0 flex-1 truncate text-base text-sidebar-text">
				{project.name}
			</span>

			<span
				class="shrink-0 text-xs text-muted/50"
			>
				{formatStatus(project.status)}
			</span>

			<span class="shrink-0 flex items-center gap-1 text-xs text-muted/50 w-[50px]">
				<Users size={12} />
				{project.members?.length ?? 0}
			</span>

			<span class="shrink-0 w-[90px] text-right font-mono text-xs text-muted/50">
				{formatDate(project.start_at)}
			</span>

			{#if project.owner}
				<span class="shrink-0 flex items-center gap-1.5 w-[130px]">
					{#if project.owner.avatar_url}
						<img
							src={project.owner.avatar_url}
							alt={project.owner.full_name}
							class="h-5 w-5 rounded-full object-cover"
						/>
					{:else}
						<span
							class="flex h-5 w-5 items-center justify-center rounded-full bg-accent/20 text-xs font-medium text-accent"
						>
							{project.owner.full_name.charAt(0)}
						</span>
					{/if}
					<span class="truncate text-xs text-muted/50">{project.owner.full_name}</span>
				</span>
			{/if}
		</a>
	{/snippet}

	{#if !selectedOrgId}
		<p class="px-4 py-12 text-center text-sm text-muted">
			Select an organization to view projects.
		</p>
	{:else if projectStore.loading}
		<p class="px-4 py-12 text-center text-sm text-muted">Loading...</p>
	{:else if projectStore.error}
		<p class="px-4 py-12 text-center text-sm text-red-500">{projectStore.error}</p>
	{:else if filteredProjects.length === 0}
		<div class="flex flex-col items-center gap-3 px-4 py-12">
			<p class="text-sm text-muted">{statusFilter ? 'No projects match this filter.' : 'No projects yet.'}</p>
			{#if !statusFilter && selectedOrgId && !isAllOrgs}
				<button
					class="flex h-7 items-center justify-center gap-1 rounded-sm bg-accent px-2.5 text-sm leading-none font-medium text-white transition-all duration-150 hover:bg-accent/90"
					onclick={() => (createModalOpen = true)}
				>
					New project
				</button>
			{/if}
		</div>
	{:else if isAllOrgs && groupedProjects}
		<div class="space-y-1 p-3">
			{#each groupedProjects as group (group.orgId)}
				{@const isCollapsed = collapsedGroups.has(group.orgId)}
				<button
					class="flex w-full items-center gap-1.5 px-1 py-1 text-left"
					onclick={() => toggleGroupCollapse(group.orgId)}
				>
					<ChevronDown size={10} class="shrink-0 text-muted/30 transition-transform duration-150 {isCollapsed ? '-rotate-90' : ''}" />
					<span class="text-sm font-medium text-muted">{group.orgName}</span>
					<span class="text-xs text-muted/30">{group.projects.length}</span>
				</button>
				{#if !isCollapsed}
					<div transition:slide={{ duration: 150 }} class="mb-2 overflow-hidden rounded border border-surface-border/50 bg-surface/50">
						{#each group.projects as project, i (project.id)}
							{@render projectRow(project)}
							{#if i < group.projects.length - 1}
								<div class="mx-3 h-px bg-surface-border/30"></div>
							{/if}
						{/each}
					</div>
				{/if}
			{/each}
		</div>

		<p class="px-3 py-2 text-xs text-muted/50">
			{filteredProjects.length} project{filteredProjects.length === 1 ? '' : 's'} across {groupedProjects.length} organization{groupedProjects.length === 1 ? '' : 's'}
		</p>
	{:else}
		<div class="p-3">
			<div class="overflow-hidden rounded border border-surface-border/50 bg-surface/50">
				{#each filteredProjects as project, i (project.id)}
					{@render projectRow(project)}
					{#if i < filteredProjects.length - 1}
						<div class="mx-3 h-px bg-surface-border/30"></div>
					{/if}
				{/each}
			</div>
		</div>

		<p class="px-3 py-2 text-xs text-muted/50">
			{filteredProjects.length} project{filteredProjects.length === 1 ? '' : 's'}
		</p>
	{/if}
</div>
