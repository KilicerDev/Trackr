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
	<div class="flex h-12 items-center gap-2 px-4">
		<img src={logo} alt="Trackr" class="h-7 w-7 shrink-0" />
		<span style="font-family: 'GeistMono', monospace" class="text-xl font-bold tracking-widest text-sidebar-text">TRACKR</span>
	</div>

	<!-- Org dropdown -->
	<div class="px-3 pb-2" data-org-dropdown>
		<button
			class="flex w-full cursor-pointer items-center justify-between gap-2 rounded-sm bg-surface-hover/40 px-2.5 py-1.5 text-base text-sidebar-text transition-all duration-150 hover:bg-surface-hover/60"
			onclick={() => (orgDropdownOpen = !orgDropdownOpen)}
		>
			<span class="truncate">{selectedOrg?.name ?? 'Select organization'}</span>
			<ChevronDown
				size={14}
				class="shrink-0 text-muted/40 transition-transform duration-150 {orgDropdownOpen
					? 'rotate-180'
					: ''}"
			/>
		</button>
		{#if orgDropdownOpen}
			<div
				class="absolute right-3 left-3 z-20 mt-1.5 max-h-56 origin-top-left animate-dropdown-in overflow-y-auto rounded-md border border-surface-border bg-surface py-1 shadow-lg shadow-black/15 ring-1 ring-white/[0.07]"
			>
				{#each organizations as org (org.id)}
					<button
						class="flex w-full items-center px-2.5 py-1.5 text-left text-sm transition-colors hover:bg-surface-hover/60 {org.id ===
						selectedOrgId
							? 'font-medium text-accent'
							: 'text-muted'}"
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
	<nav class="flex-1 overflow-y-auto overflow-x-hidden px-2 py-2">
		<div class="flex h-5 items-center px-3 pt-3 pb-1 text-xs font-medium tracking-[0.08em] text-sidebar-label/70 uppercase">
			Tickets
		</div>

		{#if clientPortal.loading}
			<div class="px-3 py-4 text-sm text-muted/50">Loading...</div>
		{:else if clientPortal.tickets.length === 0}
			<div class="px-3 py-4 text-sm text-muted/50">No tickets yet</div>
		{:else}
			{#each clientPortal.tickets as ticket (ticket.id)}
				{@const isActive = selectedTicketId === ticket.id}
				<button
					class="group relative flex w-full items-center gap-2.5 rounded-sm px-3 py-1.5 text-left transition-all duration-150 {isActive
						? 'bg-accent/10'
						: 'hover:bg-sidebar-hover-bg'}"
					onclick={() => selectTicket(ticket.id)}
				>
					<Circle
						size={7}
						class="shrink-0 {statusColor[ticket.status] ?? 'text-sidebar-icon'}"
						fill="currentColor"
					/>
					<span class="min-w-0 flex-1 truncate text-sm {isActive
						? 'font-medium text-accent'
						: 'text-sidebar-text'}">
						{ticket.subject}
					</span>
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
					class="h-7 w-7 shrink-0 rounded-sm object-cover"
				/>
			{:else}
				<div
					class="flex h-7 w-7 shrink-0 items-center justify-center rounded-sm bg-accent/10 text-sm font-medium text-accent"
				>
					{auth.user?.full_name?.charAt(0)?.toUpperCase() ?? '?'}
				</div>
			{/if}
			<div class="min-w-0 flex-1">
				<p class="truncate text-base font-medium text-sidebar-text">
					{auth.user?.full_name ?? 'User'}
				</p>
				<p class="truncate text-xs text-muted/50">{auth.user?.email ?? ''}</p>
			</div>
			<button
				class="flex h-6 w-6 shrink-0 items-center justify-center rounded-sm text-muted/40 transition-all duration-150 hover:bg-surface-hover hover:text-sidebar-text"
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

<style>
	@keyframes dropdown-in {
		from { opacity: 0; transform: scale(0.95) translateY(-4px); }
		to   { opacity: 1; transform: scale(1) translateY(0); }
	}
	:global(.animate-dropdown-in) {
		animation: dropdown-in 150ms ease-out;
	}
</style>
