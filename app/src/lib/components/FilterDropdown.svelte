<script lang="ts">
	import { Check } from '@lucide/svelte';
	import { clickOutside } from '$lib/actions/clickOutside';

	type Option = { value: string; label: string; color?: string; subtitle?: string };

	interface Props {
		label: string;
		options: Option[];
		operator: 'is' | 'is_not';
		selected: string[];
		searchable?: boolean;
		onchange: (operator: 'is' | 'is_not', selected: string[]) => void;
	}

	let { label, options, operator, selected, searchable = false, onchange }: Props = $props();

	let open = $state(false);
	let search = $state('');

	const filteredOptions = $derived(
		searchable && search
			? options.filter((o) => {
					const q = search.toLowerCase();
					return o.label.toLowerCase().includes(q) || (o.subtitle?.toLowerCase().includes(q) ?? false);
				})
			: options
	);

	function toggle(value: string) {
		const next = selected.includes(value)
			? selected.filter((v) => v !== value)
			: [...selected, value];
		onchange(operator, next);
	}

	function setOperator(op: 'is' | 'is_not') {
		onchange(op, selected);
	}

	function clear() {
		onchange('is', []);
	}

	const summary = $derived.by(() => {
		if (selected.length === 0) return 'All';
		const labels = selected.map((v) => options.find((o) => o.value === v)?.label ?? v);
		const opLabel = operator === 'is_not' ? 'not ' : '';
		const first = labels[0];
		if (labels.length === 1) return opLabel + first;
		return opLabel + first + ` +${labels.length - 1}`;
	});

	const hasSelection = $derived(selected.length > 0);
</script>

<div class="relative" data-filter-dropdown
	use:clickOutside={{ onClickOutside: () => { open = false; search = ''; }, enabled: open }}
>
	<button
		class="flex h-7 items-center gap-1.5 rounded-sm px-2 text-sm transition-all duration-150 {hasSelection ? 'text-accent' : 'text-muted hover:text-sidebar-text'}"
		onclick={() => (open = !open)}
	>
		<span class="text-muted/50">{label}</span>
		<span class="truncate {hasSelection ? 'font-medium' : ''}">{summary}</span>
		<svg
			class="h-3 w-3 shrink-0 text-muted/40 transition-transform duration-150 {open ? 'rotate-180' : ''}"
			fill="none"
			stroke="currentColor"
			viewBox="0 0 24 24"
		>
			<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
		</svg>
	</button>

	{#if open}
		<div
			class="absolute left-0 z-20 mt-1.5 min-w-[12rem] origin-top-left animate-dropdown-in rounded-md border border-surface-border bg-surface shadow-lg shadow-black/15 ring-1 ring-white/[0.07]"
		>
			<!-- Operator toggle -->
			<div class="flex items-center gap-0.5 border-b border-surface-border/40 px-1.5 py-1.5">
				<button
					class="rounded px-2 py-0.5 text-xs font-medium transition-colors {operator === 'is' ? 'bg-surface-hover text-sidebar-text' : 'text-muted hover:text-sidebar-text'}"
					onmousedown={(e) => { e.preventDefault(); setOperator('is'); }}
				>
					is
				</button>
				<button
					class="rounded px-2 py-0.5 text-xs font-medium transition-colors {operator === 'is_not' ? 'bg-surface-hover text-sidebar-text' : 'text-muted hover:text-sidebar-text'}"
					onmousedown={(e) => { e.preventDefault(); setOperator('is_not'); }}
				>
					is not
				</button>
				{#if hasSelection}
					<button
						class="ml-auto text-xs text-muted/40 transition-colors hover:text-accent"
						onmousedown={(e) => { e.preventDefault(); clear(); }}
					>
						Clear
					</button>
				{/if}
			</div>

			<!-- Search -->
			{#if searchable}
				<div class="border-b border-surface-border/40 px-2.5 py-1.5">
					<input
						type="text"
						placeholder="Search..."
						bind:value={search}
						class="w-full bg-transparent text-sm text-sidebar-text placeholder:text-muted/30 focus:outline-none"
					/>
				</div>
			{/if}

			<!-- Options list -->
			<div class="max-h-48 overflow-y-auto py-1">
				{#each filteredOptions as opt (opt.value)}
					{@const isSelected = selected.includes(opt.value)}
					<button
						class="flex w-full items-center gap-2 px-2.5 py-1.5 text-left text-sm transition-colors hover:bg-surface-hover/60 {isSelected ? 'text-sidebar-text' : 'text-muted'}"
						onmousedown={(e) => { e.preventDefault(); toggle(opt.value); }}
					>
						<span
							class="flex h-3 w-3 shrink-0 items-center justify-center rounded-sm border transition-colors {isSelected ? 'border-accent bg-accent' : 'border-surface-border/60'}"
						>
							{#if isSelected}
								<Check size={8} class="text-white" />
							{/if}
						</span>
						{#if opt.color}
							<span class="h-1.5 w-1.5 shrink-0 rounded-full" style="background-color: {opt.color}"></span>
						{/if}
						<span class="min-w-0 flex-1">
							<span class="block truncate">{opt.label}</span>
							{#if opt.subtitle}
								<span class="block truncate text-2xs text-muted/40">{opt.subtitle}</span>
							{/if}
						</span>
					</button>
				{/each}
			</div>
		</div>
	{/if}
</div>

<style>
	@keyframes dropdown-in {
		from {
			opacity: 0;
			transform: scale(0.95) translateY(-4px);
		}
		to {
			opacity: 1;
			transform: scale(1) translateY(0);
		}
	}

	:global(.animate-dropdown-in) {
		animation: dropdown-in 150ms ease-out;
	}
</style>
