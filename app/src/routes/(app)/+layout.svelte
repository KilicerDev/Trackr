<script lang="ts">
	import Sidebar from '$lib/assets/components/Sidebar.svelte';

	let { children } = $props();
	let pinned = $state(false);
</script>

<Sidebar bind:pinned />
<div class="min-h-screen transition-[margin-left] duration-200 ease-in-out" style="margin-left: {pinned ? '240px' : '64px'}">
	{@render children()}
</div>