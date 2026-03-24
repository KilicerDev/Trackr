const STORAGE_KEY = 'font';

export type FontFamily = 'geist' | 'geist-mono';

const FONT_MAP: Record<FontFamily, string> = {
	geist: "'Geist', sans-serif",
	'geist-mono': "'GeistMono', monospace"
};

function applyToDom(font: FontFamily) {
	if (typeof document === 'undefined') return;
	document.documentElement.style.setProperty('--font-sans', FONT_MAP[font]);
}

class FontState {
	current = $state<FontFamily>('geist');
	#initialized = false;

	init() {
		if (typeof document === 'undefined' || this.#initialized) return;
		this.#initialized = true;
		const stored = localStorage.getItem(STORAGE_KEY);
		const font: FontFamily = stored === 'geist' || stored === 'geist-mono' ? stored : 'geist';
		this.current = font;
		applyToDom(font);
	}

	set(font: FontFamily) {
		this.current = font;
		localStorage.setItem(STORAGE_KEY, font);
		applyToDom(font);
	}
}

export const fontStore = new FontState();
