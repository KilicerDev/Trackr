<script lang="ts">
	import { api } from '$lib/api';
	import { auth } from '$lib/stores/auth.svelte';
	import { notifications } from '$lib/stores/notifications.svelte';
	import { Send, ArrowLeft, Circle, LoaderCircle, X, Paperclip } from '@lucide/svelte';
	import { inputClass } from '$lib/styles/ui';
	import type { Attachment } from '$lib/api/attachments';
	import AttachmentUploadZone from '$lib/components/AttachmentUploadZone.svelte';
	import AttachmentGrid from '$lib/components/AttachmentGrid.svelte';
	import * as m from '$lib/paraglide/messages';
	import { tStatus, tPriority, tCategory } from '$lib/i18n/ticket-labels';

	type TicketDetail = {
		id: string;
		subject: string;
		description: string | null;
		status: string;
		priority: string;
		category: string | null;
		channel: string;
		organization_id: string;
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
		attachment_ids: string[];
		created_at: string;
		sender: { id: string; full_name: string; username: string; avatar_url: string | null } | null;
	};

	interface Props {
		ticketId: string;
		onBack: () => void;
	}

	let { ticketId, onBack }: Props = $props();

	let ticket = $state<TicketDetail | null>(null);
	let messages = $state<Message[]>([]);
	let ticketAttachments = $state<Attachment[]>([]);
	let messageAttachmentIds = $state<Record<string, string[]>>({});
	let pendingFiles = $state<File[]>([]);
	let loading = $state(false);
	let loadError = $state<string | null>(null);
	let messageBody = $state('');
	let sendingMessage = $state(false);
	let messagesContainer: HTMLDivElement | undefined = $state();
	let composeTextarea: HTMLTextAreaElement | undefined = $state();

	$effect(() => {
		const id = ticketId;
		if (!id) return;
		loadTicketDetail(id);
	});

	async function loadTicketDetail(id: string) {
		loading = true;
		loadError = null;
		messageBody = '';
		pendingFiles = [];
		try {
			const [t, m] = await Promise.all([api.tickets.getById(id), api.tickets.getMessages(id)]);
			ticket = t as TicketDetail;
			messages = (m as Message[]).filter((msg) => !msg.is_internal_note);
			const map: Record<string, string[]> = {};
			for (const msg of messages) {
				if (msg.attachment_ids?.length) map[msg.id] = msg.attachment_ids;
			}
			messageAttachmentIds = map;
			try {
				ticketAttachments = await api.attachments.list('support_ticket', id);
			} catch {
				ticketAttachments = [];
			}
			scrollToBottom();
		} catch (e) {
			loadError = e instanceof Error ? e.message : m.client_failed_to_load_ticket();
		} finally {
			loading = false;
		}
	}

	function scrollToBottom() {
		requestAnimationFrame(() => {
			if (messagesContainer) messagesContainer.scrollTop = messagesContainer.scrollHeight;
		});
	}

	function getMessageAttachments(messageId: string): Attachment[] {
		const ids = messageAttachmentIds[messageId];
		if (!ids || ids.length === 0) return [];
		return ticketAttachments.filter((a) => ids.includes(a.id));
	}

	async function sendMessage() {
		if (!ticket || !auth.user || sendingMessage) return;
		const hasBody = messageBody.trim().length > 0;
		const hasFiles = pendingFiles.length > 0;
		if (!hasBody && !hasFiles) return;
		sendingMessage = true;
		try {
			const msg = (await api.tickets.addMessage(
				ticket.id,
				auth.user.id,
				messageBody.trim(),
				false
			)) as Message;
			messages = [...messages, msg];

			if (hasFiles) {
				const uploadedIds: string[] = [];
				for (const file of pendingFiles) {
					try {
						const att = await api.attachments.upload(
							file,
							'support_ticket',
							ticket.id,
							ticket.organization_id,
							auth.user!.id
						);
						ticketAttachments = [att, ...ticketAttachments];
						uploadedIds.push(att.id);
					} catch {
						/* silent — best-effort */
					}
				}
				if (uploadedIds.length > 0) {
					messageAttachmentIds = { ...messageAttachmentIds, [msg.id]: uploadedIds };
					api.tickets.updateMessageAttachments(msg.id, uploadedIds).catch(() => {});
				}
			}

			messageBody = '';
			pendingFiles = [];
			if (composeTextarea) composeTextarea.style.height = 'auto';
			scrollToBottom();
		} catch {
			notifications.add('error', m.client_failed_send_message());
		} finally {
			sendingMessage = false;
		}
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

	const statusColor: Record<string, string> = {
		open: 'text-blue-500',
		in_progress: 'text-yellow-500',
		paused: 'text-yellow-500',
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
</script>

<div class="flex h-full min-h-0 flex-col">
	{#if loading}
		<div class="flex flex-1 items-center justify-center">
			<LoaderCircle size={24} class="animate-spin text-muted" />
		</div>
	{:else if loadError || !ticket}
		<div class="flex flex-1 flex-col items-center justify-center gap-3">
			<p class="text-base text-red-400">{loadError ?? m.client_ticket_not_found()}</p>
			<button
				class="flex h-7 items-center gap-1 rounded-sm bg-surface-hover/40 px-2.5 text-sm font-medium text-sidebar-text transition-all duration-150 hover:bg-surface-hover/60"
				onclick={onBack}
			>
				{m.client_go_back()}
			</button>
		</div>
	{:else}
		<div class="shrink-0 border-b border-surface-border/40 px-6 py-4">
			<div class="mx-auto flex max-w-3xl items-center gap-3">
				<button
					class="flex h-6 w-6 shrink-0 items-center justify-center rounded-sm text-muted/40 transition-all duration-150 hover:bg-surface-hover hover:text-sidebar-text"
					onclick={onBack}
					aria-label={m.client_back()}
				>
					<ArrowLeft size={14} />
				</button>
				<div class="min-w-0 flex-1">
					<h1 class="truncate text-lg font-semibold text-sidebar-text">{ticket.subject}</h1>
					<div class="mt-1 flex items-center gap-3 text-sm text-muted/50">
						<span class="flex items-center gap-1">
							<Circle size={7} class={statusColor[ticket.status] ?? 'text-sidebar-icon'} fill="currentColor" />
							{tStatus(ticket.status)}
						</span>
						<span class="text-xs font-medium {priorityColor[ticket.priority] ?? ''}">
							{tPriority(ticket.priority)}
						</span>
						{#if ticket.category}
							<span>{tCategory(ticket.category)}</span>
						{/if}
						<span class="font-mono">{m.client_created()} {formatDateTime(ticket.created_at)}</span>
					</div>
				</div>
			</div>
			{#if ticket.description}
				<div class="mx-auto mt-3 max-w-3xl pl-8">
					<div class="border-l-2 border-surface-border/40 pl-3">
						<p class="whitespace-pre-wrap text-base text-sidebar-text/80">{ticket.description}</p>
					</div>
				</div>
			{/if}
		</div>

		<div bind:this={messagesContainer} class="flex-1 overflow-y-auto px-6 py-4">
			<div class="mx-auto max-w-3xl">
				{#if messages.length === 0}
					<div class="flex h-full items-center justify-center py-20">
						<p class="text-sm text-muted/50">{m.client_no_messages()}</p>
					</div>
				{:else}
					<div class="space-y-4">
						{#each messages as msg (msg.id)}
							{@const isOwn = msg.sender?.id === auth.user?.id}
							{@const msgAttachments = getMessageAttachments(msg.id)}
							<div class="flex {isOwn ? 'justify-end' : 'justify-start'}">
								<div class="max-w-[70%] rounded border {isOwn ? 'border-accent/20 bg-accent/5' : 'border-surface-border/40 bg-surface/50'} p-3">
									<div class="mb-1 flex items-center justify-between gap-4">
										<span class="text-sm font-medium text-sidebar-text">{msg.sender?.full_name ?? m.client_unknown_user()}</span>
										<span class="font-mono text-xs text-muted/50">{formatTime(msg.created_at)}</span>
									</div>
									{#if msg.body}
										<p class="whitespace-pre-wrap text-base text-sidebar-text">{msg.body}</p>
									{/if}
									{#if msgAttachments.length > 0}
										<div class="mt-2">
											<AttachmentGrid attachments={msgAttachments} />
										</div>
									{/if}
								</div>
							</div>
						{/each}
					</div>
				{/if}
			</div>
		</div>

		<div class="shrink-0 border-t border-surface-border/40 px-6 py-3">
			<div class="mx-auto max-w-3xl">
				{#if pendingFiles.length > 0}
					<div class="mb-2 flex flex-wrap gap-1">
						{#each pendingFiles as file, i (file.name + i)}
							<span class="flex items-center gap-1 rounded border border-surface-border/40 bg-surface/50 px-2 py-0.5 text-xs text-sidebar-text">
								<Paperclip size={10} />
								<span class="max-w-[160px] truncate">{file.name}</span>
								<button
									type="button"
									class="text-muted hover:text-red-500"
									aria-label={m.client_remove_attachment({ name: file.name })}
									onclick={() => { pendingFiles = pendingFiles.filter((_, idx) => idx !== i); }}
								>
									<X size={10} />
								</button>
							</span>
						{/each}
					</div>
				{/if}
				<div class="flex items-end gap-2">
					<textarea
						bind:this={composeTextarea}
						bind:value={messageBody}
						rows="1"
						class="{inputClass} max-h-32 flex-1 resize-none overflow-y-auto"
						placeholder={m.client_write_message()}
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
					<div class="flex h-7 self-end">
						<AttachmentUploadZone
							variant="compact"
							onFilesSelected={(files) => { pendingFiles = [...pendingFiles, ...files]; }}
							disabled={sendingMessage}
						/>
					</div>
					<button
						class="flex h-7 w-7 shrink-0 items-center justify-center self-end rounded-sm bg-accent text-white transition-all duration-150 hover:bg-accent/90 disabled:opacity-30"
						disabled={(!messageBody.trim() && pendingFiles.length === 0) || sendingMessage}
						onclick={sendMessage}
						aria-label={m.client_send_message()}
					>
						<Send size={14} />
					</button>
				</div>
				<p class="mt-1.5 text-xs text-muted/50">
					{m.client_send_shortcut_press()} <kbd class="rounded-sm border border-surface-border/60 px-1 py-0.5 text-2xs">Ctrl</kbd>
					+
					<kbd class="rounded-sm border border-surface-border/60 px-1 py-0.5 text-2xs">Enter</kbd>
					{m.client_send_shortcut_to_send()}
				</p>
			</div>
		</div>
	{/if}
</div>
