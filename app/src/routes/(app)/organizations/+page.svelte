<script lang="ts">
	import { onMount } from 'svelte';
	import { X } from '@lucide/svelte';
	import { auth } from '$lib/stores/auth.svelte';
	import { api } from '$lib/api';
	import Modal from '$lib/components/Modal.svelte';
	import type { Organization, CreateOrgInput } from '$lib/api/organizations';
	import type { Tier } from '$lib/api/config';

	const PRIORITIES = ['low', 'medium', 'high', 'urgent'] as const;

	let loading = $state(true);
	let error = $state<string | null>(null);

	let organizations = $state<Organization[]>([]);
	let tiers = $state<Tier[]>([]);
	let activeTiers = $derived(tiers.filter((t) => t.is_active));

	// Create modal
	let createModalOpen = $state(false);
	let createName = $state('');
	let createSlug = $state('');
	let createDomain = $state('');
	let createWebsite = $state('');
	let createNotes = $state('');
	let createTierId = $state<string | null>(null);
	let createSaving = $state(false);
	let createError = $state<string | null>(null);

	// Detail panel
	let selectedOrg = $state<Organization | null>(null);
	let panelTab = $state<'details' | 'settings'>('details');

	// Dropdown state
	let openDropdown = $state<string | null>(null);

	// Editable org fields
	let editName = $state('');
	let editSlug = $state('');
	let editDomain = $state('');
	let editWebsite = $state('');
	let editNotes = $state('');
	let editTierId = $state<string | null>(null);
	let editActive = $state(true);
	let editSaving = $state(false);
	let editError = $state<string | null>(null);
	let editSuccess = $state<string | null>(null);

	// Organization settings state
	let autoAssign = $state(false);
	let defaultPriority = $state<string>('medium');
	let requireCategory = $state(false);
	let notifyTicketCreated = $state(true);
	let notifyTicketAssigned = $state(true);
	let notifyTicketResolved = $state(true);
	let notifyTaskAssigned = $state(true);
	let notifyTaskStatusChange = $state(true);
	let notifyComment = $state(true);
	let maxProjects = $state<number | null>(null);
	let maxMembers = $state<number | null>(null);
	let customLogoUrl = $state('');
	let primaryColor = $state('');
	let settingsSaving = $state(false);
	let settingsError = $state<string | null>(null);
	let settingsSuccess = $state<string | null>(null);

	const labelClass = 'mb-1.5 block text-[11px] font-medium uppercase tracking-wider text-sidebar-icon';
	const sectionLabel = 'text-[11px] font-medium uppercase tracking-wider text-sidebar-icon';
	const inputClass =
		'w-full border border-surface-border bg-surface px-3 py-2 text-xs text-sidebar-text shadow-sm outline-none transition-colors placeholder:text-sidebar-icon/70 focus:border-sidebar-icon/30 hover:border-sidebar-icon/30';
	const btnSecondary =
		'border border-surface-border bg-surface px-4 py-2 text-xs font-medium text-sidebar-text transition-colors hover:border-sidebar-icon/30 hover:bg-surface-hover';
	const btnPrimary =
		'bg-accent px-4 py-2 text-xs font-medium text-white shadow-sm transition-colors hover:bg-accent/90 disabled:opacity-50';
	const dropBtnClass =
		'flex w-full cursor-pointer items-center justify-between gap-2 border border-surface-border bg-surface px-3 py-2 text-xs text-sidebar-text shadow-sm transition-colors hover:border-sidebar-icon/30 hover:bg-surface-hover';
	const dropPanelClass =
		'absolute left-0 z-30 mt-1 max-h-48 w-full overflow-y-auto border border-surface-border bg-surface py-1 shadow-xl';
	const dropItemBase =
		'flex w-full items-center px-4 py-2 text-left text-xs transition-colors hover:bg-surface-hover';

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

	// ── Create modal ──

	function openCreateModal() {
		createName = '';
		createSlug = '';
		createDomain = '';
		createWebsite = '';
		createNotes = '';
		createTierId = activeTiers[0]?.id ?? null;
		createError = null;
		openDropdown = null;
		createModalOpen = true;
	}

	function generateCreateSlug() {
		createSlug = createName
			.toLowerCase()
			.replace(/[^a-z0-9]+/g, '-')
			.replace(/^-|-$/g, '');
	}

	async function createOrg() {
		if (!createName.trim() || !createSlug.trim()) return;
		createSaving = true;
		createError = null;
		try {
			const newOrg = await api.organizations.create({
				name: createName.trim(),
				slug: createSlug.trim(),
				domain: createDomain.trim() || null,
				website_url: createWebsite.trim() || null,
				notes: createNotes.trim() || null,
				support_tier_id: createTierId
			});
			organizations = await api.organizations.getAll();
			createModalOpen = false;
			openPanel(newOrg);
		} catch (e) {
			createError = e instanceof Error ? e.message : 'Failed to create organization';
		} finally {
			createSaving = false;
		}
	}

	// ── Detail panel ──

	function openPanel(org: Organization) {
		selectedOrg = org;
		panelTab = 'details';
		openDropdown = null;
		editError = null;
		editSuccess = null;
		settingsError = null;
		settingsSuccess = null;
		applyOrgFields(org);
		loadOrgSettings(org.id);
	}

	function closePanel() {
		selectedOrg = null;
		openDropdown = null;
	}

	function applyOrgFields(org: Organization) {
		editName = org.name;
		editSlug = org.slug;
		editDomain = org.domain ?? '';
		editWebsite = org.website_url ?? '';
		editNotes = org.notes ?? '';
		editTierId = org.support_tier_id;
		editActive = org.is_active;
	}

	async function saveOrgDetails() {
		if (!selectedOrg || !editName.trim() || !editSlug.trim()) return;
		editSaving = true;
		editError = null;
		editSuccess = null;
		try {
			const updated = await api.organizations.update(selectedOrg.id, {
				name: editName.trim(),
				slug: editSlug.trim(),
				domain: editDomain.trim() || null,
				website_url: editWebsite.trim() || null,
				notes: editNotes.trim() || null,
				support_tier_id: editTierId,
				is_active: editActive
			});
			organizations = await api.organizations.getAll();
			selectedOrg = organizations.find((o) => o.id === updated.id) ?? updated;
			editSuccess = 'Organization updated.';
		} catch (e) {
			editError = e instanceof Error ? e.message : 'Failed to update organization';
		} finally {
			editSaving = false;
		}
	}

	// ── Org settings ──

	function applySettings(data: Record<string, unknown> | null) {
		if (!data) return;
		autoAssign = (data.auto_assign_tickets as boolean) ?? false;
		defaultPriority = (data.default_ticket_priority as string) ?? 'medium';
		requireCategory = (data.require_ticket_category as boolean) ?? false;
		notifyTicketCreated = (data.notify_on_ticket_created as boolean) ?? true;
		notifyTicketAssigned = (data.notify_on_ticket_assigned as boolean) ?? true;
		notifyTicketResolved = (data.notify_on_ticket_resolved as boolean) ?? true;
		notifyTaskAssigned = (data.notify_on_task_assigned as boolean) ?? true;
		notifyTaskStatusChange = (data.notify_on_task_status_change as boolean) ?? true;
		notifyComment = (data.notify_on_comment as boolean) ?? true;
		maxProjects = (data.max_projects as number) ?? null;
		maxMembers = (data.max_members as number) ?? null;
		customLogoUrl = (data.custom_logo_url as string) ?? '';
		primaryColor = (data.primary_color as string) ?? '';
	}

	async function loadOrgSettings(orgId: string) {
		try {
			const settings = await api.config.getOrgSettings(orgId);
			applySettings(settings);
		} catch {
			// defaults
		}
	}

	async function saveSettings() {
		if (!selectedOrg) return;
		settingsSaving = true;
		settingsError = null;
		settingsSuccess = null;
		try {
			const result = await api.config.upsertOrgSettings(selectedOrg.id, {
				auto_assign_tickets: autoAssign,
				default_ticket_priority: defaultPriority,
				require_ticket_category: requireCategory,
				notify_on_ticket_created: notifyTicketCreated,
				notify_on_ticket_assigned: notifyTicketAssigned,
				notify_on_ticket_resolved: notifyTicketResolved,
				notify_on_task_assigned: notifyTaskAssigned,
				notify_on_task_status_change: notifyTaskStatusChange,
				notify_on_comment: notifyComment,
				max_projects: maxProjects,
				max_members: maxMembers,
				custom_logo_url: customLogoUrl || null,
				primary_color: primaryColor || null
			});
			applySettings(result);
			settingsSuccess = 'Settings saved.';
		} catch (e) {
			settingsError = e instanceof Error ? e.message : 'Failed to save settings';
		} finally {
			settingsSaving = false;
		}
	}

	// ── Keyboard ──

	$effect(() => {
		if (!selectedOrg) return;
		function handleKeydown(e: KeyboardEvent) {
			if (e.key === 'Escape') {
				if (openDropdown) { openDropdown = null; }
				else { closePanel(); }
			}
		}
		document.addEventListener('keydown', handleKeydown);
		return () => document.removeEventListener('keydown', handleKeydown);
	});

	onMount(async () => {
		try {
			const [orgs, tierList] = await Promise.all([
				api.organizations.getAll(),
				api.config.getTiers()
			]);
			organizations = orgs;
			tiers = tierList;
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to load data';
		} finally {
			loading = false;
		}
	});

	// ── Helpers ──

	function tierLabel(tierId: string | null): string {
		if (!tierId) return 'No tier';
		const t = tiers.find((t) => t.id === tierId);
		return t ? t.name : 'Unknown';
	}

	function tierSublabel(tierId: string | null): string {
		if (!tierId) return '';
		const t = tiers.find((t) => t.id === tierId);
		return t ? `${t.response_time_hours}h / ${t.resolution_time_hours}h` : '';
	}

	const chevronSvg = `<svg class="h-3.5 w-3.5 shrink-0 text-sidebar-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/></svg>`;
	const checkSvg = `<svg class="h-3 w-3 text-white" fill="none" stroke="currentColor" stroke-width="3" viewBox="0 0 24 24"><path stroke-linecap="square" stroke-linejoin="miter" d="M5 13l4 4L19 7"/></svg>`;
