<script lang="ts">
	import Sidebar from '$lib/assets/components/Sidebar.svelte';
	import Header from '$lib/assets/components/Header.svelte';
	import { auth } from '$lib/stores/auth.svelte';
	import { notificationCenter } from '$lib/stores/notificationCenter.svelte';

	let { children } = $props();
	let pinned = $state(true);

	$effect(() => {
		const userId = auth.user?.id;
		if (!userId) return;
		notificationCenter.init(userId);
		return () => notificationCenter.destroy();
	});
</script>

<Sidebar bind:pinned />
<div class="min-h-screen bg-page-bg transition-[margin-left] duration-200 ease-in-out" style="margin-left: {pinned ? '240px' : '64px'}">
    <Header />
	{@render children()}
</div>