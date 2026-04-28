<script lang="ts">
	import { X, ChevronLeft, ChevronRight, Download } from '@lucide/svelte';
	import { isImageType, isPdfType, isVideoType } from '$lib/config/attachments';

	export type PreviewItem = { name: string; mime: string };

	interface Props {
		items: PreviewItem[];
		currentIndex: number;
		resolveUrl: (index: number) => string | Promise<string>;
		onClose: () => void;
		onNavigate: (index: number) => void;
		onDownload?: (index: number) => void;
	}

	let { items, currentIndex, resolveUrl, onClose, onNavigate, onDownload }: Props = $props();

	let signedUrl = $state<string | null>(null);
	let loading = $state(false);

	const current = $derived(items[currentIndex]);
	const hasPrev = $derived(currentIndex > 0);
	const hasNext = $derived(currentIndex < items.length - 1);

	$effect(() => {
		const idx = currentIndex;
		if (!items[idx]) return;
		signedUrl = null;
		loading = true;
		const result = resolveUrl(idx);
		Promise.resolve(result).then((url) => {
			signedUrl = url;
		}).catch(() => {
			signedUrl = null;
		}).finally(() => {
			loading = false;
		});
	});

	// Capture-phase listener on window so Esc is consumed before any underlying
	// Modal's document-level listener fires.
	$effect(() => {
		function onKeydown(e: KeyboardEvent) {
			if (e.key === 'Escape') {
				e.stopImmediatePropagation();
				e.stopPropagation();
				e.preventDefault();
				onClose();
			} else if (e.key === 'ArrowLeft' && hasPrev) {
				e.preventDefault();
				onNavigate(currentIndex - 1);
			} else if (e.key === 'ArrowRight' && hasNext) {
				e.preventDefault();
				onNavigate(currentIndex + 1);
			}
		}
		window.addEventListener('keydown', onKeydown, true);
		return () => window.removeEventListener('keydown', onKeydown, true);
	});

	async function handleDownload() {
		if (!current) return;
		if (onDownload) {
			onDownload(currentIndex);
			return;
		}
		try {
			const url = signedUrl ?? (await Promise.resolve(resolveUrl(currentIndex)));
			const a = document.createElement('a');
			a.href = url;
			a.download = current.name;
			a.click();
		} catch {
			/* silent */
		}
	}
</script>

<!-- svelte-ignore a11y_no_static_element_interactions a11y_click_events_have_key_events -->
<div
	data-attachment-preview
	class="fixed inset-0 z-[10000] flex items-center justify-center bg-black/80"
	onclick={onClose}
>
	<!-- svelte-ignore a11y_no_static_element_interactions a11y_click_events_have_key_events -->
	<div class="absolute top-4 right-4 z-10 flex items-center gap-1.5" onclick={(e) => e.stopPropagation()}>
		<button
			class="flex h-8 w-8 items-center justify-center rounded-sm bg-white/10 text-white transition-all duration-150 hover:bg-white/20"
			onclick={handleDownload}
			aria-label="Download"
		>
			<Download size={16} />
		</button>
		<button
			class="flex h-8 w-8 items-center justify-center rounded-sm bg-white/10 text-white transition-all duration-150 hover:bg-white/20"
			onclick={onClose}
			aria-label="Close"
		>
			<X size={16} />
		</button>
	</div>

	<div class="absolute top-4 left-4 z-10">
		<span class="text-base text-white/80">{current?.name ?? ''}</span>
	</div>

	{#if hasPrev}
		<button
			class="absolute left-4 z-10 flex h-8 w-8 items-center justify-center rounded-sm bg-white/10 text-white transition-all duration-150 hover:bg-white/20"
			onclick={(e) => { e.stopPropagation(); onNavigate(currentIndex - 1); }}
			aria-label="Previous"
		>
			<ChevronLeft size={20} />
		</button>
	{/if}
	{#if hasNext}
		<button
			class="absolute right-4 z-10 flex h-8 w-8 items-center justify-center rounded-sm bg-white/10 text-white transition-all duration-150 hover:bg-white/20"
			onclick={(e) => { e.stopPropagation(); onNavigate(currentIndex + 1); }}
			aria-label="Next"
		>
			<ChevronRight size={20} />
		</button>
	{/if}

	<!-- svelte-ignore a11y_no_static_element_interactions a11y_click_events_have_key_events -->
	<div class="max-h-[85vh] max-w-[85vw]" onclick={(e) => e.stopPropagation()}>
		{#if loading}
			<p class="text-base text-white/60">Loading...</p>
		{:else if !signedUrl}
			<p class="text-base text-white/60">Failed to load preview</p>
		{:else if current && isImageType(current.mime)}
			<img
				src={signedUrl}
				alt={current.name}
				class="max-h-[85vh] max-w-[85vw] rounded object-contain"
			/>
		{:else if current && isVideoType(current.mime)}
			<!-- svelte-ignore a11y_media_has_caption -->
			<video
				src={signedUrl}
				controls
				class="max-h-[85vh] max-w-[85vw] rounded bg-black"
			></video>
		{:else if current && isPdfType(current.mime)}
			<iframe
				src={signedUrl}
				title={current.name}
				class="h-[85vh] w-[70vw] rounded border-0 bg-white"
			></iframe>
		{:else}
			<div class="flex flex-col items-center gap-4 rounded border border-surface-border/40 bg-surface/50 p-8">
				<p class="text-base text-sidebar-text">No preview available for this file type</p>
				<button
					class="flex h-7 items-center gap-1 rounded-sm bg-accent px-2.5 text-sm font-medium text-white transition-all duration-150 hover:bg-accent/90"
					onclick={handleDownload}
				>
					Download to view
				</button>
			</div>
		{/if}
	</div>
</div>
