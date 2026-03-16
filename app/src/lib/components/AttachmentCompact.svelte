<script lang="ts">
	import { Paperclip } from '@lucide/svelte';
	import type { Attachment } from '$lib/api/attachments';
	import AttachmentPreview from './AttachmentPreview.svelte';

	interface Props {
		attachments: Attachment[];
	}

	let { attachments }: Props = $props();

	let expanded = $state(false);
	let previewIndex = $state<number | null>(null);

	function openPreview(att: Attachment) {
		const idx = attachments.findIndex((a) => a.id === att.id);
		previewIndex = idx >= 0 ? idx : 0;
	}
</script>

{#if attachments.length === 1}
	<button
		class="mt-1 flex items-center gap-1 text-[11px] text-sidebar-icon transition-colors hover:text-accent"
		onclick={() => openPreview(attachments[0])}
	>
		<Paperclip size={11} />
		<span class="truncate">{attachments[0].file_name}</span>
	</button>
{:else if attachments.length > 1}
	<div class="mt-1">
		<button
			class="flex items-center gap-1 text-[11px] text-sidebar-icon transition-colors hover:text-accent"
			onclick={() => (expanded = !expanded)}
		>
			<Paperclip size={11} />
			<span>{attachments.length} attachments</span>
		</button>
		{#if expanded}
			<div class="mt-1 space-y-0.5 pl-4">
				{#each attachments as att (att.id)}
					<button
						class="block truncate text-[11px] text-sidebar-icon transition-colors hover:text-accent"
						onclick={() => openPreview(att)}
					>
						{att.file_name}
					</button>
				{/each}
			</div>
		{/if}
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
