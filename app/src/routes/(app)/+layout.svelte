<script lang="ts">
	import Sidebar from '$lib/assets/components/Sidebar.svelte';
	import Header from '$lib/assets/components/Header.svelte';
	import SearchPalette from '$lib/components/SearchPalette.svelte';
	import { auth } from '$lib/stores/auth.svelte';
	import { notificationCenter } from '$lib/stores/notificationCenter.svelte';
	import { updateChecker } from '$lib/stores/updateChecker.svelte';

	let { children } = $props();
	let pinned = $state(true);

	$effect(() => {
		const userId = auth.user?.id;
		if (!userId) return;
		notificationCenter.init(userId);
		if (auth.isAdminRole) updateChecker.check();
		return () => notificationCenter.destroy();
	});
</script>

<SearchPalette />
<Sidebar bind:pinned />
<div class="min-h-screen bg-page-bg transition-[margin-left] duration-200 ease-in-out" style="margin-left: {pinned ? '240px' : '64px'}">
    <Header />
	{@render children()}
</div>