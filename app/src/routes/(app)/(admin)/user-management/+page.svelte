<svelte:head><title>Users – Trackr</title></svelte:head>

<script lang="ts">
	import { X, Mail, UserPlus, Shield, Building2, Ban, Trash2 } from '@lucide/svelte';
	import { fly, fade } from 'svelte/transition';
	import { auth } from '$lib/stores/auth.svelte';
	import { notifications } from '$lib/stores/notifications.svelte';
	import { orgStore } from '$lib/stores/organizations.svelte';
	import { api } from '$lib/api';
	import Modal from '$lib/components/Modal.svelte';
	import ConfirmDialog from '$lib/components/ConfirmDialog.svelte';
	import type { UserWithOrg, Invitation } from '$lib/api/users';
	import type { Role } from '$lib/api/roles';
	import type { Organization } from '$lib/api/organizations';

	type Membership = {
		id: string;
		organization_id: string;
		user_id: string;
		role_id: string;
		organization: { id: string; name: string; slug: string } | null;
		role: { id: string; name: string; slug: string } | null;
	};

	// ── Page state ──

	let loading = $state(true);
	let error = $state<string | null>(null);
	let pageTab = $state<'users' | 'invitations' | 'former'>('users');

	let usersList = $state<UserWithOrg[]>([]);
	let invitations = $state<Invitation[]>([]);
	let organizations = $state<Organization[]>([]);
	let systemRoles = $state<Role[]>([]);

	const canInvite = $derived(auth.can('members', 'invite'));
	const canRemoveMember = $derived(auth.can('members', 'remove'));
	const canManageRoles = $derived(auth.can('members', 'manage_roles'));

	// ── Invite modal ──

	let inviteModalOpen = $state(false);
	let inviteEmail = $state('');
	let inviteFullName = $state('');
	let inviteOrgId = $state('');
	let inviteRoleId = $state('');
	let inviteSaving = $state(false);
	let openDropdown = $state<string | null>(null);

	// ── Detail panel ──

	let selectedUser = $state<UserWithOrg | null>(null);
	let panelTab = $state<'profile' | 'organizations'>('profile');

	// Profile edit
	let editFullName = $state('');
	let editUsername = $state('');
	let editActive = $state(true);
	let editTimezone = $state('');
	let editLocale = $state('');
	let editSaving = $state(false);
	let editError = $state<string | null>(null);
	let editSuccess = $state<string | null>(null);

	// Memberships
	let memberships = $state<Membership[]>([]);
	let membershipsLoading = $state(false);

	// Add membership
	let addMembershipOpen = $state(false);
	let addOrgId = $state('');
	let addRoleId = $state('');
	let addSaving = $state(false);

	// Confirm dialog
	let confirmOpen = $state(false);
	let confirmMessage = $state('');
	let confirmAction = $state<(() => void) | null>(null);
	let confirmTitle = $state('Remove Membership');
	let confirmLabel = $state('Remove');

	// Delete user
	let deleteConfirmOpen = $state(false);
	let deleting = $state(false);

	// Former users
	let formerUsers = $state<UserWithOrg[]>([]);
	let formerLoading = $state(false);

	// Reactivation
	let reactivateConfirmOpen = $state(false);
	let reactivateTarget = $state<UserWithOrg | null>(null);
	let reactivateSendReset = $state(true);
	let reactivating = $state(false);

	// ── Shared CSS classes ──

	import { btnPrimary, btnSecondary, labelClass, sectionLabel, inputClass } from '$lib/styles/ui';
	const dropBtnClass =
		'flex w-full cursor-pointer items-center justify-between gap-2 rounded-sm bg-surface-hover/40 px-2.5 py-1.5 text-base text-sidebar-text transition-all duration-150 hover:bg-surface-hover/60';
	const dropPanelClass =
		'absolute left-0 z-30 mt-1.5 max-h-48 w-full overflow-y-auto rounded-md border border-surface-border bg-surface py-1 shadow-lg shadow-black/15 ring-1 ring-white/[0.07] animate-dropdown-in';
	const dropItemBase =
		'flex w-full items-center px-2.5 py-1.5 text-left text-sm transition-all duration-150 hover:bg-surface-hover/60';

	const chevronSvg = `<svg class="h-3.5 w-3.5 shrink-0 text-muted/40" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/></svg>`;

	function toggleDropdown(key: string) {
		openDropdown = openDropdown === key ? null : key;
	}

	$effect(() => {
		if (!openDropdown) return;
		function onMouseDown(e: MouseEvent) {
			const target = e.target as HTMLElement;
			if (!target.closest('[data-dropdown]')) openDropdown = null;
		}
		document.addEventListener('mousedown', onMouseDown);
		return () => document.removeEventListener('mousedown', onMouseDown);
	});

	// ── Data loading ──

	async function loadData() {
		loading = true;
		error = null;
		try {
			const orgId = auth.organizationId ?? '';
			await orgStore.loadIfNeeded();
			const [u, inv, roles] = await Promise.all([
				api.users.getAll(),
				auth.can('members', 'invite')
				? api.users.getInvitations().then((inv) => inv.filter((i) => i.status !== 'accepted'))
				: Promise.resolve([]),
				orgId ? api.roles.getAll(orgId) : api.roles.getAll('')
			]);
			usersList = u;
			invitations = inv;
			organizations = orgStore.all;
			systemRoles = roles;
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to load data';
		} finally {
			loading = false;
		}
	}

	let dataLoaded = $state(false);

	$effect(() => {
		if (dataLoaded) return;
		if (!auth.isAuthenticated) return;
		dataLoaded = true;
		loadData();
	});

	// ── Invite flow ──

	function openInviteModal() {
		inviteEmail = '';
		inviteFullName = '';
		inviteOrgId = organizations[0]?.id ?? '';
		const roles = allowedRoles(inviteOrgId);
		inviteRoleId = roles[0]?.id ?? '';
		openDropdown = null;
		inviteModalOpen = true;
	}

	async function sendInvite() {
		if (!inviteEmail.trim() || !inviteOrgId || !inviteRoleId) return;
		inviteSaving = true;
		const n = notifications.action('Sending invitation');
		try {
			await api.users.invite({
				email: inviteEmail.trim(),
				full_name: inviteFullName.trim() || undefined,
				organization_id: inviteOrgId,
				role_id: inviteRoleId
			});
			n.success('Invitation sent');
			inviteModalOpen = false;
			const [u, inv] = await Promise.all([
				api.users.getAll(),
				api.users.getInvitations().then((all) => all.filter((i) => i.status !== 'accepted'))
			]);
			usersList = u;
			invitations = inv;
		} catch (err) {
			n.error('Failed to invite', err instanceof Error ? err.message : 'Unknown error');
		} finally {
			inviteSaving = false;
		}
	}

	async function revokeInvitation(inv: Invitation) {
		const n = notifications.action('Revoking invitation');
		try {
			await api.users.revokeInvitation(inv.id);
			n.success('Invitation revoked');
			invitations = (await api.users.getInvitations()).filter((i) => i.status !== 'accepted');
		} catch (err) {
			n.error('Failed to revoke', err instanceof Error ? err.message : 'Unknown error');
		}
	}

	// ── Detail panel ──

	function openPanel(user: UserWithOrg) {
		selectedUser = user;
		panelTab = 'profile';
		openDropdown = null;
		editError = null;
		editSuccess = null;
		applyUserFields(user);
		loadMemberships(user.id);
	}

	function closePanel() {
		selectedUser = null;
		openDropdown = null;
	}

	function applyUserFields(user: UserWithOrg) {
		editFullName = user.full_name;
		editUsername = user.username;
		editActive = user.is_active;
		editTimezone = user.timezone;
		editLocale = user.locale;
	}

	async function saveProfile() {
		if (!selectedUser || !editFullName.trim() || !editUsername.trim()) return;
		editSaving = true;
		editError = null;
		editSuccess = null;
		try {
			const updated = await api.users.update(selectedUser.id, {
				full_name: editFullName.trim(),
				username: editUsername.trim(),
				is_active: editActive,
				timezone: editTimezone.trim(),
				locale: editLocale.trim()
			});
			usersList = await api.users.getAll();
			selectedUser = usersList.find((u) => u.id === updated.id) ?? updated;
			editSuccess = 'Profile updated.';
		} catch (e) {
			editError = e instanceof Error ? e.message : 'Failed to update profile';
		} finally {
			editSaving = false;
		}
	}

	// ── Memberships ──

	async function loadMemberships(userId: string) {
		membershipsLoading = true;
		try {
			memberships = await api.users.getMemberships(userId);
		} catch {
			memberships = [];
		} finally {
			membershipsLoading = false;
		}
	}

	function openAddMembership() {
		const existingOrgIds = new Set(memberships.map((m) => m.organization_id));
		const available = organizations.filter((o) => !existingOrgIds.has(o.id));
		addOrgId = available[0]?.id ?? '';
		const roles = allowedRoles(addOrgId);
		addRoleId = roles[0]?.id ?? '';
		addMembershipOpen = true;
	}

	async function addMembership() {
		if (!selectedUser || !addOrgId || !addRoleId) return;
		addSaving = true;
		const n = notifications.action('Adding membership');
		try {
			await api.users.addMembership(addOrgId, selectedUser.id, addRoleId);
			n.success('Membership added');
			addMembershipOpen = false;
			await loadMemberships(selectedUser.id);
		} catch (err) {
			n.error('Failed', err instanceof Error ? err.message : 'Unknown error');
		} finally {
			addSaving = false;
		}
	}

	function confirmRemoveMembership(m: Membership) {
		confirmMessage = `Remove ${selectedUser?.full_name || 'this user'} from ${m.organization?.name || 'this organization'}?`;
		confirmAction = async () => {
			if (!selectedUser) return;
			const n = notifications.action('Removing membership');
			try {
				await api.users.removeMembership(m.organization_id, selectedUser.id);
				n.success('Membership removed');
				await loadMemberships(selectedUser.id);
			} catch (err) {
				n.error('Failed', err instanceof Error ? err.message : 'Unknown error');
			}
		};
		confirmOpen = true;
	}

	async function updateMemberRole(m: Membership, newRoleId: string) {
		if (!selectedUser) return;
		const n = notifications.action('Updating role');
		try {
			await api.users.updateMembershipRole(m.organization_id, selectedUser.id, newRoleId);
			n.success('Role updated');
			await loadMemberships(selectedUser.id);
		} catch (err) {
			n.error('Failed', err instanceof Error ? err.message : 'Unknown error');
		}
		openDropdown = null;
	}

	// ── Delete user ──

	function confirmDeleteUser() {
		if (!selectedUser || selectedUser.id === auth.user?.id) return;
		deleteConfirmOpen = true;
	}

	async function deleteUser() {
		if (!selectedUser) return;
		deleting = true;
		const n = notifications.action('Deleting user');
		try {
			await api.users.remove(selectedUser.id);
			n.success('User deleted');
			deleteConfirmOpen = false;
			closePanel();
			const [active, former] = await Promise.all([
				api.users.getAll(),
				api.users.getDeleted()
			]);
			usersList = active;
			formerUsers = former;
		} catch (err) {
			n.error('Failed to delete', err instanceof Error ? err.message : 'Unknown error');
		} finally {
			deleting = false;
		}
	}

	// ── Former users ──

	async function loadFormerUsers() {
		formerLoading = true;
		try {
			formerUsers = await api.users.getDeleted();
		} catch {
			formerUsers = [];
		} finally {
			formerLoading = false;
		}
	}

	$effect(() => {
		if (pageTab === 'former') {
			loadFormerUsers();
		}
	});

	function openReactivateConfirm(user: UserWithOrg) {
		reactivateTarget = user;
		reactivateSendReset = true;
		reactivateConfirmOpen = true;
	}

	async function reactivateUser() {
		if (!reactivateTarget) return;
		reactivating = true;
		const n = notifications.action('Reactivating user');
		try {
			await api.users.reactivate(reactivateTarget.id, reactivateSendReset);
			n.success('User reactivated');
			reactivateConfirmOpen = false;
			reactivateTarget = null;
			const [active, former] = await Promise.all([
				api.users.getAll(),
				api.users.getDeleted()
			]);
			usersList = active;
			formerUsers = former;
		} catch (err) {
			n.error('Failed to reactivate', err instanceof Error ? err.message : 'Unknown error');
		} finally {
			reactivating = false;
		}
	}

	// ── Keyboard ──

	$effect(() => {
		if (!selectedUser) return;
		function handleKeydown(e: KeyboardEvent) {
			if (e.key === 'Escape') {
				if (openDropdown) openDropdown = null;
				else closePanel();
			}
		}
		document.addEventListener('keydown', handleKeydown);
		return () => document.removeEventListener('keydown', handleKeydown);
	});

	// ── Helpers ──

	function roleName(roleId: string): string {
		return systemRoles.find((r) => r.id === roleId)?.name ?? 'Unknown';
	}

	function orgName(orgId: string): string {
		return organizations.find((o) => o.id === orgId)?.name ?? 'Unknown';
	}

	function formatDate(date: string | null): string {
		if (!date) return '—';
		return new Date(date).toLocaleDateString('de-DE', { day: '2-digit', month: '2-digit', year: 'numeric' });
	}

	function formatRelative(date: string | null): string {
		if (!date) return 'Never';
		const diff = Date.now() - new Date(date).getTime();
		const mins = Math.floor(diff / 60000);
		if (mins < 1) return 'Just now';
		if (mins < 60) return `${mins}m ago`;
		const hours = Math.floor(mins / 60);
		if (hours < 24) return `${hours}h ago`;
		const days = Math.floor(hours / 24);
		return `${days}d ago`;
	}

	function statusBadgeClass(status: string): string {
		switch (status) {
			case 'pending': return 'text-yellow-500';
			case 'accepted': return 'text-green-400';
			case 'expired': return 'text-muted/50';
			case 'revoked': return 'text-red-400';
			default: return 'text-muted/50';
		}
	}

	const availableOrgsForMembership = $derived(
		organizations.filter((o) => !memberships.some((m) => m.organization_id === o.id))
	);

	const platformOrgId = $derived(orgStore.platformOrgId);

	function allowedRoles(orgId: string): Role[] {
		if (orgId === platformOrgId) {
			return systemRoles.filter((r) => ['admin', 'manager', 'agent'].includes(r.slug));
		}
		return systemRoles.filter((r) => ['client', 'manager', 'agent'].includes(r.slug));
	}

	const checkSvg = `<svg class="h-3 w-3 text-white" fill="none" stroke="currentColor" stroke-width="3" viewBox="0 0 24 24"><path stroke-linecap="square" stroke-linejoin="miter" d="M5 13l4 4L19 7"/></svg>`;
