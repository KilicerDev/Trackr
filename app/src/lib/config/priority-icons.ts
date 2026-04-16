import type { Component } from 'svelte';
import { AlertCircle, ChevronUp, Equal, ChevronDown, Minus } from '@lucide/svelte';

export type PriorityIconInfo = {
	icon: Component<{ size?: number; class?: string }>;
	className: string;
};

export const priorityIcons: Record<string, PriorityIconInfo> = {
	urgent: { icon: AlertCircle, className: 'text-red-500 dark:text-red-400' },
	high: { icon: ChevronUp, className: 'text-orange-500 dark:text-orange-400' },
	medium: { icon: Equal, className: 'text-yellow-500 dark:text-yellow-400' },
	low: { icon: ChevronDown, className: 'text-blue-500 dark:text-blue-400' },
	none: { icon: Minus, className: 'text-gray-400 dark:text-gray-500' }
};

export const defaultPriorityIcon: PriorityIconInfo = {
	icon: Minus,
	className: 'text-gray-400 dark:text-gray-500'
};
