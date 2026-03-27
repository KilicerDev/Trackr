<svelte:head><title>Profile – Trackr</title></svelte:head>

<script lang="ts">
	import { auth } from '$lib/stores/auth.svelte';
	import { api } from '$lib/api';
	import { notifications } from '$lib/stores/notifications.svelte';
	import { fontStore, type FontFamily } from '$lib/stores/font.svelte';
	import { theme, COLOR_SCHEMES, type ColorScheme } from '$lib/stores/theme.svelte';
	import { densityStore, DENSITY_OPTIONS, type Density } from '$lib/stores/density.svelte';
	import { textSizeStore, TEXT_SIZE_OPTIONS, type TextSize } from '$lib/stores/text-size.svelte';
	import { Camera } from '@lucide/svelte';

	type Tab = 'profile' | 'style';
	let activeTab = $state<Tab>('profile');
	const tabs: { key: Tab; label: string }[] = [
		{ key: 'profile', label: 'Profile' },
		{ key: 'style', label: 'Style' }
	];

	// Profile fields
	let fullName = $state(auth.user?.full_name ?? '');
	let username = $state(auth.user?.username ?? '');
	let timezone = $state(auth.user?.timezone ?? 'UTC');
	let locale = $state(auth.user?.locale ?? 'en');
	let saving = $state(false);

	// Accent color input
	let accentInput = $state(theme.accentColor);

	const labelClass = 'mb-1.5 block text-xs font-medium uppercase tracking-[0.08em] text-muted/50';
	const inputClass =
		'w-full rounded-sm bg-surface-hover/40 px-2.5 py-1.5 text-base text-sidebar-text outline-none transition-all duration-150 placeholder:text-muted/30 focus:bg-surface-hover/60';

	async function saveProfile() {
		if (!auth.user || saving) return;
		saving = true;
		try {
			await api.users.update(auth.user.id, {
				full_name: fullName.trim(),
				username: username.trim(),
				timezone,
				locale
			});
			notifications.add('success', 'Profile updated');
		} catch {
			notifications.add('error', 'Failed to update profile');
		} finally {
			saving = false;
		}
	}
</script>

