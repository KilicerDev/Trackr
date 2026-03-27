<svelte:head><title>Roles – Trackr</title></svelte:head>

<script lang="ts">
	import { X } from '@lucide/svelte';
	import { fly, fade } from 'svelte/transition';
	import { auth } from '$lib/stores/auth.svelte';
	import { api } from '$lib/api';
	import Modal from '$lib/components/Modal.svelte';
	import ConfirmDialog from '$lib/components/ConfirmDialog.svelte';
	import { SvelteMap } from 'svelte/reactivity';
	import type { Role, Permission, PermissionEntry } from '$lib/api/roles';

	let loaded = $state(false);
	let loading = $state(true);
	let error = $state<string | null>(null);

	let roles = $state<Role[]>([]);
	let allPermissions = $state<Permission[]>([]);

	// Create modal
	let createModalOpen = $state(false);
	let createName = $state('');
	let createSlug = $state('');
	let createDescription = $state('');
	let createSaving = $state(false);
	let createError = $state<string | null>(null);

	// Detail panel
	let selectedRole = $state<Role | null>(null);
	let panelTab = $state<'details' | 'permissions'>('details');

	// Editable role fields
	let editName = $state('');
	let editSlug = $state('');
	let editDescription = $state('');
	let editSaving = $state(false);
	let editError = $state<string | null>(null);
	let editSuccess = $state<string | null>(null);

	// Permission editing
	// eslint-disable-next-line svelte/no-unnecessary-state-wrap -- variable is reassigned, not just mutated
	let editPermissions = $state(new SvelteMap<string, 'own' | 'all'>());
	let permsSaving = $state(false);
	let permsError = $state<string | null>(null);
	let permsSuccess = $state<string | null>(null);

	// Delete
	let deleteDialogOpen = $state(false);
	let deleteTarget = $state<Role | null>(null);
	let deleting = $state(false);

	const canManage = $derived(auth.can('members', 'manage_roles'));

	const labelClass = 'mb-1.5 block text-xs font-medium uppercase tracking-[0.08em] text-muted';
	const sectionLabel = 'text-xs font-medium uppercase tracking-[0.08em] text-muted';
	const inputClass =
		'w-full rounded-sm bg-surface-hover/40 px-2.5 py-1.5 text-base text-sidebar-text outline-none transition-all duration-150 placeholder:text-muted/30 focus:bg-surface-hover/60';
	const btnSecondary =
		'flex h-7 items-center rounded-sm px-2.5 text-sm font-medium text-muted transition-all duration-150 hover:text-sidebar-text';
	const btnPrimary =
		'flex h-7 items-center gap-1 rounded-sm bg-accent px-2.5 text-sm font-medium text-white transition-all duration-150 hover:bg-accent/90 disabled:opacity-30';
	const checkSvg = `<svg class="h-3 w-3 text-white" fill="none" stroke="currentColor" stroke-width="3" viewBox="0 0 24 24"><path stroke-linecap="square" stroke-linejoin="miter" d="M5 13l4 4L19 7"/></svg>`;

	const permissionGroups = $derived.by(() => {
		const groups = new SvelteMap<string, Permission[]>();
		for (const p of allPermissions) {
			const list = groups.get(p.resource) ?? [];
			list.push(p);
			groups.set(p.resource, list);
		}
		return groups;
	});

	function resourceLabel(resource: string): string {
		return resource.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase());
	}

	// ── Create modal ──

	function openCreateModal() {
		createName = '';
		createSlug = '';
		createDescription = '';
		createError = null;
		createModalOpen = true;
	}

	function generateCreateSlug() {
		createSlug = createName
			.toLowerCase()
			.replace(/[^a-z0-9]+/g, '-')
			.replace(/^-|-$/g, '');
	}

	async function createRole() {
		if (!createName.trim() || !createSlug.trim() || !auth.organizationId) return;
		createSaving = true;
		createError = null;
		try {
			const newRole = await api.roles.create({
				name: createName.trim(),
				slug: createSlug.trim(),
				description: createDescription.trim() || null,
				organization_id: auth.organizationId
			});
			roles = await api.roles.getAll(auth.organizationId);
			createModalOpen = false;
			const fresh = roles.find((r) => r.id === newRole.id) ?? newRole;
			openPanel(fresh);
			panelTab = 'permissions';
		} catch (e) {
			createError = e instanceof Error ? e.message : 'Failed to create role';
		} finally {
			createSaving = false;
		}
	}

	// ── Detail panel ──

	function openPanel(role: Role) {
		selectedRole = role;
		panelTab = 'details';
		editError = null;
		editSuccess = null;
		permsError = null;
		permsSuccess = null;
		applyRoleFields(role);
		applyPermissionFields(role);
	}

	function closePanel() {
		selectedRole = null;
	}

	function applyRoleFields(role: Role) {
		editName = role.name;
		editSlug = role.slug;
		editDescription = role.description ?? '';
	}

	function applyPermissionFields(role: Role) {
		const map = new SvelteMap<string, 'own' | 'all'>();
		for (const rp of role.permissions) {
			map.set(rp.permission_id, rp.scope);
		}
		editPermissions = map;
	}

	async function saveRoleDetails() {
		if (!selectedRole || selectedRole.is_system || !editName.trim() || !editSlug.trim()) return;
		editSaving = true;
		editError = null;
		editSuccess = null;
		try {
			await api.roles.update(selectedRole.id, {
				name: editName.trim(),
				slug: editSlug.trim(),
				description: editDescription.trim() || null
			});
			if (auth.organizationId) {
				roles = await api.roles.getAll(auth.organizationId);
				selectedRole = roles.find((r) => r.id === selectedRole!.id) ?? selectedRole;
			}
			editSuccess = 'Role updated.';
		} catch (e) {
			editError = e instanceof Error ? e.message : 'Failed to update role';
		} finally {
			editSaving = false;
		}
	}

	// ── Permissions ──

	function togglePermission(permId: string) {
		const newMap = new SvelteMap(editPermissions);
		if (newMap.has(permId)) {
			newMap.delete(permId);
		} else {
			newMap.set(permId, 'own');
		}
		editPermissions = newMap;
	}

	function toggleScope(permId: string) {
		const newMap = new SvelteMap(editPermissions);
		const current = newMap.get(permId);
		if (current === 'own') {
			newMap.set(permId, 'all');
		} else if (current === 'all') {
			newMap.set(permId, 'own');
		}
		editPermissions = newMap;
	}

	async function savePermissions() {
		if (!selectedRole || selectedRole.is_system) return;
		permsSaving = true;
		permsError = null;
		permsSuccess = null;
		try {
			const entries: PermissionEntry[] = [];
			for (const [permId, scope] of editPermissions) {
				entries.push({ permission_id: permId, scope });
			}
			await api.roles.setPermissions(selectedRole.id, entries);
			if (auth.organizationId) {
				roles = await api.roles.getAll(auth.organizationId);
				const updated = roles.find((r) => r.id === selectedRole!.id);
				if (updated) {
					selectedRole = updated;
					applyPermissionFields(updated);
				}
			}
			permsSuccess = 'Permissions saved.';
		} catch (e) {
			permsError = e instanceof Error ? e.message : 'Failed to save permissions';
		} finally {
			permsSaving = false;
		}
	}

	// ── Delete ──

	function openDeleteDialog(role: Role) {
		deleteTarget = role;
		selectedRole = null;
		deleteDialogOpen = true;
	}

	async function confirmDelete() {
		if (!deleteTarget) return;
		deleting = true;
		try {
			await api.roles.delete(deleteTarget.id);
			if (auth.organizationId) {
				roles = await api.roles.getAll(auth.organizationId);
			}
			deleteDialogOpen = false;
			deleteTarget = null;
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to delete role';
			deleteDialogOpen = false;
		} finally {
			deleting = false;
		}
	}

	// ── Keyboard ──

	$effect(() => {
		if (!selectedRole) return;
		function handleKeydown(e: KeyboardEvent) {
			if (e.key === 'Escape') closePanel();
		}
		document.addEventListener('keydown', handleKeydown);
		return () => document.removeEventListener('keydown', handleKeydown);
	});

	$effect(() => {
		if (loaded) return;
		if (!auth.isAuthenticated) return;
		if (!auth.organizationId) return;
		loaded = true;
		const orgId = auth.organizationId;
		(async () => {
			try {
				const [roleList, permList] = await Promise.all([
					api.roles.getAll(orgId),
					api.roles.getPermissions()
				]);
				roles = roleList;
				allPermissions = permList;
			} catch (e) {
				error = e instanceof Error ? e.message : 'Failed to load data';
			} finally {
				loading = false;
			}
		})();
	});
