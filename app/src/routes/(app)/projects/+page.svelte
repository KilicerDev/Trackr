<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/state';
	import { replaceState } from '$app/navigation';
	import { auth } from '$lib/stores/auth.svelte';
	import { projectStore } from '$lib/stores/projects.svelte';
	import { orgStore } from '$lib/stores/organizations.svelte';
	import { clickOutside } from '$lib/actions/clickOutside';
	import { localizeHref } from '$lib/paraglide/runtime';
	import { Users } from '@lucide/svelte';
	import CreateProjectModal from '$lib/components/CreateProjectModal.svelte';

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

	let selectedOrgId = $state<string | null>(initOrg ?? projectStore.lastLoadedOrgId);
	let orgDropdownOpen = $state(false);
	let statusFilter = $state<string>(
		(PROJECT_STATUSES as readonly string[]).includes(initStatus) ? initStatus : ''
	);
	let createModalOpen = $state(false);

	const organizations = $derived(orgStore.all);
	const selectedOrg = $derived(organizations.find((o) => o.id === selectedOrgId) ?? null);
	const orgDropdownLabel = $derived(
		selectedOrg?.name ?? (selectedOrgId ? 'Loading…' : 'Select Organization')
	);

	const filteredProjects = $derived(
		statusFilter
			? projectStore.items.filter((p) => p.status === statusFilter)
			: projectStore.items
	);

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
		if (orgId) {
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

		if (initOrg && organizations.some((o) => o.id === initOrg)) {
			selectedOrgId = initOrg;
		} else if (!selectedOrgId || !organizations.some((o) => o.id === selectedOrgId)) {
			const orgId = auth.organizationId;
			selectedOrgId = organizations.some((o) => o.id === orgId) ? orgId : null;
		}

		syncUrlParams();

		if (selectedOrgId) {
			projectStore.loadIfNeeded(selectedOrgId);
		}
	});
</script>

<div
	class="mx-auto w-full max-w-[1200px]"
	use:clickOutside={{
		onClickOutside: () => {
			orgDropdownOpen = false;
		},
		enabled: orgDropdownOpen
	}}
>
	<div class="flex items-center justify-between border-b border-surface-border px-4 py-3">
		<div class="flex items-center gap-3">
			<div class="relative">
				<button
					class="flex min-w-[11rem] cursor-pointer items-center justify-between gap-2 border border-surface-border bg-surface px-3 py-2 text-xs font-medium text-sidebar-text shadow-sm transition-colors hover:border-sidebar-icon/30 hover:bg-surface-hover"
					onclick={() => (orgDropdownOpen = !orgDropdownOpen)}
				>
					<span>{orgDropdownLabel}</span>
					<svg
						class="h-4 w-4 shrink-0 text-sidebar-icon transition-transform {orgDropdownOpen
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
						class="absolute left-0 z-10 mt-1.5 min-w-[200px] overflow-hidden border border-surface-border bg-surface py-1 shadow-xl"
					>
						{#each organizations as org (org.id)}
							<button
								class="flex w-full items-center gap-2 px-4 py-2.5 text-left text-xs transition-colors hover:bg-surface-hover {selectedOrgId ===
								org.id
									? 'font-medium text-accent'
									: 'text-sidebar-text'}"
								onmousedown={(e) => {
									e.preventDefault();
									selectOrg(org.id);
								}}
							>
								<span class="whitespace-nowrap">{org.name}</span>
								{#if org.id === platformOrgId}
									<span class="shrink-0 whitespace-nowrap rounded-sm bg-accent/15 px-1.5 py-0.5 text-[9px] font-semibold uppercase tracking-wide text-accent">
										Internal
									</span>
								{/if}
							</button>
						{/each}
					</div>
				{/if}
			</div>

			<div class="flex items-center gap-1">
				<button
					class="border border-surface-border px-2.5 py-2 text-xs transition-colors {statusFilter === ''
						? 'bg-accent text-white'
						: 'bg-surface text-sidebar-text hover:bg-surface-hover'}"
					onclick={() => setStatusFilter('')}
				>
					All
				</button>
				{#each PROJECT_STATUSES as s (s)}
					<button
						class="border border-surface-border px-2.5 py-2 text-xs transition-colors {statusFilter ===
						s
							? 'bg-accent text-white'
							: 'bg-surface text-sidebar-text hover:bg-surface-hover'}"
						onclick={() => setStatusFilter(s)}
					>
						{formatStatus(s)}
					</button>
				{/each}
			</div>
		</div>

		{#if auth.can('projects', 'create')}
			<button
				class="bg-accent px-4 py-2 text-xs font-medium text-white shadow-sm transition-colors hover:bg-accent/90"
				onclick={() => (createModalOpen = true)}
			>
				New Project
			</button>
		{/if}
	</div>

	{#if createModalOpen}
		<CreateProjectModal
			organizationId={selectedOrgId}
			organizationName={selectedOrg?.name ?? ''}
			onClose={() => (createModalOpen = false)}
			onSuccess={() => {
				if (selectedOrgId) projectStore.load(selectedOrgId);
			}}
		/>
	{/if}

	{#if !selectedOrgId}
		<p class="px-4 py-12 text-center text-sm text-muted">
			Select an organization to view projects.
		</p>
	{:else if projectStore.loading}
		<p class="px-4 py-12 text-center text-sm text-muted">Loading...</p>
	{:else if projectStore.error}
		<p class="px-4 py-12 text-center text-sm text-red-500">{projectStore.error}</p>
	{:else if filteredProjects.length === 0}
		<p class="px-4 py-12 text-center text-sm text-muted">
			{statusFilter ? 'No projects match this filter.' : 'No projects yet.'}
		</p>
	{:else}
		<div>
			{#each filteredProjects as project (project.id)}
				<a
					href={localizeHref(`/projects/${project.id}`)}
					class="group flex w-full items-center gap-4 border-b border-surface-border px-4 py-3 transition-colors hover:bg-surface-hover"
				>
					<span
						class="h-2.5 w-2.5 shrink-0 rounded-full"
						style="background-color: {project.color ?? 'var(--color-accent)'}"
					></span>

					<span class="shrink-0 w-[60px] text-xs font-medium text-accent">
						{project.identifier}
					</span>

					<span class="min-w-0 flex-1 truncate text-sm text-sidebar-text">
						{project.name}
					</span>

					<span
						class="shrink-0 inline-flex min-w-[80px] justify-center px-2 py-0.5 text-[10px] font-medium {statusColors[
							project.status
						] ?? 'bg-gray-100 text-gray-500 dark:bg-surface-hover dark:text-muted'}"
					>
						{formatStatus(project.status)}
					</span>

					<span class="shrink-0 flex items-center gap-1 text-[11px] text-muted w-[50px]">
						<Users size={12} />
						{project.members?.length ?? 0}
					</span>

					<span class="shrink-0 w-[90px] text-right text-xs text-muted">
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
									class="flex h-5 w-5 items-center justify-center rounded-full bg-accent/20 text-[10px] font-medium text-accent"
								>
									{project.owner.full_name.charAt(0)}
								</span>
							{/if}
							<span class="truncate text-[11px] text-muted">{project.owner.full_name}</span>
						</span>
					{/if}
				</a>
			{/each}
		</div>

		<p class="px-4 py-3 text-xs text-muted">
			{filteredProjects.length} project{filteredProjects.length === 1 ? '' : 's'}
		</p>
	{/if}
</div>
