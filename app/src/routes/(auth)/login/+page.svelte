<script lang="ts">
	import logo from '$lib/assets/logo.png';
	import * as m from '$lib/paraglide/messages';
	import { localizeHref } from '$lib/paraglide/runtime';

	let email = $state('');
	let password = $state('');
	let error = $state('');

	function handleSubmit(e: SubmitEvent) {
		e.preventDefault();
		// TODO: wire up auth
	}
</script>

<div class="flex flex-col items-center">
	<div class="mb-1 flex items-center gap-2">
		<img src={logo} alt="Trackr" class="h-8" />
		<span class="text-xl font-bold tracking-widest text-gray-800">TRACKR</span>
	</div>

	<div class="mb-8"></div>

	{#if error}
		<div class="mb-4 w-full rounded-md border border-red-200 bg-red-50 px-4 py-3 text-sm text-accent">
			{error}
		</div>
	{/if}

	<form onsubmit={handleSubmit} class="w-full space-y-5">
		<div>
			<label for="email" class="mb-1.5 block text-xs font-semibold tracking-wide text-accent">
				{m.auth_email()}
			</label>
			<input
				id="email"
				type="email"
				placeholder={m.auth_email()}
				bind:value={email}
				class="w-full rounded-lg bg-gray-100 px-4 py-3 text-sm text-gray-700 outline-none placeholder:text-gray-400"
			/>
		</div>

		<div>
			<label for="password" class="mb-1.5 block text-xs font-semibold tracking-wide text-accent">
				{m.auth_password()}
			</label>
			<input
				id="password"
				type="password"
				placeholder={m.auth_password()}
				bind:value={password}
				class="w-full rounded-lg bg-gray-100 px-4 py-3 text-sm text-gray-700 outline-none placeholder:text-gray-400"
			/>
		</div>

		<button
			type="submit"
			class="w-full cursor-pointer rounded-lg bg-accent py-3.5 text-sm font-semibold tracking-wide text-white shadow-md shadow-accent/30 transition-opacity hover:opacity-90"
		>
			{m.auth_login()}
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
