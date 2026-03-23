<script lang="ts">
	import Modal from '$lib/components/Modal.svelte';
	import { projectStore } from '$lib/stores/projects.svelte';
	import { notifications } from '$lib/stores/notifications.svelte';
	import { auth } from '$lib/stores/auth.svelte';
	import { api } from '$lib/api';
	import { X, Paperclip } from '@lucide/svelte';
	import AttachmentUploadZone from './AttachmentUploadZone.svelte';

	interface Props {
		organizationId: string | null;
		organizationName: string;
		onClose: () => void;
		onSuccess?: () => void;
	}

	let { organizationId, organizationName, onClose, onSuccess }: Props = $props();

	const PROJECT_STATUSES = ['planning', 'active', 'paused', 'completed', 'archived'] as const;
	const PRESET_COLORS = [
		'#10b981', '#3b82f6', '#8b5cf6', '#f59e0b', '#ef4444',
		'#ec4899', '#06b6d4', '#84cc16', '#f97316', '#6366f1'
	];

	let name = $state('');
	let identifier = $state('');
	let description = $state('');
	let status = $state<string>('planning');
	let color = $state(PRESET_COLORS[0]);
	let startAt = $state('');
	let endAt = $state('');
	let submitting = $state(false);
	let error = $state<string | null>(null);
	let pendingFiles = $state<File[]>([]);

	let openDropdown = $state<string | null>(null);

	const canSubmit = $derived(!!name.trim() && !!identifier.trim() && !!organizationId);

	function autoIdentifier() {
		if (identifier) return;
		identifier = name
			.trim()
			.toUpperCase()
			.replace(/[^A-Z0-9]/g, '')
			.slice(0, 5);
	}

	function toggleDropdown(key: string) {
		openDropdown = openDropdown === key ? null : key;
	}

	$effect(() => {
		if (openDropdown === null) return;
		function onMouseDown(e: MouseEvent) {
			const target = e.target as HTMLElement;
			if (!target.closest('[data-dropdown]')) {
				openDropdown = null;
			}
		}
		document.addEventListener('mousedown', onMouseDown);
		return () => document.removeEventListener('mousedown', onMouseDown);
	});

	function formatStatus(s: string): string {
		return s.charAt(0).toUpperCase() + s.slice(1);
	}

	async function handleSubmit(e: Event) {
		e.preventDefault();
		if (!canSubmit || !organizationId || submitting) return;
		submitting = true;
		error = null;
		const n = notifications.action('Creating project');
		try {
			const project = await projectStore.create({
				name: name.trim(),
				identifier: identifier.trim().toUpperCase(),
				description: description.trim() || undefined,
				owner_id: auth.user!.id,
				organization_id: organizationId,
				status,
				color: color || undefined,
				start_at: startAt ? `${startAt}T00:00:00.000Z` : undefined,
				end_at: endAt ? `${endAt}T00:00:00.000Z` : undefined
			});
			// Upload pending files
			if (project && pendingFiles.length > 0 && auth.user) {
				for (const file of pendingFiles) {
					try {
						await api.attachments.upload(file, 'project', (project as Record<string, unknown>).id as string, organizationId, auth.user.id);
					} catch {
						/* silent */
					}
				}
			}
			n.success('Project created');
			onSuccess?.();
			onClose();
		} catch (err) {
			n.error('Failed', err instanceof Error ? err.message : 'Failed to create project');
			error = err instanceof Error ? err.message : 'Failed to create project';
		} finally {
			submitting = false;
		}
	}

	const labelClass =
		'mb-1.5 block text-[11px] font-medium uppercase tracking-wider text-sidebar-icon';
	const inputClass =
		'w-full border border-surface-border bg-surface px-3 py-2 text-xs text-sidebar-text outline-none transition-colors placeholder:text-sidebar-icon/70 focus:border-sidebar-icon/30 hover:border-sidebar-icon/30';
	const dropdownBtnClass =
		'flex w-full cursor-pointer items-center justify-between gap-2 border border-surface-border bg-surface px-3 py-2 text-xs text-sidebar-text transition-colors hover:border-sidebar-icon/30 hover:bg-surface-hover';
	const dropdownPanelClass =
		'absolute left-0 z-20 mt-1.5 max-h-56 w-full min-w-[10rem] overflow-y-auto border border-surface-border bg-surface py-1';
	const dropdownItemBase =
		'flex w-full items-center px-4 py-2.5 text-left text-xs transition-colors hover:bg-surface-hover';
</script>

