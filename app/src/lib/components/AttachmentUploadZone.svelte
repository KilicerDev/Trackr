<script lang="ts">
	import { Paperclip, Upload } from '@lucide/svelte';
	import { isAllowedMimeType, formatFileSize, MAX_FILE_SIZE, ALLOWED_MIME_TYPES } from '$lib/config/attachments';

	interface Props {
		onFilesSelected: (files: File[]) => void;
		disabled?: boolean;
		maxFiles?: number;
		compact?: boolean;
	}

	let { onFilesSelected, disabled = false, maxFiles = 20, compact = false }: Props = $props();

	let dragOver = $state(false);
	let error = $state<string | null>(null);
	let fileInput: HTMLInputElement | undefined = $state();

	function validateFiles(files: File[]): File[] {
		error = null;
		const valid: File[] = [];
		for (const file of files) {
			if (!isAllowedMimeType(file.type)) {
				error = `${file.name}: file type not allowed`;
				continue;
			}
			if (file.size > MAX_FILE_SIZE) {
				error = `${file.name}: exceeds ${formatFileSize(MAX_FILE_SIZE)} limit`;
				continue;
			}
			valid.push(file);
		}
		if (valid.length > maxFiles) {
			error = `Maximum ${maxFiles} files allowed`;
			return valid.slice(0, maxFiles);
		}
		return valid;
	}

	function handleFiles(fileList: FileList | null) {
		if (!fileList || disabled) return;
		const valid = validateFiles(Array.from(fileList));
		if (valid.length > 0) onFilesSelected(valid);
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
			const valid = validateFiles(files);
			if (valid.length > 0) onFilesSelected(valid);
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

{#if compact}
	<button
		type="button"
		class="flex flex-1 shrink-0 items-center justify-center border border-surface-border bg-surface px-3 text-sidebar-icon transition-colors hover:border-sidebar-icon/30 hover:text-accent disabled:opacity-50"
		{disabled}
		onclick={openPicker}
		aria-label="Attach file"
	>
		<Paperclip size={14} />
	</button>
{:else}
	<!-- svelte-ignore a11y_no_static_element_interactions -->
	<div
		class="flex cursor-pointer items-center justify-center gap-2 border border-dashed px-4 py-4 text-xs transition-colors
			{dragOver ? 'border-accent bg-accent/5 text-accent' : 'border-surface-border text-sidebar-icon hover:border-sidebar-icon/30 hover:text-sidebar-text'}
			{disabled ? 'cursor-not-allowed opacity-50' : ''}"
		ondrop={handleDrop}
		ondragover={handleDragOver}
		ondragleave={handleDragLeave}
		onclick={openPicker}
		onkeydown={(e) => { if (e.key === 'Enter' || e.key === ' ') openPicker(); }}
		role="button"
		tabindex="0"
	>
		<Upload size={16} />
		<span>Drop files here or click to upload</span>
	</div>
{/if}

{#if error}
	<p class="mt-1 text-[11px] text-red-500">{error}</p>
{/if}
