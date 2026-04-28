<script lang="ts">
	import type { Snippet } from 'svelte';
	import type { SavedView } from '$lib/api/views';
	import FilterDropdown from '$lib/components/FilterDropdown.svelte';
	import {
		ListFilter,
		LayoutList,
		Columns3,
		Search,
		X,
		Plus,
		Bookmark,
		Pencil,
		Trash2,
		Check,
		EllipsisVertical
	} from '@lucide/svelte';

	type ViewMode = 'list' | 'board';

	type Props = {
		// View toggle — omit to hide
		viewMode?: ViewMode;
		onViewChange?: (v: ViewMode) => void;

		// Group-by — omit to hide
		groupBy?: string;
		groupOptions?: readonly string[];
		groupOptionsForBoard?: readonly string[];
		onGroupChange?: (g: string) => void;

		// Filter — required (always shown)
		filtersVisible: boolean;
		activeFiltersCount: number;
		onFilterToggle: () => void;

		// Saved views — omit `savedViews` to hide the dropdown entirely
		savedViews?: SavedView[];
		activeViewId?: string | null;
		onApplyView?: (v: SavedView) => void;
		onSaveCurrentView?: () => void;
		onRenameView?: (id: string, name: string) => void;
		onDeleteView?: (id: string) => void;
		onUpdateViewFilters?: (id: string) => void;

		// Search — omit to hide
		searchQuery?: string;
		onSearchInput?: (e: Event) => void;
		onSearchClear?: () => void;

		// New button — required
		newLabel: string;
		onNew: () => void;
		newDisabled?: boolean;
		newDisabledTitle?: string;
		newButton?: Snippet;

		// Custom left content (e.g. /tickets org dropdown) — rendered before the view toggle
		leftSlot?: Snippet;

		// Optional title (e.g. "Tasks (12)") for embedded uses like /projects/[id]
		title?: Snippet;

		// Layout knobs
		bordered?: boolean;
	};

	let {
		viewMode,
		onViewChange,
		groupBy,
		groupOptions,
		groupOptionsForBoard,
		onGroupChange,
		filtersVisible,
		activeFiltersCount,
		onFilterToggle,
		savedViews,
		activeViewId = null,
		onApplyView,
		onSaveCurrentView,
		onRenameView,
		onDeleteView,
		onUpdateViewFilters,
		searchQuery,
		onSearchInput,
		onSearchClear,
		newLabel,
		onNew,
		newDisabled = false,
		newDisabledTitle,
		newButton,
		leftSlot,
		title,
		bordered = true
	}: Props = $props();

	let viewsDropdownOpen = $state(false);
	let viewSubMenuId = $state<string | null>(null);
	let editingViewId = $state<string | null>(null);
	let editingViewName = $state('');

	function formatLabel(s: string): string {
		return s.split('_').map((w) => w.charAt(0).toUpperCase() + w.slice(1)).join(' ');
	}

	const visibleGroupOptions = $derived(
		viewMode === 'board' && groupOptionsForBoard ? groupOptionsForBoard : groupOptions
	);

	const showViewToggle = $derived(viewMode !== undefined && onViewChange !== undefined);
	const showGroupBy = $derived(
		groupBy !== undefined &&
			onGroupChange !== undefined &&
			visibleGroupOptions !== undefined &&
			visibleGroupOptions.length > 0
	);
	const showSavedViews = $derived(savedViews !== undefined);
	const showSearch = $derived(searchQuery !== undefined && onSearchInput !== undefined);

	const activeView = $derived(
		showSavedViews && activeViewId ? savedViews!.find((v) => v.id === activeViewId) : null
	);

	function submitRename(e: SubmitEvent, id: string) {
		e.preventDefault();
		const name = editingViewName.trim();
		if (!name) return;
		onRenameView?.(id, name);
		editingViewId = null;
	}

	$effect(() => {
		if (!viewsDropdownOpen) return;
		function onMouseDown(e: MouseEvent) {
			const target = e.target as HTMLElement;
			if (!target.closest('[data-views-dropdown]')) {
				viewsDropdownOpen = false;
				viewSubMenuId = null;
				editingViewId = null;
			}
		}
		document.addEventListener('mousedown', onMouseDown);
		return () => document.removeEventListener('mousedown', onMouseDown);
	});
</script>

<div
	class="flex shrink-0 items-center justify-between px-3 py-1.5 {bordered
		? 'border-b border-surface-border'
		: ''}"
