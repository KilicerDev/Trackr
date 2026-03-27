const STORAGE_KEY = 'density';

export type Density = 'default' | 'compact' | 'comfortable';

export const DENSITY_OPTIONS: { key: Density; label: string; description: string }[] = [
	{ key: 'compact', label: 'Compact', description: 'Tighter padding and gaps' },
	{ key: 'default', label: 'Default', description: 'Standard spacing' },
	{ key: 'comfortable', label: 'Comfortable', description: 'More breathing room' }
];

const CSS_CLASSES = ['spacing-compact', 'spacing-comfortable'] as const;

function applyToDom(density: Density) {
	if (typeof document === 'undefined') return;
	const cl = document.documentElement.classList;
	for (const c of CSS_CLASSES) cl.remove(c);
	if (density === 'compact') cl.add('spacing-compact');
	else if (density === 'comfortable') cl.add('spacing-comfortable');
}

function isValid(v: string | null): v is Density {
	return v === 'default' || v === 'compact' || v === 'comfortable';
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
