import type { Component } from 'svelte';
import {
	Circle,
	CircleDashed,
	CircleDot,
	CircleDotDashed,
	CircleCheck,
	CircleX,
	Clock,
	CirclePause,
	Archive
} from '@lucide/svelte';

export type StatusIconInfo = {
	icon: Component<{ size?: number; class?: string }>;
	className: string;
};

export const taskStatusIcons: Record<string, StatusIconInfo> = {
	backlog: { icon: CircleDashed, className: 'text-gray-400 dark:text-gray-500' },
	todo: { icon: Circle, className: 'text-gray-500 dark:text-gray-400' },
	in_progress: { icon: CircleDotDashed, className: 'text-pink-500 dark:text-pink-400' },
	paused: { icon: CirclePause, className: 'text-yellow-500 dark:text-yellow-400' },
	in_review: { icon: CircleDot, className: 'text-purple-500 dark:text-purple-400' },
	done: { icon: CircleCheck, className: 'text-green-500 dark:text-green-400' },
	cancelled: { icon: CircleX, className: 'text-gray-400 dark:text-gray-500' }
};

export const ticketStatusIcons: Record<string, StatusIconInfo> = {
	open: { icon: Circle, className: 'text-blue-500 dark:text-blue-400' },
	in_progress: { icon: CircleDotDashed, className: 'text-pink-500 dark:text-pink-400' },
	paused: { icon: CirclePause, className: 'text-yellow-500 dark:text-yellow-400' },
	waiting_on_customer: { icon: Clock, className: 'text-amber-500 dark:text-amber-400' },
	waiting_on_agent: { icon: Clock, className: 'text-orange-500 dark:text-orange-400' },
	resolved: { icon: CircleCheck, className: 'text-green-500 dark:text-green-400' },
	closed: { icon: CircleX, className: 'text-gray-400 dark:text-gray-500' }
};

export const projectStatusIcons: Record<string, StatusIconInfo> = {
	planning: { icon: CircleDashed, className: 'text-blue-500 dark:text-blue-400' },
	active: { icon: CircleDot, className: 'text-green-500 dark:text-green-400' },
	paused: { icon: CirclePause, className: 'text-yellow-500 dark:text-yellow-400' },
	completed: { icon: CircleCheck, className: 'text-green-500 dark:text-green-400' },
	archived: { icon: Archive, className: 'text-gray-400 dark:text-gray-500' }
};

export const defaultStatusIcon: StatusIconInfo = {
	icon: Circle,
	className: 'text-gray-400 dark:text-gray-500'
};
