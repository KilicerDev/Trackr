<script lang="ts">
	import { goto } from '$app/navigation';
	import { page } from '$app/state';
	import { Bell, ChevronDown, LogOut, Settings } from '@lucide/svelte';
	import { notificationCenter } from '$lib/stores/notificationCenter.svelte';
	import { auth } from '$lib/stores/auth.svelte';
	import { clickOutside } from '$lib/actions/clickOutside';
	import { getClient } from '$lib/api/client';
	import { localizeHref } from '$lib/paraglide/runtime';
	import * as m from '$lib/paraglide/messages';
	import NotificationPanel from '$lib/components/NotificationPanel.svelte';
	import Modal from '$lib/components/Modal.svelte';
	import logo from '$lib/assets/logo.png';
	import { SvelteURLSearchParams } from 'svelte/reactivity';

	type Org = { id: string; name: string; slug: string; logo_url: string | null };

	interface Props {
		organizations: Org[];
	}

	let { organizations }: Props = $props();

	let orgDropdownOpen = $state(false);
	let profileMenuOpen = $state(false);
	let logoutConfirm = $state(false);

	const selectedOrgId = $derived(page.url.searchParams.get('org') ?? organizations[0]?.id ?? '');
	const selectedOrg = $derived(organizations.find((o) => o.id === selectedOrgId) ?? organizations[0]);

	function selectOrg(orgId: string) {
		orgDropdownOpen = false;
		const params = new SvelteURLSearchParams(page.url.searchParams);
		params.set('org', orgId);
		params.delete('ticket');
		goto(`${localizeHref('/c')}?${params.toString()}`, { replaceState: true });
	}

	async function logout() {
		await getClient().auth.signOut();
		window.location.href = '/login';
	}
</script>

