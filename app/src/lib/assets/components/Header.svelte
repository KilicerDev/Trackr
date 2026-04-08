<script lang="ts">
	import { goto } from '$app/navigation';
	import { Bell, Search, LogOut, Command, User, Palette, Plug } from "@lucide/svelte";
	import { notificationCenter } from '$lib/stores/notificationCenter.svelte';
	import { auth } from '$lib/stores/auth.svelte';
	import { clickOutside } from '$lib/actions/clickOutside';
	import { getClient } from '$lib/api/client';
	import { localizeHref } from '$lib/paraglide/runtime';
	import NotificationPanel from '$lib/components/NotificationPanel.svelte';
	import Modal from '$lib/components/Modal.svelte';

	let profileMenuOpen = $state(false);
	let logoutConfirm = $state(false);

	function openSearch() {
		document.dispatchEvent(new KeyboardEvent('keydown', { key: 'k', metaKey: true }));
	}

	async function logout() {
		await getClient().auth.signOut();
		window.location.href = '/login';
	}
</script>

<div class="flex h-12 items-center justify-end gap-1.5 border-b border-surface-border px-3">
	<!-- Search trigger -->
	<button
		type="button"
		class="flex cursor-pointer items-center gap-2 rounded-sm border border-transparent px-2.5 py-1.5 text-muted transition-all duration-150 hover:border-surface-border hover:bg-surface hover:text-sidebar-text focus-visible:ring-1 focus-visible:ring-accent/50 focus-visible:outline-none"
		onclick={openSearch}
		aria-label="Search"
	>
		<Search size={14} class="shrink-0" />
		<span class="text-base">Search</span>
		<kbd class="ml-1 flex items-center gap-px rounded border border-surface-border bg-surface-hover px-1.5 py-0.5 text-xs font-medium leading-none text-muted/70">
			<Command size={9} />K
		</kbd>
	</button>

	<!-- Notification bell -->
	<div
		class="relative"
		use:clickOutside={{ onClickOutside: () => notificationCenter.close(), enabled: notificationCenter.isOpen }}
	>
		<button
			type="button"
			class="relative flex h-8 w-8 cursor-pointer items-center justify-center rounded-sm text-muted transition-all duration-150 hover:bg-surface-hover hover:text-sidebar-text focus-visible:ring-1 focus-visible:ring-accent/50 focus-visible:outline-none"
			onclick={() => notificationCenter.toggle()}
			aria-label="Notifications"
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

	<!-- Profile menu -->
	<div
		class="relative"
		use:clickOutside={{ onClickOutside: () => { profileMenuOpen = false; logoutConfirm = false; }, enabled: profileMenuOpen }}
	>
		<button
			type="button"
			class="flex h-8 w-8 cursor-pointer items-center justify-center rounded-full transition-all duration-150 hover:opacity-80 focus-visible:ring-2 focus-visible:ring-accent/50 focus-visible:outline-none"
			onclick={() => profileMenuOpen = !profileMenuOpen}
			aria-label="Profile menu"
		>
			{#if auth.user?.avatar_url}
				<img
					src={auth.user.avatar_url}
					alt={auth.user.full_name}
					class="h-7 w-7 rounded-full object-cover"
				/>
			{:else}
				<div class="flex h-7 w-7 select-none items-center justify-center rounded-full bg-accent text-xs font-semibold text-white">
					{auth.user?.full_name?.charAt(0)?.toUpperCase() ?? '?'}
				</div>
			{/if}
		</button>

		{#if profileMenuOpen}
			<div class="absolute right-0 top-full z-30 mt-1.5 w-48 rounded-md border border-surface-border bg-surface py-1 shadow-lg shadow-black/15 ring-1 ring-white/[0.07] animate-dropdown-in">
				<div class="border-b border-surface-border/40 px-3 py-2">
					<p class="truncate text-sm font-medium text-sidebar-text">{auth.user?.full_name ?? 'User'}</p>
					<p class="truncate text-xs text-muted/50">{auth.user?.email ?? ''}</p>
				</div>

				<div class="py-1">
					<a
						href={localizeHref('/profile?tab=profile')}
						class="flex w-full items-center gap-2 px-3 py-1.5 text-sm text-muted transition-all duration-150 hover:bg-surface-hover/60 hover:text-sidebar-text"
						onclick={() => profileMenuOpen = false}
					>
						<span class="flex w-4 shrink-0 justify-center"><User size={15} /></span>
						Profile
					</a>
					<a
						href={localizeHref('/profile?tab=style')}
						class="flex w-full items-center gap-2 px-3 py-1.5 text-sm text-muted transition-all duration-150 hover:bg-surface-hover/60 hover:text-sidebar-text"
						onclick={() => profileMenuOpen = false}
					>
						<span class="flex w-4 shrink-0 justify-center"><Palette size={15} /></span>
						Style
					</a>
					<a
						href={localizeHref('/profile?tab=integrations')}
						class="flex w-full items-center gap-2 px-3 py-1.5 text-sm text-muted transition-all duration-150 hover:bg-surface-hover/60 hover:text-sidebar-text"
						onclick={() => profileMenuOpen = false}
					>
						<span class="flex w-4 shrink-0 justify-center"><Plug size={15} /></span>
						Integrations
					</a>
				</div>

				<div class="border-t border-surface-border/40 py-1">
					<button
						type="button"
						class="flex w-full cursor-pointer items-center gap-2 px-3 py-1.5 text-sm text-red-400/70 transition-all duration-150 hover:bg-red-500/10 hover:text-red-400"
						onclick={() => { profileMenuOpen = false; logoutConfirm = true; }}
					>
						<span class="flex w-4 shrink-0 justify-center"><LogOut size={15} /></span>
						Log out
					</button>
				</div>
			</div>
		{/if}
	</div>
</div>

{#if logoutConfirm}
	<Modal open={true} onClose={() => logoutConfirm = false} maxWidth="max-w-sm">
		<div class="p-5">
			<h2 class="text-lg font-semibold text-sidebar-text">Log out</h2>
			<p class="mt-2 text-sm text-muted">Are you sure you want to log out?</p>
			<div class="mt-5 flex justify-end gap-2">
				<button
					type="button"
					class="flex h-7 items-center rounded-sm px-2.5 text-sm font-medium text-muted transition-all duration-150 hover:text-sidebar-text"
					onclick={() => logoutConfirm = false}
				>
					Cancel
				</button>
				<button
					type="button"
					class="flex h-7 items-center rounded-sm bg-red-500/80 px-2.5 text-sm font-medium text-white transition-all duration-150 hover:bg-red-500"
					onclick={logout}
				>
					Log out
				</button>
			</div>
		</div>
	</Modal>
{/if}
