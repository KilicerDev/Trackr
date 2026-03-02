<script lang="ts">
	import { Bell, Moon, Sun } from "@lucide/svelte";
	import { theme } from '$lib/stores/theme.svelte';
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
        <button class="text-sidebar-icon hover:text-sidebar-text cursor-pointer p-2 rounded-md hover:bg-sidebar-hover-bg">
            <Bell size={16} />
        </button>
    </div>
</div>