</script>

<div class="mx-auto w-full">
	<div class="flex items-center justify-between px-3 py-1.5">
		<h1 class="text-md font-semibold text-sidebar-text">Roles</h1>
		{#if canManage}
			<button class={btnPrimary} onclick={openCreateModal}>New role</button>
		{/if}
	</div>

	{#if loading}
		<p class="px-3 py-8 text-center text-sm text-muted">Loading...</p>
	{:else if error}
		<p class="px-3 py-8 text-center text-sm text-red-400">{error}</p>
	{:else if roles.length === 0}
		<p class="px-3 py-8 text-center text-sm text-muted">No roles found.</p>
	{:else}
		<div class="mx-3 mb-2 overflow-x-auto rounded border border-surface-border/40 bg-surface/50">
			<table class="w-full text-sm">
				<thead>
					<tr class="border-b border-surface-border/30 text-left text-xs font-medium uppercase tracking-[0.08em] text-muted">
						<th class="px-3 py-2">Name</th>
						<th class="px-3 py-2">Type</th>
						<th class="px-3 py-2">Description</th>
						<th class="px-3 py-2">Permissions</th>
					</tr>
				</thead>
				<tbody>
					{#each roles as role (role.id)}
						<tr
							class="cursor-pointer border-b border-surface-border/30 transition-all duration-150 hover:bg-surface-hover/60 {selectedRole?.id === role.id ? 'bg-surface-hover/60' : ''}"
							onclick={() => openPanel(role)}
						>
							<td class="px-3 py-2 font-medium text-sidebar-text">{role.name}</td>
							<td class="px-3 py-2">
								{#if role.is_system}
									<span class="text-xs font-medium text-accent">System</span>
								{:else}
									<span class="text-xs font-medium text-muted">Custom</span>
								{/if}
							</td>
							<td class="max-w-[300px] truncate px-3 py-2 text-muted">{role.description ?? '—'}</td>
							<td class="px-3 py-2 text-muted">{role.permissions.length}</td>
						</tr>
					{/each}
				</tbody>
			</table>
		</div>
	{/if}
</div>

<!-- Detail Panel -->
{#if selectedRole}
	{@const isEditable = !selectedRole.is_system && canManage}
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
			class="absolute top-0 right-0 bottom-0 flex w-[420px] flex-col overflow-hidden border-l border-surface-border bg-surface shadow-xl"
			role="dialog"
			aria-modal="true"
		>
			<!-- Header -->
			<div class="flex shrink-0 items-center justify-between border-b border-surface-border px-3 py-2.5">
				<div class="min-w-0 flex-1">
					<span class="text-xs font-medium text-accent">{selectedRole.slug}</span>
					<h2 class="truncate text-lg font-semibold text-sidebar-text">{selectedRole.name}</h2>
				</div>
				<div class="ml-3 flex shrink-0 items-center gap-1">
					{#if isEditable}
						<button
							class="flex h-6 w-6 items-center justify-center rounded-sm text-muted/40 transition-all duration-150 hover:bg-surface-hover hover:text-red-400"
							onclick={() => openDeleteDialog(selectedRole!)}
							aria-label="Delete role"
							title="Delete role"
						>
							<svg class="h-3.5 w-3.5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
							</svg>
						</button>
					{/if}
					<button
						class="flex h-6 w-6 items-center justify-center rounded-sm text-muted/40 transition-all duration-150 hover:bg-surface-hover hover:text-sidebar-text"
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
					class="px-3 py-2 text-sm font-medium transition-all duration-150 {panelTab === 'details'
						? 'border-b-2 border-accent text-accent'
						: 'text-muted hover:text-sidebar-text'}"
					onclick={() => { panelTab = 'details'; editError = null; editSuccess = null; }}
				>
					Details
				</button>
				<button
					class="px-3 py-2 text-sm font-medium transition-all duration-150 {panelTab === 'permissions'
						? 'border-b-2 border-accent text-accent'
						: 'text-muted hover:text-sidebar-text'}"
					onclick={() => { panelTab = 'permissions'; permsError = null; permsSuccess = null; }}
				>
					Permissions ({selectedRole.permissions.length})
				</button>
			</div>

			<!-- Content -->
			<div class="min-w-0 flex-1 overflow-y-auto">
				{#if panelTab === 'details'}
					<form onsubmit={(e) => { e.preventDefault(); saveRoleDetails(); }} class="p-3">
						<div class="mb-2 rounded border border-surface-border/40 bg-surface/50 px-3 py-2.5">
							<span class="{sectionLabel} mb-3 block">Properties</span>
							<div class="space-y-3">
								<div class="grid grid-cols-2 gap-3">
									<div>
										<label for="edit-name" class={labelClass}>Name</label>
										<input id="edit-name" type="text" required bind:value={editName}
											class={inputClass} disabled={!isEditable} />
									</div>
									<div>
										<label for="edit-slug" class={labelClass}>Slug</label>
										<input id="edit-slug" type="text" required bind:value={editSlug}
											class={inputClass} disabled={!isEditable} />
									</div>
								</div>
								<div>
									<label for="edit-desc" class={labelClass}>Description</label>
									<textarea id="edit-desc" bind:value={editDescription} rows="3"
										class="{inputClass} resize-none" disabled={!isEditable}
										placeholder="What this role can do..."></textarea>
								</div>
							</div>
						</div>

						<div class="mb-2 rounded border border-surface-border/40 bg-surface/50 px-3 py-2.5">
							<span class="{sectionLabel} mb-2 block">Info</span>
							<div class="grid grid-cols-2 gap-x-3 gap-y-1.5 text-sm">
								<div>
									<span class="text-muted/50">Type</span>
									<p class="text-sidebar-text">{selectedRole.is_system ? 'System' : 'Custom'}</p>
								</div>
								<div>
									<span class="text-muted/50">Permissions</span>
									<p class="text-sidebar-text">{selectedRole.permissions.length}</p>
								</div>
								<div>
									<span class="text-muted/50">Created</span>
									<p class="font-mono text-sidebar-text">{new Date(selectedRole.created_at).toLocaleDateString('de-DE')}</p>
								</div>
								<div>
									<span class="text-muted/50">Updated</span>
									<p class="font-mono text-sidebar-text">{new Date(selectedRole.updated_at).toLocaleDateString('de-DE')}</p>
								</div>
							</div>
						</div>

						{#if editError}
							<p class="pt-2 text-sm text-red-400">{editError}</p>
						{/if}
						{#if editSuccess}
							<p class="pt-2 text-sm text-green-400">{editSuccess}</p>
						{/if}

						{#if isEditable}
							<div class="flex justify-end pt-2">
								<button type="submit" disabled={editSaving || !editName.trim() || !editSlug.trim()} class={btnPrimary}>
									{editSaving ? 'Saving...' : 'Save changes'}
								</button>
							</div>
						{/if}
					</form>
				{/if}

				{#if panelTab === 'permissions'}
					<div class="p-3">
						{#if selectedRole.is_system}
							<p class="pb-2 text-sm text-muted/50">System role permissions are read-only.</p>
						{/if}

						{#each [...permissionGroups] as [resource, perms] (resource)}
							<div class="mb-2 rounded border border-surface-border/40 bg-surface/50 px-3 py-2.5">
								<span class="{sectionLabel} mb-3 block">{resourceLabel(resource)}</span>
								<div class="space-y-2">
									{#each perms as perm (perm.id)}
										{@const isChecked = editPermissions.has(perm.id)}
										{@const scope = editPermissions.get(perm.id) ?? 'own'}
										<div class="flex items-center justify-between gap-2">
											<button
												type="button"
												class="flex min-w-0 items-center gap-3"
												onclick={() => { if (isEditable) togglePermission(perm.id); }}
												disabled={!isEditable}
											>
												<span 												class="flex h-3 w-3 shrink-0 items-center justify-center rounded-sm border transition-all duration-150
													{isChecked ? 'border-accent bg-accent' : 'border-surface-border/60'}
													{!isEditable ? 'opacity-60' : ''}">
													{#if isChecked}{@html checkSvg}{/if}
												</span>
												<span class="shrink-0 text-sm font-medium text-sidebar-text">{perm.action}</span>
												{#if perm.description}
													<span class="truncate text-xs text-muted/50">{perm.description}</span>
												{/if}
											</button>

											{#if isChecked}
												<button
													type="button"
													class="shrink-0 rounded-sm px-2 py-0.5 text-xs font-medium transition-all duration-150
														{scope === 'all'
															? 'bg-accent/10 text-accent'
															: 'bg-surface-hover/40 text-muted hover:text-sidebar-text'}
														{!isEditable ? 'pointer-events-none opacity-60' : ''}"
													onclick={() => { if (isEditable) toggleScope(perm.id); }}
													disabled={!isEditable}
													title={scope === 'all' ? 'Access to all records' : 'Access to own records only'}
												>
													{scope}
												</button>
											{/if}
										</div>
									{/each}
								</div>
							</div>
						{/each}

						{#if permsError}
							<p class="pt-2 text-sm text-red-400">{permsError}</p>
						{/if}
						{#if permsSuccess}
							<p class="pt-2 text-sm text-green-400">{permsSuccess}</p>
						{/if}

						{#if isEditable}
							<div class="flex justify-end pt-2">
								<button type="button" disabled={permsSaving} class={btnPrimary} onclick={savePermissions}>
									{permsSaving ? 'Saving...' : 'Save permissions'}
								</button>
							</div>
						{/if}
					</div>
				{/if}
			</div>
		</div>
	</div>
{/if}

<!-- Create Role Modal -->
{#if createModalOpen}
	<Modal open={true} onClose={() => (createModalOpen = false)}>
		<div>
			<div class="border-b border-surface-border/40 px-3 py-2.5">
				<h2 class="text-md font-semibold text-sidebar-text">New Role</h2>
			</div>
			<form onsubmit={(e) => { e.preventDefault(); createRole(); }} class="space-y-3 p-3">
				<div class="grid grid-cols-2 gap-3">
					<div>
						<label for="create-name" class={labelClass}>Name</label>
						<input id="create-name" type="text" required bind:value={createName}
							class={inputClass} placeholder="Support Agent"
							oninput={generateCreateSlug} />
					</div>
					<div>
						<label for="create-slug" class={labelClass}>Slug</label>
						<input id="create-slug" type="text" required bind:value={createSlug}
							class={inputClass} placeholder="support-agent" />
					</div>
				</div>

				<div>
					<label for="create-desc" class={labelClass}>Description</label>
					<textarea id="create-desc" bind:value={createDescription} rows="2"
						class="{inputClass} resize-none" placeholder="What this role can do..."></textarea>
				</div>

				{#if createError}
					<p class="text-sm text-red-400">{createError}</p>
				{/if}

				<div class="flex justify-end gap-2 border-t border-surface-border/40 pt-3">
					<button type="button" class={btnSecondary} onclick={() => (createModalOpen = false)}>
						Cancel
					</button>
					<button type="submit" disabled={createSaving || !createName.trim() || !createSlug.trim()} class={btnPrimary}>
						{createSaving ? 'Creating...' : 'Create'}
					</button>
				</div>
			</form>
		</div>
	</Modal>
{/if}

<!-- Delete Confirmation -->
<ConfirmDialog
	open={deleteDialogOpen}
	title="Delete Role"
	message="This role will be permanently deleted. Members currently assigned this role will need to be reassigned. This action cannot be undone."
	confirmLabel="Delete"
	loading={deleting}
	destructive={true}
	onConfirm={confirmDelete}
	onCancel={() => { deleteDialogOpen = false; deleteTarget = null; }}
/>
