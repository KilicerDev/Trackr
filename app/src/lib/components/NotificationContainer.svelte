<script lang="ts">
	import { fly } from 'svelte/transition';
	import { notifications } from '$lib/stores/notifications.svelte';
	import NotificationItem from './NotificationItem.svelte';
</script>

{#if notifications.items.length > 0}
	<div class="pointer-events-none fixed bottom-4 right-4 z-50 flex flex-col-reverse gap-2.5">
		{#each notifications.items as notification (notification.id)}
			<div transition:fly={{ x: 60, duration: 250 }}>
				<NotificationItem
					{notification}
					onDismiss={() => notifications.dismiss(notification.id)}
				/>
			</div>
		{/each}
	</div>
{/if}
