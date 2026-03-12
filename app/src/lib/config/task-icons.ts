import type { Component } from 'svelte';
import { AlignJustify, Bug, Sparkles, Triangle, Diamond } from '@lucide/svelte';

export const typeIcons: Record<string, Component<{ size?: number; class?: string }>> = {
	task: AlignJustify,
	bug: Bug,
	feature: Sparkles,
	improvement: Triangle,
	epic: Diamond
};

export const defaultTypeIcon = AlignJustify;
