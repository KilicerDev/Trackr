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
			class="absolute left-0 text-xl text-accent transition-opacity hover:opacity-70"
		>
			&lsaquo;
		</a>
		<div class="flex items-center gap-2">
			<img src={logo} alt="Trackr" class="h-8" />
			<span class="text-xl font-bold tracking-widest text-gray-800">TRACKR</span>
		</div>
	</div>

	<p class="mb-8 text-sm text-gray-500">{m.auth_forgot_password_title()}</p>

	{#if form?.success}
		<div class="mb-4 w-full rounded-md border border-green-200 bg-green-50 px-4 py-3 text-sm text-green-700">
			{m.auth_reset_email_sent()}
		</div>
	{:else if form?.message}
		<div class="mb-4 w-full rounded-md border border-red-200 bg-red-50 px-4 py-3 text-sm text-accent">
			{form.message}
		</div>
	{/if}

	<form
		method="POST"
		class="w-full space-y-5"
		use:enhance={() => {
			loading = true;
			return async ({ update }) => {
				loading = false;
				await update();
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
				value={form?.email ?? ''}
				required
				class="w-full rounded-lg bg-gray-100 px-4 py-3 text-sm text-gray-700 outline-none placeholder:text-gray-400"
			/>
		</div>

		<button
			type="submit"
			disabled={loading}
			class="flex w-full cursor-pointer items-center justify-center rounded-lg bg-accent py-3.5 text-sm font-semibold tracking-wide text-white shadow-md shadow-accent/30 transition-opacity hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-60"
		>
			{#if loading}
				<LoaderCircle size={18} class="animate-spin" />
			{:else}
				{m.auth_send()}
			{/if}
		</button>
	</form>
</div>
