<script lang="ts">
	import { auth } from '$lib/stores/auth.svelte';
	import { api } from '$lib/api';
	import { notifications } from '$lib/stores/notifications.svelte';
	import { ArrowLeft, Pencil, Check, X, LogOut } from '@lucide/svelte';
	import { goto } from '$app/navigation';
	import { localizeHref, setLocale, getLocale, locales } from '$lib/paraglide/runtime';

	type Locale = (typeof locales)[number];
	import * as m from '$lib/paraglide/messages';
	import { getClient } from '$lib/api/client';
	import ConfirmDialog from '$lib/components/ConfirmDialog.svelte';

	let editingName = $state(false);
	let nameDraft = $state('');
	let saving = $state(false);
	let logoutOpen = $state(false);

	const currentLocale = $derived(getLocale());

	function startEditName() {
		nameDraft = auth.user?.full_name ?? '';
		editingName = true;
	}

	async function saveName() {
		if (!auth.user || !nameDraft.trim() || saving) return;
		saving = true;
		try {
			await api.users.update(auth.user.id, { full_name: nameDraft.trim() });
			auth.user = { ...auth.user, full_name: nameDraft.trim() };
			editingName = false;
			notifications.add('success', m.client_profile_updated());
		} catch (e) {
			notifications.add('error', m.client_failed_update_profile(), e instanceof Error ? e.message : undefined);
		} finally {
			saving = false;
		}
	}

	async function changeLanguage(newLocale: Locale) {
		if (newLocale === currentLocale) return;
		// Persist to DB so the choice survives cookie clears + syncs across devices
		if (auth.user) {
			try {
				await api.users.update(auth.user.id, { locale: newLocale });
				auth.user = { ...auth.user, locale: newLocale };
			} catch (e) {
				notifications.add('error', m.client_failed_update_language(), e instanceof Error ? e.message : undefined);
				return;
			}
		}
		// Cookie + reload so the new locale is reflected everywhere
		await setLocale(newLocale);
	}

	async function logout() {
		await getClient().auth.signOut();
		window.location.href = '/login';
	}
</script>

<svelte:head><title>{m.client_settings_title()} — Trackr</title></svelte:head>

<div class="mx-auto max-w-2xl px-6 py-8">
	<button
		class="mb-6 flex items-center gap-2 text-sm text-muted transition-colors hover:text-sidebar-text"
		onclick={() => goto(localizeHref('/c'))}
	>
		<ArrowLeft size={14} />
		{m.client_back()}
	</button>

	<h1 class="mb-6 text-2xl font-semibold text-sidebar-text">{m.client_settings_title()}</h1>

	<section class="rounded-md border border-surface-border bg-surface/40 p-5">
		<h2 class="mb-4 text-sm font-medium uppercase tracking-[0.08em] text-muted">{m.client_section_profile()}</h2>

		<div class="flex items-center gap-4">
			{#if auth.user?.avatar_url}
				<img src={auth.user.avatar_url} alt={auth.user.full_name} class="h-14 w-14 rounded-full object-cover" />
			{:else}
				<div class="flex h-14 w-14 select-none items-center justify-center rounded-full bg-accent text-xl font-semibold text-white">
					{auth.user?.full_name?.charAt(0)?.toUpperCase() ?? '?'}
				</div>
			{/if}
			<div class="min-w-0 flex-1">
				{#if editingName}
					<div class="flex items-center gap-2">
						<input
							type="text"
							bind:value={nameDraft}
							class="flex-1 rounded-sm bg-surface-hover/40 px-2.5 py-1.5 text-base text-sidebar-text outline-none focus:bg-surface-hover/60"
							placeholder={m.client_full_name_placeholder()}
							onkeydown={(e) => {
								if (e.key === 'Enter') { e.preventDefault(); saveName(); }
								if (e.key === 'Escape') { editingName = false; }
							}}
						/>
						<button
							class="flex h-7 w-7 items-center justify-center rounded-sm bg-accent text-white transition-all hover:bg-accent/90 disabled:opacity-30"
							disabled={!nameDraft.trim() || saving}
							onclick={saveName}
							aria-label={m.client_save()}
						>
							<Check size={14} />
						</button>
						<button
							class="flex h-7 w-7 items-center justify-center rounded-sm text-muted hover:bg-surface-hover hover:text-sidebar-text"
							onclick={() => (editingName = false)}
							aria-label={m.client_cancel()}
						>
							<X size={14} />
						</button>
					</div>
				{:else}
					<div class="flex items-center gap-2">
						<p class="text-base font-medium text-sidebar-text">{auth.user?.full_name ?? m.client_user_fallback()}</p>
						<button
							class="flex h-6 w-6 items-center justify-center rounded-sm text-muted/40 transition-colors hover:bg-surface-hover hover:text-sidebar-text"
							onclick={startEditName}
							aria-label={m.client_edit_name()}
						>
							<Pencil size={12} />
						</button>
					</div>
				{/if}
				<p class="mt-1 text-sm text-muted/60">{auth.user?.email ?? ''}</p>
			</div>
		</div>
	</section>

	<section class="mt-4 rounded-md border border-surface-border bg-surface/40 p-5">
		<h2 class="mb-4 text-sm font-medium uppercase tracking-[0.08em] text-muted">{m.client_section_language()}</h2>
		<div class="flex flex-wrap gap-2">
			{#each locales as loc (loc)}
				<button
					type="button"
					class="flex h-8 items-center gap-1.5 rounded-sm border px-3 text-sm font-medium transition-all duration-150 {currentLocale === loc ? 'border-accent/50 bg-accent/10 text-accent' : 'border-surface-border bg-surface-hover/40 text-sidebar-text hover:bg-surface-hover/60'}"
					onclick={() => changeLanguage(loc)}
				>
					{#if currentLocale === loc}
						<Check size={12} />
					{/if}
					{loc === 'de' ? m.client_language_german() : m.client_language_english()}
				</button>
			{/each}
		</div>
	</section>

	<section class="mt-4 rounded-md border border-surface-border bg-surface/40 p-5">
		<h2 class="mb-4 text-sm font-medium uppercase tracking-[0.08em] text-muted">{m.client_section_account()}</h2>
		<button
			type="button"
			class="flex h-8 items-center gap-2 rounded-sm border border-red-500/30 px-3 text-sm font-medium text-red-400 transition-all duration-150 hover:bg-red-500/10"
			onclick={() => (logoutOpen = true)}
		>
			<LogOut size={14} />
			{m.client_logout()}
		</button>
	</section>
</div>

<ConfirmDialog
	open={logoutOpen}
	title={m.client_logout()}
	message={m.client_logout_confirm_message()}
	confirmLabel={m.client_logout()}
	destructive={true}
	onConfirm={logout}
	onCancel={() => (logoutOpen = false)}
/>
