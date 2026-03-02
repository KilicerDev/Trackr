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
	TicketSlash,
	UserCog,
	UsersRound,
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
			{ label: 'Tickets', icon: Ticket, href: '/tickets' },
			{ label: 'Projects', icon: Files, href: '/projects' },
			{ label: '(Teams)', icon: Users, href: '/teams' },
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
			{ label: '(Ticket Configuration)', icon: TicketSlash, href: '/ticket-configuration' },
			{ label: '(User Management)', icon: UserCog, href: '/user-management' },
			{ label: '(Team Management)', icon: UsersRound, href: '/team-management' },
			{ label: '(System Settings)', icon: Settings, href: '/system-settings' },
			{ label: '(Logs)', icon: List, href: '/logs' }
		]
	}
];

