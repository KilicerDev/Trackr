<script lang="ts">
	import type { Task } from '$lib/stores/tasks.svelte';
	import { typeIcons, defaultTypeIcon } from '$lib/config/task-icons';

	type Props = {
		task: Task;
		depth?: number;
		selected?: boolean;
		onclick?: () => void;
	};

	let { task, depth = 0, selected = false, onclick }: Props = $props();

	const statusDot: Record<string, string> = {
		backlog: 'bg-gray-400/60',
		todo: 'bg-gray-400',
		in_progress: 'bg-amber-400',
		in_review: 'bg-purple-400',
		done: 'bg-green-400',
		cancelled: 'bg-gray-400/30'
	};

	const priorityColors: Record<string, string> = {
		urgent: 'text-red-400',
		high: 'text-orange-400',
		medium: 'text-yellow-500',
		low: 'text-blue-400',
		none: 'text-muted/40'
	};

	function formatDate(dateStr: unknown): string {
		if (!dateStr || typeof dateStr !== 'string') return '';
		const d = new Date(dateStr);
		if (isNaN(d.getTime())) return '';
		const day = d.getDate().toString().padStart(2, '0');
		const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
		return `${day} ${months[d.getMonth()]}`;
	}

	function formatStatus(status: string): string {
		return status.split('_').map((w) => w.charAt(0).toUpperCase() + w.slice(1)).join(' ');
	}

	function formatPriority(priority: string): string {
		return priority.charAt(0).toUpperCase() + priority.slice(1);
	}

	const displayId = $derived(
		task.short_id
			? task.short_id
			: task.project?.identifier
				? `${task.project.identifier}-?`
				: '—'
	);

	const TypeIcon = $derived(typeIcons[task.type] ?? defaultTypeIcon);

	const tags = $derived(
		((task as Record<string, unknown>).tags as { id: string; tag: { id: string; name: string; color: string } }[] | undefined)
			?.map((tt) => tt.tag).filter(Boolean) ?? []
	);
</script>

<button
	data-task-id={task.id}
	class="group flex w-full items-center gap-2.5 px-3 py-[7px] text-left transition-all duration-100 {selected ? 'bg-accent/8' : 'hover:bg-surface-hover/40'}"
	style={depth > 0 ? `padding-left: ${12 + depth * 16}px` : ''}
	{onclick}
>
	<!-- Status dot -->
	<span class="h-1.5 w-1.5 shrink-0 rounded-full {statusDot[task.status] ?? 'bg-gray-400'}"></span>

	<!-- ID -->
	<span class="w-[52px] shrink-0 font-mono text-xs text-muted/50">
		{displayId}
	</span>

	<!-- Title -->
	<span class="min-w-0 flex-1 truncate text-base leading-tight text-sidebar-text">
		{task.title}
	</span>

	<!-- Tags (show on hover) -->
	{#if tags.length > 0}
		<div class="hidden shrink-0 items-center gap-1 group-hover:flex">
			{#each tags.slice(0, 2) as tag (tag.id)}
				<span class="rounded px-1 py-px text-2xs font-medium" style="background-color: {tag.color}12; color: {tag.color}">{tag.name}</span>
			{/each}
			{#if tags.length > 2}
				<span class="text-2xs text-muted/30">+{tags.length - 2}</span>
			{/if}
		</div>
	{/if}

	<!-- Priority -->
	<span class="w-12 shrink-0 text-right text-xs font-medium {priorityColors[task.priority] ?? 'text-muted/40'}">
		{formatPriority(task.priority)}
	</span>

	<!-- Status text -->
	<span class="shrink-0 whitespace-nowrap text-right text-xs text-muted/50">
		{formatStatus(task.status)}
	</span>

	<!-- Due date -->
	{#if formatDate(task.end_at)}
		<span class="shrink-0 font-mono text-xs text-muted/30">{formatDate(task.end_at)}</span>
	{/if}
</button>
