<svelte:head><title>Profile – Trackr</title></svelte:head>

<script lang="ts">
	import { page } from '$app/state';
	import { goto } from '$app/navigation';
	import { auth } from '$lib/stores/auth.svelte';
	import { api } from '$lib/api';
	import { notifications } from '$lib/stores/notifications.svelte';
	import { fontStore, type FontFamily } from '$lib/stores/font.svelte';
	import { theme, COLOR_SCHEMES, type ColorScheme } from '$lib/stores/theme.svelte';
	import { densityStore, DENSITY_OPTIONS, type Density } from '$lib/stores/density.svelte';
	import { textSizeStore, TEXT_SIZE_OPTIONS, type TextSize } from '$lib/stores/text-size.svelte';
	import { Camera, Copy, Check, RefreshCw, Trash2, CalendarSync, Eye, EyeOff, ChevronDown } from '@lucide/svelte';
	import { getClient } from '$lib/api/client';
	import { clickOutside } from '$lib/actions/clickOutside';

	type Tab = 'profile' | 'style' | 'integrations' | 'security';
	const VALID_TABS: Tab[] = ['profile', 'style', 'integrations', 'security'];
	let activeTab = $derived.by(() => {
		const param = page.url.searchParams.get('tab') as Tab;
		return VALID_TABS.includes(param) ? param : 'profile';
	});
	const tabs: { key: Tab; label: string }[] = [
		{ key: 'profile', label: 'Profile' },
		{ key: 'style', label: 'Style' },
		{ key: 'integrations', label: 'Integrations' },
		{ key: 'security', label: 'Security' }
	];

	// Profile fields
	let fullName = $state(auth.user?.full_name ?? '');
	let username = $state(auth.user?.username ?? '');
	let timezone = $state(auth.user?.timezone ?? 'UTC');
	let locale = $state(auth.user?.locale ?? 'en');
	let saving = $state(false);
	let profileLoaded = $state(!!auth.user);
	let avatarUploading = $state(false);
	let avatarInput: HTMLInputElement;

	async function uploadAvatar(e: Event) {
		const file = (e.target as HTMLInputElement).files?.[0];
		if (!file || !auth.user) return;
		avatarUploading = true;
		try {
			const supabase = getClient();
			const path = `avatars/${auth.user.id}/${Date.now()}_${file.name}`;
			const { error: uploadErr } = await supabase.storage.from('attachments').upload(path, file, { upsert: true });
			if (uploadErr) throw uploadErr;
			const { data: urlData } = supabase.storage.from('attachments').getPublicUrl(path);
			await api.users.update(auth.user.id, { avatar_url: urlData.publicUrl });
			auth.user.avatar_url = urlData.publicUrl;
			notifications.add('success', 'Avatar updated');
		} catch {
			notifications.add('error', 'Failed to upload avatar');
		} finally {
			avatarUploading = false;
		}
	}

	// Sync fields when auth.user loads after refresh
	$effect(() => {
		if (auth.user && !profileLoaded) {
			fullName = auth.user.full_name ?? '';
			username = auth.user.username ?? '';
			timezone = auth.user.timezone ?? 'UTC';
			locale = auth.user.locale ?? 'en';
			profileLoaded = true;
		}
	});

	// iCal integration state
	let icalLoading = $state(false);
	let icalStatusLoaded = $state(false);
	let icalToken = $state<string | null>(null);
	let icalExists = $state(false);
	let icalLastUsed = $state<string | null>(null);
	let icalCopied = $state(false);
	let icalConfirmRegen = $state(false);
	let icalConfirmRevoke = $state(false);

	// Load stored token from localStorage on mount
	$effect(() => {
		if (typeof window !== 'undefined' && auth.user) {
			const stored = localStorage.getItem(`trackr_ical_token_${auth.user.id}`);
			if (stored) icalToken = stored;
		}
	});

	// Check token status when integrations tab is opened
	$effect(() => {
		if (activeTab === 'integrations') {
			loadIcalStatus();
		}
	});

	async function loadIcalStatus() {
		try {
			const status = await api.ical.getStatus();
			icalExists = status.exists;
			icalLastUsed = status.last_used_at;
			// If token was revoked externally, clear localStorage
			if (!status.exists && icalToken && auth.user) {
				localStorage.removeItem(`trackr_ical_token_${auth.user.id}`);
				icalToken = null;
			}
		} catch {
			// silent
		} finally {
			icalStatusLoaded = true;
		}
	}

	async function generateIcalToken() {
		if (icalLoading) return;
		icalLoading = true;
		try {
			const token = await api.ical.generateToken();
			icalToken = token;
			icalExists = true;
			icalConfirmRegen = false;
			if (auth.user) {
				localStorage.setItem(`trackr_ical_token_${auth.user.id}`, token);
			}
			notifications.add('success', 'Calendar URL generated');
		} catch {
			notifications.add('error', 'Failed to generate calendar URL');
		} finally {
			icalLoading = false;
		}
	}

	async function revokeIcalToken() {
		if (icalLoading) return;
		icalLoading = true;
		try {
			await api.ical.revokeToken();
			icalToken = null;
			icalExists = false;
			icalLastUsed = null;
			icalConfirmRevoke = false;
			if (auth.user) {
				localStorage.removeItem(`trackr_ical_token_${auth.user.id}`);
			}
			notifications.add('success', 'Calendar URL revoked');
		} catch {
			notifications.add('error', 'Failed to revoke calendar URL');
		} finally {
			icalLoading = false;
		}
	}

	function getIcalUrl(extra?: string): string {
		if (!icalToken) return '';
		const base = `${window.location.origin}/api/ical?token=${icalToken}`;
		return extra ? `${base}&${extra}` : base;
	}

	async function copyToClipboard(text: string) {
		await navigator.clipboard.writeText(text);
		icalCopied = true;
		setTimeout(() => (icalCopied = false), 2000);
	}

	import { formatTimeAgo, formatFullDate } from '$lib/utils/date';

	// Style dropdowns
	let schemeDropdownOpen = $state(false);

	// Accent color input
	let accentInput = $state(theme.accentColor);

	import { labelClass, inputClass, btnPrimary } from '$lib/styles/ui';

	// Security / password change
	let currentPassword = $state('');
	let newPassword = $state('');
	let confirmPassword = $state('');
	let showPassword = $state(false);
	let passwordSaving = $state(false);
	let passwordError = $state<string | null>(null);
	let passwordSuccess = $state<string | null>(null);

	const passwordValid = $derived(
		currentPassword.length > 0 && newPassword.length >= 6 && newPassword === confirmPassword
	);

	async function changePassword() {
		if (!passwordValid || !auth.user) return;
		passwordSaving = true;
		passwordError = null;
		passwordSuccess = null;
		try {
			const supabase = getClient();
			// Verify current password
			const { error: signInErr } = await supabase.auth.signInWithPassword({
				email: auth.user.email,
				password: currentPassword
			});
			if (signInErr) {
				passwordError = 'Current password is incorrect';
				return;
			}
			// Update to new password
			const { error: updateErr } = await supabase.auth.updateUser({
				password: newPassword
			});
			if (updateErr) {
				passwordError = updateErr.message;
				return;
			}
			passwordSuccess = 'Password updated successfully';
			currentPassword = '';
			newPassword = '';
			confirmPassword = '';
		} catch (e) {
			passwordError = e instanceof Error ? e.message : 'Failed to change password';
		} finally {
			passwordSaving = false;
		}
	}

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
				onclick={() => goto(`/profile?tab=${tab.key}`, { replaceState: true, noScroll: true })}
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
					<button
						type="button"
						class="absolute inset-0 flex cursor-pointer items-center justify-center rounded-full bg-black/40 opacity-0 transition-opacity group-hover:opacity-100"
						onclick={() => avatarInput.click()}
						disabled={avatarUploading}
					>
						<Camera size={18} class="text-white" />
					</button>
					<input
						bind:this={avatarInput}
						type="file"
						accept="image/*"
						class="hidden"
						onchange={uploadAvatar}
					/>
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
				<div
					class="relative max-w-xs"
					use:clickOutside={{ onClickOutside: () => schemeDropdownOpen = false, enabled: schemeDropdownOpen }}
				>
					<button
						type="button"
						class="flex w-full cursor-pointer items-center justify-between gap-2 rounded-sm bg-surface-hover/40 px-2.5 py-1.5 text-base text-sidebar-text transition-all duration-150 hover:bg-surface-hover/60"
						onclick={() => schemeDropdownOpen = !schemeDropdownOpen}
					>
						{COLOR_SCHEMES.find((s) => s.key === theme.mode)?.label ?? 'Dark'}
						<ChevronDown size={14} class="shrink-0 text-muted/40" />
					</button>
					{#if schemeDropdownOpen}
						<div class="absolute left-0 z-30 mt-1.5 w-full rounded-md border border-surface-border bg-surface py-1 shadow-lg shadow-black/15 ring-1 ring-white/[0.07] animate-dropdown-in">
							{#each COLOR_SCHEMES as scheme (scheme.key)}
								<button
									type="button"
									class="flex w-full items-center px-2.5 py-1.5 text-left text-sm transition-all duration-150 hover:bg-surface-hover/60 {theme.mode === scheme.key ? 'font-medium text-accent' : 'text-muted'}"
									onclick={() => { theme.setScheme(scheme.key); schemeDropdownOpen = false; }}
								>
									{scheme.label}
								</button>
							{/each}
						</div>
					{/if}
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

	<!-- Integrations Tab -->
	{#if activeTab === 'integrations'}
		<div class="space-y-8">
			<section>
				<div class="mb-4 flex items-center gap-2.5">
					<CalendarSync size={18} class="text-muted/50" />
					<h2 class="text-xs font-medium uppercase tracking-[0.08em] text-muted">Calendar Feed (iCal)</h2>
				</div>

				{#if !icalStatusLoaded}
					<!-- Loading state -->
				{:else if !icalExists && !icalToken}
					<!-- No token state -->
					<div class="rounded border border-surface-border/40 bg-surface/50 p-5">
						<p class="mb-4 text-base text-muted/60">
							Generate a secret URL to subscribe to your tasks and tickets in any calendar app
							— Apple Calendar, Google Calendar, Outlook, and more. Only items assigned to you with a date will appear.
						</p>
						<button
							type="button"
							disabled={icalLoading}
							onclick={generateIcalToken}
							class="flex h-7 items-center gap-1.5 rounded-sm bg-accent px-2.5 text-sm font-medium text-white transition-all duration-150 hover:bg-accent/90 disabled:opacity-30"
						>
							{icalLoading ? 'Generating...' : 'Generate Calendar URL'}
						</button>
					</div>
				{:else}
					<!-- Token exists state -->
					<div class="space-y-4">
						<!-- Main URL -->
						<div class="rounded border border-surface-border/40 bg-surface/50 p-4">
							<label class={labelClass}>Calendar URL</label>
							{#if icalToken}
								<div class="flex items-center gap-2">
									<input
										type="text"
										readonly
										value={getIcalUrl()}
										class="{inputClass} font-mono !text-xs"
									/>
									<button
										type="button"
										onclick={() => copyToClipboard(getIcalUrl())}
										class="flex h-8 w-8 shrink-0 items-center justify-center rounded-sm border border-surface-border/40 text-muted/50 transition-all duration-150 hover:bg-surface-hover/60 hover:text-sidebar-text"
										title="Copy URL"
									>
										{#if icalCopied}
											<Check size={14} class="text-green-400" />
										{:else}
											<Copy size={14} />
										{/if}
									</button>
								</div>
							{:else}
								<p class="text-sm text-muted/60">
									Token was generated in a previous session. You can regenerate to get a new URL,
									or revoke to disable the feed.
								</p>
							{/if}

							{#if icalLastUsed}
								<p class="mt-2 text-xs text-muted/40">Last synced: {formatTimeAgo(icalLastUsed)}</p>
							{/if}
						</div>

						<!-- Filter hints -->
						{#if icalToken}
							<div class="rounded border border-surface-border/40 bg-surface/50 p-4">
								<label class={labelClass}>Filtered URLs</label>
								<p class="mb-3 text-sm text-muted/40">
									Append these parameters to subscribe to a subset of your items.
									Each URL shows as a separate calendar/list.
								</p>
								<div class="space-y-2 font-mono text-xs text-muted/50">
									<div class="flex items-center justify-between gap-2 rounded bg-surface-hover/30 px-2.5 py-1.5">
										<span class="truncate">&type=tasks</span>
										<span class="shrink-0 text-muted/30">Tasks only</span>
									</div>
									<div class="flex items-center justify-between gap-2 rounded bg-surface-hover/30 px-2.5 py-1.5">
										<span class="truncate">&type=tickets</span>
										<span class="shrink-0 text-muted/30">Tickets only</span>
									</div>
									<div class="flex items-center justify-between gap-2 rounded bg-surface-hover/30 px-2.5 py-1.5">
										<span class="truncate">&project=PROJECT_ID</span>
										<span class="shrink-0 text-muted/30">Specific project</span>
									</div>
									<div class="flex items-center justify-between gap-2 rounded bg-surface-hover/30 px-2.5 py-1.5">
										<span class="truncate">&project=ID&type=tasks</span>
										<span class="shrink-0 text-muted/30">Combine filters</span>
									</div>
								</div>
							</div>
						{/if}

						<!-- Actions -->
						<div class="flex gap-3">
							{#if !icalConfirmRegen}
								<button
									type="button"
									disabled={icalLoading}
									onclick={() => (icalConfirmRegen = true)}
									class="flex h-7 items-center gap-1.5 rounded-sm border border-surface-border/40 px-2.5 text-sm font-medium text-muted/60 transition-all duration-150 hover:bg-surface-hover/60 hover:text-sidebar-text disabled:opacity-30"
								>
									<RefreshCw size={13} />
									Regenerate
								</button>
							{:else}
								<div class="flex items-center gap-2">
									<span class="text-sm text-amber-400/80">Old URL will stop working.</span>
									<button
										type="button"
										disabled={icalLoading}
										onclick={generateIcalToken}
										class="flex h-7 items-center gap-1 rounded-sm bg-amber-500/80 px-2.5 text-sm font-medium text-white transition-all duration-150 hover:bg-amber-500 disabled:opacity-30"
									>
										{icalLoading ? 'Regenerating...' : 'Confirm'}
									</button>
									<button
										type="button"
										onclick={() => (icalConfirmRegen = false)}
										class="text-sm text-muted/40 hover:text-sidebar-text"
									>
										Cancel
									</button>
								</div>
							{/if}

							{#if !icalConfirmRevoke}
								<button
									type="button"
									disabled={icalLoading}
									onclick={() => (icalConfirmRevoke = true)}
									class="flex h-7 items-center gap-1.5 rounded-sm border border-red-500/20 px-2.5 text-sm font-medium text-red-400/60 transition-all duration-150 hover:bg-red-500/10 hover:text-red-400 disabled:opacity-30"
								>
									<Trash2 size={13} />
									Revoke
								</button>
							{:else}
								<div class="flex items-center gap-2">
									<span class="text-sm text-red-400/80">Feed will be disabled.</span>
									<button
										type="button"
										disabled={icalLoading}
										onclick={revokeIcalToken}
										class="flex h-7 items-center gap-1 rounded-sm bg-red-500/80 px-2.5 text-sm font-medium text-white transition-all duration-150 hover:bg-red-500 disabled:opacity-30"
									>
										{icalLoading ? 'Revoking...' : 'Confirm'}
									</button>
									<button
										type="button"
										onclick={() => (icalConfirmRevoke = false)}
										class="text-sm text-muted/40 hover:text-sidebar-text"
									>
										Cancel
									</button>
								</div>
							{/if}
						</div>

						<!-- Security note -->
						<p class="text-xs text-muted/30">
							Treat the calendar URL like a password — anyone with the URL can view your assigned tasks and tickets.
							Regenerate the URL if you suspect it has been compromised.
						</p>
					</div>
				{/if}
			</section>
		</div>
	{/if}

	<!-- Security Tab -->
	{#if activeTab === 'security'}
		<div class="space-y-8">
			<section>
				<h2 class="mb-4 text-base font-semibold text-sidebar-text">Change Password</h2>

				<form onsubmit={(e) => { e.preventDefault(); changePassword(); }} class="max-w-md space-y-4">
					<div>
						<label for="current-password" class={labelClass}>Current Password</label>
						<div class="relative">
							<input
								id="current-password"
								type={showPassword ? 'text' : 'password'}
								autocomplete="current-password"
								bind:value={currentPassword}
								class="{inputClass} pr-9"
							/>
							<button
								type="button"
								class="absolute top-1/2 right-2.5 -translate-y-1/2 cursor-pointer text-muted/40 transition-all duration-150 hover:text-sidebar-text"
								onclick={() => (showPassword = !showPassword)}
								tabindex={-1}
							>
								{#if showPassword}<EyeOff size={14} />{:else}<Eye size={14} />{/if}
							</button>
						</div>
					</div>

					<div>
						<label for="new-password" class={labelClass}>New Password</label>
						<input
							id="new-password"
							type={showPassword ? 'text' : 'password'}
							autocomplete="new-password"
							placeholder="At least 6 characters"
							bind:value={newPassword}
							minlength={6}
							class={inputClass}
						/>
					</div>

					<div>
						<label for="confirm-new-password" class={labelClass}>Confirm New Password</label>
						<input
							id="confirm-new-password"
							type={showPassword ? 'text' : 'password'}
							autocomplete="new-password"
							placeholder="Repeat new password"
							bind:value={confirmPassword}
							minlength={6}
							class={inputClass}
						/>
						{#if confirmPassword && newPassword !== confirmPassword}
							<p class="mt-1.5 text-xs text-red-400">Passwords do not match.</p>
						{/if}
					</div>

					{#if passwordError}
						<p class="text-sm text-red-400">{passwordError}</p>
					{/if}
					{#if passwordSuccess}
						<p class="text-sm text-green-400">{passwordSuccess}</p>
					{/if}

					<div class="flex justify-end border-t border-surface-border/40 pt-4">
						<button
							type="submit"
							disabled={passwordSaving || !passwordValid}
							class={btnPrimary}
						>
							{passwordSaving ? 'Saving...' : 'Update password'}
						</button>
					</div>
				</form>
			</section>
		</div>
	{/if}
</div>
