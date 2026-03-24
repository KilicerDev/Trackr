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

<div class="flex items-center justify-end gap-2 border-b border-sidebar-border px-4 py-2">
    <div class="flex items-center gap-1">
		<button
			type="button"
			class="flex items-center gap-2 text-sidebar-icon hover:text-sidebar-text cursor-pointer hover:bg-sidebar-hover-bg  hover:border-sidebar-border"
			onclick={openSearch}
			aria-label="Search"
		>
			<div class="flex items-center gap-1  px-1.5 py-2.5 pl-2.5 text-[10px] text-muted">
				<Search size={16} />
				<span class="text-xs text-muted">Search</span>
			</div>
			<kbd class="ml-1 flex items-center gap-0.5 border border-surface-border bg-surface px-1.5 py-0.5 mr-2.5 text-[10px] font-large text-muted">
				<Command size={12} />
				<span class="text-[11px]">K</span>
			</kbd>
		</button>
		<div
			class="relative"
			use:clickOutside={{ onClickOutside: () => notificationCenter.close(), enabled: notificationCenter.isOpen }}
		>
			<button
				type="button"
				class="relative text-sidebar-icon hover:text-sidebar-text cursor-pointer p-2 hover:bg-sidebar-hover-bg"
				onclick={() => notificationCenter.toggle()}
				aria-label="Notifications"
			>
				<Bell size={16} />
				{#if notificationCenter.unreadCount > 0}
					<span class="absolute right-0.5 top-0.5 flex h-4 min-w-4 items-center justify-center bg-red-500 px-1 text-[10px] font-bold leading-none text-white">
						{notificationCenter.unreadCount > 99 ? '99+' : notificationCenter.unreadCount}
					</span>
				{/if}
			</button>
			{#if notificationCenter.isOpen}
				<NotificationPanel />
			{/if}
		</div>
		<button
			type="button"
			class="text-sidebar-icon hover:text-sidebar-text cursor-pointer p-2 hover:bg-sidebar-hover-bg"
			aria-label="Log out"
			onclick={async () => {
				await getClient().auth.signOut();
				window.location.href = '/login';
			}}
		>
			<LogOut size={16} />
		</button>
    </div>
</div>
