<script lang="ts">
	import { auth } from '$lib/stores/auth.svelte';
	import { api } from '$lib/api';
	import Modal from '$lib/components/Modal.svelte';
	import ConfirmDialog from '$lib/components/ConfirmDialog.svelte';
	import type { Tier, CreateTierInput } from '$lib/api/config';

	let loading = $state(true);
	let saving = $state(false);
	let error = $state<string | null>(null);
	let success = $state<string | null>(null);

	// Branding
	let appName = $state('Trackr');
	let appLogoUrl = $state('');
	let supportEmail = $state('');

	// Defaults
	let defaultTierId = $state<string | null>(null);
	let defaultTimezone = $state('UTC');
	let defaultLocale = $state('en');

	// Feature flags
	let signupsEnabled = $state(true);
	let maintenanceMode = $state(false);

	// Limits
	let maxOrgsPerUser = $state(1);
	let maxProjectsPerOrg = $state(10);
	let maxMembersPerOrg = $state(25);

	// Tiers
	let tiers = $state<Tier[]>([]);
	let tierModalOpen = $state(false);
	let editingTier = $state<Tier | null>(null);
	let tierName = $state('');
	let tierSlug = $state('');
	let tierResponseHours = $state(24);
	let tierResolutionHours = $state(72);
	let tierDescription = $state('');
	let tierSortOrder = $state(0);
	let tierActive = $state(true);
	let tierSaving = $state(false);
	let tierError = $state<string | null>(null);
	let deletingTierId = $state<string | null>(null);
	let confirmDeleteTier = $state<Tier | null>(null);

	// Platform org
	let platformOrgId = $state<string | null>(null);
	let platformOrgName = $state('');
	let platformOrgSlug = $state('');
	let platformOrgDomain = $state('');
	let platformOrgWebsite = $state('');
	let platformOrgSaving = $state(false);
	let platformOrgError = $state<string | null>(null);
	let platformOrgSuccess = $state<string | null>(null);

	// Tab
	type Tab = 'tiers' | 'organization' | 'branding' | 'defaults';
	let activeTab = $state<Tab>('tiers');
	const tabs: { key: Tab; label: string }[] = [
		{ key: 'tiers', label: 'Support Tiers' },
		{ key: 'organization', label: 'Organization' },
		{ key: 'branding', label: 'Branding' },
		{ key: 'defaults', label: 'Defaults' }
	];

	// Dropdown state
	let openDropdown = $state<string | null>(null);

	const labelClass = 'mb-1.5 block text-[11px] font-medium uppercase tracking-wider text-sidebar-icon';
	const inputClass =
		'w-full border border-surface-border bg-surface px-3 py-2 text-xs text-sidebar-text shadow-sm outline-none transition-colors placeholder:text-sidebar-icon/70 focus:border-sidebar-icon/30 hover:border-sidebar-icon/30';
	const btnPrimary =
		'bg-accent px-4 py-2 text-xs font-medium text-white shadow-sm transition-colors hover:bg-accent/90 disabled:opacity-50';
	const btnSecondary =
		'border border-surface-border bg-surface px-4 py-2 text-xs font-medium text-sidebar-text transition-colors hover:border-sidebar-icon/30 hover:bg-surface-hover';
	const dropBtnClass =
		'flex w-full cursor-pointer items-center justify-between gap-2 border border-surface-border bg-surface px-3 py-2 text-xs text-sidebar-text shadow-sm transition-colors hover:border-sidebar-icon/30 hover:bg-surface-hover';
	const dropPanelClass =
		'absolute left-0 z-30 mt-1 max-h-48 w-full overflow-y-auto border border-surface-border bg-surface py-1 shadow-xl';
	const dropItemBase =
		'flex w-full items-center px-4 py-2 text-left text-xs transition-colors hover:bg-surface-hover';

	const checkSvg = `<svg class="h-3 w-3 text-white" fill="none" stroke="currentColor" stroke-width="3" viewBox="0 0 24 24"><path stroke-linecap="square" stroke-linejoin="miter" d="M5 13l4 4L19 7"/></svg>`;
	const chevronSvg = `<svg class="h-3.5 w-3.5 shrink-0 text-sidebar-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/></svg>`;

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

	function applyConfig(data: Record<string, unknown>) {
		appName = (data.app_name as string) ?? 'Trackr';
		appLogoUrl = (data.app_logo_url as string) ?? '';
		supportEmail = (data.support_email as string) ?? '';
		defaultTierId = (data.default_support_tier_id as string) ?? null;
		defaultTimezone = (data.default_timezone as string) ?? 'UTC';
		defaultLocale = (data.default_locale as string) ?? 'en';
		signupsEnabled = (data.signups_enabled as boolean) ?? true;
		maintenanceMode = (data.maintenance_mode as boolean) ?? false;
		maxOrgsPerUser = (data.max_orgs_per_user as number) ?? 1;
		maxProjectsPerOrg = (data.max_projects_per_org as number) ?? 10;
		maxMembersPerOrg = (data.max_members_per_org as number) ?? 25;

		const pOrg = data.platform_organization as { id: string; name: string; slug: string } | null;
		platformOrgId = pOrg?.id ?? (data.platform_organization_id as string) ?? null;
		if (pOrg) {
			platformOrgName = pOrg.name;
			platformOrgSlug = pOrg.slug;
		}
	}

	async function save() {
		error = null;
		success = null;
		saving = true;
		try {
			const result = await api.config.updateSystem({
				app_name: appName,
				app_logo_url: appLogoUrl || null,
				support_email: supportEmail || null,
				default_support_tier_id: defaultTierId,
				default_timezone: defaultTimezone,
				default_locale: defaultLocale,
				signups_enabled: signupsEnabled,
				maintenance_mode: maintenanceMode,
				max_orgs_per_user: maxOrgsPerUser,
				max_projects_per_org: maxProjectsPerOrg,
				max_members_per_org: maxMembersPerOrg
			});
			applyConfig(result);
			success = 'System settings saved.';
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to save settings';
		} finally {
			saving = false;
		}
	}

	// ── Platform org ──

	async function savePlatformOrg() {
		if (!platformOrgId || !platformOrgName.trim() || !platformOrgSlug.trim()) return;
		platformOrgSaving = true;
		platformOrgError = null;
		platformOrgSuccess = null;
		try {
			const updated = await api.organizations.update(platformOrgId, {
				name: platformOrgName.trim(),
				slug: platformOrgSlug.trim(),
				domain: platformOrgDomain.trim() || null,
				website_url: platformOrgWebsite.trim() || null
			});
			platformOrgName = updated.name;
			platformOrgSlug = updated.slug;
			platformOrgDomain = updated.domain ?? '';
			platformOrgWebsite = updated.website_url ?? '';
			platformOrgSuccess = 'Organization updated.';
		} catch (e) {
			platformOrgError = e instanceof Error ? e.message : 'Failed to update organization';
		} finally {
			platformOrgSaving = false;
		}
	}

	// ── Tier CRUD ──

	function generateTierSlug() {
		if (!editingTier) {
			tierSlug = tierName
				.toLowerCase()
				.replace(/[^a-z0-9]+/g, '-')
				.replace(/^-|-$/g, '');
		}
	}

	function openAddTier() {
		editingTier = null;
		tierName = '';
		tierSlug = '';
		tierResponseHours = 24;
		tierResolutionHours = 72;
		tierDescription = '';
		tierSortOrder = tiers.length;
		tierActive = true;
		tierError = null;
		tierModalOpen = true;
	}

	function openEditTier(t: Tier) {
		editingTier = t;
		tierName = t.name;
		tierSlug = t.slug;
		tierResponseHours = t.response_time_hours;
		tierResolutionHours = t.resolution_time_hours;
		tierDescription = t.description ?? '';
		tierSortOrder = t.sort_order;
		tierActive = t.is_active;
		tierError = null;
		tierModalOpen = true;
	}

	async function saveTier() {
		if (!tierName.trim() || !tierSlug.trim()) return;
		tierSaving = true;
		tierError = null;
		try {
			const input: CreateTierInput = {
				name: tierName.trim(),
				slug: tierSlug.trim(),
				response_time_hours: tierResponseHours,
				resolution_time_hours: tierResolutionHours,
				description: tierDescription.trim() || null,
				sort_order: tierSortOrder,
				is_active: tierActive
			};
			if (editingTier) {
				await api.config.updateTier(editingTier.id, input);
			} else {
				await api.config.createTier(input);
			}
			tiers = await api.config.getTiers();
			tierModalOpen = false;
		} catch (e) {
			tierError = e instanceof Error ? e.message : 'Failed to save tier';
		} finally {
			tierSaving = false;
		}
	}

	async function deleteTier(id: string) {
		deletingTierId = id;
		try {
			await api.config.deleteTier(id);
			tiers = await api.config.getTiers();
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to delete tier';
		} finally {
			deletingTierId = null;
		}
	}

	// ── Helpers ──

	function defaultTierLabel(): string {
		if (!defaultTierId) return 'None';
		const t = tiers.find((t) => t.id === defaultTierId);
		return t ? t.name : 'Unknown';
	}

	let loaded = false;

	$effect(() => {
		if (loaded) return;
		if (!auth.isAuthenticated) return;
		if (!auth.isOwner) {
			loading = false;
			loaded = true;
			return;
		}
		loaded = true;
		(async () => {
			try {
				const [configData, tierList] = await Promise.all([
					api.config.getSystem(),
					api.config.getTiers()
				]);
				applyConfig(configData);
				tiers = tierList;

				if (platformOrgId) {
					try {
						const org = await api.organizations.getById(platformOrgId);
						platformOrgName = org.name;
						platformOrgSlug = org.slug;
						platformOrgDomain = org.domain ?? '';
						platformOrgWebsite = org.website_url ?? '';
					} catch {
						// platform org details not available
					}
				}
			} catch (e) {
				error = e instanceof Error ? e.message : 'Failed to load system config';
			} finally {
				loading = false;
			}
		})();
	});
