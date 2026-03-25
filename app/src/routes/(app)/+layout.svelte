<script lang="ts">
	import { untrack } from 'svelte';
	import { browser } from '$app/environment';
	import Sidebar from '$lib/assets/components/Sidebar.svelte';
	import Header from '$lib/assets/components/Header.svelte';
	import SearchPalette from '$lib/components/SearchPalette.svelte';
	import { auth } from '$lib/stores/auth.svelte';
	import { notificationCenter } from '$lib/stores/notificationCenter.svelte';
	import { updateChecker } from '$lib/stores/updateChecker.svelte';

	let { children } = $props();
	let pinned = $state(
		browser ? document.documentElement.dataset.sidebarPinned !== 'false' : true
	);

	$effect(() => {
		if (browser) {
			localStorage.setItem('sidebar-pinned', String(pinned));
			// Remove the data attribute after hydration so the CSS overrides in app.html
			// stop interfering — Svelte's own {#if expanded} handles visibility from here.
			delete document.documentElement.dataset.sidebarPinned;
		}
	});

	$effect(() => {
		const userId = auth.user?.id;
		if (!userId) return;
		const isAdmin = auth.isAdminRole;

		untrack(() => {
			notificationCenter.init(userId);
			if (isAdmin) updateChecker.check();
		});

		return () => notificationCenter.destroy();
	});
</script>

<SearchPalette />
<Sidebar bind:pinned />
<div class="flex h-dvh flex-col bg-page-bg transition-[margin-left] duration-200 ease-in-out" style="margin-left: {pinned ? '220px' : '56px'}">
    <Header />
	<div class="min-h-0 flex-1 overflow-y-auto">
		{@render children()}
	</div>
</div>