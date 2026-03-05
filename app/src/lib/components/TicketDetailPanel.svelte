<script lang="ts">
	import { X, Send, Lock, Trash2, Plus, Clock } from '@lucide/svelte';
	import { api } from '$lib/api';
	import { auth } from '$lib/stores/auth.svelte';

	const TICKET_STATUSES = [
		'open',
		'in_progress',
		'waiting_on_customer',
		'waiting_on_agent',
		'resolved',
		'closed'
	] as const;
	const TICKET_PRIORITIES = ['low', 'medium', 'high', 'urgent'] as const;
	const TICKET_CATEGORIES = ['billing', 'technical_issue', 'feature_request', 'general'] as const;
	const TICKET_CHANNELS = ['email', 'api', 'chat', 'web_form'] as const;

	type Member = {
		user_id: string;
		user: { id: string; full_name: string; avatar_url: string | null };
		role: { id: string; name: string; slug: string } | null;
	};

	type TicketDetail = {
		id: string;
		subject: string;
		description: string | null;
		status: string;
		priority: string;
		category: string | null;
		channel: string;
		assigned_agent_id: string | null;
		customer_id: string;
		sla_deadline: string | null;
		satisfaction_score: number | null;
		created_at: string;
		updated_at: string;
		resolved_at: string | null;
		first_response_at: string | null;
		customer: { id: string; full_name: string; email: string; avatar_url: string | null } | null;
		agent: { id: string; full_name: string; avatar_url: string | null } | null;
		[key: string]: unknown;
	};

	type Message = {
		id: string;
		body: string;
		is_internal_note: boolean;
		created_at: string;
		sender: { id: string; full_name: string; username: string; avatar_url: string | null } | null;
	};

	type WorkLog = {
		id: string;
		minutes: number;
		description: string | null;
		logged_at: string;
		created_at: string;
		user_id: string;
		user: { id: string; full_name: string; avatar_url: string | null } | null;
	};

	interface Props {
		ticketId: string;
		members: Member[];
		onClose: () => void;
		onUpdate: () => void;
	}

	let { ticketId, members, onClose, onUpdate }: Props = $props();

	const ASSIGNABLE_ROLES = ['owner', 'developer', 'manager'];
	const assignableMembers = $derived(
		members.filter((m) => m.role && ASSIGNABLE_ROLES.includes(m.role.slug))
	);

	let ticket = $state<TicketDetail | null>(null);
	let messages = $state<Message[]>([]);
	let loading = $state(true);
	let error = $state<string | null>(null);
	let openDropdown = $state<string | null>(null);

	let editingDescription = $state(false);
	let descriptionDraft = $state('');
	let savingDescription = $state(false);

	let messageBody = $state('');
	let isInternalNote = $state(false);
	let sendingMessage = $state(false);

	let workLogs = $state<WorkLog[]>([]);
	let wlHours = $state('');
	let wlMinutes = $state('');
	let wlDescription = $state('');
	let wlDate = $state(new Date().toISOString().slice(0, 10));
	let addingWorkLog = $state(false);

	let totalMinutes = $derived(
		workLogs.reduce((sum, wl) => sum + Number(wl.minutes), 0)
	);

	function formatMinutes(m: number): string {
		const h = Math.floor(m / 60);
		const rem = m % 60;
		if (h > 0 && rem > 0) return `${h}h ${rem}m`;
		if (h > 0) return `${h}h`;
		return `${rem}m`;
	}

	let messagesContainer: HTMLDivElement | undefined = $state();

	$effect(() => {
		const id = ticketId;
		loadTicket(id);
	});

	$effect(() => {
		function handleKeydown(e: KeyboardEvent) {
			if (e.key === 'Escape') {
				if (openDropdown) {
					openDropdown = null;
				} else {
					onClose();
				}
			}
		}
		document.addEventListener('keydown', handleKeydown);
		return () => document.removeEventListener('keydown', handleKeydown);
	});

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

	async function loadTicket(id: string) {
		loading = true;
		error = null;
		openDropdown = null;
		editingDescription = false;
		messageBody = '';
		try {
			const [t, m, wl] = await Promise.all([
				api.tickets.getById(id),
				api.tickets.getMessages(id),
				api.tickets.getWorkLogs(id)
			]);
			ticket = t as TicketDetail;
			messages = m as Message[];
			workLogs = wl as WorkLog[];
			descriptionDraft = ticket.description ?? '';
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to load ticket';
		} finally {
			loading = false;
			scrollMessagesToBottom();
		}
	}

	function scrollMessagesToBottom() {
		requestAnimationFrame(() => {
			if (messagesContainer) {
				messagesContainer.scrollTop = messagesContainer.scrollHeight;
			}
		});
	}

	async function updateField(field: string, value: unknown) {
		if (!ticket) return;
		const prev = { ...ticket };
		(ticket as Record<string, unknown>)[field] = value;
		openDropdown = null;

		const payload: Record<string, unknown> = { [field]: value };
		if (field === 'status' && value === 'resolved') {
			payload.resolved_at = new Date().toISOString();
		} else if (field === 'status' && prev.status === 'resolved' && value !== 'resolved') {
			payload.resolved_at = null;
		}

		try {
			const updated = (await api.tickets.update(ticket.id, payload)) as TicketDetail;
			ticket = updated;
			onUpdate();
		} catch {
			ticket = prev;
		}
	}

	async function saveDescription() {
		if (!ticket || savingDescription) return;
		savingDescription = true;
		try {
			const updated = (await api.tickets.update(ticket.id, {
				description: descriptionDraft.trim() || null
			})) as TicketDetail;
			ticket = updated;
			editingDescription = false;
			onUpdate();
		} catch {
			/* keep editing open on error */
		} finally {
			savingDescription = false;
		}
	}

	async function sendMessage() {
		if (!ticket || !messageBody.trim() || sendingMessage || !auth.user) return;
		sendingMessage = true;
		const shouldSetFirstResponse = !ticket.first_response_at && !isInternalNote;
		try {
			const msg = (await api.tickets.addMessage(
				ticket.id,
				auth.user.id,
				messageBody.trim(),
				isInternalNote
			)) as Message;
			messages = [...messages, msg];
			messageBody = '';
			isInternalNote = false;
			scrollMessagesToBottom();

			if (shouldSetFirstResponse) {
				const now = new Date().toISOString();
				const updated = (await api.tickets.update(ticket.id, {
					first_response_at: now
				})) as TicketDetail;
				ticket = updated;
				onUpdate();
			}
		} catch {
			/* keep message in input on error */
		} finally {
			sendingMessage = false;
		}
	}

	async function addWorkLog() {
		if (!ticket || addingWorkLog || !auth.user) return;
		const h = parseInt(wlHours || '0', 10) || 0;
		const m = parseInt(wlMinutes || '0', 10) || 0;
		const totalMins = h * 60 + m;
		if (totalMins <= 0) return;
		addingWorkLog = true;
		try {
			const entry = (await api.tickets.addWorkLog(
				ticket.id,
				auth.user.id,
				totalMins,
				wlDescription.trim() || undefined,
				wlDate || undefined
			)) as WorkLog;
			workLogs = [entry, ...workLogs];
			wlHours = '';
			wlMinutes = '';
			wlDescription = '';
			wlDate = new Date().toISOString().slice(0, 10);
		} catch {
			/* keep form state on error */
		} finally {
			addingWorkLog = false;
		}
	}

	async function deleteWorkLog(id: string) {
		const prev = workLogs;
		workLogs = workLogs.filter((wl) => wl.id !== id);
		try {
			await api.tickets.deleteWorkLog(id);
		} catch {
			workLogs = prev;
		}
	}

	function formatDate(dateStr: unknown): string {
		if (!dateStr || typeof dateStr !== 'string') return '—';
		const d = new Date(dateStr);
		if (isNaN(d.getTime())) return '—';
		return d.toLocaleDateString('de-DE', {
			day: '2-digit',
			month: '2-digit',
			year: 'numeric'
		});
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

	function displayName(val: string): string {
		return val
			.split('_')
			.map((w) => w.charAt(0).toUpperCase() + w.slice(1))
			.join(' ');
	}

	const canUpdate = $derived(auth.can('support_tickets', 'update'));
	const canAssign = $derived(auth.can('support_tickets', 'assign'));

	const labelClass = 'text-[11px] font-medium uppercase tracking-wider text-sidebar-icon';
	const propBtnClass =
		'flex w-full cursor-pointer items-center justify-between gap-2 border border-surface-border bg-surface px-3 py-1.5 text-xs text-sidebar-text transition-colors hover:border-sidebar-icon/30 hover:bg-surface-hover';
	const propBtnReadonlyClass =
		'flex w-full items-center gap-2 border border-surface-border bg-surface px-3 py-1.5 text-xs text-sidebar-text/60 cursor-default';
	const dropdownPanelClass =
		'absolute left-0 z-30 mt-1 max-h-48 w-full overflow-y-auto border border-surface-border bg-surface py-1 shadow-xl';
	const dropdownItemBase =
		'flex w-full items-center px-4 py-2 text-left text-xs transition-colors hover:bg-surface-hover';

	const chevronSvg = `<svg class="h-3.5 w-3.5 shrink-0 text-sidebar-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/></svg>`;
</script>

<!-- Backdrop -->
<div class="fixed inset-0 z-[60]" role="presentation">
	<button
		class="absolute inset-0 bg-black/30 transition-opacity"
		onclick={onClose}
		tabindex="-1"
		aria-label="Close panel"
	></button>

	<!-- Panel -->
	<div
		class="absolute top-0 right-0 bottom-0 flex w-[480px] flex-col border-l border-surface-border bg-surface shadow-xl"
		role="dialog"
		aria-modal="true"
	>
		{#if loading}
			<div class="flex flex-1 items-center justify-center">
				<p class="text-sm text-muted">Loading...</p>
			</div>
		{:else if error || !ticket}
			<div class="flex flex-1 flex-col items-center justify-center gap-3">
				<p class="text-sm text-red-500">{error ?? 'Ticket not found'}</p>
				<button
					class="border border-surface-border bg-surface px-4 py-2 text-xs font-medium text-sidebar-text transition-colors hover:bg-surface-hover"
					onclick={onClose}
				>
					Close
				</button>
			</div>
		{:else}
			<!-- Header -->
			<div
				class="flex shrink-0 items-center justify-between border-b border-surface-border px-4 py-3"
			>
				<div class="min-w-0 flex-1">
					<span class="text-xs font-medium text-accent">{ticket.id.slice(0, 8)}</span>
					<h2 class="truncate text-sm font-semibold text-sidebar-text">{ticket.subject}</h2>
				</div>
				<button
					class="ml-3 shrink-0 p-1 text-sidebar-icon transition-colors hover:text-sidebar-text"
					onclick={onClose}
					aria-label="Close"
				>
					<X size={18} />
				</button>
			</div>

			<!-- Scrollable content -->
			<div class="flex-1 overflow-y-auto">
				<!-- Properties -->
				<div class="border-b border-surface-border px-4 py-4">
					<span class="{labelClass} mb-3 block">Properties</span>
					<div class="grid grid-cols-2 gap-x-3 gap-y-2.5">
						<!-- Status -->
						<div>
							<span class="mb-1 block text-[10px] text-muted">Status</span>
							{#if canUpdate}
								<div class="relative" data-dropdown>
									<button
										class={propBtnClass}
										onclick={() => (openDropdown = openDropdown === 'status' ? null : 'status')}
									>
										<span class="truncate">{displayName(ticket.status)}</span>
										{@html chevronSvg}
									</button>
									{#if openDropdown === 'status'}
										<div class={dropdownPanelClass}>
											{#each TICKET_STATUSES as s}
												<button
													class="{dropdownItemBase} {ticket.status === s
														? 'font-medium text-accent'
														: 'text-sidebar-text'}"
													onmousedown={(e) => {
														e.preventDefault();
														updateField('status', s);
													}}>{displayName(s)}</button
												>
											{/each}
										</div>
									{/if}
								</div>
							{:else}
								<div class={propBtnReadonlyClass}>
									<span class="truncate">{displayName(ticket.status)}</span>
								</div>
							{/if}
						</div>

						<!-- Priority -->
						<div>
							<span class="mb-1 block text-[10px] text-muted">Priority</span>
							{#if canUpdate}
								<div class="relative" data-dropdown>
									<button
										class={propBtnClass}
										onclick={() =>
											(openDropdown = openDropdown === 'priority' ? null : 'priority')}
									>
										<span class="truncate">{displayName(ticket.priority)}</span>
										{@html chevronSvg}
									</button>
									{#if openDropdown === 'priority'}
										<div class={dropdownPanelClass}>
											{#each TICKET_PRIORITIES as p}
												<button
													class="{dropdownItemBase} {ticket.priority === p
														? 'font-medium text-accent'
														: 'text-sidebar-text'}"
													onmousedown={(e) => {
														e.preventDefault();
														updateField('priority', p);
													}}>{displayName(p)}</button
												>
											{/each}
										</div>
									{/if}
								</div>
							{:else}
								<div class={propBtnReadonlyClass}>
									<span class="truncate">{displayName(ticket.priority)}</span>
								</div>
							{/if}
						</div>

						<!-- Category -->
						<div>
							<span class="mb-1 block text-[10px] text-muted">Category</span>
							{#if canUpdate}
								<div class="relative" data-dropdown>
									<button
										class={propBtnClass}
										onclick={() =>
											(openDropdown = openDropdown === 'category' ? null : 'category')}
									>
										<span class="truncate"
											>{ticket.category ? displayName(ticket.category) : '—'}</span
										>
										{@html chevronSvg}
									</button>
									{#if openDropdown === 'category'}
										<div class={dropdownPanelClass}>
											<button
												class="{dropdownItemBase} {!ticket.category
													? 'font-medium text-accent'
													: 'text-sidebar-text'}"
												onmousedown={(e) => {
													e.preventDefault();
													updateField('category', null);
												}}>None</button
											>
											{#each TICKET_CATEGORIES as c}
												<button
													class="{dropdownItemBase} {ticket.category === c
														? 'font-medium text-accent'
														: 'text-sidebar-text'}"
													onmousedown={(e) => {
														e.preventDefault();
														updateField('category', c);
													}}>{displayName(c)}</button
												>
											{/each}
										</div>
									{/if}
								</div>
							{:else}
								<div class={propBtnReadonlyClass}>
									<span class="truncate">{ticket.category ? displayName(ticket.category) : '—'}</span>
								</div>
							{/if}
						</div>

						<!-- Channel -->
						<div>
							<span class="mb-1 block text-[10px] text-muted">Channel</span>
							{#if canUpdate}
								<div class="relative" data-dropdown>
									<button
										class={propBtnClass}
										onclick={() =>
											(openDropdown = openDropdown === 'channel' ? null : 'channel')}
									>
										<span class="truncate">{displayName(ticket.channel)}</span>
										{@html chevronSvg}
									</button>
									{#if openDropdown === 'channel'}
										<div class={dropdownPanelClass}>
											{#each TICKET_CHANNELS as ch}
												<button
													class="{dropdownItemBase} {ticket.channel === ch
														? 'font-medium text-accent'
														: 'text-sidebar-text'}"
													onmousedown={(e) => {
														e.preventDefault();
														updateField('channel', ch);
													}}>{displayName(ch)}</button
												>
											{/each}
										</div>
									{/if}
								</div>
							{:else}
								<div class={propBtnReadonlyClass}>
									<span class="truncate">{displayName(ticket.channel)}</span>
								</div>
							{/if}
						</div>

						<!-- Assigned agent (full width) -->
						<div class="col-span-2">
							<span class="mb-1 block text-[10px] text-muted">Assigned Agent</span>
							{#if canAssign}
								<div class="relative" data-dropdown>
									<button
										class={propBtnClass}
										onclick={() => (openDropdown = openDropdown === 'agent' ? null : 'agent')}
									>
										<span class="truncate"
											>{ticket.agent?.full_name ?? 'Unassigned'}</span
										>
										{@html chevronSvg}
									</button>
									{#if openDropdown === 'agent'}
										<div class={dropdownPanelClass}>
											<button
												class="{dropdownItemBase} {!ticket.assigned_agent_id
													? 'font-medium text-accent'
													: 'text-sidebar-text'}"
												onmousedown={(e) => {
													e.preventDefault();
													updateField('assigned_agent_id', null);
												}}>Unassigned</button
											>
											{#each assignableMembers as m (m.user_id)}
												<button
													class="{dropdownItemBase} {ticket.assigned_agent_id ===
													m.user_id
														? 'font-medium text-accent'
														: 'text-sidebar-text'}"
													onmousedown={(e) => {
														e.preventDefault();
														updateField('assigned_agent_id', m.user_id);
													}}>{m.user?.full_name ?? m.user_id}</button
												>
											{/each}
										</div>
									{/if}
								</div>
							{:else}
								<div class={propBtnReadonlyClass}>
									<span class="truncate">{ticket.agent?.full_name ?? 'Unassigned'}</span>
								</div>
							{/if}
						</div>
					</div>
				</div>

				<!-- Customer -->
				<div class="border-b border-surface-border px-4 py-3">
					<span class="{labelClass} mb-2 block">Customer</span>
					{#if ticket.customer}
						<p class="text-xs text-sidebar-text">{ticket.customer.full_name}</p>
						<p class="text-[11px] text-muted">{ticket.customer.email}</p>
					{:else}
						<p class="text-xs text-muted">—</p>
					{/if}
				</div>

				<!-- Description -->
				<div class="border-b border-surface-border px-4 py-3">
					<div class="mb-2 flex items-center justify-between">
						<span class={labelClass}>Description</span>
						{#if canUpdate && !editingDescription}
							<button
								class="text-[11px] text-sidebar-icon transition-colors hover:text-accent"
								onclick={() => {
									descriptionDraft = ticket?.description ?? '';
									editingDescription = true;
								}}>Edit</button
							>
						{/if}
					</div>
					{#if editingDescription}
						<textarea
							bind:value={descriptionDraft}
							rows="4"
							class="w-full resize-none border border-surface-border bg-surface px-3 py-2 text-xs text-sidebar-text outline-none transition-colors placeholder:text-sidebar-icon/70 focus:border-sidebar-icon/30"
							placeholder="Add a description..."
						></textarea>
						<div class="mt-2 flex justify-end gap-2">
							<button
								class="border border-surface-border bg-surface px-3 py-1.5 text-xs text-sidebar-text transition-colors hover:bg-surface-hover"
								onclick={() => (editingDescription = false)}>Cancel</button
							>
							<button
								class="bg-accent px-3 py-1.5 text-xs font-medium text-white transition-colors hover:bg-accent/90 disabled:opacity-50"
								disabled={savingDescription}
								onclick={saveDescription}>{savingDescription ? 'Saving...' : 'Save'}</button
							>
						</div>
					{:else}
						<p class="whitespace-pre-wrap text-xs text-sidebar-text">
							{ticket.description || 'No description'}
						</p>
					{/if}
				</div>

				<!-- Timestamps -->
				<div class="border-b border-surface-border px-4 py-3">
					<span class="{labelClass} mb-2 block">Timestamps</span>
					<div class="grid grid-cols-2 gap-x-3 gap-y-1.5 text-xs">
						<div>
							<span class="text-muted">Created</span>
							<p class="text-sidebar-text">{formatDateTime(ticket.created_at)}</p>
						</div>
						<div>
							<span class="text-muted">Updated</span>
							<p class="text-sidebar-text">{formatDateTime(ticket.updated_at)}</p>
						</div>
						<div>
							<span class="text-muted">Resolved</span>
							<p class="text-sidebar-text">{formatDateTime(ticket.resolved_at)}</p>
						</div>
						<div>
							<span class="text-muted">SLA Deadline</span>
							<p class="text-sidebar-text">{formatDateTime(ticket.sla_deadline)}</p>
						</div>
						<div>
							<span class="text-muted">First Response</span>
							<p class="text-sidebar-text">{formatDateTime(ticket.first_response_at)}</p>
						</div>
						{#if ticket.satisfaction_score != null}
							<div>
								<span class="text-muted">Satisfaction</span>
								<p class="text-sidebar-text">{ticket.satisfaction_score}/5</p>
							</div>
						{/if}
					</div>
				</div>

				<!-- Work Log -->
				<div class="border-b border-surface-border px-4 py-3">
					<div class="mb-3 flex items-center gap-2">
						<span class={labelClass}>Work Log</span>
						{#if totalMinutes > 0}
							<span
								class="flex items-center gap-1 rounded-full bg-accent/10 px-2 py-0.5 text-[10px] font-medium text-accent"
							>
								<Clock size={10} />
								{formatMinutes(totalMinutes)}
							</span>
						{/if}
					</div>

					{#if canUpdate}
						<!-- Add form -->
						<div class="mb-3">
							<div class="mb-1 flex gap-2">
								<span class="w-14 text-[10px] text-muted">Hours</span>
								<span class="w-14 text-[10px] text-muted">Min</span>
								<span class="min-w-0 flex-1 text-[10px] text-muted">Description</span>
								<span class="w-[110px] text-[10px] text-muted">Date</span>
								<span class="w-[30px] shrink-0"></span>
							</div>
							<div class="flex items-stretch gap-2">
								<input
									type="number"
									step="1"
									min="0"
									bind:value={wlHours}
									placeholder="0"
									class="w-14 border border-surface-border bg-surface px-2 py-1.5 text-xs text-sidebar-text outline-none transition-colors placeholder:text-sidebar-icon/70 focus:border-sidebar-icon/30"
								/>
								<input
									type="number"
									step="5"
									min="0"
									max="59"
									bind:value={wlMinutes}
									placeholder="0"
									class="w-14 border border-surface-border bg-surface px-2 py-1.5 text-xs text-sidebar-text outline-none transition-colors placeholder:text-sidebar-icon/70 focus:border-sidebar-icon/30"
								/>
								<input
									type="text"
									bind:value={wlDescription}
									placeholder="What was done..."
									class="min-w-0 flex-1 border border-surface-border bg-surface px-2 py-1.5 text-xs text-sidebar-text outline-none transition-colors placeholder:text-sidebar-icon/70 focus:border-sidebar-icon/30"
								/>
								<input
									type="date"
									bind:value={wlDate}
									class="w-[110px] border border-surface-border bg-surface px-2 py-1.5 text-xs text-sidebar-text outline-none transition-colors focus:border-sidebar-icon/30"
								/>
								<button
									class="flex w-[30px] shrink-0 items-center justify-center bg-accent text-white transition-colors hover:bg-accent/90 disabled:opacity-50"
									disabled={addingWorkLog || (!wlHours && !wlMinutes)}
									onclick={addWorkLog}
									aria-label="Add work log"
								>
									<Plus size={14} />
								</button>
							</div>
						</div>
					{/if}

					<!-- Entries -->
					<div class="max-h-[200px] space-y-2 overflow-y-auto">
						{#if workLogs.length === 0}
							<p class="py-3 text-center text-xs text-muted">No hours logged yet</p>
						{/if}
						{#each workLogs as wl (wl.id)}
							<div class="flex items-start justify-between gap-2 border border-surface-border bg-surface p-2.5">
								<div class="min-w-0 flex-1">
									<div class="flex items-center gap-2">
										<span class="text-xs font-medium text-sidebar-text">
											{wl.user?.full_name ?? 'Unknown'}
										</span>
										<span class="font-mono text-xs font-semibold text-accent">
											{formatMinutes(Number(wl.minutes))}
										</span>
									</div>
									{#if wl.description}
										<p class="mt-0.5 text-[11px] text-muted">{wl.description}</p>
									{/if}
								</div>
								<div class="flex shrink-0 items-center gap-2">
									<span class="text-[10px] text-muted">{formatDate(wl.logged_at)}</span>
									{#if canUpdate && auth.user && wl.user_id === auth.user.id}
										<button
											class="p-0.5 text-sidebar-icon transition-colors hover:text-red-500"
											onclick={() => deleteWorkLog(wl.id)}
											aria-label="Delete work log"
										>
											<Trash2 size={12} />
										</button>
									{/if}
								</div>
							</div>
						{/each}
					</div>
				</div>

				<!-- Messages -->
				<div class="flex flex-col px-4 py-3">
					<span class="{labelClass} mb-3 block"
						>Messages ({messages.length})</span
					>
					<div
						bind:this={messagesContainer}
						class="max-h-[320px] space-y-3 overflow-y-auto"
					>
						{#if messages.length === 0}
							<p class="py-4 text-center text-xs text-muted">No messages yet</p>
						{/if}
						{#each messages as msg (msg.id)}
							<div
								class="border border-surface-border p-3 {msg.is_internal_note
									? 'bg-yellow-50 dark:bg-yellow-950/20'
									: 'bg-surface'}"
							>
								<div class="mb-1.5 flex items-center justify-between">
									<span class="text-xs font-medium text-sidebar-text"
										>{msg.sender?.full_name ?? 'Unknown'}</span
									>
									<div class="flex items-center gap-2">
										{#if msg.is_internal_note}
											<span
												class="flex items-center gap-1 text-[10px] font-medium text-yellow-600 dark:text-yellow-400"
											>
												<Lock size={10} />
												Internal
											</span>
										{/if}
										<span class="text-[10px] text-muted"
											>{formatDate(msg.created_at)}</span
										>
									</div>
								</div>
								<p class="whitespace-pre-wrap text-xs text-sidebar-text">{msg.body}</p>
							</div>
						{/each}
					</div>
				</div>
			</div>

			<!-- Compose box -->
			<div class="shrink-0 border-t border-surface-border px-4 py-3">
				<div class="flex gap-2">
					<textarea
						bind:value={messageBody}
						rows="2"
						class="flex-1 resize-none border border-surface-border bg-surface px-3 py-2 text-xs text-sidebar-text outline-none transition-colors placeholder:text-sidebar-icon/70 focus:border-sidebar-icon/30"
						placeholder={isInternalNote ? 'Internal note...' : 'Write a message...'}
						onkeydown={(e) => {
							if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) {
								e.preventDefault();
								sendMessage();
							}
						}}
					></textarea>
					<button
						class="flex shrink-0 items-center justify-center bg-accent px-3 text-white transition-colors hover:bg-accent/90 disabled:opacity-50"
						disabled={!messageBody.trim() || sendingMessage}
						onclick={sendMessage}
						aria-label="Send message"
					>
						<Send size={14} />
					</button>
				</div>
				{#if !auth.isClient}
					<label class="mt-2 flex cursor-pointer items-center gap-1.5 text-[11px] text-muted">
						<input
							type="checkbox"
							bind:checked={isInternalNote}
							class="accent-accent"
						/>
						Internal note
					</label>
				{/if}
			</div>
		{/if}
	</div>
</div>
