<script lang="ts">
	import { enhance } from '$app/forms';
	import { LoaderCircle } from '@lucide/svelte';
	import logo from '$lib/assets/logo.png';
	import * as m from '$lib/paraglide/messages';
	import { localizeHref } from '$lib/paraglide/runtime';

	let { form } = $props();
	let loading = $state(false);
</script>

<div class="flex flex-col items-center">
	<div class="relative mb-1 flex w-full items-center justify-center">
		<a
			href={localizeHref('/login')}
			class="absolute left-0 text-lg text-accent transition-all duration-150 hover:text-accent/80"
		>
			&lsaquo;
		</a>
		<div class="flex items-center gap-2">
			<img src={logo} alt="Trackr" class="h-8" />
			<span class="text-lg font-bold tracking-widest text-sidebar-text">TRACKR</span>
		</div>
	</div>

	<p class="mb-6 text-sm text-muted">{m.auth_forgot_password_title()}</p>

	{#if form?.success}
		<div class="mb-4 w-full rounded border border-green-400/30 bg-green-400/10 px-3 py-2.5 text-sm text-green-400">
			{m.auth_reset_email_sent()}
		</div>
	{:else if form?.message}
		<div class="mb-4 w-full rounded border border-red-400/30 bg-red-400/10 px-3 py-2.5 text-sm text-red-400">
			{form.message}
		</div>
	{/if}

	<form
		method="POST"
		class="w-full space-y-4"
		use:enhance={() => {
			loading = true;
			return async ({ update }) => {
				loading = false;
				await update();
			};
		}}
	>
		<div>
			<label for="email" class="mb-1.5 block text-xs font-semibold uppercase tracking-[0.08em] text-accent">
				{m.auth_email()}
			</label>
			<input
				id="email"
				name="email"
				type="email"
				placeholder={m.auth_email()}
				defaultValue={form?.email ?? ''}
				required
				class="w-full rounded-sm bg-surface-hover/40 px-2.5 py-1.5 text-base text-sidebar-text outline-none placeholder:text-muted/30 focus:bg-surface-hover/60"
			/>
		</div>

		<button
			type="submit"
			disabled={loading}
			class="flex h-8 w-full cursor-pointer items-center justify-center rounded-sm bg-accent text-sm font-semibold text-white transition-all duration-150 hover:bg-accent/90 disabled:cursor-not-allowed disabled:opacity-30"
		>
			{#if loading}
				<LoaderCircle size={14} class="animate-spin" />
			{:else}
				{m.auth_send()}
			{/if}
		</button>
	</form>
</div>
