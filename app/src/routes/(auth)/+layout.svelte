<script lang="ts">
	import { page } from '$app/state';
	import { locales, localizeHref, getLocale, setLocale } from '$lib/paraglide/runtime';

	let { children } = $props();

	let dropdownOpen = $state(false);

	const localeFlags: Record<string, string> = {
		en: '🇬🇧',
		de: '🇩🇪'
	};

	const localeLabels: Record<string, string> = {
		en: 'EN',
		de: 'DE'
	};

	function switchLocale(loc: string) {
		setLocale(loc as 'en' | 'de');
		dropdownOpen = false;
	}
</script>

<div class="relative min-h-screen bg-gray-50 font-mono">
	<div class="absolute top-4 right-4">
		<div class="relative">
			<button
				class="flex cursor-pointer items-center gap-1 rounded-md border border-gray-200 bg-white px-3 py-1.5 text-sm"
				onclick={() => (dropdownOpen = !dropdownOpen)}
				onblur={() => setTimeout(() => (dropdownOpen = false), 150)}
			>
				<span class="text-base">{localeFlags[getLocale()] ?? ''}</span>
				<span class="text-xs">{localeLabels[getLocale()] ?? getLocale()}</span>
				<svg class="h-4 w-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
				</svg>
			</button>

			{#if dropdownOpen}
				<div
					class="absolute right-0 mt-1 overflow-hidden rounded-md border border-gray-200 bg-white "
				>
					{#each locales as loc (loc)}
						<a
							href={localizeHref(page.url.pathname, { locale: loc })}
							onclick={(e) => {
								e.preventDefault();
								switchLocale(loc);
							}}
							class="flex items-center gap-2 px-4 py-2 text-sm hover:bg-gray-50"
						>
							<span class="text-base">{localeFlags[loc] ?? ''}</span>
							<span class="text-xs">{localeLabels[loc] ?? loc}</span>
						</a>
					{/each}
				</div>
			{/if}
		</div>
	</div>

	<div class="flex min-h-screen items-center justify-center px-4">
		<div class="w-full max-w-md rounded-lg border border-gray-200 bg-white px-10 py-10">
			{@render children()}
		</div>
	</div>
</div>
