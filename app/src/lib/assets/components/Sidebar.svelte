<script lang="ts">
	import { page } from '$app/state';
	import { sidebarSections } from '$lib/config/sidebar';
	import { auth } from '$lib/stores/auth.svelte';
	import { updateChecker } from '$lib/stores/updateChecker.svelte';
	import { PanelLeftClose, PanelLeftOpen, ArrowUpCircle, X } from '@lucide/svelte';
	import logo from '$lib/assets/logo.png';
	import { localizeHref } from '$lib/paraglide/runtime';

	const profileActive = $derived(page.url.pathname === '/profile' || page.url.pathname.startsWith('/profile'));

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
	data-admin-sidebar
	class="fixed top-0 left-0 z-50 flex h-screen flex-col border-r border-sidebar-border bg-sidebar-bg transition-[width] duration-200 ease-out"
	style="width: {expanded ? '220px' : '56px'}"
	onmouseenter={() => { if (!pinned) hovered = true; }}
	onmouseleave={() => { if (!pinned) hovered = false; }}
>
	<!-- Logo -->
	<div class="flex h-12 items-center gap-2.5 overflow-hidden px-3.5">
		<img src={logo} alt="Trackr" class="h-6 w-6 shrink-0" />
		{#if expanded}
			<span
				style="font-family: 'GeistMono', monospace"
				class="whitespace-nowrap text-md font-bold tracking-[0.2em] text-sidebar-text"
			>
				TRACKR
			</span>
		{/if}
	</div>

	<!-- Navigation -->
	<nav class="flex-1 space-y-4 overflow-y-auto overflow-x-hidden px-2 py-2">
		{#each filteredSections as section (section.title)}
			<div>
				<div class="mb-1 flex h-5 items-center px-2">
					{#if expanded}
						<span class="whitespace-nowrap text-xs font-medium tracking-[0.08em] text-sidebar-label/70 uppercase">{section.title}</span>
					{:else}
						<span class="h-px w-full bg-sidebar-border"></span>
					{/if}
				</div>

				<div class="space-y-0.5">
					{#each section.items as item (item.href)}
						{@const isActive = page.url.pathname === item.href || (item.href !== '/' && page.url.pathname.startsWith(item.href))}
						<a
							href={localizeHref(item.href)}
							class="group relative flex h-8 items-center gap-2.5 rounded-sm px-2.5 text-md transition-all duration-150
								{isActive
									? 'bg-accent/10 font-medium text-accent'
									: 'text-sidebar-icon hover:bg-sidebar-hover-bg hover:text-sidebar-text'}"
						>
							<item.icon size={16} class="shrink-0" />
							{#if expanded}
								<span class="truncate whitespace-nowrap">{item.label}</span>
							{/if}
						</a>
					{/each}
				</div>
			</div>
		{/each}
	</nav>

	<!-- Update banner -->
	{#if showUpdateBanner}
		<div class="mx-2 mb-2">
			{#if expanded}
				<div class="relative flex items-start gap-2 rounded-sm bg-accent/8 px-3 py-2.5">
					<ArrowUpCircle size={16} class="mt-0.5 shrink-0 text-accent" />
					<div class="min-w-0 flex-1">
						<p class="text-sm font-medium text-sidebar-text">Update available</p>
						<p class="mt-0.5 text-xs text-muted">
							v{updateChecker.latestVersion}
						</p>
						{#if updateChecker.releaseUrl}
							<a
								href={updateChecker.releaseUrl}
								target="_blank"
								rel="noopener noreferrer"
								class="mt-1 inline-block text-xs font-medium text-accent hover:underline"
							>
								View release &rarr;
							</a>
						{/if}
					</div>
					<button
						onclick={() => updateChecker.dismiss()}
						class="shrink-0 rounded-sm p-0.5 text-muted transition-colors hover:bg-sidebar-hover-bg hover:text-sidebar-text"
						aria-label="Dismiss"
					>
						<X size={12} />
					</button>
				</div>
			{:else}
				<div class="flex justify-center py-2">
					<span class="relative">
						<ArrowUpCircle size={16} class="text-accent" />
						<span class="absolute -top-0.5 -right-0.5 h-1.5 w-1.5 rounded-full bg-accent"></span>
					</span>
				</div>
			{/if}
		</div>
	{/if}

	<!-- Profile -->
	<a
		href={localizeHref('/profile')}
		class="mx-2 flex items-center gap-2.5 rounded-sm px-2.5 py-1.5 transition-all duration-150
			{profileActive
				? 'bg-accent/10'
				: 'hover:bg-sidebar-hover-bg'}"
	>
		{#if auth.user?.avatar_url}
			<img
				src={auth.user.avatar_url}
				alt={auth.user.full_name}
				class="h-7 w-7 shrink-0 rounded-full object-cover"
			/>
		{:else}
			<div class="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-accent/10 text-sm font-medium text-accent">
				{auth.user?.full_name?.charAt(0)?.toUpperCase() ?? '?'}
			</div>
		{/if}
		{#if expanded}
			<div class="min-w-0 flex-1">
				<p class="truncate text-base font-medium {profileActive ? 'text-accent' : 'text-sidebar-text'}">
					{auth.user?.full_name ?? 'User'}
				</p>
				<p class="truncate text-xs text-muted/50">{auth.user?.email ?? ''}</p>
			</div>
		{/if}
	</a>

	<!-- Collapse toggle -->
	<div class="border-t border-sidebar-border px-2 py-1.5">
		<button
			onclick={() => { pinned = !pinned; hovered = false; }}
			class="flex h-8 w-full cursor-pointer items-center gap-2.5 rounded-sm px-2.5 text-md text-sidebar-icon transition-all duration-150 hover:bg-sidebar-hover-bg hover:text-sidebar-text"
		>
			{#if pinned}
				<PanelLeftClose size={16} class="shrink-0" />
			{:else}
				<PanelLeftOpen size={16} class="shrink-0" />
			{/if}
			{#if expanded}
				<span class="truncate whitespace-nowrap">{pinned ? 'Collapse' : 'Expand'}</span>
			{/if}
		</button>
	</div>
</aside>
