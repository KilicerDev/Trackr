<script lang="ts">
	import { page } from '$app/state';
	import { ShieldAlert, AlertTriangle, ArrowLeft } from '@lucide/svelte';
</script>

<div class="flex min-h-screen flex-col items-center justify-center bg-page-bg px-6 text-center">
	{#if page.status === 403}
		<div class="mb-4 flex h-14 w-14 items-center justify-center bg-red-500/10">
			<ShieldAlert size={28} class="text-red-500" />
		</div>
		<h1 class="text-lg font-semibold text-sidebar-text">Unauthorized</h1>
		<p class="mt-2 max-w-sm text-sm text-sidebar-icon">
			You don't have permission to view this page.
		</p>
	{:else}
		<div class="mb-4 flex h-14 w-14 items-center justify-center bg-yellow-500/10">
			<AlertTriangle size={28} class="text-yellow-500" />
		</div>
		<h1 class="text-lg font-semibold text-sidebar-text">{page.status}</h1>
		<p class="mt-2 max-w-sm text-sm text-sidebar-icon">
			{page.error?.message ?? 'Something went wrong.'}
		</p>
	{/if}

	<button
		onclick={() => history.back()}
		class="mt-6 inline-flex cursor-pointer items-center gap-2 border border-surface-border bg-surface px-4 py-2 text-xs font-medium text-sidebar-text transition-colors hover:border-sidebar-icon/30 hover:bg-surface-hover"
	>
		<ArrowLeft size={14} />
		Go Back
	</button>
</div>
