<script lang="ts">
	import Sidebar from '$lib/assets/components/Sidebar.svelte';
	import Header from '$lib/assets/components/Header.svelte';

	let { children } = $props();
	let pinned = $state(true);
</script>

<Sidebar bind:pinned />
<div class="min-h-screen bg-page-bg transition-[margin-left] duration-200 ease-in-out" style="margin-left: {pinned ? '240px' : '64px'}">
    <Header />
	{@render children()}
</div>