</script>

{#snippet toggle(checked: boolean, onToggle: () => void, label: string)}
	<button type="button" class="flex items-center gap-3" onclick={onToggle}>
		<span class="flex h-3 w-3 shrink-0 items-center justify-center rounded-sm border transition-all duration-150
			{checked ? 'border-accent bg-accent' : 'border-surface-border/60'}">
			{#if checked}{@html checkSvg}{/if}
		</span>
		<span class="text-base text-sidebar-text">{label}</span>
	</button>
{/snippet}

<div class="mx-auto w-full">
	<!-- Header -->
	<div class="flex items-center justify-between px-3 py-1.5">
		<div class="flex items-center gap-4">
			<h1 class="text-md font-semibold text-sidebar-text">User Management</h1>
			<div class="flex">
				<button
					class="px-2.5 py-1.5 text-sm font-medium transition-all duration-150 {pageTab === 'users'
						? 'border-b-2 border-accent text-accent'
						: 'text-muted hover:text-sidebar-text'}"
					onclick={() => (pageTab = 'users')}
				>
					Users
				</button>
				{#if canInvite}
					<button
						class="px-2.5 py-1.5 text-sm font-medium transition-all duration-150 {pageTab === 'invitations'
							? 'border-b-2 border-accent text-accent'
							: 'text-muted hover:text-sidebar-text'}"
						onclick={() => (pageTab = 'invitations')}
					>
						Invitations
					</button>
				{/if}
				{#if canRemoveMember}
					<button
						class="px-2.5 py-1.5 text-sm font-medium transition-all duration-150 {pageTab === 'former'
							? 'border-b-2 border-accent text-accent'
							: 'text-muted hover:text-sidebar-text'}"
						onclick={() => (pageTab = 'former')}
					>
						Former Users
					</button>
				{/if}
			</div>
		</div>
		{#if canInvite}
			<button class={btnPrimary} onclick={openInviteModal}>
				<UserPlus size={14} class="shrink-0" />
				Invite User
			</button>
		{/if}
	</div>

	{#if loading}
		<p class="px-3 py-8 text-center text-sm text-muted">Loading...</p>
	{:else if error}
		<p class="px-3 py-8 text-center text-sm text-red-400">{error}</p>
	{:else if pageTab === 'users'}
		<!-- Users Table -->
		{#if usersList.length === 0}
			<p class="px-3 py-8 text-center text-sm text-muted">No users yet.</p>
		{:else}
			<div class="mx-3 mb-2 overflow-x-auto rounded border border-surface-border/40 bg-surface/50">
				<table class="w-full text-sm">
					<thead>
						<tr class="border-b border-surface-border/30 text-left text-xs font-medium uppercase tracking-[0.08em] text-muted">
							<th class="px-3 py-2">Name</th>
							<th class="px-3 py-2">Email</th>
							<th class="px-3 py-2">Organization</th>
							<th class="px-3 py-2">Status</th>
							<th class="px-3 py-2">Last Seen</th>
						</tr>
					</thead>
					<tbody>
						{#each usersList as user (user.id)}
							<tr
								class="cursor-pointer border-b border-surface-border/30 transition-all duration-150 hover:bg-surface-hover/60 {selectedUser?.id === user.id ? 'bg-surface-hover/60' : ''}"
								onclick={() => openPanel(user)}
							>
								<td class="px-3 py-2">
									<div class="flex items-center gap-2">
										{#if user.avatar_url}
											<img src={user.avatar_url} alt="" class="h-5 w-5 rounded-full object-cover" />
										{:else}
											<div class="flex h-5 w-5 items-center justify-center rounded-full bg-accent/10 text-2xs font-medium text-accent">
												{user.full_name.charAt(0).toUpperCase()}
											</div>
										{/if}
										<div>
											<span class="font-medium text-sidebar-text">{user.full_name}</span>
											<span class="ml-1 text-muted/50">@{user.username}</span>
										</div>
									</div>
								</td>
								<td class="px-3 py-2 text-muted">{user.email}</td>
								<td class="px-3 py-2">
									{#if user.organization}
										<span class="text-xs font-medium text-accent">
											{user.organization.name}
											{#if user.organization.id === platformOrgId}
												<span class="ml-1 shrink-0 whitespace-nowrap rounded-sm bg-accent/10 px-1 py-px text-3xs font-semibold uppercase tracking-wide">Internal</span>
											{/if}
										</span>
									{:else}
										<span class="text-muted/50">—</span>
									{/if}
								</td>
								<td class="px-3 py-2">
									<span class="text-xs font-medium {user.is_active ? 'text-green-400' : 'text-muted/50'}">
										{user.is_active ? 'Active' : 'Inactive'}
									</span>
								</td>
								<td class="px-3 py-2 font-mono text-muted">{formatRelative(user.last_seen_at)}</td>
							</tr>
						{/each}
					</tbody>
				</table>
			</div>
		{/if}
	{:else if pageTab === 'invitations'}
		<!-- Invitations Table -->
		{#if invitations.length === 0}
			<p class="px-3 py-8 text-center text-sm text-muted">No invitations yet.</p>
		{:else}
			<div class="mx-3 mb-2 overflow-x-auto rounded border border-surface-border/40 bg-surface/50">
				<table class="w-full text-sm">
					<thead>
						<tr class="border-b border-surface-border/30 text-left text-xs font-medium uppercase tracking-[0.08em] text-muted">
							<th class="px-3 py-2">Email</th>
							<th class="px-3 py-2">Organization</th>
							<th class="px-3 py-2">Role</th>
							<th class="px-3 py-2">Status</th>
							<th class="px-3 py-2">Invited</th>
							<th class="px-3 py-2">Expires</th>
							<th class="px-3 py-2"></th>
						</tr>
					</thead>
					<tbody>
						{#each invitations as inv (inv.id)}
							<tr class="border-b border-surface-border/30 transition-all duration-150 hover:bg-surface-hover/60">
								<td class="px-3 py-2">
									<div class="flex items-center gap-1.5">
										<Mail size={12} class="text-muted/40" />
										<span class="font-medium text-sidebar-text">{inv.email}</span>
									</div>
								</td>
								<td class="px-3 py-2">
									{#if inv.organization}
										<span class="text-xs font-medium text-accent">
											{inv.organization.name}
											{#if inv.organization_id === platformOrgId}
												<span class="ml-1 shrink-0 whitespace-nowrap rounded-sm bg-accent/10 px-1 py-px text-3xs font-semibold uppercase tracking-wide">Internal</span>
											{/if}
										</span>
									{:else}
										<span class="text-muted/50">—</span>
									{/if}
								</td>
								<td class="px-3 py-2 text-muted">{inv.role?.name ?? '—'}</td>
								<td class="px-3 py-2">
									<span class="text-xs font-medium {statusBadgeClass(inv.status)}">
										{inv.status}
									</span>
								</td>
								<td class="px-3 py-2 font-mono text-muted">{formatDate(inv.created_at)}</td>
								<td class="px-3 py-2 font-mono text-muted">{formatDate(inv.expires_at)}</td>
								<td class="px-3 py-2">
									{#if inv.status === 'pending'}
										<button
											class="text-xs font-medium text-muted/50 transition-all duration-150 hover:text-red-400"
											onclick={() => revokeInvitation(inv)}
										>
											Revoke
										</button>
									{/if}
								</td>
							</tr>
						{/each}
					</tbody>
				</table>
			</div>
		{/if}
	{:else if pageTab === 'former'}
		<!-- Former Users Table -->
		{#if formerLoading}
			<p class="px-3 py-8 text-center text-sm text-muted">Loading...</p>
		{:else if formerUsers.length === 0}
			<p class="px-3 py-8 text-center text-sm text-muted">No former users.</p>
		{:else}
			<div class="mx-3 mb-2 overflow-x-auto rounded border border-surface-border/40 bg-surface/50">
				<table class="w-full text-sm">
					<thead>
						<tr class="border-b border-surface-border/30 text-left text-xs font-medium uppercase tracking-[0.08em] text-muted">
							<th class="px-3 py-2">Name</th>
							<th class="px-3 py-2">Email</th>
							<th class="px-3 py-2">Organization</th>
							<th class="px-3 py-2">Deleted</th>
							<th class="px-3 py-2"></th>
						</tr>
					</thead>
					<tbody>
						{#each formerUsers as user (user.id)}
							<tr class="border-b border-surface-border/30 transition-all duration-150 hover:bg-surface-hover/60">
								<td class="px-3 py-2">
									<div class="flex items-center gap-2">
										{#if user.avatar_url}
											<img src={user.avatar_url} alt="" class="h-5 w-5 rounded-full object-cover" />
										{:else}
											<div class="flex h-5 w-5 items-center justify-center rounded-full bg-muted/10 text-2xs font-medium text-muted">
												{user.full_name.charAt(0).toUpperCase()}
											</div>
										{/if}
										<div>
											<span class="font-medium text-sidebar-text">{user.full_name}</span>
											<span class="ml-1 text-muted/50">@{user.username}</span>
										</div>
									</div>
								</td>
								<td class="px-3 py-2 text-muted">{user.email}</td>
								<td class="px-3 py-2">
									{#if user.organization}
										<span class="text-xs font-medium text-muted">
											{user.organization.name}
										</span>
									{:else}
										<span class="text-muted/50">—</span>
									{/if}
								</td>
								<td class="px-3 py-2 font-mono text-muted">{formatDate(user.deleted_at)}</td>
								<td class="px-3 py-2">
									<button
										class="text-sm font-medium text-muted/50 transition-all duration-150 hover:text-accent"
										onclick={() => openReactivateConfirm(user)}
									>
										Reactivate
									</button>
								</td>
							</tr>
						{/each}
					</tbody>
				</table>
			</div>
		{/if}
	{/if}
</div>

<!-- User Detail Panel -->
{#if selectedUser}
	<div class="fixed inset-0 z-[60]" role="presentation">
		<button
			transition:fade={{ duration: 150 }}
			class="absolute inset-0 bg-black/30"
			onclick={closePanel}
			tabindex="-1"
			aria-label="Close panel"
		></button>

		<div
			transition:fly={{ x: 420, duration: 200 }}
			class="absolute top-0 right-0 bottom-0 flex w-[420px] flex-col border-l border-surface-border bg-surface shadow-xl"
			role="dialog"
			aria-modal="true"
		>
			<!-- Header -->
			<div class="flex shrink-0 items-center justify-between border-b border-surface-border px-3 py-2.5">
				<div class="flex items-center gap-2.5 min-w-0 flex-1">
					{#if selectedUser.avatar_url}
						<img src={selectedUser.avatar_url} alt="" class="h-7 w-7 rounded-full object-cover" />
					{:else}
						<div class="flex h-7 w-7 items-center justify-center rounded-full bg-accent/10 text-xs font-medium text-accent">
							{selectedUser.full_name.charAt(0).toUpperCase()}
						</div>
					{/if}
					<div class="min-w-0">
						<h2 class="truncate text-lg font-semibold text-sidebar-text">{selectedUser.full_name}</h2>
						<p class="truncate text-sm text-muted">{selectedUser.email}</p>
					</div>
				</div>
				<div class="ml-3 flex items-center gap-1">
					{#if canRemoveMember && selectedUser.id !== auth.user?.id}
						<button
							class="flex h-6 w-6 shrink-0 items-center justify-center rounded-sm text-muted/40 transition-all duration-150 hover:bg-surface-hover hover:text-red-400"
							onclick={confirmDeleteUser}
							aria-label="Delete user"
						>
							<Trash2 size={14} />
						</button>
					{/if}
					<button
						class="flex h-6 w-6 shrink-0 items-center justify-center rounded-sm text-muted/40 transition-all duration-150 hover:bg-surface-hover hover:text-sidebar-text"
						onclick={closePanel}
						aria-label="Close"
					>
						<X size={14} />
					</button>
				</div>
			</div>

			<!-- Tabs -->
			<div class="flex shrink-0 border-b border-surface-border">
				<button
					class="px-3 py-2 text-sm font-medium transition-all duration-150 {panelTab === 'profile'
						? 'border-b-2 border-accent text-accent'
						: 'text-muted hover:text-sidebar-text'}"
					onclick={() => { panelTab = 'profile'; openDropdown = null; editError = null; editSuccess = null; }}
				>
					Profile
				</button>
				<button
					class="px-3 py-2 text-sm font-medium transition-all duration-150 {panelTab === 'organizations'
						? 'border-b-2 border-accent text-accent'
						: 'text-muted hover:text-sidebar-text'}"
					onclick={() => { panelTab = 'organizations'; openDropdown = null; }}
				>
					Organizations
				</button>
			</div>

			<!-- Scrollable content -->
			<div class="flex-1 overflow-y-auto">
				{#if panelTab === 'profile'}
					<form onsubmit={(e) => { e.preventDefault(); saveProfile(); }} class="p-3">
						<!-- Properties -->
						<div class="mb-2 rounded border border-surface-border/40 bg-surface/50 px-3 py-2.5">
							<span class="{sectionLabel} mb-3 block">Properties</span>
							<div class="space-y-3">
								<div class="grid grid-cols-2 gap-3">
									<div>
										<label for="edit-fullname" class={labelClass}>Full Name</label>
										<input id="edit-fullname" type="text" required bind:value={editFullName} class={inputClass} />
									</div>
									<div>
										<label for="edit-username" class={labelClass}>Username</label>
										<input id="edit-username" type="text" required bind:value={editUsername} class={inputClass} />
									</div>
								</div>
								<div class="grid grid-cols-2 gap-3">
									<div>
										<label for="edit-timezone" class={labelClass}>Timezone</label>
										<input id="edit-timezone" type="text" bind:value={editTimezone} class={inputClass} placeholder="UTC" />
									</div>
									<div>
										<label for="edit-locale" class={labelClass}>Locale</label>
										<input id="edit-locale" type="text" bind:value={editLocale} class={inputClass} placeholder="en" />
									</div>
								</div>
							</div>
						</div>

						<!-- Status -->
						<div class="mb-2 rounded border border-surface-border/40 bg-surface/50 px-3 py-2.5">
							<span class="{sectionLabel} mb-3 block">Status</span>
							{@render toggle(editActive, () => { editActive = !editActive; }, 'Active')}
						</div>

						<!-- Info (read-only) -->
						<div class="mb-2 rounded border border-surface-border/40 bg-surface/50 px-3 py-2.5">
							<span class="{sectionLabel} mb-2 block">Info</span>
							<div class="grid grid-cols-2 gap-x-3 gap-y-1.5 text-sm">
								<div>
									<span class="text-muted/50">Email</span>
									<p class="text-sidebar-text">{selectedUser.email}</p>
								</div>
								<div>
									<span class="text-muted/50">Origin Org</span>
									<p class="text-sidebar-text">{selectedUser.organization?.name ?? '—'}</p>
								</div>
								<div>
									<span class="text-muted/50">Created</span>
									<p class="font-mono text-sidebar-text">{formatDate(selectedUser.created_at)}</p>
								</div>
								<div>
									<span class="text-muted/50">Last Seen</span>
									<p class="font-mono text-sidebar-text">{formatRelative(selectedUser.last_seen_at)}</p>
								</div>
							</div>
						</div>

						{#if editError}
							<p class="pt-2 text-sm text-red-400">{editError}</p>
						{/if}
						{#if editSuccess}
							<p class="pt-2 text-sm text-green-400">{editSuccess}</p>
						{/if}

						{#if canManageRoles || selectedUser.id === auth.user?.id}
							<div class="flex justify-end pt-2">
								<button type="submit" disabled={editSaving || !editFullName.trim() || !editUsername.trim()} class={btnPrimary}>
									{editSaving ? 'Saving...' : 'Save changes'}
								</button>
							</div>
						{/if}
					</form>
				{/if}

				{#if panelTab === 'organizations'}
					<div class="p-3">
						<div class="mb-2 rounded border border-surface-border/40 bg-surface/50 px-3 py-2.5">
							<div class="mb-2.5 flex items-center justify-between">
								<span class="{sectionLabel}">Memberships</span>
								{#if canInvite && availableOrgsForMembership.length > 0}
									<button class="text-sm text-muted/50 transition-all duration-150 hover:text-accent" onclick={openAddMembership}>
										+ Add
									</button>
								{/if}
							</div>

						{#if membershipsLoading}
							<p class="py-3 text-sm text-muted">Loading...</p>
						{:else if memberships.length === 0}
							<p class="py-3 text-sm text-muted">No memberships.</p>
						{:else}
							<div class="divide-y divide-surface-border/30">
								{#each memberships as m (m.id)}
									<div class="flex items-center justify-between py-2.5">
										<div class="flex items-center gap-2.5 min-w-0">
											<Building2 size={14} class="shrink-0 text-muted/40" />
											<div class="min-w-0">
												<p class="flex items-center gap-1.5 text-base font-medium text-sidebar-text">
													<span class="truncate">{m.organization?.name ?? 'Unknown'}</span>
													{#if m.organization_id === platformOrgId}
														<span class="shrink-0 whitespace-nowrap rounded-sm bg-accent/10 px-1.5 py-0.5 text-2xs font-semibold uppercase tracking-wide text-accent">Internal</span>
													{/if}
												</p>
												<div class="flex items-center gap-1.5 mt-0.5">
													<Shield size={10} class="text-muted/40" />
													<!-- Role dropdown -->
													{#if canManageRoles && selectedUser && m.user_id !== auth.user?.id}
														<div class="relative" data-dropdown>
															<button
																class="flex items-center gap-1 text-sm text-muted transition-all duration-150 hover:text-accent"
																onclick={() => toggleDropdown(`role-${m.id}`)}
															>
															{m.role?.name ?? 'Unknown'} {@html chevronSvg}
															</button>
															{#if openDropdown === `role-${m.id}`}
																<div class="absolute left-0 z-30 mt-1.5 min-w-[140px] rounded-md border border-surface-border bg-surface py-1 shadow-lg shadow-black/15 ring-1 ring-white/[0.07] animate-dropdown-in">
																	{#each allowedRoles(m.organization_id) as r (r.id)}
																		<button
																			class="{dropItemBase} {m.role_id === r.id ? 'font-medium text-accent' : 'text-muted'}"
																			onmousedown={(e) => { e.preventDefault(); updateMemberRole(m, r.id); }}
																		>
																			{r.name}
																		</button>
																	{/each}
																</div>
															{/if}
														</div>
													{:else}
														<span class="text-sm text-muted">{m.role?.name ?? 'Unknown'}</span>
													{/if}
												</div>
											</div>
										</div>
									{#if canRemoveMember && selectedUser && m.user_id !== auth.user?.id}
										<button
											class="flex h-6 w-6 shrink-0 items-center justify-center rounded-sm text-muted/40 transition-all duration-150 hover:bg-surface-hover hover:text-red-400"
											onclick={() => confirmRemoveMembership(m)}
											aria-label="Remove membership"
										>
											<Ban size={12} />
										</button>
									{/if}
									</div>
								{/each}
							</div>
						{/if}
						</div>

						<!-- Add membership inline form -->
						{#if addMembershipOpen}
							<div class="mb-2 rounded border border-surface-border/40 bg-surface/50 px-3 py-2.5 space-y-3">
								<span class="{sectionLabel} block">Add to Organization</span>
								<div>
									<span class={labelClass}>Organization</span>
									<div class="relative" data-dropdown>
										<button type="button" class={dropBtnClass} onclick={() => toggleDropdown('add-org')}>
											<span class="truncate">{orgName(addOrgId)}</span>
											{@html chevronSvg}
										</button>
										{#if openDropdown === 'add-org'}
											<div class={dropPanelClass}>
												{#each availableOrgsForMembership as org (org.id)}
													<button
														class="{dropItemBase} {addOrgId === org.id ? 'font-medium text-accent' : 'text-muted'}"
														onmousedown={(e) => { e.preventDefault(); addOrgId = org.id; addRoleId = allowedRoles(org.id)[0]?.id ?? ''; openDropdown = null; }}
													>
														<span class="truncate">{org.name}</span>
														{#if org.id === platformOrgId}
															<span class="shrink-0 whitespace-nowrap rounded-sm bg-accent/10 px-1.5 py-0.5 text-2xs font-semibold uppercase tracking-wide text-accent">Internal</span>
														{/if}
													</button>
												{/each}
											</div>
										{/if}
									</div>
								</div>
								<div>
									<span class={labelClass}>Role</span>
									<div class="relative" data-dropdown>
										<button type="button" class={dropBtnClass} onclick={() => toggleDropdown('add-role')}>
											<span class="truncate">{roleName(addRoleId)}</span>
											{@html chevronSvg}
										</button>
										{#if openDropdown === 'add-role'}
											<div class={dropPanelClass}>
												{#each allowedRoles(addOrgId) as r (r.id)}
													<button
														class="{dropItemBase} {addRoleId === r.id ? 'font-medium text-accent' : 'text-muted'}"
														onmousedown={(e) => { e.preventDefault(); addRoleId = r.id; openDropdown = null; }}
													>
														{r.name}
													</button>
												{/each}
											</div>
										{/if}
									</div>
								</div>
								<div class="flex gap-2 justify-end">
									<button class={btnSecondary} onclick={() => (addMembershipOpen = false)}>Cancel</button>
									<button class={btnPrimary} disabled={addSaving || !addOrgId || !addRoleId} onclick={addMembership}>
										{addSaving ? 'Adding...' : 'Add'}
									</button>
								</div>
							</div>
						{/if}
					</div>
				{/if}
			</div>
		</div>
	</div>
{/if}

<!-- Invite User Modal -->
{#if inviteModalOpen}
	<Modal open={true} onClose={() => (inviteModalOpen = false)}>
		<div>
			<div class="border-b border-surface-border/40 px-3 py-2.5">
				<h2 class="text-md font-semibold text-sidebar-text">Invite User</h2>
			</div>
			<form onsubmit={(e) => { e.preventDefault(); sendInvite(); }} class="space-y-3 p-3">
				<div>
					<label for="invite-email" class={labelClass}>Email</label>
					<input id="invite-email" type="email" required bind:value={inviteEmail}
						class={inputClass} placeholder="user@example.com" />
				</div>

				<div>
					<label for="invite-name" class={labelClass}>Full Name (optional)</label>
					<input id="invite-name" type="text" bind:value={inviteFullName}
						class={inputClass} placeholder="John Doe" />
				</div>

				<!-- Organization dropdown -->
				<div>
					<span class={labelClass}>Organization</span>
					<div class="relative" data-dropdown>
					<button type="button" class={dropBtnClass} onclick={() => toggleDropdown('invite-org')}>
						<span class="truncate">{orgName(inviteOrgId)}</span>
						{@html chevronSvg}
						</button>
						{#if openDropdown === 'invite-org'}
							<div class={dropPanelClass}>
								{#each organizations as org (org.id)}
									<button
										class="{dropItemBase} {inviteOrgId === org.id ? 'font-medium text-accent' : 'text-muted'}"
									onmousedown={(e) => { e.preventDefault(); inviteOrgId = org.id; inviteRoleId = allowedRoles(org.id)[0]?.id ?? ''; openDropdown = null; }}
								>
									<span class="truncate">{org.name}</span>
									{#if org.id === platformOrgId}
										<span class="shrink-0 whitespace-nowrap rounded-sm bg-accent/10 px-1.5 py-0.5 text-2xs font-semibold uppercase tracking-wide text-accent">Internal</span>
									{/if}
									</button>
								{/each}
							</div>
						{/if}
					</div>
				</div>

				<!-- Role dropdown -->
				<div>
					<span class={labelClass}>Role</span>
					<div class="relative" data-dropdown>
					<button type="button" class={dropBtnClass} onclick={() => toggleDropdown('invite-role')}>
						<span class="truncate">{roleName(inviteRoleId)}</span>
						{@html chevronSvg}
						</button>
						{#if openDropdown === 'invite-role'}
							<div class={dropPanelClass}>
								{#each allowedRoles(inviteOrgId) as r (r.id)}
									<button
										class="{dropItemBase} {inviteRoleId === r.id ? 'font-medium text-accent' : 'text-muted'}"
										onmousedown={(e) => { e.preventDefault(); inviteRoleId = r.id; openDropdown = null; }}
									>
										{r.name}
									</button>
								{/each}
							</div>
						{/if}
					</div>
				</div>

				<div class="flex justify-end gap-2 border-t border-surface-border/40 pt-3">
					<button type="button" class={btnSecondary} onclick={() => (inviteModalOpen = false)}>
						Cancel
					</button>
					<button type="submit" disabled={inviteSaving || !inviteEmail.trim() || !inviteOrgId || !inviteRoleId} class={btnPrimary}>
						{inviteSaving ? 'Sending...' : 'Send Invitation'}
					</button>
				</div>
			</form>
		</div>
	</Modal>
{/if}

<!-- Confirm Dialog (membership removal) -->
<ConfirmDialog
	open={confirmOpen}
	title="Remove Membership"
	message={confirmMessage}
	confirmLabel="Remove"
	destructive
	onConfirm={() => { confirmAction?.(); confirmOpen = false; }}
	onCancel={() => (confirmOpen = false)}
/>

<!-- Delete User Confirm Dialog -->
<ConfirmDialog
	open={deleteConfirmOpen}
	title="Delete User"
	message="This will deactivate {selectedUser?.full_name || 'this user'} and revoke their access. The user can be restored later."
	confirmLabel="Delete"
	loading={deleting}
	destructive
	onConfirm={deleteUser}
	onCancel={() => (deleteConfirmOpen = false)}
/>

<!-- Reactivate User Modal -->
{#if reactivateConfirmOpen && reactivateTarget}
	<Modal open={true} onClose={() => (reactivateConfirmOpen = false)} maxWidth="max-w-sm">
		<div class="border-b border-surface-border/40 px-3 py-2.5">
			<h2 class="text-md font-semibold text-sidebar-text">Reactivate User</h2>
		</div>
		<div class="px-3 py-3 space-y-3">
			<p class="text-base leading-relaxed text-sidebar-text/80">
				Reactivate <strong>{reactivateTarget.full_name}</strong>? They will regain access with their existing organization and memberships.
			</p>
			{@render toggle(reactivateSendReset, () => { reactivateSendReset = !reactivateSendReset; }, 'Send password reset email')}
		</div>
		<div class="flex justify-end gap-2 border-t border-surface-border/40 px-3 py-2.5">
			<button class={btnSecondary} disabled={reactivating} onclick={() => (reactivateConfirmOpen = false)}>Cancel</button>
			<button class={btnPrimary} disabled={reactivating} onclick={reactivateUser}>
				{reactivating ? 'Reactivating...' : 'Reactivate'}
			</button>
		</div>
	</Modal>
{/if}
