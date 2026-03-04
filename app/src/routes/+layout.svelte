<script lang="ts">
	import { page } from '$app/state';
	import { locales, localizeHref } from '$lib/paraglide/runtime';
	import './layout.css';
	import favicon from '$lib/assets/favicon.svg';
	import type { LayoutData } from './$types';
	import { auth } from '$lib/stores/auth.svelte';
	import { theme } from '$lib/stores/theme.svelte';
	import NotificationContainer from '$lib/components/NotificationContainer.svelte';

	let { data, children }: { data: LayoutData; children: any } = $props();

	$effect(() => {
		auth.init(data.user, data.role, data.permissions);
	});

	$effect(() => {
		if (typeof document === 'undefined') return;
		theme.init();
		document.documentElement.classList.toggle('dark', theme.mode === 'dark');
	});
</script>

<svelte:head><link rel="icon" href={favicon} /></svelte:head>
{@render children()}
<NotificationContainer />

<div style="display:none">
	{#each locales as locale}
		<a href={localizeHref(page.url.pathname, { locale })}>{locale}</a>
	{/each}
</div>
