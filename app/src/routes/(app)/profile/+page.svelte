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
	import { Camera, Copy, Check, RefreshCw, Trash2, CalendarSync, Eye, EyeOff, ChevronDown, KeyRound, Plus } from '@lucide/svelte';
	import { getClient } from '$lib/api/client';
	import { clickOutside } from '$lib/actions/clickOutside';
	import type { ApiKey } from '$lib/api/keys';

	type Tab = 'profile' | 'style' | 'integrations' | 'security' | 'apiKeys' | 'connectedApps';
	const VALID_TABS: Tab[] = ['profile', 'style', 'integrations', 'security', 'apiKeys', 'connectedApps'];
	let activeTab = $derived.by(() => {
		const param = page.url.searchParams.get('tab') as Tab;
		return VALID_TABS.includes(param) ? param : 'profile';
	});
	const tabs: { key: Tab; label: string }[] = [
		{ key: 'profile', label: 'Profile' },
		{ key: 'style', label: 'Style' },
		{ key: 'integrations', label: 'Integrations' },
		{ key: 'apiKeys', label: 'API Keys' },
		{ key: 'connectedApps', label: 'Connected Apps' },
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
			const orgId = auth.user.organization_id ?? 'shared';
			const path = `${orgId}/avatar/${auth.user.id}/${Date.now()}_${file.name}`;
			const { error: uploadErr } = await supabase.storage
				.from('attachments')
				.upload(path, file, { contentType: file.type, upsert: true });
			if (uploadErr) throw uploadErr;
			// Generate a long-lived signed URL (1 year)
			const { data: signedData, error: signErr } = await supabase.storage
				.from('attachments')
				.createSignedUrl(path, 60 * 60 * 24 * 365);
			if (signErr) throw signErr;
			await api.users.update(auth.user.id, { avatar_url: signedData.signedUrl });
			auth.user.avatar_url = signedData.signedUrl;
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

	// API keys state
	let apiKeys = $state<ApiKey[]>([]);
	let apiKeysLoaded = $state(false);
	let apiKeysLoading = $state(false);
	let showCreateForm = $state(false);
	let newKeyName = $state('');
	let newKeyExpiry = $state<'7' | '30' | '90' | '365' | 'never'>('90');
	let creatingKey = $state(false);
	let createdPlaintext = $state<string | null>(null);
	let createdCopied = $state(false);
	let confirmRevokeId = $state<string | null>(null);
	let revokingId = $state<string | null>(null);

	$effect(() => {
		if (activeTab === 'apiKeys' && !apiKeysLoaded) {
			loadApiKeys();
		}
		if (activeTab === 'connectedApps' && !connectedAppsLoaded) {
			loadConnectedApps();
		}
	});

	// Connected Apps (OAuth consents)
	type ConnectedApp = {
		client_id: string;
		client_name: string;
		logo_uri: string | null;
		scope: string[];
		approved_at: string;
		last_used_at: string | null;
	};
	let connectedApps = $state<ConnectedApp[]>([]);
	let connectedAppsLoaded = $state(false);
	let connectedAppsLoading = $state(false);
	let revokingAppId = $state<string | null>(null);

	async function loadConnectedApps() {
		connectedAppsLoading = true;
		try {
			const res = await fetch('/api/oauth/apps');
			if (!res.ok) throw new Error('Failed to load');
			const body = (await res.json()) as { apps: ConnectedApp[] };
			connectedApps = body.apps;
		} catch {
			notifications.add('error', 'Failed to load connected apps');
		} finally {
			connectedAppsLoading = false;
			connectedAppsLoaded = true;
		}
	}

	async function revokeConnectedApp(clientId: string) {
		if (revokingAppId) return;
		revokingAppId = clientId;
		try {
			const res = await fetch(`/api/oauth/apps/${encodeURIComponent(clientId)}`, {
				method: 'DELETE'
			});
			if (!res.ok) throw new Error('Failed');
			connectedApps = connectedApps.filter((a) => a.client_id !== clientId);
			notifications.add('success', 'Access revoked');
		} catch {
			notifications.add('error', 'Failed to revoke access');
		} finally {
			revokingAppId = null;
		}
	}

	async function loadApiKeys() {
		apiKeysLoading = true;
		try {
			apiKeys = await api.keys.list();
		} catch {
			notifications.add('error', 'Failed to load API keys');
		} finally {
			apiKeysLoading = false;
			apiKeysLoaded = true;
		}
	}

	async function createApiKey() {
		const name = newKeyName.trim();
		if (!name || creatingKey) return;
		creatingKey = true;
		try {
			const expiresInDays =
				newKeyExpiry === 'never' ? null : (Number(newKeyExpiry) as 7 | 30 | 90 | 365);
			const { key, plaintext } = await api.keys.create(name, expiresInDays);
			apiKeys = [key, ...apiKeys];
			createdPlaintext = plaintext;
			newKeyName = '';
			newKeyExpiry = '90';
			showCreateForm = false;
			notifications.add('success', 'API key created');
		} catch (e) {
			notifications.add('error', e instanceof Error ? e.message : 'Failed to create API key');
		} finally {
			creatingKey = false;
		}
	}

	async function revokeApiKey(id: string) {
		if (revokingId) return;
		revokingId = id;
		try {
			await api.keys.revoke(id);
			apiKeys = apiKeys.map((k) =>
				k.id === id ? { ...k, revoked_at: new Date().toISOString() } : k
			);
			confirmRevokeId = null;
			notifications.add('success', 'API key revoked');
		} catch {
			notifications.add('error', 'Failed to revoke API key');
		} finally {
			revokingId = null;
		}
	}

	async function copyPlaintextKey() {
		if (!createdPlaintext) return;
		await navigator.clipboard.writeText(createdPlaintext);
		createdCopied = true;
		setTimeout(() => (createdCopied = false), 2000);
	}

	function dismissCreatedKey() {
		createdPlaintext = null;
		createdCopied = false;
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

	<!-- API Keys Tab -->
	{#if activeTab === 'apiKeys'}
		<div class="space-y-6">
			<section>
				<div class="mb-4 flex items-center justify-between">
					<div class="flex items-center gap-2.5">
						<KeyRound size={18} class="text-muted/50" />
						<h2 class="text-xs font-medium uppercase tracking-[0.08em] text-muted">API Keys</h2>
					</div>
					{#if !showCreateForm && !createdPlaintext}
						<button
							type="button"
							onclick={() => (showCreateForm = true)}
							class="flex h-7 items-center gap-1.5 rounded-sm bg-accent px-2.5 text-sm font-medium text-white transition-all duration-150 hover:bg-accent/90"
						>
							<Plus size={13} />
							New key
						</button>
					{/if}
				</div>

				<p class="mb-4 text-base text-muted/60">
					Long-lived tokens for the Trackr MCP server and future public API integrations. Keys
					inherit your permissions and can be revoked at any time.
				</p>

				<!-- Freshly created key: shown once -->
				{#if createdPlaintext}
					<div class="mb-4 rounded border border-amber-500/30 bg-amber-500/5 p-4">
						<p class="mb-2 text-sm font-medium text-amber-400">
							Copy this key now — you won't be able to see it again.
						</p>
						<div class="flex items-center gap-2">
							<input
								type="text"
								readonly
								value={createdPlaintext}
								class="{inputClass} font-mono !text-xs"
							/>
							<button
								type="button"
								onclick={copyPlaintextKey}
								class="flex h-8 w-8 shrink-0 items-center justify-center rounded-sm border border-surface-border/40 text-muted/50 transition-all duration-150 hover:bg-surface-hover/60 hover:text-sidebar-text"
								title="Copy key"
							>
								{#if createdCopied}
									<Check size={14} class="text-green-400" />
								{:else}
									<Copy size={14} />
								{/if}
							</button>
						</div>
						<button
							type="button"
							onclick={dismissCreatedKey}
							class="mt-3 text-sm text-muted/50 hover:text-sidebar-text"
						>
							I saved it, dismiss
						</button>
					</div>
				{/if}

				<!-- Create form -->
				{#if showCreateForm}
					<div class="mb-4 rounded border border-surface-border/40 bg-surface/50 p-4">
						<form
							onsubmit={(e) => {
								e.preventDefault();
								createApiKey();
							}}
							class="space-y-3"
						>
							<div>
								<label for="api-key-name" class={labelClass}>Name</label>
								<input
									id="api-key-name"
									type="text"
									placeholder="e.g. MCP on laptop"
									bind:value={newKeyName}
									maxlength="100"
									class={inputClass}
									autofocus
								/>
							</div>
							<div>
								<label for="api-key-expiry" class={labelClass}>Expires</label>
								<select
									id="api-key-expiry"
									bind:value={newKeyExpiry}
									class={inputClass}
								>
									<option value="7">7 days</option>
									<option value="30">30 days</option>
									<option value="90">90 days</option>
									<option value="365">1 year</option>
									<option value="never">Never</option>
								</select>
							</div>
							<div class="flex justify-end gap-2 pt-2">
								<button
									type="button"
									onclick={() => {
										showCreateForm = false;
										newKeyName = '';
										newKeyExpiry = '90';
									}}
									class="text-sm text-muted/50 hover:text-sidebar-text"
								>
									Cancel
								</button>
								<button
									type="submit"
									disabled={creatingKey || !newKeyName.trim()}
									class="flex h-7 items-center gap-1 rounded-sm bg-accent px-2.5 text-sm font-medium text-white transition-all duration-150 hover:bg-accent/90 disabled:opacity-30"
								>
									{creatingKey ? 'Creating...' : 'Create key'}
								</button>
							</div>
						</form>
					</div>
				{/if}

				<!-- List -->
				{#if !apiKeysLoaded}
					<p class="text-sm text-muted/40">Loading…</p>
				{:else if apiKeys.length === 0}
					<div class="rounded border border-surface-border/40 bg-surface/50 p-5 text-center">
						<p class="text-sm text-muted/60">No API keys yet.</p>
					</div>
				{:else}
					<div class="space-y-2">
						{#each apiKeys as key (key.id)}
							{@const isRevoked = !!key.revoked_at}
							{@const isExpired =
								!!key.expires_at && new Date(key.expires_at).getTime() < Date.now()}
							<div
								class="flex items-center gap-3 rounded border border-surface-border/40 bg-surface/50 p-3 {isRevoked ||
								isExpired
									? 'opacity-50'
									: ''}"
							>
								<div class="min-w-0 flex-1">
									<div class="flex items-center gap-2">
										<span class="truncate text-base font-medium text-sidebar-text">{key.name}</span>
										{#if isRevoked}
											<span class="shrink-0 rounded bg-red-500/10 px-1.5 py-0.5 text-xs text-red-400/80">Revoked</span>
										{:else if isExpired}
											<span class="shrink-0 rounded bg-amber-500/10 px-1.5 py-0.5 text-xs text-amber-400/80">Expired</span>
										{/if}
									</div>
									<div class="mt-0.5 flex flex-wrap items-center gap-x-3 gap-y-0.5 font-mono text-xs text-muted/40">
										<span>{key.prefix}…</span>
										<span class="font-sans">
											{#if key.expires_at}
												Expires {formatFullDate(key.expires_at)}
											{:else}
												No expiry
											{/if}
										</span>
										<span class="font-sans">
											{#if key.last_used_at}
												Last used {formatTimeAgo(key.last_used_at)}
											{:else}
												Never used
											{/if}
										</span>
									</div>
								</div>
								{#if !isRevoked}
									{#if confirmRevokeId === key.id}
										<div class="flex shrink-0 items-center gap-2">
											<button
												type="button"
												disabled={revokingId === key.id}
												onclick={() => revokeApiKey(key.id)}
												class="flex h-7 items-center gap-1 rounded-sm bg-red-500/80 px-2.5 text-sm font-medium text-white transition-all duration-150 hover:bg-red-500 disabled:opacity-30"
											>
												{revokingId === key.id ? 'Revoking...' : 'Confirm'}
											</button>
											<button
												type="button"
												onclick={() => (confirmRevokeId = null)}
												class="text-sm text-muted/40 hover:text-sidebar-text"
											>
												Cancel
											</button>
										</div>
									{:else}
										<button
											type="button"
											onclick={() => (confirmRevokeId = key.id)}
											class="flex h-7 shrink-0 items-center gap-1.5 rounded-sm border border-red-500/20 px-2.5 text-sm font-medium text-red-400/60 transition-all duration-150 hover:bg-red-500/10 hover:text-red-400"
										>
											<Trash2 size={13} />
											Revoke
										</button>
									{/if}
								{/if}
							</div>
						{/each}
					</div>
				{/if}

				<p class="mt-6 text-xs text-muted/30">
					Treat API keys like passwords. Revoke immediately if a key is lost or exposed.
				</p>
			</section>
		</div>
	{/if}

	<!-- Connected Apps Tab -->
	{#if activeTab === 'connectedApps'}
		<div class="space-y-4">
			<section>
				<h2 class="mb-1 text-base font-semibold text-sidebar-text">Connected Apps</h2>
				<p class="mb-4 text-sm text-muted/60">
					Apps and integrations that have been granted access to your Trackr account via OAuth.
					Revoking access also invalidates all active tokens.
				</p>
				{#if !connectedAppsLoaded}
					<p class="text-sm text-muted/40">Loading...</p>
				{:else if connectedApps.length === 0}
					<p class="text-sm text-muted/40">No connected apps yet.</p>
				{:else}
					<div class="space-y-2">
						{#each connectedApps as app (app.client_id)}
							<div class="flex items-center gap-3 rounded-sm border border-surface-border bg-surface-hover/40 p-3">
								{#if app.logo_uri}
									<img src={app.logo_uri} alt="" class="h-8 w-8 shrink-0 rounded-sm" />
								{:else}
									<div class="flex h-8 w-8 shrink-0 items-center justify-center rounded-sm bg-surface-hover text-xs text-muted/60">
										{app.client_name.slice(0, 1).toUpperCase()}
									</div>
								{/if}
								<div class="min-w-0 flex-1">
									<p class="truncate text-sm font-medium text-sidebar-text">{app.client_name}</p>
									<p class="text-xs text-muted/50">
										Approved {new Date(app.approved_at).toLocaleDateString()}
										{#if app.last_used_at}
											· Last used {new Date(app.last_used_at).toLocaleDateString()}
										{/if}
									</p>
								</div>
								<button
									type="button"
									class="shrink-0 rounded-sm px-2.5 py-1 text-sm text-red-400 transition hover:bg-red-500/10 disabled:opacity-40"
									disabled={revokingAppId === app.client_id}
									onclick={() => revokeConnectedApp(app.client_id)}
								>
									{revokingAppId === app.client_id ? 'Revoking...' : 'Revoke'}
								</button>
							</div>
						{/each}
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
