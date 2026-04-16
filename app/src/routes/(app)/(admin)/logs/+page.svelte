<svelte:head><title>Activity Logs – Trackr</title></svelte:head>

<script lang="ts">
	import { onMount } from 'svelte';
	import { api } from '$lib/api';
	import { localizeHref } from '$lib/paraglide/runtime';
	import { btnSecondary } from '$lib/styles/ui';
	import type { ActivityLogEntry, ActivityLogFilter } from '$lib/api/activities';
	import { formatTimeAgo, formatFullDate } from '$lib/utils/date';
	import { ChevronLeft, ChevronRight } from '@lucide/svelte';

	const PER_PAGE = 25;
	const FILTERS: { key: ActivityLogFilter; label: string }[] = [
		{ key: 'all', label: 'All' },
		{ key: 'task', label: 'Tasks' },
		{ key: 'ticket', label: 'Tickets' },
		{ key: 'wiki', label: 'Wiki' }
	];

	const SOURCE_LABELS: Record<ActivityLogEntry['source_type'], string> = {
		task: 'task',
		ticket: 'ticket',
		wiki_page: 'wiki page',
		wiki_folder: 'wiki folder',
		wiki_file: 'wiki file'
	};

	let items = $state<ActivityLogEntry[]>([]);
	let totalCount = $state(0);
	let loading = $state(true);
	let error = $state<string | null>(null);
	let currentPage = $state(1);
	let typeFilter = $state<ActivityLogFilter>('all');

	let totalPages = $derived(Math.ceil(totalCount / PER_PAGE));

	async function loadLogs() {
		loading = true;
		error = null;
		try {
			const result = await api.activities.getLogs(typeFilter, currentPage, PER_PAGE);
			items = result.data;
			totalCount = result.count;
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to load logs';
		} finally {
			loading = false;
		}
	}

	function setFilter(f: ActivityLogFilter) {
		typeFilter = f;
		currentPage = 1;
		loadLogs();
	}

	function formatField(field: string | null): string {
		if (!field) return 'item';
		return field.replace(/_/g, ' ').replace(/\bid\b/g, '').trim();
	}

	function formatValue(val: string | null): string {
		if (!val) return '—';
		if (val.length > 80) return val.slice(0, 80) + '…';
		return val.replace(/_/g, ' ');
	}

	function getSourceHref(entry: ActivityLogEntry): string {
		if (entry.source_type === 'ticket') return localizeHref(`/tickets?id=${entry.source_id}`);
		if (entry.source_type === 'wiki_page') return localizeHref(`/wiki/${entry.source_id}`);
		if (entry.source_type === 'wiki_file') return localizeHref(`/wiki/file/${entry.source_id}`);
		if (entry.source_type === 'wiki_folder') return localizeHref(`/wiki`);
		if (entry.source_project_id) return localizeHref(`/projects/${entry.source_project_id}?task=${entry.source_id}`);
		return localizeHref(`/tasks`);
	}

	onMount(loadLogs);
</script>

<div class="mx-auto w-full">
	<!-- Header -->
	<div class="flex items-center justify-between px-3 py-1.5">
		<h1 class="text-md font-semibold text-sidebar-text">Activity Logs</h1>
		<div class="flex items-center gap-0.5">
			{#each FILTERS as f (f.key)}
				<button
					class="rounded-sm px-2.5 py-1 text-sm font-medium transition-all duration-150
						{typeFilter === f.key
							? 'bg-accent/10 text-accent'
							: 'text-muted hover:text-sidebar-text'}"
					onclick={() => setFilter(f.key)}
				>
					{f.label}
				</button>
			{/each}
		</div>
	</div>

	{#if loading}
		<p class="px-3 py-8 text-center text-sm text-muted">Loading...</p>
	{:else if error}
		<p class="px-3 py-8 text-center text-sm text-red-400">{error}</p>
	{:else if items.length === 0}
		<p class="px-3 py-8 text-center text-sm text-muted">No activity yet.</p>
	{:else}
		<div class="mx-3 mb-2 overflow-hidden rounded border border-surface-border/40 bg-surface/50">
			{#each items as entry (entry.id)}
				<div class="flex items-center gap-3 border-b border-surface-border/30 px-3 py-2.5 last:border-b-0">
					<!-- Avatar -->
					{#if entry.user_avatar}
						<img
							src={entry.user_avatar}
							alt={entry.user_name}
							class="h-6 w-6 shrink-0 rounded-full object-cover"
						/>
					{:else}
						<div class="mt-0.5 flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-accent/10 text-2xs font-medium text-accent">
							{entry.user_name?.charAt(0)?.toUpperCase() ?? '?'}
						</div>
					{/if}

					<!-- Content -->
					<div class="min-w-0 flex-1">
						<p class="text-sm leading-relaxed">
							<span class="font-medium text-sidebar-text">{entry.user_name}</span>
							{#if entry.action === 'created'}
								<span class="text-muted"> created </span>
							{:else if entry.action === 'deleted'}
								<span class="text-muted"> deleted </span>
							{:else if entry.action === 'commented'}
								<span class="text-muted"> commented on </span>
							{:else if entry.action === 'messaged'}
								<span class="text-muted"> sent a message on </span>
							{:else if entry.field_name === 'content'}
								<span class="text-muted"> edited the content of </span>
							{:else}
								<span class="text-muted"> changed </span>
								<span class="text-sidebar-text">{formatField(entry.field_name)}</span>
								{#if entry.old_value}
									<span class="text-muted"> from </span>
									<span class="text-red-400/70 line-through">{formatValue(entry.old_value)}</span>
								{/if}
								<span class="text-muted"> to </span>
								<span class="text-green-400/80">{formatValue(entry.new_value)}</span>
								<span class="text-muted"> on </span>
							{/if}
							<span class="inline-flex items-center gap-1">
								<span class="text-2xs uppercase tracking-wider text-muted/50">{SOURCE_LABELS[entry.source_type] ?? entry.source_type}</span>
								<a
									href={getSourceHref(entry)}
									class="text-accent hover:underline"
								>{entry.source_label}</a>
							</span>
						</p>
						{#if (entry.action === 'commented' || entry.action === 'messaged') && entry.new_value}
							<p class="mt-0.5 truncate text-sm text-muted">"{formatValue(entry.new_value)}"</p>
						{/if}
					</div>

					<!-- Timestamp -->
					<span class="shrink-0 text-xs text-muted/50" title={formatFullDate(entry.created_at)}>{formatTimeAgo(entry.created_at)}</span>
				</div>
			{/each}
		</div>

		<!-- Pagination -->
		{#if totalPages > 1}
			<div class="mx-3 mb-2 flex items-center justify-between">
				<span class="text-xs text-muted/50">
					{(currentPage - 1) * PER_PAGE + 1}–{Math.min(currentPage * PER_PAGE, totalCount)} of {totalCount}
				</span>
				<div class="flex items-center gap-1">
					<button
						class="{btnSecondary} disabled:opacity-30"
						disabled={currentPage <= 1}
						onclick={() => { currentPage--; loadLogs(); }}
					>
						<ChevronLeft size={14} />
					</button>
					<span class="px-2 text-xs text-muted">
						{currentPage} / {totalPages}
					</span>
					<button
						class="{btnSecondary} disabled:opacity-30"
						disabled={currentPage >= totalPages}
						onclick={() => { currentPage++; loadLogs(); }}
					>
						<ChevronRight size={14} />
					</button>
				</div>
			</div>
		{/if}
	{/if}
</div>
