<script lang="ts">
	import { goto } from '$app/navigation';
	import { Eye, EyeOff, LoaderCircle } from '@lucide/svelte';
	import { getClient } from '$lib/api/client';
	import { localizeHref } from '$lib/paraglide/runtime';
	import logo from '$lib/assets/logo.png';
	import type { PageData } from './$types';

	let { data }: { data: PageData } = $props();

	let password = $state('');
	let confirmPassword = $state('');
	let showPassword = $state(false);
	let loading = $state(false);
	let error = $state<string | null>(null);

	const valid = $derived(
		password.length >= 6 && password === confirmPassword
	);

	async function setPassword() {
		if (!valid) return;
		loading = true;
		error = null;

		try {
		const supabase = getClient();
		const { error: updateErr } = await supabase.auth.updateUser({
			password
		});

		if (updateErr) {
			error = updateErr.message;
			return;
		}

		// Accept pending invitation if one exists (skip for password resets with no invitation)
		const { data: rpcResult } = await supabase.rpc('accept_invitation');

		if (rpcResult && !rpcResult.success && rpcResult.error !== 'No pending invitation found') {
			error = rpcResult.error ?? 'Failed to accept invitation';
			return;
		}

		goto(localizeHref(data.redirectTo));
		} catch (e) {
			error = e instanceof Error ? e.message : 'Something went wrong';
		} finally {
			loading = false;
		}
	}
</script>

<div class="relative min-h-screen bg-page-bg">
	<div class="flex min-h-screen items-center justify-center px-4">
		<div class="w-full max-w-md rounded border border-surface-border bg-surface px-10 py-10 shadow-xl">
			<div class="flex flex-col items-center">
				<div class="mb-1 flex items-center gap-2">
					<img src={logo} alt="Trackr" class="h-8" />
					<span class="text-lg font-bold tracking-widest text-sidebar-text">TRACKR</span>
				</div>

				<p class="mb-6 mt-2 text-sm text-muted">Set your password to complete your account setup.</p>

				{#if error}
					<div class="mb-4 w-full rounded border border-red-400/30 bg-red-400/10 px-3 py-2.5 text-sm text-red-400">
						{error}
					</div>
				{/if}

				<form
					onsubmit={(e) => { e.preventDefault(); setPassword(); }}
					class="w-full space-y-4"
				>
					<div>
						<label for="password" class="mb-1.5 block text-xs font-semibold uppercase tracking-[0.08em] text-accent">
							Password
						</label>
						<div class="relative">
							<input
								id="password"
								type={showPassword ? 'text' : 'password'}
								placeholder="At least 6 characters"
								bind:value={password}
								required
								minlength={6}
								class="w-full rounded-sm bg-surface-hover/40 px-2.5 py-1.5 pr-9 text-base text-sidebar-text outline-none placeholder:text-muted/30 focus:bg-surface-hover/60"
							/>
							<button
								type="button"
								class="absolute top-1/2 right-2.5 -translate-y-1/2 cursor-pointer text-muted/40 transition-all duration-150 hover:text-sidebar-text"
								onclick={() => (showPassword = !showPassword)}
								tabindex={-1}
							>
								{#if showPassword}
									<EyeOff size={14} />
								{:else}
									<Eye size={14} />
								{/if}
							</button>
						</div>
					</div>

					<div>
						<label for="confirm-password" class="mb-1.5 block text-xs font-semibold uppercase tracking-[0.08em] text-accent">
							Confirm Password
						</label>
						<input
							id="confirm-password"
							type={showPassword ? 'text' : 'password'}
							placeholder="Repeat your password"
							bind:value={confirmPassword}
							required
							minlength={6}
							class="w-full rounded-sm bg-surface-hover/40 px-2.5 py-1.5 text-base text-sidebar-text outline-none placeholder:text-muted/30 focus:bg-surface-hover/60"
						/>
						{#if confirmPassword && password !== confirmPassword}
							<p class="mt-1.5 text-xs text-red-400">Passwords do not match.</p>
						{/if}
					</div>

					<button
						type="submit"
						disabled={loading || !valid}
						class="flex h-8 w-full cursor-pointer items-center justify-center rounded-sm bg-accent text-sm font-semibold text-white transition-all duration-150 hover:bg-accent/90 disabled:cursor-not-allowed disabled:opacity-30"
					>
						{#if loading}
							<LoaderCircle size={14} class="animate-spin" />
						{:else}
							Set Password & Continue
						{/if}
					</button>
				</form>
			</div>
		</div>
	</div>
</div>
