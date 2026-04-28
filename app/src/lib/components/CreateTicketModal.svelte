<script lang="ts">
	import Modal from '$lib/components/Modal.svelte';
	import { ticketStore } from '$lib/stores/tickets.svelte';
	import { notifications } from '$lib/stores/notifications.svelte';
	import { auth } from '$lib/stores/auth.svelte';
	import { api } from '$lib/api';
	import { X, Paperclip } from '@lucide/svelte';
	import { priorityIcons, defaultPriorityIcon } from '$lib/config/priority-icons';
	import AttachmentUploadZone from './AttachmentUploadZone.svelte';
	import * as m from '$lib/paraglide/messages';
	import { tPriority, tCategory } from '$lib/i18n/ticket-labels';

	interface CustomerOption {
		id: string;
		full_name: string;
		email: string;
		avatar_url: string | null;
	}

	interface Props {
		organizationId: string | null;
		customers: CustomerOption[];
		onClose: () => void;
		onSuccess?: () => void;
	}

	let {
		organizationId,
		customers,
		onClose,
		onSuccess
	}: Props = $props();

	const TICKET_PRIORITIES = ['low', 'medium', 'high', 'urgent'] as const;
	const TICKET_CATEGORIES = ['billing', 'technical_issue', 'feature_request', 'general'] as const;
	const TICKET_CHANNELS = ['email', 'api', 'chat', 'web_form'] as const;

	const isSelfService = $derived(auth.isClient && !!auth.user);

	let subject = $state('');
	let description = $state('');
	let customerId = $state('');
	let priority = $state<string>('medium');
	const selectedTicketPriority = $derived(priorityIcons[priority] ?? defaultPriorityIcon);
	const SelectedTicketPriorityIcon = $derived(selectedTicketPriority.icon);
	let category = $state<string>('');
	let channel = $state<string>('web_form');
	let submitting = $state(false);
	let error = $state<string | null>(null);
	let pendingFiles = $state<File[]>([]);

	let openDropdown = $state<string | null>(null);

	const effectiveCustomerId = $derived(isSelfService ? auth.user!.id : customerId);

	const canSubmit = $derived(
		!!subject.trim() &&
			(organizationId === null || !!effectiveCustomerId) &&
			(organizationId === null || isSelfService || customers.length > 0)
	);

	function toggleDropdown(key: string) {
		openDropdown = openDropdown === key ? null : key;
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
		submitting = true;
		const n = notifications.action(m.client_creating_ticket());
		try {
			const ticket = await ticketStore.create({
				subject: subject.trim(),
				description: description.trim() || undefined,
				customer_id: effectiveCustomerId,
				organization_id: organizationId,
				priority: priority || undefined,
				channel: channel || 'web_form',
				category: category || undefined
			});
			// Upload pending files
			if (ticket && pendingFiles.length > 0 && auth.user) {
				for (const file of pendingFiles) {
					try {
						await api.attachments.upload(file, 'support_ticket', (ticket as Record<string, unknown>).id as string, organizationId, auth.user.id);
					} catch {
						/* silent */
					}
				}
			}
			n.success(m.client_ticket_created());
			onSuccess?.();
			onClose();
		} catch (err) {
			n.error(m.client_failed_create_ticket(), err instanceof Error ? err.message : m.client_failed_create_ticket());
		} finally {
			submitting = false;
		}
	}

	function displayName(val: string): string {
		return val.replace(/_/g, ' ');
	}

	import { labelClass, inputClass } from '$lib/styles/ui';
	const dropdownBtnClass =
		'flex w-full cursor-pointer items-center justify-between gap-2 rounded-sm bg-surface-hover/40 px-2.5 py-1.5 text-base text-sidebar-text transition-all duration-150 hover:bg-surface-hover/60';
	const dropdownPanelClass =
		'absolute left-0 z-20 mt-1.5 max-h-56 w-full min-w-[10rem] overflow-y-auto rounded-md border border-surface-border bg-surface py-1 shadow-lg shadow-black/15 ring-1 ring-white/[0.07] animate-dropdown-in';
	const dropdownPanelUpClass =
		'absolute bottom-full left-0 z-20 mb-1.5 max-h-56 w-full min-w-[10rem] overflow-y-auto rounded-md border border-surface-border bg-surface py-1 shadow-lg shadow-black/15 ring-1 ring-white/[0.07] animate-dropdown-in';
	const dropdownItemBase =
		'flex w-full items-center px-2.5 py-1.5 text-left text-sm transition-colors hover:bg-surface-hover/60';
</script>

