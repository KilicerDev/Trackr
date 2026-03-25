<script lang="ts">
	import { page } from '$app/state';
	import { goto } from '$app/navigation';
	import { api } from '$lib/api';
	import { auth } from '$lib/stores/auth.svelte';
	import { clientPortal } from '$lib/stores/clientPortal.svelte';
	import { notifications } from '$lib/stores/notifications.svelte';
	import { Send, ArrowLeft, Circle, LoaderCircle } from '@lucide/svelte';
	import type { LayoutData } from './$types';
	import { SvelteURLSearchParams } from 'svelte/reactivity';
	import { localizeHref } from '$lib/paraglide/runtime';

	let { data }: { data: LayoutData } = $props();

	const PRIORITIES = ['low', 'medium', 'high', 'urgent'] as const;
	const CATEGORIES = ['billing', 'technical_issue', 'feature_request', 'general'] as const;

	let selectedOrgId = $derived(
		page.url.searchParams.get('org') ?? data.organizations[0]?.id ?? ''
	);
	let selectedTicketId = $derived(page.url.searchParams.get('ticket'));

	// Create ticket form state
	let subject = $state('');
	let description = $state('');
	let priority = $state('medium');
	let category = $state('general');
	let creating = $state(false);
	let openDropdown = $state<string | null>(null);

	// Ticket detail state
	type TicketDetail = {
		id: string;
		subject: string;
		description: string | null;
		status: string;
		priority: string;
		category: string | null;
		channel: string;
		created_at: string;
		updated_at: string;
		resolved_at: string | null;
		agent: { id: string; full_name: string; avatar_url: string | null } | null;
		[key: string]: unknown;
	};

	type Message = {
		id: string;
		body: string;
		is_internal_note: boolean;
		created_at: string;
		sender: {
			id: string;
			full_name: string;
			username: string;
			avatar_url: string | null;
		} | null;
	};

	let ticket = $state<TicketDetail | null>(null);
	let messages = $state<Message[]>([]);
	let ticketLoading = $state(false);
	let ticketError = $state<string | null>(null);
	let messageBody = $state('');
	let sendingMessage = $state(false);
	let messagesContainer: HTMLDivElement | undefined = $state();
	let composeTextarea: HTMLTextAreaElement | undefined = $state();

	// Ensure ?org is always set in URL
	$effect(() => {
		if (!page.url.searchParams.get('org') && data.organizations.length > 0) {
			const params = new SvelteURLSearchParams(page.url.searchParams);
			params.set('org', data.organizations[0].id);
			goto(`${localizeHref('/c')}?${params.toString()}`, { replaceState: true });
		}
	});

	// Load tickets when org changes
	$effect(() => {
		const orgId = selectedOrgId;
		const userId = auth.user?.id;
		if (!orgId || !userId) return;
		clientPortal.loadTickets(orgId, userId);
	});

	// Load ticket detail when ticket param changes
	$effect(() => {
		const ticketId = selectedTicketId;
		if (!ticketId) {
			ticket = null;
			messages = [];
			ticketError = null;
			return;
		}
		loadTicketDetail(ticketId);
	});

	async function loadTicketDetail(id: string) {
		ticketLoading = true;
		ticketError = null;
		messageBody = '';
		try {
			const [t, m] = await Promise.all([
				api.tickets.getById(id),
				api.tickets.getMessages(id)
			]);
			ticket = t as TicketDetail;
			messages = (m as Message[]).filter((msg) => !msg.is_internal_note);
			scrollToBottom();
		} catch (e) {
			ticketError = e instanceof Error ? e.message : 'Failed to load ticket';
		} finally {
			ticketLoading = false;
		}
	}

	function scrollToBottom() {
		requestAnimationFrame(() => {
			if (messagesContainer) {
				messagesContainer.scrollTop = messagesContainer.scrollHeight;
			}
		});
	}

	async function createTicket() {
		if (!subject.trim() || !auth.user || creating) return;
		creating = true;
		const handle = notifications.action('Creating ticket...');
		try {
			const newTicket = await api.tickets.create({
				subject: subject.trim(),
				description: description.trim() || undefined,
				customer_id: auth.user.id,
				organization_id: selectedOrgId,
				priority,
				category,
				channel: 'web_form'
			});
			clientPortal.addTicket(newTicket as unknown as Parameters<typeof clientPortal.addTicket>[0]);
			handle.success('Ticket created successfully');
			subject = '';
			description = '';
			priority = 'medium';
			category = 'general';
			const params = new SvelteURLSearchParams(page.url.searchParams);
			params.set('ticket', newTicket.id);
			goto(`${localizeHref('/c')}?${params.toString()}`);
		} catch (e) {
			handle.error(
				'Failed to create ticket',
				e instanceof Error ? e.message : undefined
			);
		} finally {
			creating = false;
		}
	}

	async function sendMessage() {
		if (!ticket || !messageBody.trim() || sendingMessage || !auth.user) return;
		sendingMessage = true;
		try {
			const msg = (await api.tickets.addMessage(
				ticket.id,
				auth.user.id,
				messageBody.trim(),
				false
			)) as Message;
			messages = [...messages, msg];
			messageBody = '';
			if (composeTextarea) composeTextarea.style.height = 'auto';
			scrollToBottom();
		} catch {
			notifications.add('error', 'Failed to send message');
		} finally {
			sendingMessage = false;
		}
	}

	function backToCreate() {
		const params = new SvelteURLSearchParams(page.url.searchParams);
		params.delete('ticket');
		goto(`${localizeHref('/c')}?${params.toString()}`);
	}

	function displayName(val: string): string {
		return val
			.split('_')
			.map((w) => w.charAt(0).toUpperCase() + w.slice(1))
			.join(' ');
	}

	function formatDateTime(dateStr: unknown): string {
		if (!dateStr || typeof dateStr !== 'string') return '—';
		const d = new Date(dateStr);
		if (isNaN(d.getTime())) return '—';
		return (
			d.toLocaleDateString('de-DE', { day: '2-digit', month: '2-digit', year: 'numeric' }) +
			' ' +
			d.toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' })
		);
	}

	function formatTime(dateStr: string): string {
		const d = new Date(dateStr);
		if (isNaN(d.getTime())) return '';
		return d.toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' });
	}

	$effect(() => {
		if (!openDropdown) return;
		function handleClick(e: MouseEvent) {
			const target = e.target as HTMLElement;
			if (!target.closest('[data-dropdown]')) {
				openDropdown = null;
			}
		}
		document.addEventListener('mousedown', handleClick);
		return () => document.removeEventListener('mousedown', handleClick);
	});

	const statusColor: Record<string, string> = {
		open: 'text-blue-500',
		in_progress: 'text-yellow-500',
		waiting_on_customer: 'text-orange-500',
		waiting_on_agent: 'text-purple-500',
		resolved: 'text-green-500',
		closed: 'text-sidebar-icon'
	};

	const priorityColor: Record<string, string> = {
		low: 'text-blue-400',
		medium: 'text-yellow-500',
		high: 'text-orange-400',
		urgent: 'text-red-400'
	};

	const chevronSvg = `<svg class="h-3.5 w-3.5 shrink-0 text-muted/40" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/></svg>`;
	const dropdownBtnClass =
		'flex w-full cursor-pointer items-center justify-between gap-2 rounded-sm bg-surface-hover/40 px-2.5 py-1.5 text-base text-sidebar-text transition-all duration-150 hover:bg-surface-hover/60';
	const dropdownPanelClass =
		'absolute left-0 z-20 mt-1.5 max-h-48 w-full origin-top-left animate-dropdown-in overflow-y-auto rounded-md border border-surface-border/70 bg-surface py-1 shadow-lg shadow-black/20';
	const dropdownItemBase =
		'flex w-full items-center px-2.5 py-1.5 text-left text-sm transition-colors hover:bg-surface-hover/60';
	const labelClass = 'mb-1.5 block text-xs font-medium uppercase tracking-[0.08em] text-muted/50';
	const inputClass =
		'w-full rounded-sm bg-surface-hover/40 px-2.5 py-1.5 text-base text-sidebar-text outline-none placeholder:text-muted/30 focus:bg-surface-hover/60';