<div class="mx-auto w-full max-w-2xl px-6 py-6">
	<!-- Tabs -->
	<div class="mb-6 flex gap-1 border-b border-surface-border/40">
		{#each tabs as tab (tab.key)}
			<button
				class="relative px-3 py-2 text-base font-medium transition-colors
					{activeTab === tab.key
						? 'text-sidebar-text'
						: 'text-muted/50 hover:text-sidebar-text'}"
				onclick={() => (activeTab = tab.key)}
			>
				{tab.label}
				{#if activeTab === tab.key}
					<span class="absolute bottom-0 left-0 right-0 h-0.5 bg-accent"></span>
				{/if}
			</button>
		{/each}
	</div>

	<!-- Profile Tab -->
	{#if activeTab === 'profile'}
		<div class="space-y-8">
			<!-- Avatar + Name header -->
			<div class="flex items-center gap-5">
				<div class="group relative">
					{#if auth.user?.avatar_url}
						<img
							src={auth.user.avatar_url}
							alt={auth.user.full_name}
							class="h-16 w-16 rounded-full object-cover"
						/>
					{:else}
						<div class="flex h-16 w-16 items-center justify-center rounded-full bg-accent/10 text-xl font-semibold text-accent">
							{auth.user?.full_name?.charAt(0)?.toUpperCase() ?? '?'}
						</div>
					{/if}
					<div class="absolute inset-0 flex items-center justify-center rounded-full bg-black/40 opacity-0 transition-opacity group-hover:opacity-100">
						<Camera size={18} class="text-white" />
					</div>
				</div>
				<div>
					<h1 class="text-lg font-semibold text-sidebar-text">{auth.user?.full_name ?? 'User'}</h1>
					<p class="text-sm text-muted/50">{auth.user?.email ?? ''}</p>
				</div>
			</div>

			<!-- Form -->
			<form onsubmit={(e) => { e.preventDefault(); saveProfile(); }} class="space-y-4">
				<div class="grid grid-cols-2 gap-4">
					<div>
						<label for="full-name" class={labelClass}>Full Name</label>
						<input id="full-name" type="text" bind:value={fullName} class={inputClass} />
					</div>
					<div>
						<label for="username" class={labelClass}>Username</label>
						<input id="username" type="text" bind:value={username} class={inputClass} />
					</div>
				</div>

				<div>
					<label for="email" class={labelClass}>Email</label>
					<input id="email" type="email" value={auth.user?.email ?? ''} disabled class="{inputClass} cursor-not-allowed opacity-50" />
				</div>

				<div class="grid grid-cols-2 gap-4">
					<div>
						<label for="timezone" class={labelClass}>Timezone</label>
						<input id="timezone" type="text" bind:value={timezone} class={inputClass} placeholder="UTC" />
					</div>
					<div>
						<label for="locale" class={labelClass}>Locale</label>
						<input id="locale" type="text" bind:value={locale} class={inputClass} placeholder="en" />
					</div>
				</div>

				<div class="flex justify-end border-t border-surface-border/40 pt-4">
					<button
						type="submit"
						disabled={saving}
						class="flex h-7 items-center gap-1 rounded-sm bg-accent px-2.5 text-sm font-medium text-white transition-all duration-150 hover:bg-accent/90 disabled:opacity-30"
					>
						{saving ? 'Saving...' : 'Save changes'}
					</button>
				</div>
			</form>
		</div>
	{/if}

	<!-- Style Tab -->
	{#if activeTab === 'style'}
		<div class="space-y-8">
			<section>
				<h2 class="mb-4 text-xs font-medium uppercase tracking-[0.08em] text-muted">Color Scheme</h2>
				<div class="flex gap-3">
					{#each COLOR_SCHEMES as scheme (scheme.key)}
						<button
							type="button"
							class="flex flex-1 flex-col gap-1 rounded border px-3 py-2.5 text-left transition-all duration-150
								{theme.mode === scheme.key
									? 'border-accent/30 bg-accent/5'
									: 'border-surface-border/40 bg-surface/50 hover:bg-surface-hover/60'}"
							onclick={() => theme.setScheme(scheme.key)}
						>
							<span class="text-base font-medium text-sidebar-text">{scheme.label}</span>
							<span class="text-sm text-muted/50">{scheme.description}</span>
							<div class="mt-2 flex gap-1.5">
								{#each scheme.swatches as color}
									<span class="h-4 w-4 rounded-sm border border-surface-border/40" style="background:{color}"></span>
								{/each}
							</div>
						</button>
					{/each}
				</div>
			</section>

			<section>
				<h2 class="mb-4 text-xs font-medium uppercase tracking-[0.08em] text-muted">Accent Color</h2>
				<div class="flex max-w-lg items-center gap-3">
					<input
						type="color"
						value={theme.accentColor}
						oninput={(e) => {
							const v = (e.target as HTMLInputElement).value;
							accentInput = v;
							theme.setAccentColor(v);
						}}
						class="h-7 w-7 shrink-0 cursor-pointer rounded-sm border border-surface-border/40 bg-transparent p-0.5"
					/>
					<input
						type="text"
						value={accentInput}
						maxlength="7"
						placeholder="#ff4867"
						class="{inputClass} font-mono !w-28"
						oninput={(e) => {
							let v = (e.target as HTMLInputElement).value;
							if (v && !v.startsWith('#')) v = '#' + v;
							accentInput = v;
							if (/^#[0-9a-fA-F]{6}$/.test(v)) theme.setAccentColor(v);
						}}
					/>
					{#if theme.accentColor !== theme.defaultAccent}
						<button
							type="button"
							class="text-sm text-muted/50 transition-all duration-150 hover:text-accent"
							onclick={() => { theme.resetAccent(); accentInput = theme.defaultAccent; }}
						>
							Reset
						</button>
					{/if}
				</div>
				<p class="mt-2 text-sm text-muted/40">Used for buttons, active states, and highlights across the app.</p>
			</section>

			<section>
				<h2 class="mb-4 text-xs font-medium uppercase tracking-[0.08em] text-muted">Font</h2>
				<div class="flex gap-3">
					{#each [{ key: 'geist' as FontFamily, label: 'Geist', sample: 'The quick brown fox' }, { key: 'geist-mono' as FontFamily, label: 'Geist Mono', sample: 'The quick brown fox' }] as opt (opt.key)}
						<button
							type="button"
							class="flex flex-1 flex-col gap-2 rounded border px-3 py-2.5 text-left transition-all duration-150
								{fontStore.current === opt.key
									? 'border-accent/30 bg-accent/5'
									: 'border-surface-border/40 bg-surface/50 hover:bg-surface-hover/60'}"
							onclick={() => fontStore.set(opt.key)}
						>
							<span class="text-base font-medium text-sidebar-text">{opt.label}</span>
							<span class="text-base text-muted/50" style="font-family: {opt.key === 'geist' ? "'Geist', sans-serif" : "'GeistMono', monospace"}">{opt.sample}</span>
						</button>
					{/each}
				</div>
			</section>

			<section>
				<h2 class="mb-4 text-xs font-medium uppercase tracking-[0.08em] text-muted">Spacing</h2>
				<div class="flex gap-3">
					{#each DENSITY_OPTIONS as opt (opt.key)}
						<button
							type="button"
							class="flex flex-1 flex-col gap-1 rounded border px-3 py-2.5 text-left transition-all duration-150
								{densityStore.current === opt.key
									? 'border-accent/30 bg-accent/5'
									: 'border-surface-border/40 bg-surface/50 hover:bg-surface-hover/60'}"
							onclick={() => densityStore.set(opt.key)}
						>
							<span class="text-base font-medium text-sidebar-text">{opt.label}</span>
							<span class="text-sm text-muted/50">{opt.description}</span>
						</button>
					{/each}
				</div>
			</section>

			<section>
				<h2 class="mb-4 text-xs font-medium uppercase tracking-[0.08em] text-muted">Text Size</h2>
				<div class="flex gap-3">
					{#each TEXT_SIZE_OPTIONS as opt (opt.key)}
						<button
							type="button"
							class="flex flex-1 flex-col gap-1 rounded border px-3 py-2.5 text-left transition-all duration-150
								{textSizeStore.current === opt.key
									? 'border-accent/30 bg-accent/5'
									: 'border-surface-border/40 bg-surface/50 hover:bg-surface-hover/60'}"
							onclick={() => textSizeStore.set(opt.key)}
						>
							<span class="text-base font-medium text-sidebar-text">{opt.label}</span>
							<span class="text-sm text-muted/50">{opt.description}</span>
						</button>
					{/each}
				</div>
			</section>
		</div>
	{/if}
</div>
