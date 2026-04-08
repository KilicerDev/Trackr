const SCHEME_KEY = 'mode';
const ACCENT_KEY = 'accent-color';

export type ColorScheme = 'light' | 'dark' | 'midnight' | 'catppuccin' | 'gruvbox' | 'github' | 'rosepine' | 'tokyonight';
export const COLOR_SCHEMES: { key: ColorScheme; label: string }[] = [
	{ key: 'light', label: 'Light' },
	{ key: 'dark', label: 'Dark' },
	{ key: 'midnight', label: 'Midnight' },
	{ key: 'catppuccin', label: 'Catppuccin Mocha' },
	{ key: 'gruvbox', label: 'Gruvbox Dark' },
	{ key: 'github', label: 'GitHub Dark' },
	{ key: 'rosepine', label: 'Rosé Pine' },
	{ key: 'tokyonight', label: 'Tokyo Night' }
];

const DEFAULT_ACCENT = '#ff4867';

function isDark(scheme: ColorScheme) {
	return scheme !== 'light';
}


const SCHEME_CLASSES = ['midnight', 'catppuccin', 'gruvbox', 'github', 'rosepine', 'tokyonight'] as const;

function applyScheme(scheme: ColorScheme) {
	if (typeof document === 'undefined') return;
	const cl = document.documentElement.classList;
	cl.toggle('dark', isDark(scheme));
	for (const c of SCHEME_CLASSES) cl.toggle(c, scheme === c);
}

function applyAccent(color: string) {
	if (typeof document === 'undefined') return;
	document.documentElement.style.setProperty('--color-accent', color);
}

function isValidScheme(v: string | null): v is ColorScheme {
	return COLOR_SCHEMES.some((s) => s.key === v);
}

function isValidHex(v: string): boolean {
	return /^#[0-9a-fA-F]{6}$/.test(v);
}

class ThemeState {
	mode = $state<ColorScheme>('light');
	accentColor = $state<string>(DEFAULT_ACCENT);
	#initialized = false;

	get isDark() {
		return isDark(this.mode);
	}

	get defaultAccent() {
		return DEFAULT_ACCENT;
	}

	init() {
		if (typeof document === 'undefined' || this.#initialized) return;
		this.#initialized = true;

		const storedScheme = localStorage.getItem(SCHEME_KEY);
		this.mode = isValidScheme(storedScheme) ? storedScheme : 'light';
		applyScheme(this.mode);

		const storedAccent = localStorage.getItem(ACCENT_KEY);
		if (storedAccent && isValidHex(storedAccent)) {
			this.accentColor = storedAccent;
			applyAccent(storedAccent);
		}
	}

	setScheme(scheme: ColorScheme) {
		this.mode = scheme;
		localStorage.setItem(SCHEME_KEY, scheme);
		applyScheme(scheme);
	}

	setAccentColor(color: string) {
		if (!isValidHex(color)) return;
		this.accentColor = color;
		localStorage.setItem(ACCENT_KEY, color);
		applyAccent(color);
	}

	resetAccent() {
		this.accentColor = DEFAULT_ACCENT;
		localStorage.removeItem(ACCENT_KEY);
		applyAccent(DEFAULT_ACCENT);
	}

	toggle() {
		this.setScheme(this.isDark ? 'light' : 'dark');
	}
}

export const theme = new ThemeState();
