<script lang="ts">
	import Modal from '$lib/components/Modal.svelte';
	import { ticketStore } from '$lib/stores/tickets.svelte';

	interface CustomerOption {
		id: string;
		full_name: string;
		email: string;
		avatar_url: string | null;
	}

	interface Props {
		organizationId: string | null;
		organizationName: string;
		customers: CustomerOption[];
		onClose: () => void;
		onSuccess?: () => void;
	}

	let {
		organizationId,
		organizationName,
		customers,
		onClose,
		onSuccess
	}: Props = $props();

	const TICKET_PRIORITIES = ['low', 'medium', 'high', 'urgent'] as const;
	const TICKET_CATEGORIES = ['billing', 'technical_issue', 'feature_request', 'general'] as const;
	const TICKET_CHANNELS = ['email', 'api', 'chat', 'web_form'] as const;

	let subject = $state('');
	let description = $state('');
	let customerId = $state('');
	let priority = $state<string>('medium');
	let category = $state<string>('');
	let channel = $state<string>('web_form');
	let submitting = $state(false);
	let error = $state<string | null>(null);

	let openDropdown = $state<string | null>(null);

	const canSubmit = $derived(
		!!subject.trim() &&
			(organizationId === null || !!customerId) &&
			(organizationId === null || customers.length > 0)
	);

	function toggleDropdown(key: string) {
		openDropdown = openDropdown === key ? null : key;
	}

	function closeDropdowns() {
		openDropdown = null;
	}

	$effect(() => {
		if (openDropdown === null) return;
		function onMouseDown(e: MouseEvent) {
			const target = e.target as HTMLElement;
			if (!target.closest('[data-dropdown]')) {
				openDropdown = null;
			}
		}
		document.addEventListener('mousedown', onMouseDown);
		return () => document.removeEventListener('mousedown', onMouseDown);
	});

	async function handleSubmit(e: Event) {
		e.preventDefault();
		if (!canSubmit || !organizationId || submitting) return;
		error = null;
		submitting = true;
		try {
			await ticketStore.create({
				subject: subject.trim(),
				description: description.trim() || undefined,
				customer_id: customerId,
				organization_id: organizationId,
				priority: priority || undefined,
				channel: channel || 'web_form',
				category: category || undefined
			});
			onSuccess?.();
			onClose();
		} catch (err) {
			error = err instanceof Error ? err.message : 'Failed to create ticket';
		} finally {
			submitting = false;
		}
	}

	function displayName(val: string): string {
		return val.replace(/_/g, ' ');
	}

	const labelClass = 'mb-1.5 block text-[11px] font-medium uppercase tracking-wider text-sidebar-icon';
	const inputClass =
		'w-full border border-surface-border bg-surface px-3 py-2 text-xs text-sidebar-text shadow-sm outline-none transition-colors placeholder:text-sidebar-icon/70 focus:border-sidebar-icon/30 hover:border-sidebar-icon/30';
	const dropdownBtnClass =
		'flex w-full cursor-pointer items-center justify-between gap-2 border border-surface-border bg-surface px-3 py-2 text-xs text-sidebar-text shadow-sm transition-colors hover:border-sidebar-icon/30 hover:bg-surface-hover';
	const dropdownPanelClass =
		'absolute left-0 z-20 mt-1.5 max-h-56 w-full min-w-[10rem] overflow-y-auto border border-surface-border bg-surface py-1 shadow-xl';
	const dropdownPanelUpClass =
		'absolute bottom-full left-0 z-20 mb-1.5 max-h-56 w-full min-w-[10rem] overflow-y-auto border border-surface-border bg-surface py-1 shadow-xl';
	const dropdownItemBase =
		'flex w-full items-center px-4 py-2.5 text-left text-xs transition-colors hover:bg-surface-hover';
</script>

