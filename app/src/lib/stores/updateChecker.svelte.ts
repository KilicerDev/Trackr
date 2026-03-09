type VersionInfo = {
	latest: string;
	releaseUrl: string;
	changelog: string;
	minSupported: string;
	releasedAt: string;
};

function compareVersions(a: string, b: string): number {
	const pa = a.split('.').map(Number);
	const pb = b.split('.').map(Number);
	for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
		const na = pa[i] ?? 0;
		const nb = pb[i] ?? 0;
		if (na !== nb) return na - nb;
	}
	return 0;
}

class UpdateCheckerState {
	currentVersion = __APP_VERSION__;
	latestVersion = $state<string | null>(null);
	releaseUrl = $state<string | null>(null);
	changelog = $state<string | null>(null);
	hasUpdate = $derived(
		this.latestVersion !== null && compareVersions(this.currentVersion, this.latestVersion) < 0
	);
	loading = $state(false);
	dismissed = $state(false);

	async check() {
		if (this.loading) return;
		this.loading = true;
		try {
			const res = await fetch('/api/version-check');
			if (!res.ok) return;
			const data: VersionInfo = await res.json();
			this.latestVersion = data.latest;
			this.releaseUrl = data.releaseUrl;
			this.changelog = data.changelog;
			this.dismissed = false;
		} catch {
			// silently ignore – network errors shouldn't block the app
		} finally {
			this.loading = false;
		}
	}

	dismiss() {
		this.dismissed = true;
	}
}

export const updateChecker = new UpdateCheckerState();
