<script lang="ts">
	import { page } from '$app/state';
	import { sidebarSections } from '$lib/config/sidebar';
	import { PanelLeftClose, PanelLeftOpen } from '@lucide/svelte';
	import logo from '$lib/assets/logo.png';

	let { pinned = $bindable(false) } = $props();

	let hovered = $state(false);
	let expanded = $derived(pinned || hovered);
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<aside
	class="fixed top-0 left-0 z-50 flex h-screen flex-col border-r border-sidebar-border bg-sidebar-bg transition-all duration-200 ease-in-out"
	style="width: {expanded ? '240px' : '64px'}"
	onmouseenter={() => { if (!pinned) hovered = true; }}
	onmouseleave={() => { if (!pinned) hovered = false; }}
>
	<div class="flex h-14 items-center gap-2 overflow-hidden px-4">
		<img src={logo} alt="Trackr" class="h-7 w-7 shrink-0" />
		{#if expanded}
			<span
				class="whitespace-nowrap text-lg font-bold tracking-widest text-sidebar-text transition-opacity duration-200"
			>
				TRACKR
			</span>
		{/if}
	</div>

	<nav class="flex-1 overflow-y-auto overflow-x-hidden py-2">
		{#each sidebarSections as section, sectionIdx}
			<div class="overflow-hidden px-4 pt-3 pb-1 text-[10px] font-semibold tracking-widest text-sidebar-label uppercase">
				{#if expanded}
					<span class="whitespace-nowrap">{section.title}</span>
				{:else}
					&nbsp;
				{/if}
			</div>

			{#each section.items as item}
				{@const isActive = page.url.pathname === item.href || (item.href !== '/' && page.url.pathname.startsWith(item.href))}
				<a
					href={item.href}
					class="group relative flex h-10 items-center gap-3 px-5 text-sm transition-colors duration-150
						{isActive
							? 'bg-sidebar-hover-bg font-semibold text-accent'
							: 'text-sidebar-icon hover:bg-sidebar-hover-bg hover:text-sidebar-text'}"
				>
					{#if isActive}
						<span class="absolute top-0 left-0 h-full w-[3px] bg-accent"></span>
					{/if}
					<item.icon size={20} class="shrink-0" />
					{#if expanded}
						<span class="truncate whitespace-nowrap">{item.label}</span>
					{/if}
				</a>
			{/each}
		{/each}
	</nav>

	<div class="border-t border-sidebar-border py-2">
		<button
			onclick={() => { pinned = !pinned; hovered = false; }}
			class="flex h-10 w-full cursor-pointer items-center gap-3 px-5 text-sm text-sidebar-icon transition-colors duration-150 hover:bg-sidebar-hover-bg hover:text-sidebar-text"
		>
			{#if pinned}
				<PanelLeftClose size={20} class="shrink-0" />
			{:else}
				<PanelLeftOpen size={20} class="shrink-0" />
			{/if}
			{#if expanded}
				<span class="truncate whitespace-nowrap">{pinned ? 'Collapse' : 'Expand'}</span>
			{/if}
		</button>
	</div>
</aside>
