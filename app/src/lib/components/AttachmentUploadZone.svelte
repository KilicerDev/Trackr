<script lang="ts">
	import { Paperclip, Upload } from '@lucide/svelte';
	import { ALLOWED_MIME_TYPES, validateAttachmentFiles } from '$lib/config/attachments';

	interface Props {
		onFilesSelected: (files: File[]) => void;
		disabled?: boolean;
		maxFiles?: number;
		variant?: 'tile' | 'compact' | 'button';
	}

	let { onFilesSelected, disabled = false, maxFiles = 20, variant = 'tile' }: Props = $props();

	let dragOver = $state(false);
	let error = $state<string | null>(null);
	let fileInput: HTMLInputElement | undefined = $state();

	function handleFiles(fileList: FileList | null) {
		if (!fileList || disabled) return;
		const result = validateAttachmentFiles(Array.from(fileList), maxFiles);
		error = result.error;
		if (result.valid.length > 0) onFilesSelected(result.valid);
	}

	function handleDrop(e: DragEvent) {
		e.preventDefault();
		dragOver = false;
		handleFiles(e.dataTransfer?.files ?? null);
	}

	function handleDragOver(e: DragEvent) {
		e.preventDefault();
		if (!disabled) dragOver = true;
	}

	function handleDragLeave() {
		dragOver = false;
	}

	function handlePaste(e: ClipboardEvent) {
		if (disabled) return;
		const items = e.clipboardData?.items;
		if (!items) return;
		const files: File[] = [];
		for (const item of items) {
			if (item.kind === 'file') {
				const file = item.getAsFile();
				if (file) files.push(file);
			}
		}
		if (files.length > 0) {
			const result = validateAttachmentFiles(files, maxFiles);
			error = result.error;
			if (result.valid.length > 0) onFilesSelected(result.valid);
		}
	}

	function openPicker() {
		if (!disabled) fileInput?.click();
	}

	const acceptTypes = ALLOWED_MIME_TYPES.join(',');
</script>

<svelte:window onpaste={handlePaste} />

<input
	bind:this={fileInput}
	type="file"
	multiple
	accept={acceptTypes}
	class="hidden"
	onchange={(e) => handleFiles((e.target as HTMLInputElement).files)}
/>

{#if variant === 'compact'}
	<button
		type="button"
		class="flex flex-1 shrink-0 items-center justify-center rounded-sm border border-surface-border bg-surface px-3 text-sidebar-icon transition-colors hover:border-sidebar-icon/30 hover:text-accent disabled:opacity-50 focus-visible:ring-1 focus-visible:ring-accent/50 focus-visible:outline-none"
		{disabled}
		onclick={openPicker}
		aria-label="Attach file"
	>
		<Paperclip size={14} />
	</button>
{:else if variant === 'button'}
	<button
		type="button"
		class="text-sm text-sidebar-icon transition-colors hover:text-accent disabled:opacity-50"
		{disabled}
		onclick={openPicker}
	>
		+ Add
	</button>
{:else}
	<!-- svelte-ignore a11y_no_static_element_interactions -->
	<div
		class="flex h-[100px] w-[100px] cursor-pointer flex-col items-center justify-center gap-1 rounded-sm border border-dashed text-xs transition-colors
			{dragOver ? 'border-accent bg-accent/5 text-accent' : 'border-surface-border/60 text-muted/40 hover:border-sidebar-icon/30 hover:text-muted'}
			{disabled ? 'cursor-not-allowed opacity-50' : ''}"
		ondrop={handleDrop}
		ondragover={handleDragOver}
		ondragleave={handleDragLeave}
		onclick={openPicker}
		onkeydown={(e) => { if (e.key === 'Enter' || e.key === ' ') openPicker(); }}
		role="button"
		tabindex="0"
	>
		<Upload size={14} />
		<span>Upload</span>
	</div>
{/if}

{#if error}
	<p class="mt-1 text-sm text-red-500">{error}</p>
{/if}
