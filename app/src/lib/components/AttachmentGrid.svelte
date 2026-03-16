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
	let thumbnailUrls = $state<Record<string, string>>({});

	const iconMap: Record<string, typeof File> = {
		'image': Image,
		'file-text': FileText,
		'table': Table,
		'presentation': Presentation,
		'file': File,
	};

	function getIcon(mime: string) {
		if (isImageType(mime)) return Image;
		if (mime === 'application/pdf') return FileText;
		if (mime.includes('spreadsheet') || mime.includes('excel') || mime === 'text/csv') return Table;
		if (mime.includes('presentation') || mime.includes('powerpoint')) return Presentation;
		if (mime.includes('word') || mime.includes('document') || mime === 'text/plain') return FileText;
		return File;
	}

	$effect(() => {
		for (const att of attachments) {
			if (isImageType(att.mime_type) && !thumbnailUrls[att.id]) {
				api.attachments.getThumbnailUrl(att.storage_path, 200, 200).then((url) => {
					thumbnailUrls = { ...thumbnailUrls, [att.id]: url };
				}).catch(() => {});
			}
		}
	});

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

	function handleClick(index: number) {
		previewIndex = index;
	}
</script>

{#if attachments.length > 0}
	<div class="flex flex-wrap gap-2">
		{#each attachments as att, i (att.id)}
			{@const Icon = getIcon(att.mime_type)}
			<div
				class="group relative flex h-[100px] w-[100px] cursor-pointer flex-col items-center justify-center gap-1 border border-surface-border bg-surface transition-colors hover:border-sidebar-icon/30"
			>
				<button
					class="flex h-full w-full flex-col items-center justify-center gap-1 p-2"
					onclick={() => handleClick(i)}
				>
					{#if isImageType(att.mime_type) && thumbnailUrls[att.id]}
						<img
							src={thumbnailUrls[att.id]}
							alt={att.file_name}
							class="h-full w-full object-cover"
						/>
					{:else}
						<Icon size={24} class="text-sidebar-icon" />
						<span class="w-full truncate text-center text-[9px] text-muted">{att.file_name}</span>
					{/if}
				</button>

				<!-- Action overlay -->
				<div class="absolute top-0.5 right-0.5 flex gap-0.5 opacity-0 transition-opacity group-hover:opacity-100">
					<button
						class="rounded-sm bg-surface/90 p-0.5 text-sidebar-icon transition-colors hover:text-accent"
						onclick={(e) => { e.stopPropagation(); handleDownload(att); }}
						aria-label="Download {att.file_name}"
					>
						<Download size={12} />
					</button>
					{#if canDelete && onRemove}
						<button
							class="rounded-sm bg-surface/90 p-0.5 text-sidebar-icon transition-colors hover:text-red-500"
							onclick={(e) => { e.stopPropagation(); onRemove?.(att); }}
							aria-label="Delete {att.file_name}"
						>
							<Trash2 size={12} />
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
