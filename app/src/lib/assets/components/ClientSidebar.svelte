<script lang="ts">
	import { page } from '$app/state';
	import { goto } from '$app/navigation';
	import { auth } from '$lib/stores/auth.svelte';
	import { clientPortal } from '$lib/stores/clientPortal.svelte';
	import { ChevronDown, Circle, LogOut } from '@lucide/svelte';
	import { getClient } from '$lib/api/client';
	import logo from '$lib/assets/logo.png';
	import { SvelteURLSearchParams } from 'svelte/reactivity';
	import { localizeHref } from '$lib/paraglide/runtime';

	interface Props {
		organizations: { id: string; name: string; slug: string; logo_url: string | null }[];
	}

	let { organizations }: Props = $props();

	let orgDropdownOpen = $state(false);

	let selectedOrgId = $derived(page.url.searchParams.get('org') ?? organizations[0]?.id ?? '');
	let selectedOrg = $derived(organizations.find((o) => o.id === selectedOrgId) ?? organizations[0]);
	let selectedTicketId = $derived(page.url.searchParams.get('ticket'));

	$effect(() => {
		if (!orgDropdownOpen) return;
		function handleClick(e: MouseEvent) {
			const target = e.target as HTMLElement;
			if (!target.closest('[data-org-dropdown]')) {
				orgDropdownOpen = false;
			}
		}
		document.addEventListener('mousedown', handleClick);
		return () => document.removeEventListener('mousedown', handleClick);
	});

	function selectOrg(orgId: string) {
		orgDropdownOpen = false;
		const params = new SvelteURLSearchParams(page.url.searchParams);
		params.set('org', orgId);
		params.delete('ticket');
		goto(localizeHref(`/c?${params.toString()}`), { replaceState: true });
	}

	function selectTicket(ticketId: string) {
		const params = new SvelteURLSearchParams(page.url.searchParams);
		params.set('ticket', ticketId);
		goto(localizeHref(`/c?${params.toString()}`));
	}

	const statusColor: Record<string, string> = {
		open: 'text-blue-500',
		in_progress: 'text-yellow-500',
		waiting_on_customer: 'text-orange-500',
		waiting_on_agent: 'text-purple-500',
		resolved: 'text-green-500',
		closed: 'text-sidebar-icon'
	};
</script>

<aside
	class="fixed top-0 left-0 z-50 flex h-screen w-[260px] flex-col border-r border-sidebar-border bg-sidebar-bg"
>
	<!-- Logo -->
	<div class="flex h-14 items-center gap-2 px-4">
		<img src={logo} alt="Trackr" class="h-7 w-7 shrink-0" />
		<span style="font-family: 'GeistMono', monospace" class="text-lg font-bold tracking-widest text-sidebar-text">TRACKR</span>
	</div>

	<!-- Org dropdown -->
	<div class="px-3 pb-2" data-org-dropdown>
		<button
			class="flex w-full cursor-pointer items-center justify-between gap-2 border border-surface-border bg-surface px-3 py-2 text-xs text-sidebar-text shadow-sm transition-colors hover:border-sidebar-icon/30 hover:bg-surface-hover"
			onclick={() => (orgDropdownOpen = !orgDropdownOpen)}
		>
			<span class="truncate">{selectedOrg?.name ?? 'Select organization'}</span>
			<ChevronDown
				size={14}
				class="shrink-0 text-sidebar-icon transition-transform {orgDropdownOpen
					? 'rotate-180'
					: ''}"
			/>
		</button>
		{#if orgDropdownOpen}
			<div
				class="absolute right-3 left-3 z-20 mt-1 max-h-56 overflow-y-auto border border-surface-border bg-surface py-1 shadow-xl"
			>
				{#each organizations as org (org.id)}
					<button
						class="flex w-full items-center px-4 py-2.5 text-left text-xs transition-colors hover:bg-surface-hover {org.id ===
						selectedOrgId
							? 'font-medium text-accent'
							: 'text-sidebar-text'}"
						onmousedown={(e) => {
							e.preventDefault();
							selectOrg(org.id);
						}}
					>
						{org.name}
					</button>
				{/each}
			</div>
		{/if}
	</div>

	<!-- Ticket list -->
	<nav class="flex-1 overflow-y-auto overflow-x-hidden">
		<div class="px-4 pt-3 pb-1 text-[10px] font-semibold tracking-widest text-sidebar-label uppercase">
			Tickets
		</div>

		{#if clientPortal.loading}
			<div class="px-5 py-4 text-xs text-muted">Loading...</div>
		{:else if clientPortal.tickets.length === 0}
			<div class="px-5 py-4 text-xs text-muted">No tickets yet</div>
		{:else}
			{#each clientPortal.tickets as ticket (ticket.id)}
				{@const isActive = selectedTicketId === ticket.id}
				<button
					class="group relative flex w-full items-start gap-3 px-5 py-2.5 text-left transition-colors duration-150 {isActive
						? 'bg-sidebar-hover-bg'
						: 'hover:bg-sidebar-hover-bg'}"
					onclick={() => selectTicket(ticket.id)}
				>
					{#if isActive}
						<span class="absolute top-0 left-0 h-full w-[3px] bg-accent"></span>
					{/if}
					<Circle
						size={8}
						class="mt-1 shrink-0 {statusColor[ticket.status] ?? 'text-sidebar-icon'}"
						fill="currentColor"
					/>
					<div class="min-w-0 flex-1">
						<p
							class="truncate text-xs {isActive
								? 'font-semibold text-accent'
								: 'text-sidebar-text'}"
						>
							{ticket.subject}
						</p>
						<p class="mt-0.5 text-[10px] text-muted">
							{ticket.status.replace(/_/g, ' ')}
						</p>
					</div>
				</button>
			{/each}
		{/if}
	</nav>

	<!-- Profile -->
	<div class="border-t border-sidebar-border px-4 py-3">
		<div class="flex items-center gap-3">
			{#if auth.user?.avatar_url}
				<img
					src={auth.user.avatar_url}
					alt={auth.user.full_name}
					class="h-7 w-7 shrink-0 object-cover"
				/>
			{:else}
				<div
					class="flex h-7 w-7 shrink-0 items-center justify-center bg-accent/10 text-xs font-medium text-accent"
				>
					{auth.user?.full_name?.charAt(0)?.toUpperCase() ?? '?'}
				</div>
			{/if}
			<div class="min-w-0 flex-1">
				<p class="truncate text-xs font-medium text-sidebar-text">
					{auth.user?.full_name ?? 'User'}
				</p>
				<p class="truncate text-[10px] text-muted">{auth.user?.email ?? ''}</p>
			</div>
			<button
				class="shrink-0 p-1.5 text-sidebar-icon transition-colors hover:text-sidebar-text"
				aria-label="Log out"
				onclick={async () => {
					await getClient().auth.signOut();
					window.location.href = '/login';
				}}
			>
				<LogOut size={15} />
			</button>
		</div>
	</div>
</aside>
