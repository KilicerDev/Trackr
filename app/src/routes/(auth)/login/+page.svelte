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
		<span class="text-xl font-bold tracking-widest text-gray-800">TRACKR</span>
	</div>

	<div class="mb-8"></div>

	{#if form?.message}
		<div class="mb-4 w-full rounded-md border border-red-200 bg-red-50 px-4 py-3 text-sm text-accent">
			{form.message}
		</div>
	{/if}

	<form
		method="POST"
		class="w-full space-y-5"
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
			<label for="email" class="mb-1.5 block text-xs font-semibold tracking-wide text-accent">
				{m.auth_email()}
			</label>
			<input
				id="email"
				name="email"
				type="email"
				placeholder={m.auth_email()}
				defaultValue={form?.email ?? ''}
				required
				class="w-full rounded-lg bg-gray-100 px-4 py-3 text-sm text-gray-700 outline-none placeholder:text-gray-400"
			/>
		</div>

		<div>
			<label for="password" class="mb-1.5 block text-xs font-semibold tracking-wide text-accent">
				{m.auth_password()}
			</label>
			<div class="relative">
				<input
					id="password"
					name="password"
					type={showPassword ? 'text' : 'password'}
					placeholder={m.auth_password()}
					required
					class="w-full rounded-lg bg-gray-100 px-4 py-3 pr-11 text-sm text-gray-700 outline-none placeholder:text-gray-400"
				/>
				<button
					type="button"
					class="absolute top-1/2 right-3 -translate-y-1/2 cursor-pointer text-gray-400 transition-colors hover:text-gray-600"
					onclick={() => (showPassword = !showPassword)}
					tabindex={-1}
				>
					{#if showPassword}
						<EyeOff size={18} />
					{:else}
						<Eye size={18} />
					{/if}
				</button>
			</div>
		</div>

		<button
			type="submit"
			disabled={loading}
			class="flex w-full cursor-pointer items-center justify-center rounded-lg bg-accent py-3.5 text-sm font-semibold tracking-wide text-white shadow-md shadow-accent/30 transition-opacity hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-60"
		>
			{#if loading}
				<LoaderCircle size={18} class="animate-spin" />
			{:else}
				{m.auth_login()}
			{/if}
		</button>
	</form>

	<div class="mt-5 border-t border-gray-100 pt-4">
		<a
			href={localizeHref('/forgot-password')}
			class="text-sm font-medium text-accent hover:underline"
		>
			{m.auth_forgot_password()}
		</a>
	</div>
</div>
