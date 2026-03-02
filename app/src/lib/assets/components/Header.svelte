<script lang="ts">
	import { Bell, Moon } from "@lucide/svelte";

</script>

<div class="flex items-center justify-end gap-2 border-b border-sidebar-border px-4 py-2">
    <div class="flex items-center gap-0">
        <button class="text-sidebar-icon hover:text-sidebar-text cursor-pointer p-2 rounded-md hover:bg-sidebar-hover-bg">
            <Moon size={16} />
        </button>
        <button class="text-sidebar-icon hover:text-sidebar-text cursor-pointer p-2 rounded-md hover:bg-sidebar-hover-bg">
            <Bell size={16} />
        </button>
    </div>
</div>