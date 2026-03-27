<svelte:head><title>Setup – Trackr</title></svelte:head>

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

<div class="relative min-h-screen bg-page-bg">
	<div class="absolute top-4 right-4">
		<div class="relative">
			<button
				class="flex cursor-pointer items-center gap-1 rounded-sm bg-surface-hover/40 px-2.5 py-1.5 text-sm transition-all duration-150 hover:bg-surface-hover/60"
				onclick={() => (dropdownOpen = !dropdownOpen)}
				onblur={() => setTimeout(() => (dropdownOpen = false), 150)}
			>
				<span class="text-base">{localeFlags[getLocale()] ?? ''}</span>
				<span class="text-xs text-sidebar-text">{localeLabels[getLocale()] ?? getLocale()}</span>
				<svg class="h-3 w-3 text-muted/40" fill="none" stroke="currentColor" viewBox="0 0 24 24">
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
					class="absolute right-0 z-20 mt-1.5 min-w-[8rem] overflow-hidden rounded-md border border-surface-border/70 bg-surface shadow-lg shadow-black/20"
				>
					{#each locales as loc (loc)}
						<a
							href={localizeHref(page.url.pathname, { locale: loc })}
							onclick={(e) => {
								e.preventDefault();
								switchLocale(loc);
							}}
							class="flex items-center gap-2 px-2.5 py-1.5 text-sm text-muted transition-colors hover:bg-surface-hover/60 hover:text-sidebar-text"
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
		<div class="w-full max-w-md rounded border border-surface-border bg-surface px-10 py-10 shadow-xl">
			<div class="flex flex-col items-center">
				<div class="mb-1 flex items-center gap-2">
					<img src={logo} alt="Trackr" class="h-8" />
					<span class="text-lg font-bold tracking-widest text-sidebar-text">TRACKR</span>
				</div>

				<p class="mb-6 text-sm text-muted">{m.setup_subtitle()}</p>

				{#if form?.message}
					<div
						class="mb-4 w-full rounded border border-red-400/30 bg-red-400/10 px-3 py-2.5 text-sm text-red-400"
					>
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
						<label
							for="org_name"
							class="mb-1.5 block text-xs font-semibold uppercase tracking-[0.08em] text-accent"
						>
							{m.setup_org_name()}
						</label>
						<input
							id="org_name"
							name="org_name"
							type="text"
							placeholder={m.setup_org_name()}
							defaultValue={form?.orgName ?? ''}
							required
							class="w-full rounded-sm bg-surface-hover/40 px-2.5 py-1.5 text-base text-sidebar-text outline-none placeholder:text-muted/30 focus:bg-surface-hover/60"
						/>
					</div>

					<div>
						<label
							for="full_name"
							class="mb-1.5 block text-xs font-semibold uppercase tracking-[0.08em] text-accent"
						>
							{m.setup_full_name()}
						</label>
						<input
							id="full_name"
							name="full_name"
							type="text"
							placeholder={m.setup_full_name()}
							defaultValue={form?.fullName ?? ''}
							required
							class="w-full rounded-sm bg-surface-hover/40 px-2.5 py-1.5 text-base text-sidebar-text outline-none placeholder:text-muted/30 focus:bg-surface-hover/60"
						/>
					</div>

					<div>
						<label
							for="email"
							class="mb-1.5 block text-xs font-semibold uppercase tracking-[0.08em] text-accent"
						>
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
						<label
							for="password"
							class="mb-1.5 block text-xs font-semibold uppercase tracking-[0.08em] text-accent"
						>
							{m.auth_password()}
						</label>
						<div class="relative">
							<input
								id="password"
								name="password"
								type={showPassword ? 'text' : 'password'}
								autocomplete="new-password"
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

					<div>
						<label
							for="confirm_password"
							class="mb-1.5 block text-xs font-semibold uppercase tracking-[0.08em] text-accent"
						>
							{m.setup_confirm_password()}
						</label>
						<input
							id="confirm_password"
							name="confirm_password"
							type="password"
							autocomplete="new-password"
							placeholder={m.setup_confirm_password()}
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
							{m.setup_submit()}
						{/if}
					</button>
				</form>
			</div>
		</div>
	</div>
</div>
