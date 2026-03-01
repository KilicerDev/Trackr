<script lang="ts">
	import logo from '$lib/assets/logo.png';
	import * as m from '$lib/paraglide/messages';
	import { localizeHref } from '$lib/paraglide/runtime';

	let email = $state('');

	function handleSubmit(e: SubmitEvent) {
		e.preventDefault();
		// TODO: wire up password reset
	}
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

		<button
			type="submit"
			class="w-full cursor-pointer rounded-lg bg-accent py-3.5 text-sm font-semibold tracking-wide text-white shadow-md shadow-accent/30 transition-opacity hover:opacity-90"
		>
			{m.auth_send()}
		</button>
	</form>
</div>
