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

			goto(localizeHref(data.redirectTo));
		} catch (e) {
			error = e instanceof Error ? e.message : 'Something went wrong';
		} finally {
			loading = false;
		}
	}
</script>

<div class="relative min-h-screen bg-gray-50 font-mono">
	<div class="flex min-h-screen items-center justify-center px-4">
		<div class="w-full max-w-md rounded-lg border border-gray-200 bg-white px-10 py-10">
			<div class="flex flex-col items-center">
				<div class="mb-1 flex items-center gap-2">
					<img src={logo} alt="Trackr" class="h-8" />
					<span class="text-xl font-bold tracking-widest text-gray-800">TRACKR</span>
				</div>

				<p class="mb-8 mt-2 text-sm text-gray-500">Set your password to complete your account setup.</p>

				{#if error}
					<div class="mb-4 w-full rounded-md border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-600">
						{error}
					</div>
				{/if}

				<form
					onsubmit={(e) => { e.preventDefault(); setPassword(); }}
					class="w-full space-y-5"
				>
					<div>
						<label for="password" class="mb-1.5 block text-xs font-semibold tracking-wide text-accent">
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
								class="w-full rounded-lg bg-gray-100 px-4 py-3 pr-11 text-sm text-gray-700 outline-none placeholder:text-gray-400"
							/>
							<button
								type="button"
								class="absolute top-1/2 right-3 -translate-y-1/2 cursor-pointer text-gray-400 transition-colors hover:text-gray-600"
								onclick={() => (showPassword = !showPassword)}
								tabindex={-1}
							>
								{#if showPassword}
									<EyeOff size={18} />
								{:else}
									<Eye size={18} />
								{/if}
							</button>
						</div>
					</div>

					<div>
						<label for="confirm-password" class="mb-1.5 block text-xs font-semibold tracking-wide text-accent">
							Confirm Password
						</label>
						<input
							id="confirm-password"
							type={showPassword ? 'text' : 'password'}
							placeholder="Repeat your password"
							bind:value={confirmPassword}
							required
							minlength={6}
							class="w-full rounded-lg bg-gray-100 px-4 py-3 text-sm text-gray-700 outline-none placeholder:text-gray-400"
						/>
						{#if confirmPassword && password !== confirmPassword}
							<p class="mt-1.5 text-xs text-red-500">Passwords do not match.</p>
						{/if}
					</div>

					<button
						type="submit"
						disabled={loading || !valid}
						class="flex w-full cursor-pointer items-center justify-center rounded-lg bg-accent py-3.5 text-sm font-semibold tracking-wide text-white shadow-md shadow-accent/30 transition-opacity hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-60"
					>
						{#if loading}
							<LoaderCircle size={18} class="animate-spin" />
						{:else}
							Set Password & Continue
						{/if}
					</button>
				</form>
			</div>
		</div>
	</div>
</div>
