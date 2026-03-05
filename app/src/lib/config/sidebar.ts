import type { Component } from 'svelte';
import {
	LayoutDashboard,
	Ticket,
	Files,
	Users,
	MessageCircle,
	BookOpen,
	Library,
	GraduationCap,
	Building2,
	TicketSlash,
	UserCog,
	UsersRound,
	Shield,
	Settings,
	List
} from '@lucide/svelte';

export type SidebarItem = {
	label: string;
	icon: Component<{ size?: number; class?: string }>;
	href: string;
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
			{ label: 'Support Tickets', icon: Ticket, href: '/tickets' },
			{ label: 'Projects', icon: Files, href: '/projects' },
			{ label: '(Chats)', icon: MessageCircle, href: '/chats' }
		]
	},
	{
		title: 'Knowledge Base',
		items: [
			{ label: '(FAQ-Articles)', icon: BookOpen, href: '/faq-articles' },
			{ label: '(Solutions Database)', icon: Library, href: '/solutions-database' },
			{ label: '(Tutorials)', icon: GraduationCap, href: '/tutorials' }
		]
	},
	{
		title: 'Administration',
		items: [
			{ label: 'Organizations', icon: Building2, href: '/organizations' },
			{ label: 'Roles', icon: Shield, href: '/roles' },
			{ label: 'User Management', icon: UserCog, href: '/user-management' },
			{ label: 'System Settings', icon: Settings, href: '/system-settings' },
			{ label: '(Logs)', icon: List, href: '/logs' }
		]
	}
];

