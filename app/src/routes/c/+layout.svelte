<script lang="ts">
	import ClientSidebar from '$lib/assets/components/ClientSidebar.svelte';
	import type { LayoutData } from './$types';
	import type { Snippet } from 'svelte';

	let { data, children }: { data: LayoutData; children: Snippet } = $props();
</script>

<ClientSidebar organizations={data.organizations} />
<div class="min-h-screen bg-page-bg" style="margin-left: 260px">
	{@render children()}
</div>
