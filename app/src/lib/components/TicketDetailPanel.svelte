<script lang="ts">
	import { X, Send, Lock, Trash2, Plus, Clock, ArrowRightFromLine, Paperclip, MessageSquare, Info } from '@lucide/svelte';
	import { ticketStatusIcons, defaultStatusIcon } from '$lib/config/status-icons';
	import { priorityIcons, defaultPriorityIcon } from '$lib/config/priority-icons';
	import { api } from '$lib/api';
	import { auth } from '$lib/stores/auth.svelte';
	import CreateTaskModal from '$lib/components/CreateTaskModal.svelte';
	import type { Attachment } from '$lib/api/attachments';
	import AttachmentUploadZone from './AttachmentUploadZone.svelte';
	import AttachmentGrid from './AttachmentGrid.svelte';
	import AttachmentCompact from './AttachmentCompact.svelte';

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
		user: { id: string; full_name: string; avatar_url: string | null; is_active: boolean; deleted_at: string | null };
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
		attachment_ids: string[];
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
		initialTab?: 'details' | 'messages' | 'time';
		onClose: () => void;
		onUpdate: () => void;
		onTabChange?: (tab: 'details' | 'messages' | 'time') => void;
	}

	let { ticketId, members, initialTab = 'details', onClose, onUpdate, onTabChange }: Props = $props();

	const ASSIGNABLE_ROLES = ['owner', 'admin', 'manager', 'agent'];
	const assignableMembers = $derived(
		members.filter((m) => m.user.is_active && !m.user.deleted_at && m.role && ASSIGNABLE_ROLES.includes(m.role.slug))
	);

	let ticket = $state<TicketDetail | null>(null);

	const currentTicketStatus = $derived(ticket ? (ticketStatusIcons[ticket.status] ?? defaultStatusIcon) : defaultStatusIcon);
	const CurrentTicketStatusIcon = $derived(currentTicketStatus.icon);
	const currentTicketPriority = $derived(ticket ? (priorityIcons[ticket.priority] ?? defaultPriorityIcon) : defaultPriorityIcon);
	const CurrentTicketPriorityIcon = $derived(currentTicketPriority.icon);
	let messages = $state<Message[]>([]);
	let loading = $state(true);
	let error = $state<string | null>(null);
	let openDropdown = $state<string | null>(null);

	let activeTab = $state<'details' | 'messages' | 'time'>(initialTab);

	let editingDescription = $state(false);
	let descriptionDraft = $state('');
	let savingDescription = $state(false);

	let messageBody = $state('');
	let isInternalNote = $state(false);
	let sendingMessage = $state(false);

	type LinkedTask = {
		id: string;
		title: string;
		short_id: string;
		status: string;
		priority: string;
		type: string;
		project_id: string;
		created_at: string;
	};

	let linkedTasks = $state<LinkedTask[]>([]);
	let loadingLinkedTasks = $state(false);
	let convertToTaskOpen = $state(false);

	let ticketAttachments = $state<Attachment[]>([]);
	let messageAttachmentIds = $state<Record<string, string[]>>({});
	let uploadingFiles = $state(false);
	let messagePendingFiles = $state<File[]>([]);

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
			const [t, m, wl, lt] = await Promise.all([
				api.tickets.getById(id),
				api.tickets.getMessages(id),
				api.tickets.getWorkLogs(id),
				api.tasks.getByTicketId(id)
			]);
			ticket = t as TicketDetail;
			messages = m as Message[];
			workLogs = wl as WorkLog[];
			linkedTasks = lt as LinkedTask[];
			descriptionDraft = ticket.description ?? '';
			// Restore message → attachment mapping from persisted data
			const map: Record<string, string[]> = {};
			for (const msg of messages) {
				if (msg.attachment_ids && msg.attachment_ids.length > 0) {
					map[msg.id] = msg.attachment_ids;
				}
			}
			messageAttachmentIds = map;
			// Load attachments separately so failures don't block ticket loading
			try {
				ticketAttachments = await api.attachments.list('support_ticket', id);
			} catch {
				ticketAttachments = [];
			}
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to load ticket';
		} finally {
			loading = false;
			scrollMessagesToBottom();
		}
	}

	async function handleTicketFileUpload(files: File[]) {
		if (!ticket || !auth.user || uploadingFiles) return;
		uploadingFiles = true;
		try {
			const orgId = (ticket as Record<string, unknown>).organization_id as string;
			for (const file of files) {
				const att = await api.attachments.upload(file, 'support_ticket', ticket.id, orgId, auth.user!.id);
				ticketAttachments = [att, ...ticketAttachments];
			}
		} catch {
			/* silent */
		} finally {
			uploadingFiles = false;
		}
	}

	async function handleRemoveAttachment(att: Attachment) {
		try {
			await api.attachments.remove(att.id, att.storage_path);
			ticketAttachments = ticketAttachments.filter((a) => a.id !== att.id);
		} catch {
			/* silent */
		}
	}

	function getMessageAttachments(messageId: string): Attachment[] {
		const ids = messageAttachmentIds[messageId];
		if (!ids || ids.length === 0) return [];
		return ticketAttachments.filter((a) => ids.includes(a.id));
	}

	async function loadLinkedTasks() {
		if (!ticket) return;
		loadingLinkedTasks = true;
		try {
			linkedTasks = (await api.tasks.getByTicketId(ticket.id)) as LinkedTask[];
		} catch {
			/* silent */
		} finally {
			loadingLinkedTasks = false;
		}
	}

	function mapTicketPriority(ticketPriority: string): string {
		const map: Record<string, string> = { low: 'low', medium: 'medium', high: 'high', urgent: 'urgent' };
		return map[ticketPriority] ?? 'medium';
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
			// Upload pending files to the ticket, but remember which belong to this message
			if (messagePendingFiles.length > 0) {
				const uploadedIds: string[] = [];
				const orgId = (ticket as Record<string, unknown>).organization_id as string;
				if (orgId) {
					for (const file of messagePendingFiles) {
						try {
							const att = await api.attachments.upload(file, 'support_ticket', ticket.id, orgId, auth.user!.id);
							ticketAttachments = [att, ...ticketAttachments];
							uploadedIds.push(att.id);
						} catch {
							/* silent */
						}
					}
				}
				if (uploadedIds.length > 0) {
					messageAttachmentIds = { ...messageAttachmentIds, [msg.id]: uploadedIds };
					// Persist to DB
					api.tickets.updateMessageAttachments(msg.id, uploadedIds).catch(() => {});
				}
			}
			messageBody = '';
			isInternalNote = false;
			messagePendingFiles = [];
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

	const labelClass = 'text-xs font-medium uppercase tracking-[0.08em] text-muted/50';
	const propBtnClass =
		'flex w-full cursor-pointer items-center justify-between gap-2 rounded-sm bg-surface-hover/40 px-2.5 py-1.5 text-base text-sidebar-text transition-all duration-150 hover:bg-surface-hover/60';
	const propBtnReadonlyClass =
		'flex w-full items-center gap-2 rounded-sm bg-surface-hover/40 px-2.5 py-1.5 text-base text-sidebar-text/60 cursor-default';
	const dropdownPanelClass =
		'absolute left-0 z-30 mt-1.5 max-h-48 w-full overflow-y-auto rounded-md border border-surface-border bg-surface py-1 shadow-lg shadow-black/15 ring-1 ring-white/[0.07] animate-dropdown-in';
	const dropdownItemBase =
		'flex w-full items-center px-2.5 py-1.5 text-left text-sm transition-colors hover:bg-surface-hover/60';

	const chevronSvg = `<svg class="h-3.5 w-3.5 shrink-0 text-muted/40" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/></svg>`;
</script>

<div class="flex h-full w-[420px] shrink-0 flex-col border-l border-surface-border bg-surface">
		{#if loading}
			<div class="flex flex-1 items-center justify-center">
				<p class="text-sm text-muted">Loading...</p>
			</div>
		{:else if error || !ticket}
			<div class="flex flex-1 flex-col items-center justify-center gap-3">
				<p class="text-sm text-red-500">{error ?? 'Ticket not found'}</p>
				<button
					class="flex h-7 items-center rounded-sm bg-surface-hover/40 px-2.5 text-sm font-medium text-sidebar-text transition-all duration-150 hover:bg-surface-hover/60"
					onclick={onClose}
				>
					Close
				</button>
			</div>
		{:else}
			<!-- Header -->
			<div
				class="flex shrink-0 items-center justify-between px-3 py-2.5"
			>
				<div class="min-w-0 flex-1">
					<span class="font-mono text-xs text-muted/50">{ticket.id.slice(0, 8)}</span>
					<h2 class="truncate text-lg font-semibold text-sidebar-text">{ticket.subject}</h2>
				</div>
				<button
					class="ml-3 flex h-6 w-6 shrink-0 items-center justify-center rounded-sm text-muted/40 transition-all duration-150 hover:bg-surface-hover hover:text-sidebar-text"
					onclick={onClose}
					aria-label="Close"
				>
					<X size={18} />
				</button>
			</div>

			<!-- Tab bar -->
			<div class="flex items-center gap-0.5 border-b border-surface-border px-4">
				<button
					class="flex items-center gap-1.5 border-b-2 px-2 py-1.5 text-sm font-medium transition-colors {activeTab === 'details' ? 'border-accent text-sidebar-text' : 'border-transparent text-muted hover:text-sidebar-text'}"
					onclick={() => { activeTab = 'details'; onTabChange?.('details'); }}
				>
					<Info size={12} /> Details
				</button>
				<button
					class="flex items-center gap-1.5 border-b-2 px-2 py-1.5 text-sm font-medium transition-colors {activeTab === 'messages' ? 'border-accent text-sidebar-text' : 'border-transparent text-muted hover:text-sidebar-text'}"
					onclick={() => { activeTab = 'messages'; onTabChange?.('messages'); }}
				>
					<MessageSquare size={12} /> Messages
					{#if messages.length > 0}
						<span class="text-2xs font-semibold text-accent">{messages.length}</span>
					{/if}
				</button>
				<button
					class="flex items-center gap-1.5 border-b-2 px-2 py-1.5 text-sm font-medium transition-colors {activeTab === 'time' ? 'border-accent text-sidebar-text' : 'border-transparent text-muted hover:text-sidebar-text'}"
					onclick={() => { activeTab = 'time'; onTabChange?.('time'); }}
				>
					<Clock size={12} /> Time
					{#if totalMinutes > 0}
						<span class="text-xs text-muted">{formatMinutes(totalMinutes)}</span>
					{/if}
				</button>
			</div>

			<!-- Scrollable content -->
			<div class="flex-1 overflow-y-auto">
				{#if activeTab === 'details'}
					<!-- Properties -->
					<div class="mx-3 mt-2 mb-2 rounded border border-surface-border/40 bg-surface/40 px-3 py-2.5">
						<span class="{labelClass} mb-3 block">Properties</span>
						<div class="grid grid-cols-2 gap-x-3 gap-y-2.5">
							<!-- Status -->
							<div>
								<span class="mb-1 block text-xs text-muted/50">Status</span>
								{#if canUpdate}
									<div class="relative" data-dropdown>
										<button
											class={propBtnClass}
											onclick={() => (openDropdown = openDropdown === 'status' ? null : 'status')}
										>
										<span class="flex items-center gap-1.5 truncate">
											<CurrentTicketStatusIcon size={15} class={currentTicketStatus.className} />
											{displayName(ticket.status)}
										</span>
										{@html chevronSvg}
									</button>
									{#if openDropdown === 'status'}
										<div class={dropdownPanelClass}>
											{#each TICKET_STATUSES as s (s)}
													{@const info = ticketStatusIcons[s] ?? defaultStatusIcon}
													{@const StatusIcon = info.icon}
													<button
														class="{dropdownItemBase} {ticket.status === s
															? 'font-medium text-accent'
															: 'text-sidebar-text'}"
														onmousedown={(e) => {
															e.preventDefault();
															updateField('status', s);
														}}><span class="mr-1.5"><StatusIcon size={15} class={info.className} /></span>{displayName(s)}</button
													>
												{/each}
											</div>
										{/if}
									</div>
								{:else}
									<div class={propBtnReadonlyClass}>
										<span class="flex items-center gap-1.5 truncate">
											<CurrentTicketStatusIcon size={15} class={currentTicketStatus.className} />
											{displayName(ticket.status)}
										</span>
									</div>
								{/if}
							</div>

							<!-- Priority -->
							<div>
								<span class="mb-1 block text-xs text-muted/50">Priority</span>
								{#if canUpdate}
									<div class="relative" data-dropdown>
										<button
											class={propBtnClass}
											onclick={() =>
												(openDropdown = openDropdown === 'priority' ? null : 'priority')}
										>
										<span class="flex items-center gap-1.5 truncate">
											<CurrentTicketPriorityIcon size={15} class={currentTicketPriority.className} />
											{displayName(ticket.priority)}
										</span>
										{@html chevronSvg}
									</button>
									{#if openDropdown === 'priority'}
										<div class={dropdownPanelClass}>
											{#each TICKET_PRIORITIES as p (p)}
													{@const info = priorityIcons[p] ?? defaultPriorityIcon}
													{@const PriorityIcon = info.icon}
													<button
														class="{dropdownItemBase} {ticket.priority === p
															? 'font-medium text-accent'
															: 'text-sidebar-text'}"
														onmousedown={(e) => {
															e.preventDefault();
															updateField('priority', p);
														}}><span class="mr-1.5"><PriorityIcon size={15} class={info.className} /></span>{displayName(p)}</button
													>
												{/each}
											</div>
										{/if}
									</div>
								{:else}
									<div class={propBtnReadonlyClass}>
										<span class="flex items-center gap-1.5 truncate">
											<CurrentTicketPriorityIcon size={15} class={currentTicketPriority.className} />
											{displayName(ticket.priority)}
										</span>
									</div>
								{/if}
							</div>

							<!-- Category -->
							<div>
								<span class="mb-1 block text-xs text-muted/50">Category</span>
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
											{#each TICKET_CATEGORIES as c (c)}
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
								<span class="mb-1 block text-xs text-muted/50">Channel</span>
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
											{#each TICKET_CHANNELS as ch (ch)}
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
								<span class="mb-1 block text-xs text-muted/50">Assigned Agent</span>
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
					<div class="mx-3 mb-2 rounded border border-surface-border/40 bg-surface/40 px-3 py-2.5">
						<span class="{labelClass} mb-2 block">Customer</span>
						{#if ticket.customer}
							<p class="text-base text-sidebar-text">{ticket.customer.full_name}</p>
							<p class="text-sm text-muted">{ticket.customer.email}</p>
						{:else}
							<p class="text-base text-muted">—</p>
						{/if}
					</div>

					<!-- Description -->
					<div class="mx-3 mb-2 rounded border border-surface-border/40 bg-surface/40 px-3 py-2.5">
						<div class="mb-2 flex items-center justify-between">
							<span class={labelClass}>Description</span>
							{#if canUpdate && !editingDescription}
								<button
									class="text-sm text-muted/50 transition-colors hover:text-accent"
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
								class="w-full resize-none rounded-sm bg-surface-hover/40 px-2.5 py-1.5 text-base text-sidebar-text outline-none placeholder:text-muted/30 focus:bg-surface-hover/60"
								placeholder="Add a description..."
							></textarea>
							<div class="mt-2 flex justify-end gap-2">
								<button
									class="flex h-7 items-center rounded-sm bg-surface-hover/40 px-2.5 text-sm text-sidebar-text transition-all duration-150 hover:bg-surface-hover/60"
									onclick={() => (editingDescription = false)}>Cancel</button
								>
								<button
									class="flex h-7 items-center rounded-sm bg-accent px-2.5 text-sm font-medium text-white transition-all duration-150 hover:bg-accent/90 disabled:opacity-30"
									disabled={savingDescription}
									onclick={saveDescription}>{savingDescription ? 'Saving...' : 'Save'}</button
								>
							</div>
						{:else}
							<p class="whitespace-pre-wrap text-base text-sidebar-text">
								{ticket.description || 'No description'}
							</p>
						{/if}
					</div>

					<!-- Attachments -->
					<div class="mx-3 mb-2 rounded border border-surface-border/40 bg-surface/40 px-3 py-2.5">
						<span class="{labelClass} mb-2 block">Attachments ({ticketAttachments.length})</span>
						<AttachmentUploadZone
							onFilesSelected={handleTicketFileUpload}
							disabled={uploadingFiles}
						/>
						{#if uploadingFiles}
							<p class="mt-2 text-sm text-muted">Uploading...</p>
						{/if}
						{#if ticketAttachments.length > 0}
							<div class="mt-2">
								<AttachmentGrid
									attachments={ticketAttachments}
									canDelete={true}
									onRemove={handleRemoveAttachment}
								/>
							</div>
						{/if}
					</div>

					<!-- Linked Tasks -->
					<div class="mx-3 mb-2 rounded border border-surface-border/40 bg-surface/40 px-3 py-2.5">
						<div class="mb-2 flex items-center justify-between">
							<span class={labelClass}>Linked Tasks</span>
							{#if canUpdate}
								<button
									class="flex items-center gap-1 text-sm text-muted/50 transition-colors hover:text-accent"
									onclick={() => (convertToTaskOpen = true)}
								>
									<ArrowRightFromLine size={12} />
									Convert to Task
								</button>
							{/if}
						</div>
						{#if loadingLinkedTasks}
							<p class="py-2 text-center text-base text-muted">Loading...</p>
						{:else if linkedTasks.length === 0}
							<p class="py-2 text-center text-base text-muted">No linked tasks</p>
						{:else}
							<div class="space-y-1.5">
								{#each linkedTasks as lt (lt.id)}
									<div class="flex items-center gap-2 rounded border border-surface-border/40 bg-surface/50 px-3 py-2">
										<span class="shrink-0 font-mono text-sm text-accent">{lt.short_id}</span>
										<span class="min-w-0 flex-1 truncate text-base text-sidebar-text">{lt.title}</span>
										<span class="shrink-0 text-xs text-muted">{displayName(lt.status)}</span>
									</div>
								{/each}
							</div>
						{/if}
					</div>

					{#if convertToTaskOpen && ticket}
						<CreateTaskModal
							onClose={() => (convertToTaskOpen = false)}
							onCreated={() => { convertToTaskOpen = false; loadLinkedTasks(); }}
							supportTicketId={ticket.id}
							prefillTitle={ticket.subject}
							prefillDescription={ticket.description ?? ''}
							prefillPriority={mapTicketPriority(ticket.priority)}
						/>
					{/if}

					<!-- Timestamps -->
					<div class="mx-3 mb-2 rounded border border-surface-border/40 bg-surface/40 px-3 py-2.5">
						<span class="{labelClass} mb-2 block">Timestamps</span>
						<div class="grid grid-cols-2 gap-x-3 gap-y-1.5 text-base">
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
				{:else if activeTab === 'messages'}
					<!-- Compose area at top -->
					<div class="mx-3 mt-2 mb-2 rounded border border-surface-border/40 bg-surface/40 px-3 py-2.5">
						{#if messagePendingFiles.length > 0}
							<div class="mb-2 flex flex-wrap gap-1">
								{#each messagePendingFiles as file, i (file.name + i)}
									<span class="flex items-center gap-1 rounded border border-surface-border/40 bg-surface/50 px-2 py-0.5 text-xs text-sidebar-text">
										<Paperclip size={10} />
										<span class="max-w-[100px] truncate">{file.name}</span>
										<button class="text-muted hover:text-red-500" onclick={() => { messagePendingFiles = messagePendingFiles.filter((_, idx) => idx !== i); }}>
											<X size={10} />
										</button>
									</span>
								{/each}
							</div>
						{/if}
						<div class="flex gap-1.5">
							<textarea
								bind:value={messageBody}
								rows="2"
								class="flex-1 resize-none rounded-sm bg-surface-hover/40 px-2.5 py-1.5 text-base text-sidebar-text outline-none placeholder:text-muted/30 focus:bg-surface-hover/60"
								placeholder={isInternalNote ? 'Internal note...' : 'Write a message...'}
								onkeydown={(e) => {
									if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) {
										e.preventDefault();
										sendMessage();
									}
								}}
							></textarea>
							<div class="flex shrink-0 flex-col gap-1">
								<AttachmentUploadZone
									compact
									onFilesSelected={(files) => { messagePendingFiles = [...messagePendingFiles, ...files]; }}
								/>
								<button
									class="flex flex-1 items-center justify-center rounded-sm bg-accent px-2.5 text-white transition-colors hover:bg-accent/90 disabled:opacity-30"
									disabled={!messageBody.trim() || sendingMessage}
									onclick={sendMessage}
									aria-label="Send"
								>
									<Send size={12} />
								</button>
							</div>
						</div>
						{#if !auth.isClient}
							<label class="mt-1.5 flex cursor-pointer items-center gap-1.5 text-xs text-muted/50">
								<input
									type="checkbox"
									bind:checked={isInternalNote}
									class="h-3 w-3 accent-accent"
								/>
								Internal note
							</label>
						{/if}
					</div>

					<!-- Messages list (newest first) -->
					<div
						bind:this={messagesContainer}
						class="divide-y divide-surface-border/30"
					>
						{#if messages.length === 0}
							<p class="py-8 text-center text-base text-muted">No messages yet</p>
						{/if}
						{#each [...messages].reverse() as msg (msg.id)}
							<div
								class="px-4 py-3 {msg.is_internal_note
									? 'bg-yellow-50 dark:bg-yellow-950/20'
									: ''}"
							>
								<div class="mb-1 flex items-center justify-between">
									<span class="text-base font-medium text-sidebar-text"
										>{msg.sender?.full_name ?? 'Unknown'}</span
									>
									<div class="flex items-center gap-2">
										{#if msg.is_internal_note}
											<span
												class="flex items-center gap-1 text-xs font-medium text-yellow-600 dark:text-yellow-400"
											>
												<Lock size={10} />
												Internal
											</span>
										{/if}
										<span class="text-xs text-muted"
											>{formatDateTime(msg.created_at)}</span
										>
									</div>
								</div>
								<p class="whitespace-pre-wrap text-base text-sidebar-text">{msg.body}</p>
								{#if getMessageAttachments(msg.id).length > 0}
									<div class="mt-1.5">
										<AttachmentCompact attachments={getMessageAttachments(msg.id)} />
									</div>
								{/if}
							</div>
						{/each}
					</div>
				{:else}
					<!-- Time tab -->
					<!-- Log form at top -->
					{#if canUpdate}
						<div class="mx-3 mt-2 mb-2 rounded border border-surface-border/40 bg-surface/40 px-3 py-2.5">
							<div class="space-y-2">
								<div class="flex items-center gap-2">
									<div class="flex items-center gap-1 rounded-sm bg-surface-hover/40 px-2 py-1">
										<input
											type="text"
											inputmode="numeric"
											bind:value={wlHours}
											placeholder="0"
											class="w-6 bg-transparent text-center text-base text-sidebar-text outline-none placeholder:text-muted/30"
										/>
										<span class="text-xs text-muted/40">h</span>
									</div>
									<div class="flex items-center gap-1 rounded-sm bg-surface-hover/40 px-2 py-1">
										<input
											type="text"
											inputmode="numeric"
											bind:value={wlMinutes}
											placeholder="0"
											class="w-6 bg-transparent text-center text-base text-sidebar-text outline-none placeholder:text-muted/30"
										/>
										<span class="text-xs text-muted/40">m</span>
									</div>
									<input
										type="date"
										bind:value={wlDate}
										class="ml-auto rounded-sm bg-surface-hover/40 px-2 py-1 text-sm text-muted outline-none"
									/>
								</div>
								<textarea
									bind:value={wlDescription}
									rows="2"
									placeholder="What did you work on..."
									class="w-full resize-none rounded-sm bg-surface-hover/40 px-2.5 py-1.5 text-base text-sidebar-text outline-none placeholder:text-muted/30 focus:bg-surface-hover/60"
								></textarea>
								<button
									class="flex h-7 w-full items-center justify-center rounded-sm bg-accent text-sm font-medium text-white transition-colors hover:bg-accent/90 disabled:opacity-30"
									disabled={addingWorkLog || (!wlHours && !wlMinutes)}
									onclick={addWorkLog}
								>
									Log time
								</button>
							</div>
						</div>
					{/if}

					<!-- Work log entries (newest first) -->
					<div class="divide-y divide-surface-border/30">
						{#if workLogs.length === 0}
							<p class="py-8 text-center text-base text-muted">No hours logged yet</p>
						{/if}
						{#each [...workLogs].reverse() as wl (wl.id)}
							<div class="px-4 py-3">
								<div class="flex items-start justify-between gap-2">
									<div class="min-w-0 flex-1">
										<div class="flex items-center gap-2">
											<span class="text-base font-medium text-sidebar-text">
												{wl.user?.full_name ?? 'Unknown'}
											</span>
											<span class="font-mono text-base font-semibold text-accent">
												{formatMinutes(Number(wl.minutes))}
											</span>
										</div>
										{#if wl.description}
											<p class="mt-0.5 text-sm text-muted">{wl.description}</p>
										{/if}
									</div>
									<div class="flex shrink-0 items-center gap-2">
										<span class="text-xs text-muted">{formatDate(wl.logged_at)}</span>
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
							</div>
						{/each}
					</div>
				{/if}
			</div>
		{/if}
</div>

<style>
@keyframes dropdown-in {
	from { opacity: 0; transform: scale(0.95) translateY(-4px); }
	to { opacity: 1; transform: scale(1) translateY(0); }
}
:global(.animate-dropdown-in) { animation: dropdown-in 150ms ease-out; }
</style>
