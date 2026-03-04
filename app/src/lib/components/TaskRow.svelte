<script lang="ts">
	import type { Task } from '$lib/stores/tasks.svelte';

	type Props = {
		task: Task;
		depth?: number;
		onclick?: () => void;
	};

	let { task, depth = 0, onclick }: Props = $props();

	const typeIcons: Record<string, string> = {
		task: '☰',
		bug: '🐛',
		feature: '✦',
		improvement: '▲',
		epic: '◆'
	};

	const priorityColors: Record<string, string> = {
		urgent:
			'bg-red-100 text-red-700 dark:bg-red-950/60 dark:text-red-300',
		high:
			'bg-orange-100 text-orange-700 dark:bg-orange-950/60 dark:text-orange-300',
		medium:
			'bg-yellow-100 text-yellow-700 dark:bg-yellow-950/60 dark:text-yellow-300',
		low:
			'bg-blue-100 text-blue-700 dark:bg-blue-950/60 dark:text-blue-300',
		none:
			'bg-gray-100 text-gray-500 dark:bg-surface-hover dark:text-muted'
	};

	const statusColors: Record<string, string> = {
		backlog:
			'bg-gray-100 text-gray-600 dark:bg-surface-hover dark:text-sidebar-text',
		todo:
			'bg-gray-100 text-gray-700 dark:bg-surface-hover dark:text-sidebar-text',
		in_progress:
			'bg-pink-100 text-pink-700 dark:bg-pink-950/60 dark:text-pink-300',
		in_review:
			'bg-purple-100 text-purple-700 dark:bg-purple-950/60 dark:text-purple-300',
		done:
			'bg-green-100 text-green-700 dark:bg-green-950/60 dark:text-green-300',
		cancelled:
			'bg-gray-100 text-gray-400 dark:bg-surface-hover dark:text-muted'
	};

	function formatDate(dateStr: unknown): string {
		if (!dateStr || typeof dateStr !== 'string') return '';
		const d = new Date(dateStr);
		if (isNaN(d.getTime())) return '';
		return d.toLocaleDateString('de-DE', {
			day: '2-digit',
			month: '2-digit',
			year: 'numeric'
		});
	}

	function formatStatus(status: string): string {
		return status
			.split('_')
			.map((w) => w.charAt(0).toUpperCase() + w.slice(1))
			.join(' ');
	}

	function formatPriority(priority: string): string {
		return priority.charAt(0).toUpperCase() + priority.slice(1);
	}

	const displayId = $derived(
		task.project?.identifier ? `${task.project.identifier}-${task.short_id}` : task.short_id
	);
</script>

<button
	class="group flex w-full items-center gap-3 border-b border-surface-border py-2.5 text-left text-sm transition-colors hover:bg-surface-hover"
	style="padding-left: {16 + depth * 24}px; padding-right: 16px;"
	{onclick}
>
	<span class="shrink-0 text-base text-muted">
		{typeIcons[task.type] ?? '☰'}
	</span>

	<span class="shrink-0 font-medium text-accent">
		{displayId}
	</span>

	<span class="min-w-0 flex-1 truncate text-sidebar-text">
		{task.title}
	</span>

	<div class="flex shrink-0 items-center gap-3">
		<span
			class="inline-flex min-w-[70px] justify-center rounded-sm px-2 py-0.5 text-xs font-medium {priorityColors[
				task.priority
			] ?? 'bg-gray-100 text-gray-500 dark:bg-surface-hover dark:text-muted'}"
		>
			{formatPriority(task.priority)}
		</span>

		<span
			class="inline-flex min-w-[90px] justify-center rounded-sm px-2 py-0.5 text-xs font-medium {statusColors[
				task.status
			] ?? 'bg-gray-100 text-gray-600 dark:bg-surface-hover dark:text-sidebar-text'}"
		>
			{formatStatus(task.status)}
		</span>

		<span class="w-[80px] text-right text-xs text-muted">
			{formatDate(task.start_at)}
		</span>

		<span class="w-[80px] text-right text-xs text-muted">
			{formatDate(task.end_at)}
		</span>
	</div>
</button>
