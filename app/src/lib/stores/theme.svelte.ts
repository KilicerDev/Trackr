const STORAGE_KEY = 'mode';
type ThemeMode = 'dark' | 'light';

function applyToDom(mode: ThemeMode) {
	if (typeof document === 'undefined') return;
	document.documentElement.classList.toggle('dark', mode === 'dark');
}

class ThemeState {
	mode = $state<ThemeMode>('light');
	#initialized = false;

	init() {
		if (typeof document === 'undefined' || this.#initialized) return;
		this.#initialized = true;
		const stored = localStorage.getItem(STORAGE_KEY);
		const mode: ThemeMode =
			stored === 'dark' || stored === 'light' ? stored : 'light';
		this.mode = mode;
		applyToDom(mode);
	}

	setMode(mode: ThemeMode) {
		this.mode = mode;
		localStorage.setItem(STORAGE_KEY, mode);
		applyToDom(mode);
	}

	toggle() {
		this.setMode(this.mode === 'dark' ? 'light' : 'dark');
	}
}

export const theme = new ThemeState();
