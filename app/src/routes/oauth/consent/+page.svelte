<svelte:head><title>Authorize — Trackr</title></svelte:head>

<script lang="ts">
	import type { PageData } from './$types';

	let { data }: { data: PageData } = $props();

	const scopes = data.scope.split(/\s+/).filter(Boolean);
</script>

<div class="mx-auto flex min-h-screen max-w-md flex-col items-center justify-center px-6">
	<div class="w-full rounded-md border border-surface-border bg-surface p-6 shadow-lg shadow-black/15">
		<div class="flex items-center gap-3">
			{#if data.client.logo_uri}
				<img src={data.client.logo_uri} alt="" class="h-10 w-10 rounded-sm" />
			{/if}
			<div>
				<h1 class="text-lg font-semibold text-sidebar-text">{data.client.name}</h1>
				<p class="text-xs text-muted/60">wants to connect to your Trackr account</p>
			</div>
		</div>

		<div class="mt-5 rounded-sm bg-surface-hover/40 p-3 text-sm text-sidebar-text">
			<p class="mb-2 text-xs uppercase tracking-wide text-muted/50">It will be able to</p>
			<ul class="space-y-1">
				{#each scopes as s (s)}
					<li class="flex items-center gap-2">
						<span class="h-1.5 w-1.5 rounded-full bg-accent/60"></span>
						<span>{s === 'mcp' ? 'Read and modify your Trackr data (tasks, tickets, wiki, projects)' : s}</span>
					</li>
				{/each}
			</ul>
		</div>

		<p class="mt-4 text-xs text-muted/60">
			Redirects back to <span class="font-mono text-sidebar-text">{data.redirectUri}</span>
		</p>

		{#if data.client.uri}
			<p class="mt-2 text-xs text-muted/60">
				<a href={data.client.uri} target="_blank" rel="noopener noreferrer" class="underline">
					{data.client.uri}
				</a>
			</p>
		{/if}

		<form method="POST" class="mt-6 flex flex-col gap-2">
			<input type="hidden" name="authorization_id" value={data.authorizationId} />
			<button
				type="submit"
				formaction="?/approve"
				class="flex w-full items-center justify-center rounded-sm bg-accent px-3 py-2 text-sm font-medium text-white transition hover:bg-accent/90"
			>
				Allow
			</button>
			<button
				type="submit"
				formaction="?/deny"
				class="flex w-full items-center justify-center rounded-sm bg-surface-hover/40 px-3 py-2 text-sm text-muted hover:bg-surface-hover/60"
			>
				Deny
			</button>
		</form>

		<p class="mt-4 text-center text-xs text-muted/40">
			Trackr did not verify this application. Make sure you recognise it before granting access.
		</p>
	</div>
</div>
