<script lang="ts">
	import type { Task } from '$lib/stores/tasks.svelte';

	type Props = {
		task: Task;
		onclick?: () => void;
	};

	let { task, onclick }: Props = $props();

	const typeIcons: Record<string, string> = {
		task: '☰',
		bug: '🐛',
		feature: '✦',
		improvement: '▲',
		epic: '◆'
	};

	const priorityColors: Record<string, string> = {
		urgent: 'bg-red-100 text-red-700',
		high: 'bg-orange-100 text-orange-700',
		medium: 'bg-yellow-100 text-yellow-700',
		low: 'bg-blue-100 text-blue-700',
		none: 'bg-gray-100 text-gray-500'
	};

	const statusColors: Record<string, string> = {
		backlog: 'bg-gray-100 text-gray-600',
		todo: 'bg-gray-100 text-gray-700',
		in_progress: 'bg-pink-100 text-pink-700',
		in_review: 'bg-purple-100 text-purple-700',
		done: 'bg-green-100 text-green-700',
		cancelled: 'bg-gray-100 text-gray-400'
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
	class="group flex w-full items-center gap-3 border-b border-gray-100 px-4 py-2.5 text-left text-sm transition-colors hover:bg-gray-50/60"
	{onclick}
>
	<span class="shrink-0 text-base text-gray-400">
		{typeIcons[task.type] ?? '☰'}
	</span>

	<span class="shrink-0 font-medium text-accent">
		{displayId}
	</span>

	<span class="min-w-0 flex-1 truncate text-gray-800">
		{task.title}
	</span>

	<div class="flex shrink-0 items-center gap-3">
		<span
			class="inline-flex min-w-[70px] justify-center rounded-sm px-2 py-0.5 text-xs font-medium {priorityColors[
				task.priority
			] ?? 'bg-gray-100 text-gray-500'}"
		>
			{formatPriority(task.priority)}
		</span>

		<span
			class="inline-flex min-w-[90px] justify-center rounded-sm px-2 py-0.5 text-xs font-medium {statusColors[
				task.status
			] ?? 'bg-gray-100 text-gray-600'}"
		>
			{formatStatus(task.status)}
		</span>

		<span class="w-[80px] text-right text-xs text-gray-400">
			{formatDate(task.start_at)}
		</span>

		<span class="w-[80px] text-right text-xs text-gray-400">
			{formatDate(task.end_at)}
		</span>
	</div>
</button>