<div class="flex h-12 shrink-0 items-center justify-between gap-3 border-b border-surface-border px-3">
	<!-- Left: logo + org dropdown -->
	<div class="flex items-center gap-3">
		<a href={localizeHref('/c')} class="flex items-center gap-2">
			<img src={logo} alt="Trackr" class="h-7 w-7 shrink-0" />
			<span style="font-family: 'GeistMono', monospace" class="text-lg font-bold tracking-widest text-sidebar-text">TRACKR</span>
		</a>

		{#if organizations.length > 0}
			<div
				class="relative"
				use:clickOutside={{ onClickOutside: () => (orgDropdownOpen = false), enabled: orgDropdownOpen }}
			>
				<button
					type="button"
					class="flex h-7 cursor-pointer items-center gap-1.5 rounded-sm border border-transparent px-2 text-base text-muted transition-all duration-150 hover:border-surface-border hover:bg-surface hover:text-sidebar-text focus-visible:ring-1 focus-visible:ring-accent/50 focus-visible:outline-none"
					onclick={() => (orgDropdownOpen = !orgDropdownOpen)}
				>
					<span class="max-w-40 truncate">{selectedOrg?.name ?? m.client_select_organization()}</span>
					<ChevronDown size={12} class="shrink-0 text-muted/40 transition-transform duration-150 {orgDropdownOpen ? 'rotate-180' : ''}" />
				</button>
				{#if orgDropdownOpen}
					<div class="absolute left-0 top-full z-30 mt-1.5 max-h-56 w-56 overflow-y-auto rounded-md border border-surface-border bg-surface py-1 shadow-lg shadow-black/15 ring-1 ring-white/[0.07] animate-dropdown-in">
						{#each organizations as org (org.id)}
							<button
								type="button"
								class="flex w-full items-center px-2.5 py-1.5 text-left text-sm transition-colors hover:bg-surface-hover/60 {org.id === selectedOrgId ? 'font-medium text-accent' : 'text-sidebar-text'}"
								onmousedown={(e) => { e.preventDefault(); selectOrg(org.id); }}
							>
								{org.name}
							</button>
						{/each}
					</div>
				{/if}
			</div>
		{/if}
	</div>

	<!-- Right: bell + profile -->
	<div class="flex items-center gap-1.5">
		<div
			class="relative"
			use:clickOutside={{ onClickOutside: () => notificationCenter.close(), enabled: notificationCenter.isOpen }}
		>
			<button
				type="button"
				class="relative flex h-8 w-8 cursor-pointer items-center justify-center rounded-sm text-muted transition-all duration-150 hover:bg-surface-hover hover:text-sidebar-text focus-visible:ring-1 focus-visible:ring-accent/50 focus-visible:outline-none"
				onclick={() => notificationCenter.toggle()}
				aria-label={m.client_notifications()}
			>
				<Bell size={15} />
				{#if notificationCenter.unreadCount > 0}
					<span class="absolute top-0.5 right-1 h-2.5 w-2.5 rounded-full bg-accent"></span>
				{/if}
			</button>
			{#if notificationCenter.isOpen}
				<NotificationPanel />
			{/if}
		</div>

		<div
			class="relative"
			use:clickOutside={{ onClickOutside: () => { profileMenuOpen = false; }, enabled: profileMenuOpen }}
		>
			<button
				type="button"
				class="flex h-8 w-8 cursor-pointer items-center justify-center rounded-full transition-all duration-150 hover:opacity-80 focus-visible:ring-2 focus-visible:ring-accent/50 focus-visible:outline-none"
				onclick={() => (profileMenuOpen = !profileMenuOpen)}
				aria-label={m.client_profile_menu()}
			>
				{#if auth.user?.avatar_url}
					<img src={auth.user.avatar_url} alt={auth.user.full_name} class="h-7 w-7 rounded-full object-cover" />
				{:else}
					<div class="flex h-7 w-7 select-none items-center justify-center rounded-full bg-accent text-xs font-semibold text-white">
						{auth.user?.full_name?.charAt(0)?.toUpperCase() ?? '?'}
					</div>
				{/if}
			</button>

			{#if profileMenuOpen}
				<div class="absolute right-0 top-full z-30 mt-1.5 w-52 rounded-md border border-surface-border bg-surface py-1 shadow-lg shadow-black/15 ring-1 ring-white/[0.07] animate-dropdown-in">
					<div class="border-b border-surface-border/40 px-3 py-2">
						<p class="truncate text-sm font-medium text-sidebar-text">{auth.user?.full_name ?? m.client_user_fallback()}</p>
						<p class="truncate text-xs text-muted/50">{auth.user?.email ?? ''}</p>
					</div>
					<div class="py-1">
						<a
							href={localizeHref('/c/settings')}
							class="flex w-full items-center gap-2 px-3 py-1.5 text-sm text-muted transition-all duration-150 hover:bg-surface-hover/60 hover:text-sidebar-text"
							onclick={() => (profileMenuOpen = false)}
						>
							<span class="flex w-4 shrink-0 justify-center"><Settings size={15} /></span>
							{m.client_settings()}
						</a>
					</div>
					<div class="border-t border-surface-border/40 py-1">
						<button
							type="button"
							class="flex w-full cursor-pointer items-center gap-2 px-3 py-1.5 text-sm text-red-400/70 transition-all duration-150 hover:bg-red-500/10 hover:text-red-400"
							onclick={() => { profileMenuOpen = false; logoutConfirm = true; }}
						>
							<span class="flex w-4 shrink-0 justify-center"><LogOut size={15} /></span>
							{m.client_logout()}
						</button>
					</div>
				</div>
			{/if}
		</div>
	</div>
</div>

{#if logoutConfirm}
	<Modal open={true} onClose={() => (logoutConfirm = false)} maxWidth="max-w-sm">
		<div class="p-5">
			<h2 class="text-lg font-semibold text-sidebar-text">{m.client_logout()}</h2>
			<p class="mt-2 text-sm text-muted">{m.client_logout_confirm_message()}</p>
			<div class="mt-5 flex justify-end gap-2">
				<button
					type="button"
					class="flex h-7 items-center rounded-sm px-2.5 text-sm font-medium text-muted transition-all duration-150 hover:text-sidebar-text"
					onclick={() => (logoutConfirm = false)}
				>
					{m.client_cancel()}
				</button>
				<button
					type="button"
					class="flex h-7 items-center rounded-sm bg-red-500/80 px-2.5 text-sm font-medium text-white transition-all duration-150 hover:bg-red-500"
					onclick={logout}
				>
					{m.client_logout()}
				</button>
			</div>
		</div>
	</Modal>
{/if}
