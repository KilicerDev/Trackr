<script lang="ts">
	import ClientHeader from '$lib/assets/components/ClientHeader.svelte';
	import type { LayoutData } from './$types';
	import type { Snippet } from 'svelte';

	let { data, children }: { data: LayoutData; children: Snippet } = $props();
</script>

<div class="flex min-h-screen flex-col bg-page-bg">
	<ClientHeader organizations={data.organizations} />
	<main class="flex-1 min-h-0">
		{@render children()}
	</main>
</div>
