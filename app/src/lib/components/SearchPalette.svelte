<script lang="ts">
	import { goto } from '$app/navigation';
	import { localizeHref } from '$lib/paraglide/runtime';
	import { Ticket, SquareCheck, MessageCircle, MessageSquare, Search, Loader2 } from '@lucide/svelte';

	type SourceType = 'ticket' | 'task' | 'ticket_message' | 'task_comment';

	type SearchResult = {
		source_type: SourceType;
		source_id: string;
		parent_id: string | null;
		title: string;
		preview: string | null;
		metadata: Record<string, unknown>;
		similarity: number;
	};

	type FilterTab = { label: string; value: SourceType | null };

	const tabs: FilterTab[] = [
		{ label: 'All', value: null },
		{ label: 'Tickets', value: 'ticket' },
		{ label: 'Tasks', value: 'task' },
		{ label: 'Messages', value: 'ticket_message' },
		{ label: 'Comments', value: 'task_comment' }
	];

	let open = $state(false);
	let query = $state('');
	let results = $state<SearchResult[]>([]);
	let loading = $state(false);
	let selectedIndex = $state(0);
	let activeTab = $state<SourceType | null>(null);
	let inputRef = $state<HTMLInputElement | null>(null);
	let debounceTimer: ReturnType<typeof setTimeout> | undefined;

	const filteredResults = $derived(
		activeTab ? results.filter((r) => r.source_type === activeTab) : results
	);

	const groupedResults = $derived(() => {
		const groups: Record<string, SearchResult[]> = {};
		for (const r of filteredResults) {
			(groups[r.source_type] ??= []).push(r);
		}
		return groups;
	});

	const flatResults = $derived(
		(() => {
			const g = groupedResults();
			const order: SourceType[] = ['ticket', 'task', 'ticket_message', 'task_comment'];
			const flat: SearchResult[] = [];
			for (const type of order) {
				if (g[type]) flat.push(...g[type]);
			}
			return flat;
		})()
	);

	function toggle() {
		open = !open;
		if (open) {
			query = '';
			results = [];
			selectedIndex = 0;
			activeTab = null;
			requestAnimationFrame(() => inputRef?.focus());
		}
	}

	function close() {
		open = false;
	}

	$effect(() => {
		function onKeydown(e: KeyboardEvent) {
			if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
				e.preventDefault();
				toggle();
			}
		}
		document.addEventListener('keydown', onKeydown);
		return () => document.removeEventListener('keydown', onKeydown);
	});

	function onPaletteKeydown(e: KeyboardEvent) {
		if (e.key === 'Escape') {
			e.preventDefault();
			e.stopPropagation();
			close();
			return;
		}
		if (e.key === 'ArrowDown') {
			e.preventDefault();
			selectedIndex = Math.min(selectedIndex + 1, flatResults.length - 1);
			scrollToSelected();
			return;
		}
		if (e.key === 'ArrowUp') {
			e.preventDefault();
			selectedIndex = Math.max(selectedIndex - 1, 0);
			scrollToSelected();
			return;
		}
		if (e.key === 'Enter' && flatResults.length > 0) {
			e.preventDefault();
			navigateTo(flatResults[selectedIndex]);
			return;
		}
	}

	function scrollToSelected() {
		const el = document.querySelector(`[data-search-index="${selectedIndex}"]`);
		el?.scrollIntoView({ block: 'nearest' });
	}

	async function doSearch() {
		const q = query.trim();
		if (!q) {
			results = [];
			return;
		}
		loading = true;
		try {
			const res = await fetch('/api/search', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ query: q, limit: 30 })
			});
			if (res.ok) {
				const data = await res.json();
				results = data.results ?? [];
				selectedIndex = 0;
			}
		} catch {
			// silently fail
		} finally {
			loading = false;
		}
	}

	function onInput() {
		clearTimeout(debounceTimer);
		debounceTimer = setTimeout(doSearch, 300);
	}

	function navigateTo(result: SearchResult) {
		close();
		const meta = result.metadata ?? {};
		switch (result.source_type) {
		case 'ticket':
			goto(localizeHref(`/tickets?id=${result.source_id}`));
			break;
		case 'task':
			goto(localizeHref(`/projects/${result.parent_id}?task=${result.source_id}`));
			break;
		case 'ticket_message':
			goto(localizeHref(`/tickets?id=${result.parent_id}`));
			break;
		case 'task_comment': {
			const projectId = meta.project_id as string;
			goto(localizeHref(`/projects/${projectId}?task=${result.parent_id}`));
			break;
		}
		}
	}

	function groupLabel(type: string): string {
		switch (type) {
			case 'ticket': return 'Tickets';
			case 'task': return 'Tasks';
			case 'ticket_message': return 'Messages';
			case 'task_comment': return 'Comments';
			default: return type;
		}
	}

	function groupIcon(type: string) {
		switch (type) {
			case 'ticket': return Ticket;
			case 'task': return SquareCheck;
			case 'ticket_message': return MessageCircle;
			case 'task_comment': return MessageSquare;
			default: return Search;
		}
	}

	function statusColor(status: string | undefined): string {
		switch (status) {
			case 'open': return 'bg-blue-500/15 text-blue-400';
			case 'in_progress': return 'bg-yellow-500/15 text-yellow-400';
			case 'resolved': case 'done': return 'bg-green-500/15 text-green-400';
			case 'closed': return 'bg-neutral-500/15 text-neutral-400';
			case 'todo': case 'backlog': return 'bg-neutral-500/15 text-neutral-400';
			default: return 'bg-neutral-500/15 text-neutral-400';
		}
	}

	function getFlatIndex(result: SearchResult): number {
		return flatResults.findIndex(
			(r) => r.source_type === result.source_type && r.source_id === result.source_id
		);
	}