>
	<div class="flex items-center gap-1">
		{#if leftSlot}{@render leftSlot()}{/if}

		{#if title}
			<div class="flex items-center">{@render title()}</div>
		{/if}

		{#if showViewToggle}
			{#if leftSlot || title}
				<span class="mx-1 h-4 w-px bg-surface-border"></span>
			{/if}
			<div class="flex items-center gap-0.5">
				<button
					class="flex h-7 items-center gap-1 rounded-sm px-2 text-sm leading-none font-medium transition-all duration-150 {viewMode ===
					'list'
						? 'text-accent'
						: 'text-muted hover:text-sidebar-text'}"
					onclick={() => onViewChange?.('list')}
				>
					<LayoutList size={12} /> List
				</button>
				<button
					class="flex h-7 items-center gap-1 rounded-sm px-2 text-sm leading-none font-medium transition-all duration-150 {viewMode ===
					'board'
						? 'text-accent'
						: 'text-muted hover:text-sidebar-text'}"
					onclick={() => onViewChange?.('board')}
				>
					<Columns3 size={12} /> Board
				</button>
			</div>
		{/if}

		{#if showGroupBy}
			{#if showViewToggle || leftSlot || title}
				<span class="mx-1 h-4 w-px bg-surface-border"></span>
			{/if}
			<div class="flex items-center gap-0.5">
				{#each visibleGroupOptions! as g (g)}
					<button
						class="flex h-7 items-center rounded-sm px-2 text-sm font-medium transition-all duration-150 {groupBy ===
						g
							? 'text-accent'
							: 'text-muted hover:text-sidebar-text'}"
						onclick={() => onGroupChange?.(g)}
					>
						{formatLabel(g)}
					</button>
				{/each}
			</div>
		{/if}

		{#if showViewToggle || showGroupBy || leftSlot || title}
			<span class="mx-1 h-4 w-px bg-surface-border"></span>
		{/if}

		<!-- Filter toggle -->
		<div class="relative shrink-0">
			<button
				class="flex h-7 w-7 items-center justify-center rounded-sm transition-all duration-150 hover:bg-surface-hover/50 {filtersVisible
					? 'text-accent'
					: 'text-muted'}"
				onclick={onFilterToggle}
				title={filtersVisible ? 'Hide filters' : 'Show filters'}
			>
				<ListFilter size={14} />
			</button>
			{#if activeFiltersCount > 0}
				<span
					class="absolute -top-1 -right-1 flex h-3.5 min-w-3.5 items-center justify-center rounded-full bg-accent px-0.5 text-3xs leading-none font-semibold text-white"
				>
					{activeFiltersCount > 9 ? '9+' : activeFiltersCount}
				</span>
			{/if}
		</div>

		{#if showSavedViews}
			<div class="relative shrink-0" data-views-dropdown>
				<button
					class="flex h-7 items-center gap-1 rounded-sm px-2 text-sm font-medium leading-none transition-all duration-150 hover:bg-surface-hover/50 {viewsDropdownOpen ||
					activeViewId
						? 'text-accent'
						: 'text-muted'}"
					onclick={() => {
						viewsDropdownOpen = !viewsDropdownOpen;
						viewSubMenuId = null;
						editingViewId = null;
					}}
					title="Saved views"
				>
					<Bookmark size={14} class="shrink-0" />
					{#if activeView}
						<span class="max-w-24 truncate leading-none">{activeView.name}</span>
					{/if}
				</button>
				{#if viewsDropdownOpen}
					<div
						class="absolute left-0 top-full z-20 mt-1.5 w-52 origin-top-left animate-dropdown-in rounded-md border border-surface-border bg-surface py-1 shadow-lg shadow-black/15 ring-1 ring-white/[0.07]"
					>
						<button
							class="flex w-full items-center gap-2 border-b border-surface-border/40 px-2.5 py-1.5 text-left text-sm text-muted transition-colors hover:bg-surface-hover/60 hover:text-sidebar-text"
							onclick={() => {
								onSaveCurrentView?.();
								viewsDropdownOpen = false;
							}}
						>
							<Plus size={11} class="text-muted/40" />
							Save current view
						</button>

						{#if savedViews!.length === 0}
							<p class="px-3 py-3 text-center text-xs text-muted/40">No saved views yet.</p>
						{:else}
							{#each savedViews! as view (view.id)}
								<div class="group flex items-center justify-between transition-colors hover:bg-surface-hover/60">
									{#if editingViewId === view.id}
										<form
											class="flex min-w-0 flex-1 items-center gap-1 px-2.5 py-1"
											onsubmit={(e) => submitRename(e, view.id)}
										>
											<input
												type="text"
												bind:value={editingViewName}
												class="h-6 min-w-0 flex-1 rounded-sm border border-accent/40 bg-transparent px-2 text-sm text-sidebar-text outline-none focus:border-accent"
												onkeydown={(e) => {
													if (e.key === 'Escape') editingViewId = null;
												}}
											/>
											<button type="submit" class="shrink-0 text-accent hover:text-accent/80">
												<Check size={11} />
											</button>
											<button
												type="button"
												class="shrink-0 text-muted hover:text-sidebar-text"
												onclick={() => (editingViewId = null)}
											>
												<X size={11} />
											</button>
										</form>
									{:else}
										<button
											class="flex flex-1 items-center gap-2 px-2.5 py-1.5 text-left text-sm transition-colors {activeViewId ===
											view.id
												? 'text-accent font-medium'
												: 'text-muted hover:text-sidebar-text'}"
											onclick={() => {
												onApplyView?.(view);
												viewsDropdownOpen = false;
												viewSubMenuId = null;
											}}
										>
											{#if activeViewId === view.id}
												<Check size={11} class="shrink-0" />
											{/if}
											<span class="truncate">{view.name}</span>
										</button>
										<div class="relative">
											<button
												class="shrink-0 px-1.5 py-1.5 text-muted/30 opacity-0 transition-opacity hover:text-sidebar-text group-hover:opacity-100 {viewSubMenuId ===
												view.id
													? '!opacity-100'
													: ''}"
												onclick={(e) => {
													e.stopPropagation();
													viewSubMenuId = viewSubMenuId === view.id ? null : view.id;
												}}
											>
												<EllipsisVertical size={12} />
											</button>
											{#if viewSubMenuId === view.id}
												<div
													class="absolute right-0 top-full z-30 mt-1 w-36 origin-top-right animate-dropdown-in rounded-md border border-surface-border bg-surface py-1 shadow-lg shadow-black/15 ring-1 ring-white/[0.07]"
												>
													<button
														class="flex w-full items-center gap-2 px-2.5 py-1.5 text-left text-sm text-muted transition-colors hover:bg-surface-hover/60 hover:text-sidebar-text"
														onclick={() => {
															editingViewId = view.id;
															editingViewName = view.name;
															viewSubMenuId = null;
														}}
													>
														<Pencil size={11} /> Rename
													</button>
													<button
														class="flex w-full items-center gap-2 px-2.5 py-1.5 text-left text-sm text-muted transition-colors hover:bg-surface-hover/60 hover:text-sidebar-text"
														onclick={() => {
															onUpdateViewFilters?.(view.id);
															viewSubMenuId = null;
														}}
													>
														<Bookmark size={11} /> Update filters
													</button>
													<button
														class="flex w-full items-center gap-2 px-2.5 py-1.5 text-left text-sm text-red-400 transition-colors hover:bg-surface-hover/60"
														onclick={() => {
															onDeleteView?.(view.id);
															viewSubMenuId = null;
														}}
													>
														<Trash2 size={11} /> Delete
													</button>
												</div>
											{/if}
										</div>
									{/if}
								</div>
							{/each}
						{/if}
					</div>
				{/if}
			</div>
		{/if}
	</div>

	<div class="flex items-center gap-1.5">
		{#if showSearch}
			<div class="relative flex items-center">
				<Search size={12} class="absolute left-2 text-muted pointer-events-none" />
				<input
					type="text"
					placeholder="Search..."
					value={searchQuery}
					oninput={onSearchInput}
					class="h-7 w-40 rounded-sm border border-transparent bg-surface-hover/50 pl-7 pr-6 text-sm text-sidebar-text transition-all duration-150 placeholder:text-muted/50 focus:w-56 focus:border-surface-border focus:bg-surface focus:outline-none"
				/>
				{#if searchQuery}
					<button
						class="absolute right-2 text-sidebar-icon hover:text-sidebar-text"
						onclick={onSearchClear}
					>
						<X size={12} />
					</button>
				{/if}
			</div>
		{/if}

		{#if newButton}
			{@render newButton()}
		{:else}
			<button
				class="flex h-7 items-center justify-center gap-1 rounded-sm bg-accent px-2.5 text-sm leading-none font-medium text-white transition-all duration-150 hover:bg-accent/90 disabled:cursor-not-allowed disabled:opacity-40"
				onclick={onNew}
				disabled={newDisabled}
				title={newDisabled ? newDisabledTitle : undefined}
			>
				<Plus size={14} class="shrink-0" />
				{newLabel}
			</button>
		{/if}
	</div>
</div>
