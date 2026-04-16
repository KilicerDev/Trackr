<script lang="ts">
	import { typeIcons, defaultTypeIcon } from '$lib/config/task-icons';
	import { CalendarClock } from '@lucide/svelte';
	import type { Task } from '$lib/stores/tasks.svelte';

	interface Props {
		task: Task;
		selected?: boolean;
		showProjectIdentifier?: boolean;
		showStatus?: boolean;
		onclick: () => void;
	}

	let { task, selected = false, showProjectIdentifier = false, showStatus = false, onclick }: Props = $props();

	const TypeIcon = $derived(typeIcons[task.type] ?? defaultTypeIcon);
	const cardTags = $derived(
		((task as Record<string, unknown>).tags as { id: string; tag: { id: string; name: string; color: string } }[] | undefined)
			?.map((tt) => tt.tag)
			.filter(Boolean) ?? []
	);
	const priorityClass = $derived(
		task.priority === 'urgent' ? 'text-red-400'
			: task.priority === 'high' ? 'text-orange-400'
			: task.priority === 'medium' ? 'text-yellow-500'
			: task.priority === 'low' ? 'text-blue-400'
			: 'text-muted/30'
	);

	const DONE_STATUSES = new Set(['done', 'cancelled']);
	const deadline = $derived.by(() => {
		const endAt = (task as Record<string, unknown>).end_at as string | null | undefined;
		if (!endAt || DONE_STATUSES.has(task.status)) return null;
		const now = new Date();
		const end = new Date(endAt);
		const dayMs = 86_400_000;
		const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
		const startOfEnd = new Date(end.getFullYear(), end.getMonth(), end.getDate()).getTime();
		const days = Math.round((startOfEnd - startOfToday) / dayMs);

		if (days > 4) return null;
		let label: string;
		let klass: string;
		if (days < 0) {
			label = days === -1 ? '1d late' : `${-days}d late`;
			klass = 'bg-red-500/15 text-red-400';
		} else if (days === 0) {
			label = 'Today';
			klass = 'bg-orange-500/15 text-orange-400';
		} else if (days <= 2) {
			label = `${days}d`;
			klass = 'bg-orange-500/15 text-orange-400';
		} else {
			label = `${days}d`;
			klass = 'bg-yellow-500/15 text-yellow-500';
		}
		return { label, klass };
	});

	function formatPriority(p: string): string {
		return p ? p.charAt(0).toUpperCase() + p.slice(1) : '';
	}
	function formatStatus(s: string): string {
		return s ? s.split('_').map((w) => w.charAt(0).toUpperCase() + w.slice(1)).join(' ') : '';
	}
</script>

<button
	class="mb-1.5 w-full cursor-pointer rounded border border-surface-border/50 bg-surface/50 px-3 py-2 text-left transition-all duration-150 hover:bg-surface/80 last:mb-0 {selected ? '!border-accent/50 !bg-accent/15' : ''}"
	{onclick}
>
	<div class="mb-1 flex items-center gap-1.5">
		<span class="text-muted"><TypeIcon size={11} /></span>
		<span class="font-mono text-xs text-muted/50">{task.short_id || '—'}</span>
		{#if deadline}
			<span class="flex items-center gap-1 rounded px-1.5 py-0.5 text-xs font-medium {deadline.klass}">
				<CalendarClock size={11} />
				{deadline.label}
			</span>
		{/if}
		<span class="ml-auto text-xs {priorityClass}">{formatPriority(task.priority)}</span>
	</div>

	<p class="mb-1.5 line-clamp-2 text-base leading-snug text-sidebar-text">{task.title}</p>

	{#if (showProjectIdentifier && task.project) || showStatus || cardTags.length > 0 || task.assignments?.length}
		<div class="flex items-center gap-1.5">
			{#if showProjectIdentifier && task.project}
				<span class="flex items-center gap-1 text-xs text-muted/40">
					<span class="h-1.5 w-1.5 shrink-0 rounded-full" style="background-color: {task.project.color ?? 'var(--color-accent)'}"></span>
					{task.project.identifier}
				</span>
			{:else if showStatus}
				<span class="text-xs text-muted/40">{formatStatus(task.status)}</span>
			{/if}

			{#if cardTags.length > 0}
				<div class="flex flex-1 items-center gap-1 min-w-0">
					{#each cardTags.slice(0, 2) as tag (tag.id)}
						<span class="rounded px-1.5 py-0.5 text-xs font-medium truncate" style="background-color: {tag.color}20; color: {tag.color}">{tag.name}</span>
					{/each}
					{#if cardTags.length > 2}
						<span class="text-xs text-muted/40">+{cardTags.length - 2}</span>
					{/if}
				</div>
			{:else}
				<div class="flex-1"></div>
			{/if}

			{#if task.assignments?.length}
				<div class="flex shrink-0 -space-x-1">
					{#each task.assignments.slice(0, 3) as a (a.user_id)}
						{#if a.user.avatar_url}
							<img src={a.user.avatar_url} alt={a.user.full_name} class="h-4 w-4 rounded-full border border-page-bg object-cover" />
						{:else}
							<span class="flex h-4 w-4 items-center justify-center rounded-full border border-page-bg bg-accent/10 text-4xs font-semibold text-accent">
								{a.user.full_name.charAt(0)}
							</span>
						{/if}
					{/each}
				</div>
			{/if}
		</div>
	{/if}
</button>
