<script lang="ts">
	import { enhance } from '$app/forms';
	import { Eye, EyeOff, LoaderCircle } from '@lucide/svelte';
	import logo from '$lib/assets/logo.png';
	import * as m from '$lib/paraglide/messages';
	import { localizeHref } from '$lib/paraglide/runtime';
	import { locales, getLocale, setLocale } from '$lib/paraglide/runtime';
	import { page } from '$app/state';

	let showPassword = $state(false);
	let loading = $state(false);
	let dropdownOpen = $state(false);

	let { form } = $props();

	const localeFlags: Record<string, string> = {
		en: '🇬🇧',
		de: '🇩🇪'
	};

	const localeLabels: Record<string, string> = {
		en: 'EN',
		de: 'DE'
	};

	function switchLocale(loc: string) {
		setLocale(loc as 'en' | 'de');
		dropdownOpen = false;
	}
</script>

<div class="relative min-h-screen bg-gray-50 font-mono">
	<div class="absolute top-4 right-4">
		<div class="relative">
			<button
				class="flex cursor-pointer items-center gap-1 rounded-md border border-gray-200 bg-white px-3 py-1.5 text-sm"
				onclick={() => (dropdownOpen = !dropdownOpen)}
				onblur={() => setTimeout(() => (dropdownOpen = false), 150)}
			>
				<span class="text-base">{localeFlags[getLocale()] ?? ''}</span>
				<span class="text-xs">{localeLabels[getLocale()] ?? getLocale()}</span>
				<svg class="h-4 w-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path
						stroke-linecap="round"
						stroke-linejoin="round"
						stroke-width="2"
						d="M19 9l-7 7-7-7"
					/>
				</svg>
			</button>

			{#if dropdownOpen}
				<div
					class="absolute right-0 mt-1 overflow-hidden rounded-md border border-gray-200 bg-white"
				>
					{#each locales as loc}
						<a
							href={localizeHref(page.url.pathname, { locale: loc })}
							onclick={(e) => {
								e.preventDefault();
								switchLocale(loc);
							}}
							class="flex items-center gap-2 px-4 py-2 text-sm hover:bg-gray-50"
						>
							<span class="text-base">{localeFlags[loc] ?? ''}</span>
							<span class="text-xs">{localeLabels[loc] ?? loc}</span>
						</a>
					{/each}
				</div>
			{/if}
		</div>
	</div>

	<div class="flex min-h-screen items-center justify-center px-4">
		<div class="w-full max-w-md rounded-lg border border-gray-200 bg-white px-10 py-10">
			<div class="flex flex-col items-center">
				<div class="mb-1 flex items-center gap-2">
					<img src={logo} alt="Trackr" class="h-8" />
					<span class="text-xl font-bold tracking-widest text-gray-800">TRACKR</span>
				</div>

				<p class="mb-8 text-sm text-gray-500">{m.setup_subtitle()}</p>

				{#if form?.message}
					<div
						class="mb-4 w-full rounded-md border border-red-200 bg-red-50 px-4 py-3 text-sm text-accent"
					>
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
						<label
							for="org_name"
							class="mb-1.5 block text-xs font-semibold tracking-wide text-accent"
						>
							{m.setup_org_name()}
						</label>
						<input
							id="org_name"
							name="org_name"
							type="text"
							placeholder={m.setup_org_name()}
							value={form?.orgName ?? ''}
							required
							class="w-full rounded-lg bg-gray-100 px-4 py-3 text-sm text-gray-700 outline-none placeholder:text-gray-400"
						/>
					</div>

					<div>
						<label
							for="full_name"
							class="mb-1.5 block text-xs font-semibold tracking-wide text-accent"
						>
							{m.setup_full_name()}
						</label>
						<input
							id="full_name"
							name="full_name"
							type="text"
							placeholder={m.setup_full_name()}
							value={form?.fullName ?? ''}
							required
							class="w-full rounded-lg bg-gray-100 px-4 py-3 text-sm text-gray-700 outline-none placeholder:text-gray-400"
						/>
					</div>

					<div>
						<label
							for="email"
							class="mb-1.5 block text-xs font-semibold tracking-wide text-accent"
						>
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

					<div>
						<label
							for="password"
							class="mb-1.5 block text-xs font-semibold tracking-wide text-accent"
						>
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

					<div>
						<label
							for="confirm_password"
							class="mb-1.5 block text-xs font-semibold tracking-wide text-accent"
						>
							{m.setup_confirm_password()}
						</label>
						<input
							id="confirm_password"
							name="confirm_password"
							type="password"
							placeholder={m.setup_confirm_password()}
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
							{m.setup_submit()}
						{/if}
					</button>
				</form>
			</div>
		</div>
	</div>
</div>
