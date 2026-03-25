const STORAGE_KEY = 'density';

export type Density = 'default' | 'compact' | 'comfortable' | 'cozy';

export const DENSITY_OPTIONS: { key: Density; label: string; description: string }[] = [
	{ key: 'compact', label: 'Compact', description: 'Tighter layout, smaller text' },
	{ key: 'default', label: 'Default', description: 'Standard spacing and font sizes' },
	{ key: 'comfortable', label: 'Comfortable', description: 'Slightly larger text' },
	{ key: 'cozy', label: 'Cozy', description: 'Roomier layout, largest text' }
];

const DENSITY_CLASSES: Density[] = ['compact', 'comfortable', 'cozy'];

function applyToDom(density: Density) {
	if (typeof document === 'undefined') return;
	const cl = document.documentElement.classList;
	for (const c of DENSITY_CLASSES) cl.toggle(c, density === c);
}

function isValid(v: string | null): v is Density {
	return v === 'default' || v === 'compact' || v === 'comfortable' || v === 'cozy';
}

class DensityState {
	current = $state<Density>('default');
	#initialized = false;

	init() {
		if (typeof document === 'undefined' || this.#initialized) return;
		this.#initialized = true;
		const stored = localStorage.getItem(STORAGE_KEY);
		this.current = isValid(stored) ? stored : 'default';
		applyToDom(this.current);
	}

	set(density: Density) {
		this.current = density;
		localStorage.setItem(STORAGE_KEY, density);
		applyToDom(density);
	}
}

export const densityStore = new DensityState();
