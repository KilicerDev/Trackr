<svelte:head><title>Dashboard – Trackr</title></svelte:head>

<script lang="ts">
	import { auth } from '$lib/stores/auth.svelte';
	import { api } from '$lib/api';
	import type { Project } from '$lib/stores/projects.svelte';
	import type { Task } from '$lib/stores/tasks.svelte';
	import type { Ticket } from '$lib/stores/tickets.svelte';
	import { localizeHref } from '$lib/paraglide/runtime';
	import DashboardChart from '$lib/components/DashboardChart.svelte';
	import {
		FolderKanban,
		ListChecks,
		Ticket as TicketIcon,
		ShieldAlert,
		ArrowRight,
		Circle,
		Loader2
	} from '@lucide/svelte';
	import type { ChartData } from 'chart.js';

	const TASK_STATUSES = ['backlog', 'todo', 'in_progress', 'in_review', 'done', 'cancelled'] as const;
	const TICKET_PRIORITIES = ['low', 'medium', 'high', 'urgent'] as const;

	const taskStatusLabels: Record<string, string> = {
		backlog: 'Backlog',
		todo: 'To Do',
		in_progress: 'In Progress',
		in_review: 'In Review',
		done: 'Done',
		cancelled: 'Cancelled'
	};

	const taskStatusColors: Record<string, string> = {
		backlog: '#a1a1aa',
		todo: '#60a5fa',
		in_progress: '#f59e0b',
		in_review: '#a78bfa',
		done: '#34d399',
		cancelled: '#f87171'
	};

	const taskStatusBadge: Record<string, string> = {
		backlog: 'text-zinc-400',
		todo: 'text-blue-400',
		in_progress: 'text-amber-400',
		in_review: 'text-violet-400',
		done: 'text-green-400',
		cancelled: 'text-red-400'
	};

	const priorityColors: Record<string, string> = {
		low: '#60a5fa',
		medium: '#f59e0b',
		high: '#f97316',
		urgent: '#ef4444'
	};

	const priorityBadge: Record<string, string> = {
		low: 'text-blue-400',
		medium: 'text-yellow-500',
		high: 'text-orange-400',
		urgent: 'text-red-400'
	};

	let loading = $state(true);
	let projects = $state<Project[]>([]);
	let allTasks = $state<Task[]>([]);
	let allTaskCount = $state(0);
	let allTickets = $state<Ticket[]>([]);
	let allTicketCount = $state(0);
	let breachCount = $state(0);
	let myTasks = $state<Task[]>([]);

	const activeProjects = $derived(projects.filter((p) => p.status === 'active').length);
	const openTasks = $derived(allTasks.filter((t) => !['done', 'cancelled'].includes(t.status)).length);
	const backlogTasks = $derived(allTasks.filter((t) => t.status === 'backlog').length);
	const openTickets = $derived(
		allTickets.filter((t) => !['resolved', 'closed'].includes(t.status as string)).length
	);

	const taskStatusData = $derived<ChartData>({
		labels: TASK_STATUSES.map((s) => taskStatusLabels[s]),
		datasets: [
			{
				data: TASK_STATUSES.map((s) => allTasks.filter((t) => t.status === s).length),
				backgroundColor: TASK_STATUSES.map((s) => taskStatusColors[s]),
				borderWidth: 0,
				hoverOffset: 4
			}
		]
	});

	const ticketPriorityData = $derived<ChartData>({
		labels: TICKET_PRIORITIES.map((p) => p.charAt(0).toUpperCase() + p.slice(1)),
		datasets: [
			{
				data: TICKET_PRIORITIES.map(
					(p) => allTickets.filter((t) => t.priority === p).length
				),
				backgroundColor: TICKET_PRIORITIES.map((p) => priorityColors[p]),
				borderWidth: 0,
				hoverOffset: 4
			}
		]
	});

	const chartOptions: Record<string, unknown> = {
		responsive: true,
		maintainAspectRatio: true,
		aspectRatio: 1,
		cutout: '60%',
		plugins: {
			legend: { display: false },
			tooltip: {
				bodyFont: { family: "'JetBrains Mono', monospace" },
				titleFont: { family: "'JetBrains Mono', monospace" }
			}
		}
	};

	function formatLabel(s: string): string {
		return s
			.replace(/_/g, ' ')
			.replace(/\b\w/g, (c) => c.toUpperCase());
	}

	function timeAgo(dateStr: string): string {
		const diff = Date.now() - new Date(dateStr).getTime();
		const mins = Math.floor(diff / 60000);
		if (mins < 1) return 'just now';
		if (mins < 60) return `${mins}m ago`;
		const hours = Math.floor(mins / 60);
		if (hours < 24) return `${hours}h ago`;
		const days = Math.floor(hours / 24);
		return `${days}d ago`;
	}

	let loaded = $state(false);

	$effect(() => {
		const orgId = auth.organizationId;
		if (loaded) return;
		if (!auth.isAuthenticated) return;

		if (!orgId) {
			loading = false;
			return;
		}

		loaded = true;

		(async () => {
			try {
				const clientOrgs = await api.organizations.getAll().catch(() => []);
				const isPlatformUser = !clientOrgs.some((o) => o.id === orgId);
				const ticketOrgId = isPlatformUser ? null : orgId;

				const [projectsRes, tasksRes, ticketsRes, breachesRes] = await Promise.all([
					api.projects.getAll(orgId).catch(() => [] as Project[]),
					api.tasks.getAll({}, 1, 200).catch(() => ({ data: [], count: 0 })),
					api.tickets.getAll(ticketOrgId, {}, 1, 200).catch(() => ({ data: [], count: 0 })),
					api.config.getBreaches().catch(() => [])
				]);

				projects = projectsRes as Project[];
				allTasks = tasksRes.data as Task[];
				allTaskCount = tasksRes.count;
				allTickets = ticketsRes.data as Ticket[];
				allTicketCount = ticketsRes.count;
				breachCount = breachesRes.length;

				const userId = auth.user?.id;
				if (userId) {
					myTasks = allTasks
						.filter(
							(t) =>
								!['done', 'cancelled'].includes(t.status) &&
								t.assignments?.some((a) => a.user_id === userId)
						)
						.slice(0, 8);
				}
			} catch (e) {
				console.error('[Dashboard]', e);
			} finally {
				loading = false;
			}
		})();
	});

	const recentTickets = $derived(
		allTickets
			.filter((t) => !['resolved', 'closed'].includes(t.status as string))
			.slice(0, 8)
	);