</script>

{#if selectedTicketId}
	<!-- Ticket detail + chat view -->
	<div class="flex h-screen flex-col">
		{#if ticketLoading}
			<div class="flex flex-1 items-center justify-center">
				<LoaderCircle size={24} class="animate-spin text-muted" />
			</div>
		{:else if ticketError || !ticket}
			<div class="flex flex-1 flex-col items-center justify-center gap-3">
				<p class="text-base text-red-400">{ticketError ?? 'Ticket not found'}</p>
				<button
					class="flex h-7 items-center gap-1 rounded-sm bg-surface-hover/40 px-2.5 text-sm font-medium text-sidebar-text transition-all duration-150 hover:bg-surface-hover/60"
					onclick={backToCreate}
				>
					Go back
				</button>
			</div>
		{:else}
			<!-- Ticket header -->
			<div class="shrink-0 border-b border-surface-border/40 px-6 py-4">
				<div class="mx-auto flex max-w-3xl items-center gap-3">
					<button
						class="flex h-6 w-6 shrink-0 items-center justify-center rounded-sm text-muted/40 transition-all duration-150 hover:bg-surface-hover hover:text-sidebar-text"
						onclick={backToCreate}
						aria-label="Back"
					>
						<ArrowLeft size={14} />
					</button>
					<div class="min-w-0 flex-1">
						<div class="flex items-center gap-2">
							<h1 class="truncate text-lg font-semibold text-sidebar-text">
								{ticket.subject}
							</h1>
						</div>
						<div class="mt-1 flex items-center gap-3 text-sm text-muted/50">
							<span class="flex items-center gap-1">
							<Circle
								size={7}
								class={statusColor[ticket.status] ?? 'text-sidebar-icon'}
								fill="currentColor"
							/>
								{displayName(ticket.status)}
							</span>
							<span
								class="text-xs font-medium {priorityColor[ticket.priority] ??
									''}"
							>
								{displayName(ticket.priority)}
							</span>
							{#if ticket.category}
								<span>{displayName(ticket.category)}</span>
							{/if}
							<span class="font-mono">Created {formatDateTime(ticket.created_at)}</span>
						</div>
					</div>
				</div>

				{#if ticket.description}
					<div class="mx-auto mt-3 max-w-3xl pl-8">
						<div class="border-l-2 border-surface-border/40 pl-3">
							<p class="whitespace-pre-wrap text-base text-sidebar-text/80">
								{ticket.description}
							</p>
						</div>
					</div>
				{/if}
			</div>

			<!-- Messages -->
			<div
				bind:this={messagesContainer}
				class="flex-1 overflow-y-auto px-6 py-4"
			>
				<div class="mx-auto max-w-3xl">
					{#if messages.length === 0}
						<div class="flex h-full items-center justify-center py-20">
							<p class="text-sm text-muted/50">No messages yet. Start the conversation below.</p>
						</div>
					{:else}
						<div class="space-y-4">
							{#each messages as msg (msg.id)}
								{@const isOwn = msg.sender?.id === auth.user?.id}
								<div class="flex {isOwn ? 'justify-end' : 'justify-start'}">
									<div
										class="max-w-[70%] rounded border {isOwn
											? 'border-accent/20 bg-accent/5'
											: 'border-surface-border/40 bg-surface/50'} p-3"
									>
										<div class="mb-1 flex items-center justify-between gap-4">
											<span class="text-sm font-medium text-sidebar-text">
												{msg.sender?.full_name ?? 'Unknown'}
											</span>
											<span class="font-mono text-xs text-muted/50">
												{formatTime(msg.created_at)}
											</span>
										</div>
										<p class="whitespace-pre-wrap text-base text-sidebar-text">
											{msg.body}
										</p>
									</div>
								</div>
							{/each}
						</div>
					{/if}
				</div>
			</div>

			<!-- Compose -->
			<div class="shrink-0 border-t border-surface-border/40 px-6 py-3">
				<div class="mx-auto max-w-3xl">
					<div class="flex items-end gap-2">
						<textarea
							bind:this={composeTextarea}
							bind:value={messageBody}
							rows="1"
							class="{inputClass} max-h-32 flex-1 resize-none overflow-y-auto"
							placeholder="Write a message..."
							oninput={(e) => {
								const el = e.currentTarget;
								el.style.height = 'auto';
								el.style.height = el.scrollHeight + 'px';
							}}
							onkeydown={(e) => {
								if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) {
									e.preventDefault();
									sendMessage();
								}
							}}
						></textarea>
						<button
							class="flex h-7 w-7 shrink-0 items-center justify-center self-end rounded-sm bg-accent text-white transition-all duration-150 hover:bg-accent/90 disabled:opacity-30"
							disabled={!messageBody.trim() || sendingMessage}
							onclick={sendMessage}
							aria-label="Send message"
						>
							<Send size={14} />
						</button>
					</div>
					<p class="mt-1.5 text-xs text-muted/50">
						Press <kbd class="rounded-sm border border-surface-border/60 px-1 py-0.5 text-2xs">Ctrl</kbd>
						+
						<kbd class="rounded-sm border border-surface-border/60 px-1 py-0.5 text-2xs">Enter</kbd>
						to send
					</p>
				</div>
			</div>
		{/if}
	</div>
{:else}
	<!-- Create ticket form (centered) -->
	<div class="flex min-h-screen items-center justify-center px-6">
		<div class="w-full max-w-lg">
			<h1 class="mb-1 text-lg font-semibold text-sidebar-text">New Support Ticket</h1>
			<p class="mb-6 text-sm text-muted/50">Describe your issue and we'll get back to you.</p>

			<form
				onsubmit={(e) => {
					e.preventDefault();
					createTicket();
				}}
				class="space-y-4"
			>
				<!-- Subject -->
				<div>
					<label for="subject" class={labelClass}>Subject</label>
					<input
						id="subject"
						type="text"
						bind:value={subject}
						class={inputClass}
						placeholder="Brief summary of your issue"
						required
					/>
				</div>

				<!-- Description -->
				<div>
					<label for="description" class={labelClass}>Description</label>
					<textarea
						id="description"
						bind:value={description}
						class="{inputClass} resize-none"
						rows="5"
						placeholder="Provide details about your issue..."
					></textarea>
				</div>

				<div class="grid grid-cols-2 gap-4">
					<!-- Priority -->
					<div>
						<span class={labelClass}>Priority</span>
						<div class="relative" data-dropdown>
							<button
								type="button"
								class={dropdownBtnClass}
								onclick={() =>
									(openDropdown = openDropdown === 'priority' ? null : 'priority')}
							>
								<span class="truncate">{displayName(priority)}</span>
								{@html chevronSvg}
							</button>
							{#if openDropdown === 'priority'}
								<div class={dropdownPanelClass}>
									{#each PRIORITIES as p (p)}
										<button
											type="button"
											class="{dropdownItemBase} {priority === p
												? 'font-medium text-accent'
												: 'text-sidebar-text'}"
											onmousedown={(e) => {
												e.preventDefault();
												priority = p;
												openDropdown = null;
											}}>{displayName(p)}</button
										>
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
								onclick={() =>
									(openDropdown = openDropdown === 'category' ? null : 'category')}
							>
								<span class="truncate">{displayName(category)}</span>
								{@html chevronSvg}
							</button>
							{#if openDropdown === 'category'}
								<div class={dropdownPanelClass}>
									{#each CATEGORIES as c (c)}
										<button
											type="button"
											class="{dropdownItemBase} {category === c
												? 'font-medium text-accent'
												: 'text-sidebar-text'}"
											onmousedown={(e) => {
												e.preventDefault();
												category = c;
												openDropdown = null;
											}}>{displayName(c)}</button
										>
									{/each}
								</div>
							{/if}
						</div>
					</div>
				</div>

				<button
					type="submit"
					disabled={!subject.trim() || creating}
					class="flex h-7 w-full items-center justify-center rounded-sm bg-accent text-sm font-medium text-white transition-all duration-150 hover:bg-accent/90 disabled:opacity-30"
				>
					{#if creating}
						<LoaderCircle size={14} class="mr-2 animate-spin" />
						Creating...
					{:else}
						Submit Ticket
					{/if}
				</button>
			</form>
		</div>
	</div>
{/if}

<style>
	@keyframes dropdown-in {
		from { opacity: 0; transform: scale(0.95) translateY(-4px); }
		to   { opacity: 1; transform: scale(1) translateY(0); }
	}
	:global(.animate-dropdown-in) {
		animation: dropdown-in 150ms ease-out;
	}
</style>
