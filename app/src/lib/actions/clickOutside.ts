import type { Action } from 'svelte/action';

export type ClickOutsideParams = {
	/** Called when a click occurs outside the element */
	onClickOutside: () => void;
	/** When false, the handler does nothing. Use to only listen while e.g. dropdown is open. Default true. */
	enabled?: boolean;
};

/**
 * Svelte action: run a callback when the user clicks outside the element.
 * Attach to the dropdown container (the element that wraps both trigger and panel).
 *
 * @example
 * ```svelte
 * <div class="relative" use:clickOutside={{ onClickOutside: () => open = false, enabled: open }}>
 *   <button onclick={() => open = !open}>Toggle</button>
 *   {#if open}
 *     <div class="dropdown-panel">...</div>
 *   {/if}
 * </div>
 * ```
 */
export const clickOutside: Action<HTMLElement, ClickOutsideParams> = (node, params) => {
	let current = params;

	function handleClick(e: MouseEvent) {
		if (current.enabled !== false && !node.contains(e.target as Node)) {
			current.onClickOutside();
		}
	}

	document.addEventListener('mousedown', handleClick, true);

	return {
		update(newParams) {
			current = newParams;
		},
		destroy() {
			document.removeEventListener('mousedown', handleClick, true);
		}
	};
};
