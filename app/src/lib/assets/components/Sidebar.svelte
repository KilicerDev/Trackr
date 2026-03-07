<script lang="ts">
	import { page } from '$app/state';
	import { sidebarSections } from '$lib/config/sidebar';
	import { auth } from '$lib/stores/auth.svelte';
	import { updateChecker } from '$lib/stores/updateChecker.svelte';
	import { PanelLeftClose, PanelLeftOpen, ArrowUpCircle, X } from '@lucide/svelte';
	import logo from '$lib/assets/logo.png';
	import { localizeHref } from '$lib/paraglide/runtime';

	let { pinned = $bindable(false) } = $props();

	let hovered = $state(false);
	let expanded = $derived(pinned || hovered);
	let showUpdateBanner = $derived(
		auth.isAdminRole && updateChecker.hasUpdate && !updateChecker.dismissed
	);
	let filteredSections = $derived(
		sidebarSections
			.filter((s) => s.title !== 'Administration' || auth.isAdminRole)
			.map((s) => ({
				...s,
				items: s.items.filter((item) => {
					if (!item.requiredPermission) return true;
					return auth.can(item.requiredPermission.resource, item.requiredPermission.action);
				})
			}))
			.filter((s) => s.items.length > 0)
	);
</script>

<aside
	class="fixed top-0 left-0 z-50 flex h-screen flex-col border-r border-sidebar-border bg-sidebar-bg transition-all duration-200 ease-in-out"
	style="width: {expanded ? '240px' : '64px'}"
	onmouseenter={() => { if (!pinned) hovered = true; }}
	onmouseleave={() => { if (!pinned) hovered = false; }}
>
	<div class="flex h-14 items-center gap-2 overflow-hidden px-4">
		<img src={logo} alt="Trackr" class="h-7 w-7 shrink-0" />
		{#if expanded}
			<span
				class="whitespace-nowrap text-lg font-bold tracking-widest text-sidebar-text transition-opacity duration-200"
			>
				TRACKR
			</span>
		{/if}
	</div>

	<nav class="flex-1 overflow-y-auto overflow-x-hidden py-2">
		{#each filteredSections as section (section.title)}
			<div class="overflow-hidden px-4 pt-3 pb-1 text-[10px] font-semibold tracking-widest text-sidebar-label uppercase">
				{#if expanded}
					<span class="whitespace-nowrap">{section.title}</span>
				{:else}
					&nbsp;
				{/if}
			</div>

			{#each section.items as item (item.href)}
				{@const isActive = page.url.pathname === item.href || (item.href !== '/' && page.url.pathname.startsWith(item.href))}
				<a
					href={localizeHref(item.href)}
					class="group relative flex h-10 items-center gap-3 px-5 text-sm transition-colors duration-150
						{isActive
							? 'bg-sidebar-hover-bg font-semibold text-accent'
							: 'text-sidebar-icon hover:bg-sidebar-hover-bg hover:text-sidebar-text'}"
				>
					{#if isActive}
						<span class="absolute top-0 left-0 h-full w-[3px] bg-accent"></span>
					{/if}
					<item.icon size={20} class="shrink-0" />
					{#if expanded}
						<span class="truncate whitespace-nowrap">{item.label}</span>
					{/if}
				</a>
			{/each}
		{/each}
	</nav>

	{#if showUpdateBanner}
		<div class="border-t border-sidebar-border">
			{#if expanded}
				<div class="relative flex items-start gap-2.5 px-4 py-3">
					<ArrowUpCircle size={18} class="mt-0.5 shrink-0 text-accent" />
					<div class="min-w-0 flex-1">
						<p class="text-xs font-semibold text-sidebar-text">Update available</p>
						<p class="mt-0.5 text-[10px] text-muted">
							v{updateChecker.latestVersion}
							{#if updateChecker.changelog}
								&mdash; {updateChecker.changelog}
							{/if}
						</p>
						{#if updateChecker.releaseUrl}
							<a
								href={updateChecker.releaseUrl}
								target="_blank"
								rel="noopener noreferrer"
								class="mt-1.5 inline-block text-[11px] font-medium text-accent hover:underline"
							>
								View release
							</a>
						{/if}
					</div>
					<button
						onclick={() => updateChecker.dismiss()}
						class="shrink-0 p-0.5 text-sidebar-icon transition-colors hover:text-sidebar-text"
						aria-label="Dismiss"
					>
						<X size={14} />
					</button>
				</div>
			{:else}
				<div class="flex justify-center py-3">
					<span class="relative">
						<ArrowUpCircle size={20} class="text-accent" />
						<span class="absolute -top-0.5 -right-0.5 h-2 w-2 rounded-full bg-red-500"></span>
					</span>
				</div>
			{/if}
		</div>
	{/if}

	<div class="border-t border-sidebar-border py-2">
		<button
			onclick={() => { pinned = !pinned; hovered = false; }}
			class="flex h-10 w-full cursor-pointer items-center gap-3 px-5 text-sm text-sidebar-icon transition-colors duration-150 hover:bg-sidebar-hover-bg hover:text-sidebar-text"
		>
			{#if pinned}
				<PanelLeftClose size={20} class="shrink-0" />
			{:else}
				<PanelLeftOpen size={20} class="shrink-0" />
			{/if}
			{#if expanded}
				<span class="truncate whitespace-nowrap">{pinned ? 'Collapse' : 'Expand'}</span>
			{/if}
		</button>
	</div>
</aside>
