<script lang="ts">
	import { page } from '$app/state';
	import { locales, localizeHref } from '$lib/paraglide/runtime';
	import './layout.css';
	import favicon from '$lib/assets/favicon.svg';
	import type { LayoutData } from './$types';
	import { auth } from '$lib/stores/auth.svelte';
	import { theme } from '$lib/stores/theme.svelte';
	import NotificationContainer from '$lib/components/NotificationContainer.svelte';

	import type { Snippet } from 'svelte';

	let { data, children }: { data: LayoutData; children: Snippet } = $props();

	$effect(() => {
		auth.init(data.user, data.role, data.permissions, data.isPlatformMember);
	});

	$effect(() => {
		if (typeof document === 'undefined') return;
		theme.init();
		document.documentElement.classList.toggle('dark', theme.mode === 'dark');
	});
</script>

<svelte:head>
	<link rel="icon" href={favicon} />
	<meta name="robots" content="noindex, nofollow" />
</svelte:head>

{@render children()}
<NotificationContainer />

<div style="display:none">
	{#each locales as locale (locale)}
		<a href={localizeHref(page.url.pathname, { locale })}>{locale}</a>
	{/each}
</div>
