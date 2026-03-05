<script lang="ts">
	import { Bell, Moon, Sun } from "@lucide/svelte";
	import { theme } from '$lib/stores/theme.svelte';
	import { notificationCenter } from '$lib/stores/notificationCenter.svelte';
	import { clickOutside } from '$lib/actions/clickOutside';
	import NotificationPanel from '$lib/components/NotificationPanel.svelte';
</script>

<div class="flex items-center justify-end gap-2 border-b border-sidebar-border px-4 py-2">
    <div class="flex items-center gap-0">
        <button
			type="button"
			class="text-sidebar-icon hover:text-sidebar-text cursor-pointer p-2 rounded-md hover:bg-sidebar-hover-bg"
			onclick={() => theme.toggle()}
			aria-label={theme.mode === 'dark' ? 'Switch to light mode' : 'Switch to dark mode'}
		>
            {#if theme.mode === 'dark'}
                <Sun size={16} />
            {:else}
                <Moon size={16} />
            {/if}
        </button>
		<div
			class="relative"
			use:clickOutside={{ onClickOutside: () => notificationCenter.close(), enabled: notificationCenter.isOpen }}
		>
			<button
				type="button"
				class="relative text-sidebar-icon hover:text-sidebar-text cursor-pointer p-2 rounded-md hover:bg-sidebar-hover-bg"
				onclick={() => notificationCenter.toggle()}
				aria-label="Notifications"
			>
				<Bell size={16} />
				{#if notificationCenter.unreadCount > 0}
					<span class="absolute right-1 top-1 flex h-4 min-w-4 items-center justify-center rounded-full bg-red-500 px-1 text-[10px] font-bold leading-none text-white">
						{notificationCenter.unreadCount > 99 ? '99+' : notificationCenter.unreadCount}
					</span>
				{/if}
			</button>
			{#if notificationCenter.isOpen}
				<NotificationPanel />
			{/if}
		</div>
    </div>
</div>