</script>

{#snippet toggle(checked: boolean, onToggle: () => void, label: string, extra?: import('svelte').Snippet)}
	<button type="button" class="flex items-center gap-3" onclick={onToggle}>
		<span class="flex h-4 w-4 shrink-0 items-center justify-center border transition-colors
			{checked ? 'border-accent bg-accent' : 'border-surface-border bg-surface hover:border-sidebar-icon/30'}">
			{#if checked}{@html checkSvg}{/if}
		</span>
		<span class="text-xs text-sidebar-text">{label}</span>
	</button>
	{#if extra}{@render extra()}{/if}
{/snippet}

<div class="mx-auto w-full max-w-[900px]">
	<div class="flex items-center justify-between border-b border-surface-border px-6 py-4">
		<h1 class="text-sm font-semibold text-sidebar-text">System Settings</h1>
	</div>

	{#if !auth.isOwner}
		<p class="px-6 py-8 text-center text-sm text-sidebar-icon">
			Access denied. Only the platform owner can manage system settings.
		</p>
	{:else if loading}
		<p class="px-6 py-8 text-center text-sm text-sidebar-icon">Loading...</p>
	{:else}
		<!-- Tab Bar -->
		<div class="flex border-b border-surface-border bg-surface-hover/40 px-6">
			{#each tabs as tab (tab.key)}
				<button
					class="relative px-4 py-2.5 text-xs font-medium transition-colors {activeTab === tab.key
						? 'text-accent after:absolute after:bottom-0 after:left-0 after:h-[2px] after:w-full after:bg-accent'
						: 'text-sidebar-icon hover:text-sidebar-text'}"
					onclick={() => { activeTab = tab.key; error = null; success = null; }}
				>
					{tab.label}
				</button>
			{/each}
		</div>

		<div class="p-6">
			<!-- Support Tiers -->
			{#if activeTab === 'tiers'}
				<section>
					<div class="mb-4 flex items-center justify-between">
						<h2 class="text-xs font-semibold uppercase tracking-wider text-sidebar-text">Support Tiers</h2>
						<button class={btnPrimary} onclick={openAddTier}>Add tier</button>
					</div>

					{#if tiers.length === 0}
						<p class="py-6 text-center text-xs text-sidebar-icon">No tiers configured.</p>
					{:else}
						<div class="overflow-x-auto">
							<table class="w-full text-xs">
								<thead>
									<tr class="border-b border-surface-border text-left text-[11px] font-medium uppercase tracking-wider text-sidebar-icon">
										<th class="px-3 py-2">Name</th>
										<th class="px-3 py-2">Response</th>
										<th class="px-3 py-2">Resolution</th>
										<th class="px-3 py-2">Order</th>
										<th class="px-3 py-2">Status</th>
										<th class="px-3 py-2"></th>
									</tr>
								</thead>
								<tbody>
									{#each tiers as t (t.id)}
										<tr class="border-b border-surface-border/50 transition-colors hover:bg-surface-hover/50">
											<td class="px-3 py-2.5">
												<div>
													<span class="font-medium text-sidebar-text">{t.name}</span>
													<span class="ml-1.5 text-[10px] text-sidebar-icon">({t.slug})</span>
												</div>
												{#if t.description}
													<p class="mt-0.5 text-[10px] text-sidebar-icon">{t.description}</p>
												{/if}
											</td>
											<td class="px-3 py-2.5 text-sidebar-text">{t.response_time_hours}h</td>
											<td class="px-3 py-2.5 text-sidebar-text">{t.resolution_time_hours}h</td>
											<td class="px-3 py-2.5 text-sidebar-icon">{t.sort_order}</td>
											<td class="px-3 py-2.5">
												<span class="text-[10px] font-medium {t.is_active ? 'text-green-600' : 'text-sidebar-icon'}">
													{t.is_active ? 'Active' : 'Inactive'}
												</span>
											</td>
											<td class="px-3 py-2.5">
												<div class="flex items-center gap-2">
													<button
														class="text-[11px] text-sidebar-icon transition-colors hover:text-accent"
														onclick={() => openEditTier(t)}
													>
														Edit
													</button>
													<button
														class="text-[11px] text-sidebar-icon transition-colors hover:text-red-500"
														disabled={deletingTierId === t.id}
														onclick={() => (confirmDeleteTier = t)}
													>
														{deletingTierId === t.id ? '...' : 'Delete'}
													</button>
												</div>
											</td>
										</tr>
									{/each}
								</tbody>
							</table>
						</div>
					{/if}
				</section>
			{/if}

			<!-- Organization -->
			{#if activeTab === 'organization'}
				<section>
					<h2 class="mb-4 text-xs font-semibold uppercase tracking-wider text-sidebar-text">Platform Organization</h2>
					{#if platformOrgId}
						<p class="mb-4 text-[11px] text-sidebar-icon">
							Your team's organization. Members here have global access across all client organizations.
						</p>
						<form onsubmit={(e) => { e.preventDefault(); savePlatformOrg(); }}>
							<div class="grid max-w-lg grid-cols-2 gap-4">
								<div>
									<label for="porg-name" class={labelClass}>Name</label>
									<input id="porg-name" type="text" required bind:value={platformOrgName} class={inputClass} />
								</div>
								<div>
									<label for="porg-slug" class={labelClass}>Slug</label>
									<input id="porg-slug" type="text" required bind:value={platformOrgSlug} class={inputClass} />
								</div>
								<div>
									<label for="porg-domain" class={labelClass}>Domain</label>
									<input id="porg-domain" type="text" bind:value={platformOrgDomain}
										class={inputClass} placeholder="example.com" />
								</div>
								<div>
									<label for="porg-website" class={labelClass}>Website</label>
									<input id="porg-website" type="text" bind:value={platformOrgWebsite}
										class={inputClass} placeholder="https://..." />
								</div>
							</div>

							{#if platformOrgError}
								<p class="mt-3 text-xs text-red-500">{platformOrgError}</p>
							{/if}
							{#if platformOrgSuccess}
								<p class="mt-3 text-xs text-green-600">{platformOrgSuccess}</p>
							{/if}

							<div class="mt-4 flex justify-end">
								<button type="submit" disabled={platformOrgSaving || !platformOrgName.trim() || !platformOrgSlug.trim()} class={btnPrimary}>
									{platformOrgSaving ? 'Saving...' : 'Save organization'}
								</button>
							</div>
						</form>
					{:else}
						<p class="text-xs text-sidebar-icon">No platform organization configured.</p>
					{/if}
				</section>
			{/if}

			<!-- Branding -->
			{#if activeTab === 'branding'}
				<form onsubmit={(e) => { e.preventDefault(); save(); }}>
					<section>
						<h2 class="mb-4 text-xs font-semibold uppercase tracking-wider text-sidebar-text">Branding</h2>
						<div class="grid max-w-lg grid-cols-2 gap-4">
							<div class="col-span-2 sm:col-span-1">
								<label for="app-name" class={labelClass}>App name</label>
								<input id="app-name" type="text" bind:value={appName} class={inputClass} />
							</div>
							<div class="col-span-2 sm:col-span-1">
								<label for="support-email" class={labelClass}>Support email</label>
								<input id="support-email" type="text" autocomplete="off" data-1p-ignore data-lpignore="true" bind:value={supportEmail}
									class={inputClass} placeholder="support@example.com" />
							</div>
							<div class="col-span-2">
								<label for="app-logo" class={labelClass}>Logo URL</label>
								<input id="app-logo" type="text" bind:value={appLogoUrl}
									class={inputClass} placeholder="https://..." />
							</div>
						</div>
					</section>

					{#if error}
						<p class="mt-4 text-xs text-red-500">{error}</p>
					{/if}
					{#if success}
						<p class="mt-4 text-xs text-green-600">{success}</p>
					{/if}

					<div class="mt-6 flex justify-end border-t border-surface-border pt-4">
						<button type="submit" disabled={saving} class={btnPrimary}>
							{saving ? 'Saving...' : 'Save settings'}
						</button>
					</div>
				</form>
			{/if}

			<!-- Defaults -->
			{#if activeTab === 'defaults'}
				<form onsubmit={(e) => { e.preventDefault(); save(); }} class="space-y-8">
					<section>
						<h2 class="mb-4 text-xs font-semibold uppercase tracking-wider text-sidebar-text">Defaults for New Organizations</h2>
						<div class="grid max-w-lg grid-cols-3 gap-4">
							<div>
								<span class={labelClass}>Default tier</span>
								<div class="relative" data-dropdown>
									<button type="button" class={dropBtnClass} onclick={() => toggleDropdown('default-tier')}>
										<span class="truncate">{defaultTierLabel()}</span>
										{@html chevronSvg}
									</button>
									{#if openDropdown === 'default-tier'}
										<div class={dropPanelClass}>
											<button type="button"
												class="{dropItemBase} {defaultTierId === null ? 'font-medium text-accent' : 'text-sidebar-text'}"
												onmousedown={(e) => { e.preventDefault(); defaultTierId = null; openDropdown = null; }}
											>None</button>
											{#each tiers.filter((t) => t.is_active) as t (t.id)}
												<button type="button"
													class="{dropItemBase} {defaultTierId === t.id ? 'font-medium text-accent' : 'text-sidebar-text'}"
													onmousedown={(e) => { e.preventDefault(); defaultTierId = t.id; openDropdown = null; }}
												>{t.name}</button>
											{/each}
										</div>
									{/if}
								</div>
							</div>
							<div>
								<label for="default-tz" class={labelClass}>Timezone</label>
								<input id="default-tz" type="text" bind:value={defaultTimezone}
									class={inputClass} placeholder="UTC" />
							</div>
							<div>
								<label for="default-locale" class={labelClass}>Locale</label>
								<input id="default-locale" type="text" bind:value={defaultLocale}
									class={inputClass} placeholder="en" />
							</div>
						</div>
					</section>

					<section>
						<h2 class="mb-4 text-xs font-semibold uppercase tracking-wider text-sidebar-text">Feature Flags</h2>
						<div class="space-y-3">
							{@render toggle(signupsEnabled, () => { signupsEnabled = !signupsEnabled; }, 'Signups enabled')}
							<div class="flex items-center gap-3">
								<button type="button" class="flex items-center gap-3" onclick={() => { maintenanceMode = !maintenanceMode; }}>
								<span class="flex h-4 w-4 shrink-0 items-center justify-center border transition-colors
									{maintenanceMode ? 'border-accent bg-accent' : 'border-surface-border bg-surface hover:border-sidebar-icon/30'}">
									{#if maintenanceMode}{@html checkSvg}{/if}
									</span>
									<span class="text-xs text-sidebar-text">Maintenance mode</span>
								</button>
								{#if maintenanceMode}
									<span class="inline-block bg-red-500/10 px-1.5 py-0.5 text-[10px] font-medium text-red-500">ON</span>
								{/if}
							</div>
						</div>
					</section>

					<section>
						<h2 class="mb-4 text-xs font-semibold uppercase tracking-wider text-sidebar-text">Limits</h2>
						<div class="grid max-w-lg grid-cols-3 gap-4">
							<div>
								<label for="max-orgs" class={labelClass}>Max orgs / user</label>
								<input id="max-orgs" type="number" min="1" bind:value={maxOrgsPerUser} class={inputClass} />
							</div>
							<div>
								<label for="max-projects" class={labelClass}>Max projects / org</label>
								<input id="max-projects" type="number" min="1" bind:value={maxProjectsPerOrg} class={inputClass} />
							</div>
							<div>
								<label for="max-members" class={labelClass}>Max members / org</label>
								<input id="max-members" type="number" min="1" bind:value={maxMembersPerOrg} class={inputClass} />
							</div>
						</div>
					</section>

					{#if error}
						<p class="text-xs text-red-500">{error}</p>
					{/if}
					{#if success}
						<p class="text-xs text-green-600">{success}</p>
					{/if}

					<div class="flex justify-end border-t border-surface-border pt-4">
						<button type="submit" disabled={saving} class={btnPrimary}>
							{saving ? 'Saving...' : 'Save settings'}
						</button>
					</div>
				</form>
			{/if}
		</div>
	{/if}
</div>

<!-- Tier Modal -->
{#if tierModalOpen}
	<Modal open={true} onClose={() => (tierModalOpen = false)}>
		<div>
			<div class="border-b border-surface-border px-4 py-3">
				<h2 class="text-sm font-semibold text-sidebar-text">
					{editingTier ? 'Edit Tier' : 'Add Tier'}
				</h2>
			</div>
			<form onsubmit={(e) => { e.preventDefault(); saveTier(); }} class="space-y-4 p-4">
				<div class="grid grid-cols-2 gap-3">
					<div>
						<label for="tier-name" class={labelClass}>Name</label>
						<input id="tier-name" type="text" required bind:value={tierName}
							class={inputClass} placeholder="e.g. Premium"
							oninput={generateTierSlug} />
					</div>
					<div>
						<label for="tier-slug" class={labelClass}>Slug</label>
						<input id="tier-slug" type="text" required bind:value={tierSlug}
							class={inputClass} placeholder="premium" />
					</div>
				</div>

				<div class="grid grid-cols-2 gap-3">
					<div>
						<label for="tier-response" class={labelClass}>Response time (hours)</label>
						<input id="tier-response" type="number" min="1" required
							bind:value={tierResponseHours} class={inputClass} />
					</div>
					<div>
						<label for="tier-resolution" class={labelClass}>Resolution time (hours)</label>
						<input id="tier-resolution" type="number" min="1" required
							bind:value={tierResolutionHours} class={inputClass} />
					</div>
				</div>

				<div>
					<label for="tier-desc" class={labelClass}>Description</label>
					<input id="tier-desc" type="text" bind:value={tierDescription}
						class={inputClass} placeholder="Optional description" />
				</div>

				<div class="grid grid-cols-2 gap-3">
					<div>
						<label for="tier-order" class={labelClass}>Sort order</label>
						<input id="tier-order" type="number" min="0"
							bind:value={tierSortOrder} class={inputClass} />
					</div>
					<div class="flex items-end pb-1">
						<button type="button" class="flex items-center gap-3" onclick={() => { tierActive = !tierActive; }}>
							<span class="flex h-4 w-4 shrink-0 items-center justify-center border transition-colors
							{tierActive ? 'border-accent bg-accent' : 'border-surface-border bg-surface hover:border-sidebar-icon/30'}">
							{#if tierActive}{@html checkSvg}{/if}
							</span>
							<span class="text-xs text-sidebar-text">Active</span>
						</button>
					</div>
				</div>

				{#if tierError}
					<p class="text-xs text-red-500">{tierError}</p>
				{/if}

				<div class="flex justify-end gap-2 border-t border-surface-border pt-4">
					<button type="button" class={btnSecondary} onclick={() => (tierModalOpen = false)}>
						Cancel
					</button>
					<button type="submit" disabled={tierSaving || !tierName.trim() || !tierSlug.trim()} class={btnPrimary}>
						{tierSaving ? 'Saving...' : editingTier ? 'Update tier' : 'Create tier'}
					</button>
				</div>
			</form>
		</div>
	</Modal>
{/if}

<!-- Delete Tier Confirm -->
<ConfirmDialog
	open={confirmDeleteTier !== null}
	title="Delete Tier"
	message="Are you sure you want to delete {confirmDeleteTier?.name ?? 'this tier'}? This action cannot be undone."
	loading={deletingTierId !== null}
	onConfirm={async () => {
		if (!confirmDeleteTier) return;
		await deleteTier(confirmDeleteTier.id);
		confirmDeleteTier = null;
	}}
	onCancel={() => (confirmDeleteTier = null)}
/>
