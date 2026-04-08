import type { Component } from 'svelte';
import {
	LayoutDashboard,
	Ticket,
	Files,
	SquareCheckBig,
	BookOpen,
	Building2,
	UserCog,
	Shield,
	Settings,
	List
} from '@lucide/svelte';

export type SidebarItem = {
	label: string;
	icon: Component<{ size?: number; class?: string }>;
	href: string;
	requiredPermission?: { resource: string; action: string };
};

export type SidebarSection = {
	title: string;
	items: SidebarItem[];
};

export const sidebarSections: SidebarSection[] = [
	{
		title: 'Routes',
		items: [
			{ label: 'Dashboard', icon: LayoutDashboard, href: '/' },
			{ label: 'Support Tickets', icon: Ticket, href: '/tickets', requiredPermission: { resource: 'support_tickets', action: 'read' } },
			{ label: 'Projects', icon: Files, href: '/projects' },
			{ label: 'Tasks', icon: SquareCheckBig, href: '/tasks' },
		]
	},
	{
		title: 'Knowledge Base',
		items: [
			{ label: 'Wiki', icon: BookOpen, href: '/wiki' }
		]
	},
	{
		title: 'Administration',
		items: [
			{ label: 'Organizations', icon: Building2, href: '/organizations' },
			{ label: 'Roles', icon: Shield, href: '/roles' },
			{ label: 'User Management', icon: UserCog, href: '/user-management' },
			{ label: 'System Settings', icon: Settings, href: '/system-settings' },
			{ label: 'Logs', icon: List, href: '/logs' }
		]
	}
];

