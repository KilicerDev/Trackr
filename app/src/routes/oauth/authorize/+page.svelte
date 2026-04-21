<svelte:head><title>Authorize — Trackr</title></svelte:head>

<script lang="ts">
	import { enhance } from '$app/forms';
	import type { PageData } from './$types';

	let { data }: { data: PageData } = $props();

	// If the user already granted this client the requested scopes, we would
	// ideally auto-submit. For safety we still show the page with a one-click
	// "Continue" button so the user stays in control.
</script>

<div class="mx-auto flex min-h-screen max-w-md flex-col items-center justify-center px-6">
	<div class="w-full rounded-md border border-surface-border bg-surface p-6 shadow-lg shadow-black/15">
		<div class="flex items-center gap-3">
			{#if data.client.logo_uri}
				<img src={data.client.logo_uri} alt="" class="h-10 w-10 rounded-sm" />
			{/if}
			<div>
				<h1 class="text-lg font-semibold text-sidebar-text">{data.client.client_name}</h1>
				<p class="text-xs text-muted/60">wants to connect to your Trackr account</p>
			</div>
		</div>

		<div class="mt-5 rounded-sm bg-surface-hover/40 p-3 text-sm text-sidebar-text">
			<p class="mb-2 text-xs uppercase tracking-wide text-muted/50">It will be able to</p>
			<ul class="space-y-1">
				{#each data.params.scope as s (s)}
					<li class="flex items-center gap-2">
						<span class="h-1.5 w-1.5 rounded-full bg-accent/60"></span>
						<span>{s === 'mcp' ? 'Read and modify your Trackr data (tasks, tickets, wiki, projects)' : s}</span>
					</li>
				{/each}
			</ul>
		</div>

		<p class="mt-4 text-xs text-muted/60">
			Redirects back to <span class="font-mono text-sidebar-text">{data.params.redirectUri}</span>
		</p>

		{#if data.client.policy_uri || data.client.tos_uri}
			<p class="mt-2 text-xs text-muted/60">
				{#if data.client.policy_uri}
					<a href={data.client.policy_uri} target="_blank" rel="noopener noreferrer" class="underline">Privacy</a>
				{/if}
				{#if data.client.policy_uri && data.client.tos_uri}
					·
				{/if}
				{#if data.client.tos_uri}
					<a href={data.client.tos_uri} target="_blank" rel="noopener noreferrer" class="underline">Terms</a>
				{/if}
			</p>
		{/if}

		<form method="POST" use:enhance class="mt-6 flex flex-col gap-2">
			<input type="hidden" name="csrf" value={data.csrf} />
			<button
				type="submit"
				formaction="?/approve"
				class="flex w-full items-center justify-center rounded-sm bg-accent px-3 py-2 text-sm font-medium text-white transition hover:bg-accent/90"
			>
				{data.alreadyConsented ? 'Continue' : 'Allow'}
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
			Trackr did not verify this application. Make sure you recognise it.
		</p>
	</div>
</div>
