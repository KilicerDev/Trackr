<svelte:head><title>Login – Trackr</title></svelte:head>

<script lang="ts">
	import { enhance } from '$app/forms';
	import { Eye, EyeOff, LoaderCircle } from '@lucide/svelte';
	import logo from '$lib/assets/logo.png';
	import * as m from '$lib/paraglide/messages';
	import { localizeHref } from '$lib/paraglide/runtime';

	let showPassword = $state(false);
	let loading = $state(false);

	let { form } = $props();
</script>

<div class="flex flex-col items-center">
	<div class="mb-1 flex items-center gap-2">
		<img src={logo} alt="Trackr" class="h-8" />
		<span class="text-lg font-bold tracking-widest text-sidebar-text">TRACKR</span>
	</div>

	<div class="mb-6"></div>

	{#if form?.message}
		<div class="mb-4 w-full rounded border border-red-400/30 bg-red-400/10 px-3 py-2.5 text-sm text-red-400">
			{form.message}
		</div>
	{/if}

	<form
		method="POST"
		class="w-full space-y-4"
		use:enhance={() => {
			loading = true;
			return async ({ result, update }) => {
				loading = false;
				if (result.type === 'redirect') {
					window.location.href = result.location;
				} else {
					await update();
				}
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

		<div>
			<label for="password" class="mb-1.5 block text-xs font-semibold uppercase tracking-[0.08em] text-accent">
				{m.auth_password()}
			</label>
			<div class="relative">
				<input
					id="password"
					name="password"
					type={showPassword ? 'text' : 'password'}
					placeholder={m.auth_password()}
					required
					class="w-full rounded-sm bg-surface-hover/40 px-2.5 py-1.5 pr-9 text-base text-sidebar-text outline-none placeholder:text-muted/30 focus:bg-surface-hover/60"
				/>
				<button
					type="button"
					class="absolute top-1/2 right-2.5 -translate-y-1/2 cursor-pointer text-muted/40 transition-all duration-150 hover:text-sidebar-text"
					onclick={() => (showPassword = !showPassword)}
					tabindex={-1}
				>
					{#if showPassword}
						<EyeOff size={14} />
					{:else}
						<Eye size={14} />
					{/if}
				</button>
			</div>
		</div>

		<button
			type="submit"
			disabled={loading}
			class="flex h-8 w-full cursor-pointer items-center justify-center rounded-sm bg-accent text-sm font-semibold text-white transition-all duration-150 hover:bg-accent/90 disabled:cursor-not-allowed disabled:opacity-30"
		>
			{#if loading}
				<LoaderCircle size={14} class="animate-spin" />
			{:else}
				{m.auth_login()}
			{/if}
		</button>
	</form>

	<div class="mt-4 border-t border-surface-border/30 pt-3">
		<a
			href={localizeHref('/forgot-password')}
			class="text-sm font-medium text-accent transition-colors hover:text-accent/80"
		>
			{m.auth_forgot_password()}
		</a>
	</div>
</div>