<Modal open={true} {onClose}>
	<div>
		<div class="border-b border-surface-border px-4 py-3">
			<h2 class="text-sm font-semibold text-sidebar-text">Create project</h2>
			{#if organizationName}
				<p class="mt-0.5 text-[11px] text-muted">{organizationName}</p>
			{/if}
		</div>
		<div class="p-4">
			{#if organizationId === null}
				<p class="mb-4 text-xs text-sidebar-icon">
					Select an organization first to create a project.
				</p>
				<button
					type="button"
					class="border border-surface-border bg-surface px-4 py-2 text-xs font-medium text-sidebar-text transition-colors hover:border-sidebar-icon/30 hover:bg-surface-hover"
					onclick={onClose}
				>
					Close
				</button>
			{:else}
				<form onsubmit={handleSubmit} class="space-y-4">
					<div>
						<label for="create-project-name" class={labelClass}>Name</label>
						<input
							id="create-project-name"
							type="text"
							required
							bind:value={name}
							onblur={autoIdentifier}
							class={inputClass}
							placeholder="e.g. Marketing Website"
						/>
					</div>

					<div class="grid grid-cols-2 gap-3">
						<div>
							<label for="create-project-identifier" class={labelClass}>Identifier</label>
							<input
								id="create-project-identifier"
								type="text"
								required
								maxlength="10"
								bind:value={identifier}
								class="{inputClass} uppercase"
								placeholder="e.g. MKTG"
							/>
						</div>

						<div>
							<span class={labelClass}>Status</span>
							<div class="relative" data-dropdown>
								<button
									type="button"
									class={dropdownBtnClass}
									onclick={() => toggleDropdown('status')}
								>
									<span class="truncate">{formatStatus(status)}</span>
									<svg
										class="h-4 w-4 shrink-0 text-sidebar-icon transition-transform {openDropdown ===
										'status'
											? 'rotate-180'
											: ''}"
										fill="none"
										stroke="currentColor"
										viewBox="0 0 24 24"
									>
										<path
											stroke-linecap="round"
											stroke-linejoin="round"
											stroke-width="2"
											d="M19 9l-7 7-7-7"
										/>
									</svg>
								</button>
								{#if openDropdown === 'status'}
									<div class={dropdownPanelClass}>
										{#each PROJECT_STATUSES as s (s)}
											<button
												type="button"
												class="{dropdownItemBase} {status === s
													? 'font-medium text-accent'
													: 'text-sidebar-text'}"
												onmousedown={(e) => {
													e.preventDefault();
													status = s;
													openDropdown = null;
												}}
											>
												{formatStatus(s)}
											</button>
										{/each}
									</div>
								{/if}
							</div>
						</div>
					</div>

					<div>
						<label for="create-project-description" class={labelClass}>Description</label>
						<textarea
							id="create-project-description"
							bind:value={description}
							rows="3"
							class="{inputClass} resize-none"
							placeholder="Optional project description"
						></textarea>
					</div>

					<div>
						<span class={labelClass}>Color</span>
						<div class="flex items-center gap-2">
							{#each PRESET_COLORS as c (c)}
								<button
									type="button"
									aria-label="Select color {c}"
									class="h-6 w-6 rounded-full border-2 transition-transform hover:scale-110 {color ===
									c
										? 'border-sidebar-text scale-110'
										: 'border-transparent'}"
									style="background-color: {c}"
									onclick={() => (color = c)}
								></button>
							{/each}
						</div>
					</div>

					<div class="grid grid-cols-2 gap-3">
						<div>
							<label for="create-project-start" class={labelClass}>Start date</label>
							<input
								id="create-project-start"
								type="date"
								bind:value={startAt}
								class={inputClass}
							/>
						</div>
						<div>
							<label for="create-project-end" class={labelClass}>End date</label>
							<input
								id="create-project-end"
								type="date"
								bind:value={endAt}
								class={inputClass}
							/>
						</div>
					</div>

					<div>
						<span class={labelClass}>Attachments</span>
						<AttachmentUploadZone
							onFilesSelected={(files) => { pendingFiles = [...pendingFiles, ...files]; }}
							disabled={submitting}
						/>
						{#if pendingFiles.length > 0}
							<div class="mt-2 flex flex-wrap gap-1">
								{#each pendingFiles as file, i (file.name + i)}
									<span class="flex items-center gap-1 border border-surface-border bg-surface px-2 py-0.5 text-[10px] text-sidebar-text">
										<Paperclip size={10} />
										<span class="max-w-[120px] truncate">{file.name}</span>
										<button type="button" class="text-muted hover:text-red-500" onclick={() => { pendingFiles = pendingFiles.filter((_, idx) => idx !== i); }}>
											<X size={10} />
										</button>
									</span>
								{/each}
							</div>
						{/if}
					</div>

					{#if error}
						<p class="text-xs text-red-500">{error}</p>
					{/if}

					<div class="flex justify-end gap-2 border-t border-surface-border pt-4">
						<button
							type="button"
							class="border border-surface-border bg-surface px-4 py-2 text-xs font-medium text-sidebar-text transition-colors hover:border-sidebar-icon/30 hover:bg-surface-hover"
							onclick={onClose}
						>
							Cancel
						</button>
						<button
							type="submit"
							disabled={!canSubmit || submitting}
							class="bg-accent px-4 py-2 text-xs font-medium text-white transition-colors hover:bg-accent/90 disabled:opacity-50"
						>
							{submitting ? 'Creating…' : 'Create project'}
						</button>
					</div>
				</form>
			{/if}
		</div>
	</div>
</Modal>
