<script lang="ts">
	import { Download, Trash2, FileText, Image, Table, Presentation, File } from '@lucide/svelte';
	import { isImageType, formatFileSize } from '$lib/config/attachments';
	import type { Attachment } from '$lib/api/attachments';
	import { api } from '$lib/api';
	import AttachmentPreview from './AttachmentPreview.svelte';

	interface Props {
		attachments: Attachment[];
		canDelete?: boolean;
		onRemove?: (attachment: Attachment) => void;
	}

	let { attachments, canDelete = false, onRemove }: Props = $props();

	let previewIndex = $state<number | null>(null);

	function getIcon(mime: string) {
		if (isImageType(mime)) return Image;
		if (mime === 'application/pdf') return FileText;
		if (mime.includes('spreadsheet') || mime.includes('excel') || mime === 'text/csv') return Table;
		if (mime.includes('presentation') || mime.includes('powerpoint')) return Presentation;
		if (mime.includes('word') || mime.includes('document') || mime === 'text/plain') return FileText;
		return File;
	}

	function formatDate(dateStr: string): string {
		const d = new Date(dateStr);
		if (isNaN(d.getTime())) return '—';
		return d.toLocaleDateString('de-DE', { day: '2-digit', month: '2-digit', year: 'numeric' });
	}

	async function handleDownload(att: Attachment) {
		try {
			const url = await api.attachments.getSignedUrl(att.storage_path);
			const a = document.createElement('a');
			a.href = url;
			a.download = att.file_name;
			a.click();
		} catch {
			/* silent */
		}
	}
</script>

{#if attachments.length > 0}
	<div class="divide-y divide-surface-border">
		{#each attachments as att, i (att.id)}
			{@const Icon = getIcon(att.mime_type)}
			<div class="group flex items-center gap-3 py-2">
				<button
					class="flex min-w-0 flex-1 items-center gap-3 text-left"
					onclick={() => (previewIndex = i)}
				>
					<Icon size={16} class="shrink-0 text-sidebar-icon" />
					<div class="min-w-0 flex-1">
						<p class="truncate text-xs text-sidebar-text">{att.file_name}</p>
						<p class="text-[10px] text-muted">
							{formatFileSize(att.file_size)}
							{#if att.uploader}
								&middot; {att.uploader.full_name}
							{/if}
							&middot; {formatDate(att.created_at)}
						</p>
					</div>
				</button>
				<div class="flex shrink-0 items-center gap-1 opacity-0 transition-opacity group-hover:opacity-100">
					<button
						class="p-1 text-sidebar-icon transition-colors hover:text-accent"
						onclick={() => handleDownload(att)}
						aria-label="Download {att.file_name}"
					>
						<Download size={14} />
					</button>
					{#if canDelete && onRemove}
						<button
							class="p-1 text-sidebar-icon transition-colors hover:text-red-500"
							onclick={() => onRemove?.(att)}
							aria-label="Delete {att.file_name}"
						>
							<Trash2 size={14} />
						</button>
					{/if}
				</div>
			</div>
		{/each}
	</div>
{/if}

{#if previewIndex !== null}
	<AttachmentPreview
		{attachments}
		currentIndex={previewIndex}
		onClose={() => (previewIndex = null)}
		onNavigate={(idx) => (previewIndex = idx)}
	/>
{/if}
