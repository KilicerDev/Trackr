<script lang="ts">
	import { page } from '$app/state';
	import { ShieldAlert, AlertTriangle, ArrowLeft } from '@lucide/svelte';
</script>

<div class="flex min-h-screen flex-col items-center justify-center bg-page-bg px-6 text-center">
	{#if page.status === 403}
		<div class="mb-3 flex h-10 w-10 items-center justify-center rounded bg-red-400/10">
			<ShieldAlert size={20} class="text-red-400" />
		</div>
		<h1 class="text-md font-semibold text-sidebar-text">Unauthorized</h1>
		<p class="mt-1.5 max-w-sm text-sm text-muted">
			You don't have permission to view this page.
		</p>
	{:else}
		<div class="mb-3 flex h-10 w-10 items-center justify-center rounded bg-yellow-400/10">
			<AlertTriangle size={20} class="text-yellow-400" />
		</div>
		<h1 class="text-md font-semibold text-sidebar-text">{page.status}</h1>
		<p class="mt-1.5 max-w-sm text-sm text-muted">
			{page.error?.message ?? 'Something went wrong.'}
		</p>
	{/if}

	<button
		onclick={() => history.back()}
		class="mt-5 inline-flex h-7 cursor-pointer items-center gap-1.5 rounded-sm bg-surface-hover/40 px-2.5 text-sm font-medium text-sidebar-text transition-all duration-150 hover:bg-surface-hover/60"
	>
		<ArrowLeft size={12} />
		Go Back
	</button>
</div>