<Modal open={true} onClose={onClose}>
	<div>
		<div class="px-3 py-2.5">
			<h2 class="text-md font-semibold text-sidebar-text">{m.client_create_support_ticket()}</h2>
		</div>
		<div class="p-3">
			{#if organizationId === null}
				<p class="mb-4 text-base text-sidebar-icon">
					{m.client_select_org_first()}
				</p>
				<button
					type="button"
					class="flex h-7 items-center rounded-sm bg-surface-hover/40 px-2.5 text-sm font-medium text-sidebar-text transition-all duration-150 hover:bg-surface-hover/60"
					onclick={onClose}
				>
					{m.client_close()}
				</button>
			{:else if !isSelfService && customers.length === 0}
				<p class="mb-4 text-base text-sidebar-icon">
					{m.client_no_customers_in_org()}
				</p>
				<button
					type="button"
					class="flex h-7 items-center rounded-sm bg-surface-hover/40 px-2.5 text-sm font-medium text-sidebar-text transition-all duration-150 hover:bg-surface-hover/60"
					onclick={onClose}
				>
					{m.client_close()}
				</button>
			{:else}
				<form onsubmit={handleSubmit} class="space-y-4">
					<div>
						<label for="create-ticket-subject" class={labelClass}>{m.client_subject()}</label>
						<input
							id="create-ticket-subject"
							type="text"
							required
							bind:value={subject}
							class={inputClass}
							placeholder={m.client_subject_placeholder()}
						/>
					</div>

					<div>
						<label for="create-ticket-description" class={labelClass}>{m.client_description()}</label>
						<textarea
							id="create-ticket-description"
							bind:value={description}
							rows="3"
							class="{inputClass} resize-none"
							placeholder={m.client_description_placeholder()}
						></textarea>
					</div>

					{#if !isSelfService}
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
					{/if}

					<!-- Priority / Category / Channel side by side (clients can't pick channel — locked to web_form) -->
					<div class="grid {isSelfService ? 'grid-cols-2' : 'grid-cols-3'} gap-3">
						<!-- Priority -->
						<div>
							<span class={labelClass}>{m.client_priority()}</span>
							<div class="relative" data-dropdown>
								<button
									type="button"
									class={dropdownBtnClass}
									onclick={() => toggleDropdown('priority')}
								>
									<span class="flex items-center gap-1.5 truncate">
										{#if priority}
											<SelectedTicketPriorityIcon size={16} class={selectedTicketPriority.className} />
										{/if}
										{priority ? tPriority(priority) : '—'}
									</span>
									<svg class="h-4 w-4 shrink-0 text-sidebar-icon transition-transform {openDropdown === 'priority' ? 'rotate-180' : ''}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
										<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
									</svg>
								</button>
								{#if openDropdown === 'priority'}
									<div class={dropdownPanelUpClass}>
										{#each TICKET_PRIORITIES as p (p)}
											{@const info = priorityIcons[p] ?? defaultPriorityIcon}
											{@const PriorityIcon = info.icon}
											<button
												type="button"
												class="{dropdownItemBase} {priority === p ? 'font-medium text-accent' : 'text-sidebar-text'}"
												onmousedown={(e) => { e.preventDefault(); priority = p; openDropdown = null; }}
											>
												<span class="mr-2"><PriorityIcon size={16} class={info.className} /></span>
												{tPriority(p)}
											</button>
										{/each}
									</div>
								{/if}
							</div>
						</div>

						<!-- Category -->
						<div>
							<span class={labelClass}>{m.client_category()}</span>
							<div class="relative" data-dropdown>
								<button
									type="button"
									class={dropdownBtnClass}
									onclick={() => toggleDropdown('category')}
								>
									<span class="truncate">{category ? tCategory(category) : '—'}</span>
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
											{m.client_category_none()}
										</button>
										{#each TICKET_CATEGORIES as c (c)}
											<button
												type="button"
												class="{dropdownItemBase} {category === c ? 'font-medium text-accent' : 'text-sidebar-text'}"
												onmousedown={(e) => { e.preventDefault(); category = c; openDropdown = null; }}
											>
												{tCategory(c)}
											</button>
										{/each}
									</div>
								{/if}
							</div>
						</div>

						<!-- Channel — staff only; clients always submit as web_form -->
						{#if !isSelfService}
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
											{#each TICKET_CHANNELS as ch (ch)}
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
						{/if}
					</div>

					<div>
						<span class={labelClass}>{m.client_attachments()}</span>
						<AttachmentUploadZone
							onFilesSelected={(files) => { pendingFiles = [...pendingFiles, ...files]; }}
							disabled={submitting}
						/>
						{#if pendingFiles.length > 0}
							<div class="mt-2 flex flex-wrap gap-1">
								{#each pendingFiles as file, i (file.name + i)}
									<span class="flex items-center gap-1 rounded border border-surface-border/40 bg-surface/50 px-2 py-0.5 text-xs text-sidebar-text">
										<Paperclip size={10} />
										<span class="max-w-[120px] truncate">{file.name}</span>
										<button type="button" class="text-muted hover:text-red-500" onclick={() => { pendingFiles = pendingFiles.filter((_, idx) => idx !== i); }}>
											<X size={10} />
										</button>
									</span>
								{/each}
							</div>
						{/if}
					</div>

					{#if error}
						<p class="text-base text-red-500">{error}</p>
					{/if}

					<div class="flex justify-end gap-2 pt-4">
						<button
							type="button"
							class="flex h-7 items-center rounded-sm bg-surface-hover/40 px-2.5 text-sm font-medium text-sidebar-text transition-all duration-150 hover:bg-surface-hover/60"
							onclick={onClose}
						>
							{m.client_cancel()}
						</button>
						<button
							type="submit"
							disabled={!canSubmit || submitting}
							class="flex h-7 items-center gap-1 rounded-sm bg-accent px-2.5 text-sm font-medium text-white transition-all duration-150 hover:bg-accent/90 disabled:opacity-30"
						>
							{submitting ? m.client_creating() : m.client_create_ticket()}
						</button>
					</div>
				</form>
			{/if}
		</div>
	</div>
</Modal>
