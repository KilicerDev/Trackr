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
		const opLabel = operator === 'is_not' ? 'is not ' : '';
		const first = labels[0];
		if (labels.length === 1) return opLabel + first;
		return opLabel + first + ` +${labels.length - 1}`;
	});

	const hasSelection = $derived(selected.length > 0);
</script>

<div class="flex flex-col gap-1.5">
	<span class="text-[11px] font-medium uppercase tracking-wider text-sidebar-icon">{label}</span>
	<div class="relative" data-filter-dropdown
		use:clickOutside={{ onClickOutside: () => { open = false; search = ''; }, enabled: open }}
	>
		<button
			class="flex min-w-[6.5rem] cursor-pointer items-center justify-between gap-2 border border-surface-border bg-surface px-3 py-2 text-xs text-sidebar-text shadow-sm transition-colors hover:border-sidebar-icon/30 hover:bg-surface-hover {hasSelection ? 'border-accent/40' : ''}"
			onclick={() => (open = !open)}
		>
			<span class="truncate {hasSelection ? 'text-sidebar-text' : 'text-muted'}">{summary}</span>
			<svg
				class="h-4 w-4 shrink-0 text-sidebar-icon transition-transform {open ? 'rotate-180' : ''}"
				fill="none"
				stroke="currentColor"
				viewBox="0 0 24 24"
			>
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
			</svg>
		</button>

		{#if open}
			<div class="absolute left-0 z-20 mt-1.5 min-w-[13rem] border border-surface-border bg-surface shadow-xl">
				<!-- Operator toggle -->
				<div class="flex items-center gap-1 border-b border-surface-border px-2 py-2">
					<button
						class="px-2.5 py-1 text-[10px] font-medium transition-colors {operator === 'is' ? 'bg-accent text-white' : 'bg-surface-hover text-sidebar-text hover:text-sidebar-text'}"
						onmousedown={(e) => { e.preventDefault(); setOperator('is'); }}
					>
						is
					</button>
					<button
						class="px-2.5 py-1 text-[10px] font-medium transition-colors {operator === 'is_not' ? 'bg-accent text-white' : 'bg-surface-hover text-sidebar-text hover:text-sidebar-text'}"
						onmousedown={(e) => { e.preventDefault(); setOperator('is_not'); }}
					>
						is not
					</button>
					{#if hasSelection}
						<button
							class="ml-auto text-[10px] text-sidebar-icon transition-colors hover:text-accent"
							onmousedown={(e) => { e.preventDefault(); clear(); }}
						>
							Clear
						</button>
					{/if}
				</div>

				<!-- Search -->
				{#if searchable}
					<div class="border-b border-surface-border px-2 py-1.5">
						<input
							type="text"
							placeholder="Search..."
							bind:value={search}
							class="w-full bg-transparent px-1 py-1 text-xs text-sidebar-text placeholder:text-muted focus:outline-none"
						/>
					</div>
				{/if}

				<!-- Options list -->
				<div class="max-h-48 overflow-y-auto py-1">
					{#each filteredOptions as opt (opt.value)}
						{@const isSelected = selected.includes(opt.value)}
						<button
							class="flex w-full items-center gap-2.5 px-3 py-2 text-left text-xs transition-colors hover:bg-surface-hover {isSelected ? 'text-sidebar-text' : 'text-muted'}"
							onmousedown={(e) => { e.preventDefault(); toggle(opt.value); }}
						>
							<span
								class="flex h-3.5 w-3.5 shrink-0 items-center justify-center border transition-colors {isSelected ? 'border-accent bg-accent' : 'border-surface-border bg-surface'}"
							>
								{#if isSelected}
									<Check size={10} class="text-white" />
								{/if}
							</span>
							{#if opt.color}
								<span class="h-2 w-2 shrink-0 rounded-full" style="background-color: {opt.color}"></span>
							{/if}
							<span class="min-w-0 flex-1">
							<span class="block truncate">{opt.label}</span>
							{#if opt.subtitle}
								<span class="block truncate text-[10px] text-accent/50">{opt.subtitle}</span>
							{/if}
						</span>
						</button>
					{/each}
				</div>
			</div>
		{/if}
	</div>
</div>