</script>

{#if open}
	<div
		role="dialog"
		aria-modal="true"
		tabindex="-1"
		class="fixed inset-0 z-9999 flex items-start justify-center pt-[15vh]"
		onkeydown={onPaletteKeydown}
	>
		<!-- backdrop -->
		<button
			class="absolute inset-0 bg-black/50"
			onclick={close}
			aria-label="Close search"
			tabindex="-1"
		></button>

		<!-- palette -->
		<div class="relative flex w-full max-w-xl flex-col border border-surface-border bg-surface shadow-2xl">
			<!-- search input -->
			<div class="flex items-center gap-3 border-b border-surface-border px-4 py-3">
				{#if loading}
					<Loader2 size={16} class="shrink-0 animate-spin text-sidebar-icon" />
				{:else}
					<Search size={16} class="shrink-0 text-sidebar-icon" />
				{/if}
				<input
					bind:this={inputRef}
					bind:value={query}
					oninput={onInput}
					type="text"
					placeholder="Search tickets, tasks, messages..."
					class="w-full bg-transparent text-sm text-sidebar-text placeholder-sidebar-icon/50 outline-none"
				/>
				<kbd class="shrink-0 rounded border border-surface-border px-1.5 py-0.5 text-[10px] text-sidebar-icon">ESC</kbd>
			</div>

			<!-- filter tabs -->
			<div class="flex gap-1 border-b border-surface-border px-4 py-2">
				{#each tabs as tab (tab.value)}
					<button
						class="rounded-sm px-2.5 py-1 text-[11px] font-medium transition-colors {activeTab === tab.value ? 'bg-accent text-white' : 'text-sidebar-text/60 hover:bg-surface-hover hover:text-sidebar-text'}"
						onclick={() => { activeTab = tab.value; selectedIndex = 0; }}
					>
						{tab.label}
					</button>
				{/each}
			</div>

			<!-- results -->
			<div class="max-h-[50vh] overflow-y-auto">
				{#if query.trim() && !loading && flatResults.length === 0}
					<div class="px-4 py-8 text-center text-xs text-sidebar-icon/60">
						No results found
					</div>
				{:else if !query.trim() && !loading}
					<div class="px-4 py-8 text-center text-xs text-sidebar-icon/60">
						Type to search across all content...
					</div>
				{:else}
					{@const groups = groupedResults()}
					{#each ['ticket', 'task', 'ticket_message', 'task_comment'] as type (type)}
						{#if groups[type]?.length}
							<div class="px-4 pt-3 pb-1">
								<span class="text-[10px] font-semibold uppercase tracking-wider text-sidebar-icon/50">
									{groupLabel(type)}
								</span>
							</div>
							{#each groups[type] as result (result.source_id)}
								{@const idx = getFlatIndex(result)}
								{@const Icon = groupIcon(result.source_type)}
								{@const status = String(result.metadata?.status ?? '')}
								<button
									data-search-index={idx}
									class="flex w-full items-start gap-3 px-4 py-2.5 text-left transition-colors {idx === selectedIndex ? 'bg-accent/10' : 'hover:bg-surface-hover'}"
									onclick={() => navigateTo(result)}
									onmouseenter={() => { selectedIndex = idx; }}
								>
									<div class="mt-0.5 shrink-0">
										<Icon size={14} class="text-sidebar-icon" />
									</div>
									<div class="min-w-0 flex-1">
										<div class="flex items-center gap-2">
											<span class="truncate text-xs font-medium text-sidebar-text">{result.title}</span>
											{#if status && status !== 'undefined'}
												<span class="shrink-0 rounded px-1.5 py-0.5 text-[10px] font-medium {statusColor(status)}">
													{status.replace('_', ' ')}
												</span>
											{/if}
											<span class="ml-auto shrink-0 text-[10px] text-sidebar-icon/40">
												{Math.round(result.similarity * 100)}%
											</span>
										</div>
										{#if result.preview}
											<p class="mt-0.5 truncate text-[11px] leading-relaxed text-sidebar-text/50">
												{result.preview}
											</p>
										{/if}
									</div>
								</button>
							{/each}
						{/if}
					{/each}
				{/if}
			</div>

			<!-- footer -->
			{#if flatResults.length > 0}
				<div class="flex items-center gap-4 border-t border-surface-border px-4 py-2 text-[10px] text-sidebar-icon/40">
					<span><kbd class="rounded border border-surface-border px-1 py-0.5">↑</kbd><kbd class="ml-0.5 rounded border border-surface-border px-1 py-0.5">↓</kbd> navigate</span>
					<span><kbd class="rounded border border-surface-border px-1 py-0.5">↵</kbd> open</span>
					<span><kbd class="rounded border border-surface-border px-1 py-0.5">esc</kbd> close</span>
				</div>
			{/if}
		</div>
	</div>
{/if}