<Modal open={true} onClose={onClose}>
	<div>
		<div class="border-b border-surface-border px-4 py-3">
			<h2 class="text-sm font-semibold text-sidebar-text">Create support ticket</h2>
		</div>
		<div class="p-4">
			{#if organizationId === null}
				<p class="mb-4 text-xs text-sidebar-icon">
					Select an organization first to create a ticket.
				</p>
				<button
					type="button"
					class="border border-surface-border bg-surface px-4 py-2 text-xs font-medium text-sidebar-text transition-colors hover:border-sidebar-icon/30 hover:bg-surface-hover"
					onclick={onClose}
				>
					Close
				</button>
			{:else if customers.length === 0}
				<p class="mb-4 text-xs text-sidebar-icon">
					No customers in this organization. Add customers before creating tickets.
				</p>
				<button
					type="button"
					class="border border-surface-border bg-surface px-4 py-2 text-xs font-medium text-sidebar-text transition-colors hover:border-sidebar-icon/30 hover:bg-surface-hover"
					onclick={onClose}
				>
					Close
				</button>
			{:else}
				<form onsubmit={handleSubmit} class="space-y-4">
					<div>
						<label for="create-ticket-subject" class={labelClass}>Subject</label>
						<input
							id="create-ticket-subject"
							type="text"
							required
							bind:value={subject}
							class={inputClass}
							placeholder="Brief description of the issue"
						/>
					</div>

					<div>
						<label for="create-ticket-description" class={labelClass}>Description</label>
						<textarea
							id="create-ticket-description"
							bind:value={description}
							rows="3"
							class="{inputClass} resize-none"
							placeholder="Optional details"
						></textarea>
					</div>

					<!-- Customer dropdown -->
					<div>
						<span class={labelClass}>Customer</span>
						<div class="relative" data-dropdown>
							<button
								type="button"
								class={dropdownBtnClass}
								onclick={() => toggleDropdown('customer')}
							>
								<span class="truncate">
									{#if customerId}
										{@const selected = customers.find(c => c.id === customerId)}
										{selected?.full_name ?? '—'}
									{:else}
										Select customer
									{/if}
								</span>
								<svg class="h-4 w-4 shrink-0 text-sidebar-icon transition-transform {openDropdown === 'customer' ? 'rotate-180' : ''}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
									<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
								</svg>
							</button>
							{#if openDropdown === 'customer'}
								<div class={dropdownPanelClass}>
									{#each customers as c (c.id)}
										<button
											type="button"
											class="{dropdownItemBase} {customerId === c.id ? 'font-medium text-accent' : 'text-sidebar-text'}"
											onmousedown={(e) => { e.preventDefault(); customerId = c.id; openDropdown = null; }}
										>
											{c.full_name}{#if c.email} <span class="ml-1 text-sidebar-icon">({c.email})</span>{/if}
										</button>
									{/each}
								</div>
							{/if}
						</div>
					</div>

					<!-- Priority / Category / Channel side by side -->
					<div class="grid grid-cols-3 gap-3">
						<!-- Priority -->
						<div>
							<span class={labelClass}>Priority</span>
							<div class="relative" data-dropdown>
								<button
									type="button"
									class={dropdownBtnClass}
									onclick={() => toggleDropdown('priority')}
								>
									<span class="truncate">{priority || '—'}</span>
									<svg class="h-4 w-4 shrink-0 text-sidebar-icon transition-transform {openDropdown === 'priority' ? 'rotate-180' : ''}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
										<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
									</svg>
								</button>
								{#if openDropdown === 'priority'}
									<div class={dropdownPanelUpClass}>
										{#each TICKET_PRIORITIES as p}
											<button
												type="button"
												class="{dropdownItemBase} {priority === p ? 'font-medium text-accent' : 'text-sidebar-text'}"
												onmousedown={(e) => { e.preventDefault(); priority = p; openDropdown = null; }}
											>
												{p}
											</button>
										{/each}
									</div>
								{/if}
							</div>
						</div>

						<!-- Category -->
						<div>
							<span class={labelClass}>Category</span>
							<div class="relative" data-dropdown>
								<button
									type="button"
									class={dropdownBtnClass}
									onclick={() => toggleDropdown('category')}
								>
									<span class="truncate">{category ? displayName(category) : '—'}</span>
									<svg class="h-4 w-4 shrink-0 text-sidebar-icon transition-transform {openDropdown === 'category' ? 'rotate-180' : ''}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
										<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
									</svg>
								</button>
								{#if openDropdown === 'category'}
									<div class={dropdownPanelUpClass}>
										<button
											type="button"
											class="{dropdownItemBase} {!category ? 'font-medium text-accent' : 'text-sidebar-text'}"
											onmousedown={(e) => { e.preventDefault(); category = ''; openDropdown = null; }}
										>
											None
										</button>
										{#each TICKET_CATEGORIES as c}
											<button
												type="button"
												class="{dropdownItemBase} {category === c ? 'font-medium text-accent' : 'text-sidebar-text'}"
												onmousedown={(e) => { e.preventDefault(); category = c; openDropdown = null; }}
											>
												{displayName(c)}
											</button>
										{/each}
									</div>
								{/if}
							</div>
						</div>

						<!-- Channel -->
						<div>
							<span class={labelClass}>Channel</span>
							<div class="relative" data-dropdown>
								<button
									type="button"
									class={dropdownBtnClass}
									onclick={() => toggleDropdown('channel')}
								>
									<span class="truncate">{channel ? displayName(channel) : '—'}</span>
									<svg class="h-4 w-4 shrink-0 text-sidebar-icon transition-transform {openDropdown === 'channel' ? 'rotate-180' : ''}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
										<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
									</svg>
								</button>
								{#if openDropdown === 'channel'}
									<div class={dropdownPanelUpClass}>
										{#each TICKET_CHANNELS as ch}
											<button
												type="button"
												class="{dropdownItemBase} {channel === ch ? 'font-medium text-accent' : 'text-sidebar-text'}"
												onmousedown={(e) => { e.preventDefault(); channel = ch; openDropdown = null; }}
											>
												{displayName(ch)}
											</button>
										{/each}
									</div>
								{/if}
							</div>
						</div>
					</div>

					{#if error}
						<p class="text-xs text-red-500">{error}</p>
					{/if}

					<div class="flex justify-end gap-2 border-t border-surface-border pt-4">
						<button
							type="button"
							class="border border-surface-border bg-surface px-4 py-2 text-xs font-medium text-sidebar-text transition-colors hover:border-sidebar-icon/30 hover:bg-surface-hover"
							onclick={onClose}
						>
							Cancel
						</button>
						<button
							type="submit"
							disabled={!canSubmit || submitting}
							class="bg-accent px-4 py-2 text-xs font-medium text-white shadow-sm transition-colors hover:bg-accent/90 disabled:opacity-50"
						>
							{submitting ? 'Creating…' : 'Create ticket'}
						</button>
					</div>
				</form>
			{/if}
		</div>
	</div>
</Modal>
