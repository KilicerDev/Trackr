<script lang="ts">
	import { Bell, Search, LogOut, Command } from "@lucide/svelte";
	import { notificationCenter } from '$lib/stores/notificationCenter.svelte';
	import { clickOutside } from '$lib/actions/clickOutside';
	import { getClient } from '$lib/api/client';
	import NotificationPanel from '$lib/components/NotificationPanel.svelte';

	function openSearch() {
		document.dispatchEvent(new KeyboardEvent('keydown', { key: 'k', metaKey: true }));
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
				<span class="absolute -top-0.5 -right-0.5 flex h-4 min-w-4 items-center justify-center rounded-full bg-accent px-1 text-2xs font-semibold leading-none text-white">
					{notificationCenter.unreadCount > 99 ? '99+' : notificationCenter.unreadCount}
				</span>
			{/if}
		</button>
		{#if notificationCenter.isOpen}
			<NotificationPanel />
		{/if}
	</div>

	<!-- Logout -->
	<button
		type="button"
		class="flex h-8 w-8 cursor-pointer items-center justify-center rounded-sm text-muted transition-all duration-150 hover:bg-surface-hover hover:text-sidebar-text focus-visible:ring-1 focus-visible:ring-accent/50 focus-visible:outline-none"
		aria-label="Log out"
		onclick={async () => {
			await getClient().auth.signOut();
			window.location.href = '/login';
		}}
	>
		<LogOut size={15} />
	</button>
</div>
