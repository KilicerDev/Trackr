<script lang="ts">
	import { page } from '$app/state';
	import { invalidateAll } from '$app/navigation';
	import { locales, localizeHref } from '$lib/paraglide/runtime';
	import './layout.css';
	import favicon from '$lib/assets/favicon.svg';
	import type { LayoutData } from './$types';
	import { auth } from '$lib/stores/auth.svelte';
	import { theme } from '$lib/stores/theme.svelte';
	import { getClient } from '$lib/api/client';
	import NotificationContainer from '$lib/components/NotificationContainer.svelte';

	import type { Snippet } from 'svelte';

	let { data, children }: { data: LayoutData; children: Snippet } = $props();

	$effect(() => {
		auth.init(data.user, data.role, data.permissions, data.isPlatformMember);
	});

	$effect(() => {
		const supabase = getClient();
		const {
			data: { subscription }
		} = supabase.auth.onAuthStateChange((event: string) => {
			if (event === 'SIGNED_OUT' || event === 'TOKEN_REFRESHED') {
				invalidateAll();
			}
		});
		return () => subscription.unsubscribe();
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
	<meta title="Trackr" />
	<meta name="description" content="Trackr is a platform for tracking your tasks and projects." />
	<meta name="keywords" content="trackr, tasks, projects, tracking" />
	<meta name="author" content="Trackr" />
	<meta name="viewport" content="width=device-width, initial-scale=1.0" />
	<meta name="robots" content="noindex, nofollow" />
	<meta name="robots" content="noindex, nofollow" />
</svelte:head>

{@render children()}
<NotificationContainer />

<div style="display:none">
	{#each locales as locale (locale)}
		<a href={localizeHref(page.url.pathname, { locale })}>{locale}</a>
	{/each}
</div>