</script>

{#snippet toggle(checked: boolean, onToggle: () => void, label: string)}
	<button type="button" class="flex items-center gap-3" onclick={onToggle}>
		<span class="flex h-4 w-4 shrink-0 items-center justify-center border transition-colors
			{checked ? 'border-accent bg-accent' : 'border-surface-border bg-surface hover:border-sidebar-icon/30'}">
			{#if checked}{@html checkSvg}{/if}
		</span>
		<span class="text-xs text-sidebar-text">{label}</span>
	</button>
{/snippet}

<div class="mx-auto w-full max-w-[1200px]">
	<div class="flex items-center justify-between border-b border-surface-border px-6 py-4">
		<h1 class="text-sm font-semibold text-sidebar-text">Organizations</h1>
		{#if auth.isOwner}
			<button class={btnPrimary} onclick={openCreateModal}>New organization</button>
		{/if}
	</div>

	{#if loading}
		<p class="px-6 py-8 text-center text-sm text-sidebar-icon">Loading...</p>
	{:else if error}
		<p class="px-6 py-8 text-center text-sm text-red-500">{error}</p>
	{:else if organizations.length === 0}
		<p class="px-6 py-8 text-center text-sm text-sidebar-icon">No organizations yet.</p>
	{:else}
		<div class="overflow-x-auto">
			<table class="w-full text-xs">
				<thead>
					<tr class="border-b border-surface-border text-left text-[11px] font-medium uppercase tracking-wider text-sidebar-icon">
						<th class="px-4 py-2.5">Name</th>
						<th class="px-4 py-2.5">Slug</th>
						<th class="px-4 py-2.5">Tier</th>
						<th class="px-4 py-2.5">Status</th>
					</tr>
				</thead>
				<tbody>
					{#each organizations as org (org.id)}
						<tr
							class="cursor-pointer border-b border-surface-border/50 transition-colors hover:bg-surface-hover/50 {selectedOrg?.id === org.id ? 'bg-surface-hover/50' : ''}"
							onclick={() => openPanel(org)}
						>
							<td class="px-4 py-2.5 font-medium text-sidebar-text">{org.name}</td>
							<td class="px-4 py-2.5 text-sidebar-icon">{org.slug}</td>
							<td class="px-4 py-2.5">
								{#if org.support_tier}
									<span class="inline-block bg-accent/10 px-1.5 py-0.5 text-[10px] font-medium text-accent">
										{org.support_tier.name}
									</span>
								{:else}
									<span class="text-sidebar-icon">—</span>
								{/if}
							</td>
							<td class="px-4 py-2.5">
								<span class="text-[10px] font-medium {org.is_active ? 'text-green-600' : 'text-sidebar-icon'}">
									{org.is_active ? 'Active' : 'Inactive'}
								</span>
							</td>
						</tr>
					{/each}
				</tbody>
			</table>
		</div>
	{/if}
</div>

<!-- Detail Panel -->
{#if selectedOrg}
	<div class="fixed inset-0 z-[60]" role="presentation">
		<button
			class="absolute inset-0 bg-black/30 transition-opacity"
			onclick={closePanel}
			tabindex="-1"
			aria-label="Close panel"
		></button>

		<div
			class="absolute top-0 right-0 bottom-0 flex w-[480px] flex-col border-l border-surface-border bg-surface shadow-xl"
			role="dialog"
			aria-modal="true"
		>
			<!-- Header -->
			<div class="flex shrink-0 items-center justify-between border-b border-surface-border px-4 py-3">
				<div class="min-w-0 flex-1">
					<span class="text-xs font-medium text-accent">{selectedOrg.slug}</span>
					<h2 class="truncate text-sm font-semibold text-sidebar-text">{selectedOrg.name}</h2>
				</div>
				<button
					class="ml-3 shrink-0 p-1 text-sidebar-icon transition-colors hover:text-sidebar-text"
					onclick={closePanel}
					aria-label="Close"
				>
					<X size={18} />
				</button>
			</div>

			<!-- Tabs -->
			<div class="flex shrink-0 border-b border-surface-border">
				<button
					class="px-4 py-2.5 text-xs font-medium transition-colors {panelTab === 'details'
						? 'border-b-2 border-accent text-accent'
						: 'text-sidebar-icon hover:text-sidebar-text'}"
					onclick={() => { panelTab = 'details'; openDropdown = null; editError = null; editSuccess = null; }}
				>
					Details
				</button>
				<button
					class="px-4 py-2.5 text-xs font-medium transition-colors {panelTab === 'settings'
						? 'border-b-2 border-accent text-accent'
						: 'text-sidebar-icon hover:text-sidebar-text'}"
					onclick={() => { panelTab = 'settings'; openDropdown = null; settingsError = null; settingsSuccess = null; }}
				>
					Settings
				</button>
			</div>

			<!-- Scrollable content -->
			<div class="flex-1 overflow-y-auto">
				{#if panelTab === 'details'}
					<form onsubmit={(e) => { e.preventDefault(); saveOrgDetails(); }} class="px-4">
						<!-- Properties -->
						<div class="border-b border-surface-border py-4">
							<span class="{sectionLabel} mb-3 block">Properties</span>
							<div class="space-y-3">
								<div class="grid grid-cols-2 gap-3">
									<div>
										<label for="edit-name" class={labelClass}>Name</label>
										<input id="edit-name" type="text" required bind:value={editName} class={inputClass} />
									</div>
									<div>
										<label for="edit-slug" class={labelClass}>Slug</label>
										<input id="edit-slug" type="text" required bind:value={editSlug} class={inputClass} />
									</div>
								</div>
								<div class="grid grid-cols-2 gap-3">
									<div>
										<label for="edit-domain" class={labelClass}>Domain</label>
										<input id="edit-domain" type="text" bind:value={editDomain}
											class={inputClass} placeholder="acme.com" />
									</div>
									<div>
										<label for="edit-website" class={labelClass}>Website</label>
										<input id="edit-website" type="text" bind:value={editWebsite}
											class={inputClass} placeholder="https://..." />
									</div>
								</div>
							</div>
						</div>

						<!-- Support Tier (custom dropdown) -->
						<div class="border-b border-surface-border py-4">
							<span class="{sectionLabel} mb-3 block">Support Tier</span>
							<div class="relative" data-dropdown>
								<button type="button" class={dropBtnClass} onclick={() => toggleDropdown('edit-tier')}>
									<div class="min-w-0">
										<span class="truncate">{tierLabel(editTierId)}</span>
										{#if tierSublabel(editTierId)}
											<span class="ml-1.5 text-sidebar-icon">({tierSublabel(editTierId)})</span>
										{/if}
									</div>
									{@html chevronSvg}
								</button>
								{#if openDropdown === 'edit-tier'}
									<div class={dropPanelClass}>
										<button type="button"
											class="{dropItemBase} {editTierId === null ? 'font-medium text-accent' : 'text-sidebar-text'}"
											onmousedown={(e) => { e.preventDefault(); editTierId = null; openDropdown = null; }}
										>No tier</button>
										{#each activeTiers as t (t.id)}
											<button type="button"
												class="{dropItemBase} {editTierId === t.id ? 'font-medium text-accent' : 'text-sidebar-text'}"
												onmousedown={(e) => { e.preventDefault(); editTierId = t.id; openDropdown = null; }}
											>
												{t.name}
												<span class="ml-auto pl-3 text-sidebar-icon">{t.response_time_hours}h / {t.resolution_time_hours}h</span>
											</button>
										{/each}
									</div>
								{/if}
							</div>
							{#if selectedOrg.support_tier}
								<p class="mt-2 text-[11px] text-sidebar-icon">
									Current: <span class="font-medium text-accent">{selectedOrg.support_tier.name}</span>
									({selectedOrg.support_tier.response_time_hours}h / {selectedOrg.support_tier.resolution_time_hours}h)
								</p>
							{/if}
						</div>

						<!-- Notes -->
						<div class="border-b border-surface-border py-4">
							<label for="edit-notes" class="{sectionLabel} mb-3 block">Notes</label>
							<textarea id="edit-notes" bind:value={editNotes} rows="3"
								class="{inputClass} resize-none" placeholder="Internal notes..."></textarea>
						</div>

						<!-- Status -->
						<div class="border-b border-surface-border py-4">
							<span class="{sectionLabel} mb-3 block">Status</span>
							{@render toggle(editActive, () => { editActive = !editActive; }, 'Active')}
						</div>

						<!-- Timestamps -->
						<div class="border-b border-surface-border py-4">
							<span class="{sectionLabel} mb-2 block">Timestamps</span>
							<div class="grid grid-cols-2 gap-x-3 gap-y-1.5 text-xs">
								<div>
									<span class="text-sidebar-icon">Created</span>
									<p class="text-sidebar-text">{new Date(selectedOrg.created_at).toLocaleDateString('de-DE')}</p>
								</div>
								<div>
									<span class="text-sidebar-icon">Updated</span>
									<p class="text-sidebar-text">{new Date(selectedOrg.updated_at).toLocaleDateString('de-DE')}</p>
								</div>
							</div>
						</div>

						{#if editError}
							<p class="pt-3 text-xs text-red-500">{editError}</p>
						{/if}
						{#if editSuccess}
							<p class="pt-3 text-xs text-green-600">{editSuccess}</p>
						{/if}

						<div class="flex justify-end py-4">
							<button type="submit" disabled={editSaving || !editName.trim() || !editSlug.trim()} class={btnPrimary}>
								{editSaving ? 'Saving...' : 'Save changes'}
							</button>
						</div>
					</form>
				{/if}

				{#if panelTab === 'settings'}
					<form onsubmit={(e) => { e.preventDefault(); saveSettings(); }} class="px-4">
						<div class="border-b border-surface-border py-4">
							<span class="{sectionLabel} mb-3 block">Ticket Settings</span>
							<div class="space-y-3">
								{@render toggle(autoAssign, () => { autoAssign = !autoAssign; }, 'Auto-assign tickets')}

								<div class="max-w-[200px]">
									<span class={labelClass}>Default priority</span>
									<div class="relative" data-dropdown>
										<button type="button" class={dropBtnClass} onclick={() => toggleDropdown('settings-priority')}>
											<span class="truncate">{defaultPriority}</span>
											{@html chevronSvg}
										</button>
										{#if openDropdown === 'settings-priority'}
											<div class={dropPanelClass}>
												{#each PRIORITIES as p}
													<button type="button"
														class="{dropItemBase} {defaultPriority === p ? 'font-medium text-accent' : 'text-sidebar-text'}"
														onmousedown={(e) => { e.preventDefault(); defaultPriority = p; openDropdown = null; }}
													>{p}</button>
												{/each}
											</div>
										{/if}
									</div>
								</div>

								{@render toggle(requireCategory, () => { requireCategory = !requireCategory; }, 'Require ticket category')}
							</div>
						</div>

						<div class="border-b border-surface-border py-4">
							<span class="{sectionLabel} mb-3 block">Notifications</span>
							<div class="space-y-2.5">
								{@render toggle(notifyTicketCreated, () => { notifyTicketCreated = !notifyTicketCreated; }, 'Ticket created')}
								{@render toggle(notifyTicketAssigned, () => { notifyTicketAssigned = !notifyTicketAssigned; }, 'Ticket assigned')}
								{@render toggle(notifyTicketResolved, () => { notifyTicketResolved = !notifyTicketResolved; }, 'Ticket resolved')}
								{@render toggle(notifyTaskAssigned, () => { notifyTaskAssigned = !notifyTaskAssigned; }, 'Task assigned')}
								{@render toggle(notifyTaskStatusChange, () => { notifyTaskStatusChange = !notifyTaskStatusChange; }, 'Task status change')}
								{@render toggle(notifyComment, () => { notifyComment = !notifyComment; }, 'New comment')}
							</div>
						</div>

						<div class="border-b border-surface-border py-4">
							<span class="{sectionLabel} mb-3 block">Limits</span>
							<p class="mb-2 text-[11px] text-sidebar-icon">Leave empty to use system defaults.</p>
							<div class="grid grid-cols-2 gap-3">
								<div>
									<label for="sp-max-projects" class={labelClass}>Max projects</label>
									<input id="sp-max-projects" type="number" min="1" bind:value={maxProjects}
										class={inputClass} placeholder="Default" />
								</div>
								<div>
									<label for="sp-max-members" class={labelClass}>Max members</label>
									<input id="sp-max-members" type="number" min="1" bind:value={maxMembers}
										class={inputClass} placeholder="Default" />
								</div>
							</div>
						</div>

						<div class="border-b border-surface-border py-4">
							<span class="{sectionLabel} mb-3 block">Custom Branding</span>
							<div class="space-y-3">
								<div>
									<label for="sp-logo" class={labelClass}>Logo URL</label>
									<input id="sp-logo" type="text" bind:value={customLogoUrl}
										class={inputClass} placeholder="https://..." />
								</div>
								<div>
									<label for="sp-color" class={labelClass}>Primary color</label>
									<div class="flex gap-2">
										<input id="sp-color" type="text" bind:value={primaryColor}
											class={inputClass} placeholder="#3b82f6" />
										{#if primaryColor}
											<div class="h-[34px] w-[34px] shrink-0 border border-surface-border"
												style="background-color: {primaryColor}"></div>
										{/if}
									</div>
								</div>
							</div>
						</div>

						{#if settingsError}
							<p class="pt-3 text-xs text-red-500">{settingsError}</p>
						{/if}
						{#if settingsSuccess}
							<p class="pt-3 text-xs text-green-600">{settingsSuccess}</p>
						{/if}

						<div class="flex justify-end py-4">
							<button type="submit" disabled={settingsSaving} class={btnPrimary}>
								{settingsSaving ? 'Saving...' : 'Save settings'}
							</button>
						</div>
					</form>
				{/if}
			</div>
		</div>
	</div>
{/if}

<!-- Create Org Modal -->
{#if createModalOpen}
	<Modal open={true} onClose={() => (createModalOpen = false)}>
		<div>
			<div class="border-b border-surface-border px-4 py-3">
				<h2 class="text-sm font-semibold text-sidebar-text">New Organization</h2>
			</div>
			<form onsubmit={(e) => { e.preventDefault(); createOrg(); }} class="space-y-4 p-4">
				<div class="grid grid-cols-2 gap-3">
					<div>
						<label for="create-name" class={labelClass}>Name</label>
						<input id="create-name" type="text" required bind:value={createName}
							class={inputClass} placeholder="Acme Corp"
							oninput={generateCreateSlug} />
					</div>
					<div>
						<label for="create-slug" class={labelClass}>Slug</label>
						<input id="create-slug" type="text" required bind:value={createSlug}
							class={inputClass} placeholder="acme-corp" />
					</div>
				</div>

				<div class="grid grid-cols-2 gap-3">
					<div>
						<label for="create-domain" class={labelClass}>Domain</label>
						<input id="create-domain" type="text" bind:value={createDomain}
							class={inputClass} placeholder="acme.com" />
					</div>
					<div>
						<label for="create-website" class={labelClass}>Website</label>
						<input id="create-website" type="text" bind:value={createWebsite}
							class={inputClass} placeholder="https://acme.com" />
					</div>
				</div>

				<!-- Tier (custom dropdown) -->
				<div>
					<span class={labelClass}>Support Tier</span>
					<div class="relative" data-dropdown>
						<button type="button" class={dropBtnClass} onclick={() => toggleDropdown('create-tier')}>
							<div class="min-w-0">
								<span class="truncate">{tierLabel(createTierId)}</span>
								{#if tierSublabel(createTierId)}
									<span class="ml-1.5 text-sidebar-icon">({tierSublabel(createTierId)})</span>
								{/if}
							</div>
							{@html chevronSvg}
						</button>
						{#if openDropdown === 'create-tier'}
							<div class={dropPanelClass}>
								<button type="button"
									class="{dropItemBase} {createTierId === null ? 'font-medium text-accent' : 'text-sidebar-text'}"
									onmousedown={(e) => { e.preventDefault(); createTierId = null; openDropdown = null; }}
								>No tier</button>
								{#each activeTiers as t (t.id)}
									<button type="button"
										class="{dropItemBase} {createTierId === t.id ? 'font-medium text-accent' : 'text-sidebar-text'}"
										onmousedown={(e) => { e.preventDefault(); createTierId = t.id; openDropdown = null; }}
									>
										{t.name}
										<span class="ml-auto pl-3 text-sidebar-icon">{t.response_time_hours}h / {t.resolution_time_hours}h</span>
									</button>
								{/each}
							</div>
						{/if}
					</div>
				</div>

				<div>
					<label for="create-notes" class={labelClass}>Notes</label>
					<textarea id="create-notes" bind:value={createNotes} rows="2"
						class="{inputClass} resize-none" placeholder="Internal notes..."></textarea>
				</div>

				{#if createError}
					<p class="text-xs text-red-500">{createError}</p>
				{/if}

				<div class="flex justify-end gap-2 border-t border-surface-border pt-4">
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