</script>

<div class="mx-auto max-w-7xl p-3">
	{#if loading}
		<div class="flex h-64 items-center justify-center">
			<Loader2 size={24} class="animate-spin text-muted" />
		</div>
	{:else}
		<div class="mb-4">
			<h1 class="text-lg font-semibold text-sidebar-text">
				Welcome back, {auth.user?.full_name?.split(' ')[0] ?? 'there'}
			</h1>
			<p class="mt-1 text-sm text-muted/50">Here's what's happening across your workspace.</p>
		</div>

		<!-- KPI Cards -->
		<div class="mb-4 grid grid-cols-1 gap-2 sm:grid-cols-2 lg:grid-cols-4">
			<div class="rounded border border-surface-border/40 bg-surface/50 px-3 py-2.5">
				<div class="mb-2 flex items-center gap-2 text-muted/50">
					<FolderKanban size={14} />
					<span class="text-xs font-medium uppercase tracking-[0.08em]">Active Projects</span>
				</div>
				<p class="text-2xl font-semibold text-sidebar-text">{activeProjects}</p>
				<p class="mt-1 text-xs text-muted/50">{projects.length} total</p>
			</div>

			<div class="rounded border border-surface-border/40 bg-surface/50 px-3 py-2.5">
				<div class="mb-2 flex items-center gap-2 text-muted/50">
					<ListChecks size={14} />
					<span class="text-xs font-medium uppercase tracking-[0.08em]">Open Tasks</span>
				</div>
				<p class="text-2xl font-semibold text-sidebar-text">{openTasks}</p>
				<div class="mt-1 flex items-center gap-2 text-xs text-muted/50">
					<span>{allTaskCount} total</span>
					{#if backlogTasks > 0}
						<span class="text-xs font-medium text-zinc-400">
							{backlogTasks} in backlog
						</span>
					{/if}
				</div>
			</div>

			<div class="rounded border border-surface-border/40 bg-surface/50 px-3 py-2.5">
				<div class="mb-2 flex items-center gap-2 text-muted/50">
					<TicketIcon size={14} />
					<span class="text-xs font-medium uppercase tracking-[0.08em]">Open Tickets</span>
				</div>
				<p class="text-2xl font-semibold text-sidebar-text">{openTickets}</p>
				<p class="mt-1 text-xs text-muted/50">{allTicketCount} total</p>
			</div>

			<div class="rounded border border-surface-border/40 bg-surface/50 px-3 py-2.5">
				<div class="mb-2 flex items-center gap-2 text-muted/50">
					<ShieldAlert size={14} />
					<span class="text-xs font-medium uppercase tracking-[0.08em]">SLA Breaches</span>
				</div>
				<p class="text-2xl font-semibold text-sidebar-text">{breachCount}</p>
				<p class="mt-1 text-xs text-muted/50">all time</p>
			</div>
		</div>

		<!-- Charts -->
		<div class="mb-4 grid grid-cols-1 gap-2 lg:grid-cols-2">
			<div class="rounded border border-surface-border/40 bg-surface/50 px-3 py-2.5">
				<h2 class="mb-4 text-xs font-medium uppercase tracking-[0.08em] text-muted/50">
					Tasks by Status
				</h2>
				{#if allTasks.length > 0}
					<div class="mx-auto h-44 w-44">
						<DashboardChart type="doughnut" data={taskStatusData} options={chartOptions} />
					</div>
					<div class="mt-4 flex flex-wrap justify-center gap-x-4 gap-y-1.5">
						{#each TASK_STATUSES as s (s)}
							<div class="flex items-center gap-1.5">
								<span class="inline-block h-1.5 w-1.5 rounded-full" style="background:{taskStatusColors[s]}"></span>
								<span class="text-sm text-muted">{taskStatusLabels[s]}</span>
							</div>
						{/each}
					</div>
				{:else}
					<div class="flex h-52 items-center justify-center text-sm text-muted/50">
						No task data yet
					</div>
				{/if}
			</div>

			<div class="rounded border border-surface-border/40 bg-surface/50 px-3 py-2.5">
				<h2 class="mb-4 text-xs font-medium uppercase tracking-[0.08em] text-muted/50">
					Tickets by Priority
				</h2>
				{#if allTickets.length > 0}
					<div class="mx-auto h-44 w-44">
						<DashboardChart type="doughnut" data={ticketPriorityData} options={chartOptions} />
					</div>
					<div class="mt-4 flex flex-wrap justify-center gap-x-4 gap-y-1.5">
						{#each TICKET_PRIORITIES as p (p)}
							<div class="flex items-center gap-1.5">
								<span class="inline-block h-1.5 w-1.5 rounded-full" style="background:{priorityColors[p]}"></span>
								<span class="text-sm text-muted">{p.charAt(0).toUpperCase() + p.slice(1)}</span>
							</div>
						{/each}
					</div>
				{:else}
					<div class="flex h-52 items-center justify-center text-sm text-muted/50">
						No ticket data yet
					</div>
				{/if}
			</div>
		</div>

		<!-- Lists -->
		<div class="grid grid-cols-1 gap-2 lg:grid-cols-2">
			<!-- My Tasks -->
			<div class="rounded border border-surface-border/40 bg-surface/50">
				<div class="flex items-center justify-between border-b border-surface-border/30 px-3 py-2.5">
					<h2 class="text-xs font-medium uppercase tracking-[0.08em] text-muted/50">My Tasks</h2>
				<a
					href={localizeHref("/projects")}
					class="flex items-center gap-1 text-sm text-muted/50 transition-colors hover:text-accent"
				>
					View all <ArrowRight size={12} />
				</a>
			</div>
			{#if myTasks.length > 0}
				<ul>
					{#each myTasks as task (task.id)}
						<li>
							<a
								href={localizeHref(`/projects/${task.project_id}`)}
									class="flex items-center gap-3 px-3 py-[7px] transition-all duration-150 hover:bg-surface-hover/40"
								>
									<Circle
										size={8}
										fill={taskStatusColors[task.status] ?? '#a1a1aa'}
										class="shrink-0"
										style="color: {taskStatusColors[task.status] ?? '#a1a1aa'}"
									/>
									<div class="min-w-0 flex-1">
										<p class="truncate text-base text-sidebar-text">{task.title}</p>
										<p class="mt-0.5 font-mono text-xs text-muted/50">
											{task.project?.identifier ?? ''}-{task.short_id}
										</p>
									</div>
									<span
										class="shrink-0 text-xs font-medium {taskStatusBadge[task.status] ?? ''}"
									>
										{formatLabel(task.status)}
									</span>
								</a>
							</li>
						{/each}
					</ul>
				{:else}
					<div class="flex h-32 items-center justify-center text-sm text-muted/50">
						No tasks assigned to you
					</div>
				{/if}
			</div>

			<!-- Recent Tickets -->
			<div class="rounded border border-surface-border/40 bg-surface/50">
				<div class="flex items-center justify-between border-b border-surface-border/30 px-3 py-2.5">
					<h2 class="text-xs font-medium uppercase tracking-[0.08em] text-muted/50">
						Recent Tickets
					</h2>
				<a
					href={localizeHref("/tickets")}
					class="flex items-center gap-1 text-sm text-muted/50 transition-colors hover:text-accent"
					>
						View all <ArrowRight size={12} />
					</a>
				</div>
				{#if recentTickets.length > 0}
					<ul>
						{#each recentTickets as ticket (ticket.id)}
							<li>
								<div
									class="flex items-center gap-3 px-3 py-[7px] transition-all duration-150 hover:bg-surface-hover/40"
								>
									<div class="min-w-0 flex-1">
										<p class="truncate text-base text-sidebar-text">{ticket.subject}</p>
										<p class="mt-0.5 text-xs text-muted/50">
											{ticket.customer?.full_name ?? 'Unknown'}
											{#if ticket.created_at}
												&middot; <span class="font-mono">{timeAgo(ticket.created_at as string)}</span>
											{/if}
										</p>
									</div>
									<span
										class="shrink-0 text-xs font-medium {priorityBadge[ticket.priority] ?? ''}"
									>
										{formatLabel(ticket.priority)}
									</span>
								</div>
							</li>
						{/each}
					</ul>
				{:else}
					<div class="flex h-32 items-center justify-center text-sm text-muted/50">
						No open tickets
					</div>
				{/if}
			</div>
		</div>
	{/if}
</div>
