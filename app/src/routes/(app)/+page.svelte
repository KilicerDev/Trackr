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
		backlog: 'bg-zinc-100 text-zinc-600 dark:bg-zinc-800 dark:text-zinc-400',
		todo: 'bg-blue-100 text-blue-700 dark:bg-blue-950/60 dark:text-blue-300',
		in_progress: 'bg-amber-100 text-amber-700 dark:bg-amber-950/60 dark:text-amber-300',
		in_review: 'bg-violet-100 text-violet-700 dark:bg-violet-950/60 dark:text-violet-300',
		done: 'bg-emerald-100 text-emerald-700 dark:bg-emerald-950/60 dark:text-emerald-300',
		cancelled: 'bg-red-100 text-red-600 dark:bg-red-950/60 dark:text-red-300'
	};

	const priorityColors: Record<string, string> = {
		low: '#60a5fa',
		medium: '#f59e0b',
		high: '#f97316',
		urgent: '#ef4444'
	};

	const priorityBadge: Record<string, string> = {
		low: 'bg-blue-100 text-blue-700 dark:bg-blue-950/60 dark:text-blue-300',
		medium: 'bg-amber-100 text-amber-700 dark:bg-amber-950/60 dark:text-amber-300',
		high: 'bg-orange-100 text-orange-700 dark:bg-orange-950/60 dark:text-orange-300',
		urgent: 'bg-red-100 text-red-700 dark:bg-red-950/60 dark:text-red-300'
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

<div class="mx-auto max-w-7xl px-6 py-6">
	{#if loading}
		<div class="flex h-64 items-center justify-center">
			<Loader2 size={24} class="animate-spin text-muted" />
		</div>
	{:else}
		<div class="mb-6">
			<h1 class="text-lg font-semibold text-sidebar-text">
				Welcome back, {auth.user?.full_name?.split(' ')[0] ?? 'there'}
			</h1>
			<p class="mt-1 text-xs text-muted">Here's what's happening across your workspace.</p>
		</div>

		<!-- KPI Cards -->
		<div class="mb-6 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
			<div class="border border-surface-border bg-surface px-4 py-4">
				<div class="mb-2 flex items-center gap-2 text-muted">
					<FolderKanban size={15} />
					<span class="text-[11px] uppercase tracking-wide">Active Projects</span>
				</div>
				<p class="text-2xl font-semibold text-sidebar-text">{activeProjects}</p>
				<p class="mt-1 text-[11px] text-muted">{projects.length} total</p>
			</div>

			<div class="border border-surface-border bg-surface px-4 py-4">
				<div class="mb-2 flex items-center gap-2 text-muted">
					<ListChecks size={15} />
					<span class="text-[11px] uppercase tracking-wide">Open Tasks</span>
				</div>
				<p class="text-2xl font-semibold text-sidebar-text">{openTasks}</p>
				<div class="mt-1 flex items-center gap-2 text-[11px] text-muted">
					<span>{allTaskCount} total</span>
					{#if backlogTasks > 0}
						<span class="rounded bg-zinc-100 px-1.5 py-0.5 text-[10px] font-medium text-zinc-600 dark:bg-zinc-800 dark:text-zinc-400">
							{backlogTasks} in backlog
						</span>
					{/if}
				</div>
			</div>

			<div class="border border-surface-border bg-surface px-4 py-4">
				<div class="mb-2 flex items-center gap-2 text-muted">
					<TicketIcon size={15} />
					<span class="text-[11px] uppercase tracking-wide">Open Tickets</span>
				</div>
				<p class="text-2xl font-semibold text-sidebar-text">{openTickets}</p>
				<p class="mt-1 text-[11px] text-muted">{allTicketCount} total</p>
			</div>

			<div class="border border-surface-border bg-surface px-4 py-4">
				<div class="mb-2 flex items-center gap-2 text-muted">
					<ShieldAlert size={15} />
					<span class="text-[11px] uppercase tracking-wide">SLA Breaches</span>
				</div>
				<p class="text-2xl font-semibold text-sidebar-text">{breachCount}</p>
				<p class="mt-1 text-[11px] text-muted">all time</p>
			</div>
		</div>

		<!-- Charts -->
		<div class="mb-6 grid grid-cols-1 gap-4 lg:grid-cols-2">
			<div class="border border-surface-border bg-surface p-4">
				<h2 class="mb-4 text-xs font-semibold uppercase tracking-wide text-muted">
					Tasks by Status
				</h2>
				{#if allTasks.length > 0}
					<div class="mx-auto h-44 w-44">
						<DashboardChart type="doughnut" data={taskStatusData} options={chartOptions} />
					</div>
					<div class="mt-4 flex flex-wrap justify-center gap-x-4 gap-y-1.5">
						{#each TASK_STATUSES as s (s)}
							<div class="flex items-center gap-1.5">
								<span class="inline-block h-[7px] w-[7px] rounded-full" style="background:{taskStatusColors[s]}"></span>
								<span class="text-[11px] text-muted">{taskStatusLabels[s]}</span>
							</div>
						{/each}
					</div>
				{:else}
					<div class="flex h-52 items-center justify-center text-xs text-muted">
						No task data yet
					</div>
				{/if}
			</div>

			<div class="border border-surface-border bg-surface p-4">
				<h2 class="mb-4 text-xs font-semibold uppercase tracking-wide text-muted">
					Tickets by Priority
				</h2>
				{#if allTickets.length > 0}
					<div class="mx-auto h-44 w-44">
						<DashboardChart type="doughnut" data={ticketPriorityData} options={chartOptions} />
					</div>
					<div class="mt-4 flex flex-wrap justify-center gap-x-4 gap-y-1.5">
						{#each TICKET_PRIORITIES as p (p)}
							<div class="flex items-center gap-1.5">
								<span class="inline-block h-[7px] w-[7px] rounded-full" style="background:{priorityColors[p]}"></span>
								<span class="text-[11px] text-muted">{p.charAt(0).toUpperCase() + p.slice(1)}</span>
							</div>
						{/each}
					</div>
				{:else}
					<div class="flex h-52 items-center justify-center text-xs text-muted">
						No ticket data yet
					</div>
				{/if}
			</div>
		</div>

		<!-- Lists -->
		<div class="grid grid-cols-1 gap-4 lg:grid-cols-2">
			<!-- My Tasks -->
			<div class="border border-surface-border bg-surface">
				<div class="flex items-center justify-between border-b border-surface-border px-4 py-3">
					<h2 class="text-xs font-semibold uppercase tracking-wide text-muted">My Tasks</h2>
				<a
					href={localizeHref("/projects")}
					class="flex items-center gap-1 text-[11px] text-accent hover:underline"
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
									class="flex items-center gap-3 border-b border-surface-border px-4 py-2.5 last:border-0 hover:bg-surface-hover"
								>
									<Circle
										size={8}
										fill={taskStatusColors[task.status] ?? '#a1a1aa'}
										class="shrink-0"
										style="color: {taskStatusColors[task.status] ?? '#a1a1aa'}"
									/>
									<div class="min-w-0 flex-1">
										<p class="truncate text-xs text-sidebar-text">{task.title}</p>
										<p class="mt-0.5 text-[10px] text-muted">
											{task.project?.identifier ?? ''}-{task.short_id}
										</p>
									</div>
									<span
										class="shrink-0 rounded px-1.5 py-0.5 text-[10px] font-medium {taskStatusBadge[task.status] ?? ''}"
									>
										{formatLabel(task.status)}
									</span>
								</a>
							</li>
						{/each}
					</ul>
				{:else}
					<div class="flex h-32 items-center justify-center text-xs text-muted">
						No tasks assigned to you
					</div>
				{/if}
			</div>

			<!-- Recent Tickets -->
			<div class="border border-surface-border bg-surface">
				<div class="flex items-center justify-between border-b border-surface-border px-4 py-3">
					<h2 class="text-xs font-semibold uppercase tracking-wide text-muted">
						Recent Tickets
					</h2>
				<a
					href={localizeHref("/tickets")}
					class="flex items-center gap-1 text-[11px] text-accent hover:underline"
					>
						View all <ArrowRight size={12} />
					</a>
				</div>
				{#if recentTickets.length > 0}
					<ul>
						{#each recentTickets as ticket (ticket.id)}
							<li>
								<div
									class="flex items-center gap-3 border-b border-surface-border px-4 py-2.5 last:border-0"
								>
									<div class="min-w-0 flex-1">
										<p class="truncate text-xs text-sidebar-text">{ticket.subject}</p>
										<p class="mt-0.5 text-[10px] text-muted">
											{ticket.customer?.full_name ?? 'Unknown'}
											{#if ticket.created_at}
												&middot; {timeAgo(ticket.created_at as string)}
											{/if}
										</p>
									</div>
									<span
										class="shrink-0 rounded px-1.5 py-0.5 text-[10px] font-medium {priorityBadge[ticket.priority] ?? ''}"
									>
										{formatLabel(ticket.priority)}
									</span>
								</div>
							</li>
						{/each}
					</ul>
				{:else}
					<div class="flex h-32 items-center justify-center text-xs text-muted">
						No open tickets
					</div>
				{/if}
			</div>
		</div>
	{/if}
</div>
