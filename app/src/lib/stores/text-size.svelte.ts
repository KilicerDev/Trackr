const STORAGE_KEY = 'text-size';

export type TextSize = 'default' | 'compact' | 'comfortable';

export const TEXT_SIZE_OPTIONS: { key: TextSize; label: string; description: string }[] = [
	{ key: 'compact', label: 'Small', description: 'Smaller text across the UI' },
	{ key: 'default', label: 'Default', description: 'Standard font sizes' },
	{ key: 'comfortable', label: 'Large', description: 'Larger, easier to read text' }
];

const CSS_CLASSES = ['text-compact', 'text-comfortable'] as const;

function applyToDom(size: TextSize) {
	if (typeof document === 'undefined') return;
	const cl = document.documentElement.classList;
	for (const c of CSS_CLASSES) cl.remove(c);
	if (size === 'compact') cl.add('text-compact');
	else if (size === 'comfortable') cl.add('text-comfortable');
}

function isValid(v: string | null): v is TextSize {
	return v === 'default' || v === 'compact' || v === 'comfortable';
}

class TextSizeState {
	current = $state<TextSize>('default');
	#initialized = false;

	init() {
		if (typeof document === 'undefined' || this.#initialized) return;
		this.#initialized = true;
		const stored = localStorage.getItem(STORAGE_KEY);
		this.current = isValid(stored) ? stored : 'default';
		applyToDom(this.current);
	}

	set(size: TextSize) {
		this.current = size;
		localStorage.setItem(STORAGE_KEY, size);
		applyToDom(size);
	}
}

export const textSizeStore = new TextSizeState();
