<script lang="ts">
	import ClientSidebar from '$lib/assets/components/ClientSidebar.svelte';
	import NotificationContainer from '$lib/components/NotificationContainer.svelte';
	import type { LayoutData } from './$types';

	let { data, children }: { data: LayoutData; children: any } = $props();
</script>

<ClientSidebar organizations={data.organizations} />
<div class="min-h-screen bg-page-bg" style="margin-left: 260px">
	{@render children()}
</div>
