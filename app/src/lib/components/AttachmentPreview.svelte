<script lang="ts">
	import { X, ChevronLeft, ChevronRight, Download } from '@lucide/svelte';
	import { isImageType, isPdfType } from '$lib/config/attachments';
	import type { Attachment } from '$lib/api/attachments';
	import { api } from '$lib/api';

	interface Props {
		attachments: Attachment[];
		currentIndex: number;
		onClose: () => void;
		onNavigate: (index: number) => void;
	}

	let { attachments, currentIndex, onClose, onNavigate }: Props = $props();

	let signedUrl = $state<string | null>(null);
	let loading = $state(false);

	const current = $derived(attachments[currentIndex]);
	const hasPrev = $derived(currentIndex > 0);
	const hasNext = $derived(currentIndex < attachments.length - 1);

	$effect(() => {
		const att = attachments[currentIndex];
		if (!att) return;
		signedUrl = null;
		loading = true;
		api.attachments.getSignedUrl(att.storage_path).then((url) => {
			signedUrl = url;
		}).catch(() => {
			signedUrl = null;
		}).finally(() => {
			loading = false;
		});
	});

	function handleKeydown(e: KeyboardEvent) {
		if (e.key === 'Escape') onClose();
		if (e.key === 'ArrowLeft' && hasPrev) onNavigate(currentIndex - 1);
		if (e.key === 'ArrowRight' && hasNext) onNavigate(currentIndex + 1);
	}

	async function handleDownload() {
		if (!current) return;
		try {
			const url = signedUrl || (await api.attachments.getSignedUrl(current.storage_path));
			const a = document.createElement('a');
			a.href = url;
			a.download = current.file_name;
			a.click();
		} catch {
			/* silent */
		}
	}
</script>

<svelte:window onkeydown={handleKeydown} />

<!-- svelte-ignore a11y_no_static_element_interactions a11y_click_events_have_key_events -->
<div
	data-attachment-preview
	class="fixed inset-0 z-[9999] flex items-center justify-center bg-black/80"
	onclick={onClose}
>
	<!-- Controls -->
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

	<!-- File name -->
	<div class="absolute top-4 left-4 z-10">
		<span class="text-base text-white/80">{current?.file_name ?? ''}</span>
	</div>

	<!-- Nav arrows -->
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

	<!-- Content -->
	<!-- svelte-ignore a11y_no_static_element_interactions a11y_click_events_have_key_events -->
	<div class="max-h-[85vh] max-w-[85vw]" onclick={(e) => e.stopPropagation()}>
		{#if loading}
			<p class="text-base text-white/60">Loading...</p>
		{:else if !signedUrl}
			<p class="text-base text-white/60">Failed to load preview</p>
		{:else if current && isImageType(current.mime_type)}
			<img
				src={signedUrl}
				alt={current.file_name}
				class="max-h-[85vh] max-w-[85vw] rounded object-contain"
			/>
		{:else if current && isPdfType(current.mime_type)}
			<iframe
				src={signedUrl}
				title={current.file_name}
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
