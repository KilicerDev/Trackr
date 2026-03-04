<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { getClient } from '$lib/api/client';

	onMount(async () => {
		const supabase = getClient();

		// Handle hash fragment tokens (implicit flow from invite/magic links)
		const hash = window.location.hash;
		if (hash) {
			const params = new URLSearchParams(hash.substring(1));
			const accessToken = params.get('access_token');
			const refreshToken = params.get('refresh_token');

			if (accessToken && refreshToken) {
				const { error } = await supabase.auth.setSession({
					access_token: accessToken,
					refresh_token: refreshToken,
				});

				if (!error) {
					goto('/set-password');
					return;
				}
			}

			// Check for error in hash (e.g. expired token)
			const errorDesc = params.get('error_description');
			if (errorDesc) {
				goto(`/login`);
				return;
			}
		}

		// If we get here with a valid session (code exchange happened server-side),
		// check and redirect
		const { data: { session } } = await supabase.auth.getSession();
		if (session) {
			goto('/set-password');
			return;
		}

		goto('/login');
	});
</script>

<div class="flex min-h-screen items-center justify-center bg-gray-50">
	<p class="text-sm text-gray-400">Setting up your account...</p>
</div>
