<script lang="ts">
	import { page } from '$app/state';
	import { ShieldAlert, ArrowLeft } from '@lucide/svelte';
</script>

<div class="flex min-h-[60vh] flex-col items-center justify-center px-6 text-center">
	{#if page.status === 403}
		<div class="mb-4 flex h-14 w-14 items-center justify-center rounded-full bg-red-500/10">
			<ShieldAlert size={28} class="text-red-500" />
		</div>
		<h1 class="text-lg font-semibold text-sidebar-text">Unauthorized</h1>
		<p class="mt-2 max-w-sm text-sm text-sidebar-icon">
			You don't have permission to view this page. Contact your administrator if you believe this is a mistake.
		</p>
	{:else}
		<h1 class="text-lg font-semibold text-sidebar-text">{page.status}</h1>
		<p class="mt-2 max-w-sm text-sm text-sidebar-icon">
			{page.error?.message ?? 'Something went wrong.'}
		</p>
	{/if}

	<a
		href="/"
		class="mt-6 inline-flex items-center gap-2 border border-surface-border bg-surface px-4 py-2 text-xs font-medium text-sidebar-text transition-colors hover:border-sidebar-icon/30 hover:bg-surface-hover"
	>
		<ArrowLeft size={14} />
		Back to Dashboard
	</a>
</div>
