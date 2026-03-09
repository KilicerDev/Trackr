import { getClient } from "$lib/api/client";
import { notificationsApi, type AppNotification } from "$lib/api/notifications";
import type { RealtimeChannel } from "@supabase/supabase-js";

class NotificationCenterStore {
	items = $state<AppNotification[]>([]);
	unreadCount = $state(0);
	isOpen = $state(false);
	loading = $state(false);
	hasMore = $state(true);

	private page = 1;
	private perPage = 15;
	private channel: RealtimeChannel | null = null;

	async init(userId: string) {
		try {
			this.unreadCount = await notificationsApi.getUnreadCount();
		} catch {
			// API may be unreachable; keep default count and retry on next load
		}

		const supabase = getClient();
		this.channel = supabase
			.channel("user-notifications")
			.on(
				"postgres_changes",
				{
					event: "INSERT",
					schema: "public",
					table: "notifications",
					filter: `recipient_id=eq.${userId}`,
				},
			(payload: { new: Record<string, unknown> }) => {
				const n = payload.new as AppNotification;
					this.items = [n, ...this.items];
					this.unreadCount++;
				}
			)
			.subscribe();
	}

	toggle() {
		this.isOpen = !this.isOpen;
		if (this.isOpen && this.items.length === 0) {
			this.loadInitial();
		}
	}

	close() {
		this.isOpen = false;
	}

	async loadInitial() {
		this.loading = true;
		this.page = 1;
		try {
			const { data, count } = await notificationsApi.getAll(
				this.page,
				this.perPage
			);
			this.items = data;
			this.hasMore = this.items.length < count;
		} finally {
			this.loading = false;
		}
	}

	async loadMore() {
		if (this.loading || !this.hasMore) return;
		this.loading = true;
		this.page++;
		try {
			const { data, count } = await notificationsApi.getAll(
				this.page,
				this.perPage
			);
			this.items = [...this.items, ...data];
			this.hasMore = this.items.length < count;
		} finally {
			this.loading = false;
		}
	}

	async markRead(id: string) {
		await notificationsApi.markRead(id);
		this.items = this.items.map((n) =>
			n.id === id
				? { ...n, is_read: true, read_at: new Date().toISOString() }
				: n
		);
		this.unreadCount = Math.max(0, this.unreadCount - 1);
	}

	async markAllRead() {
		await notificationsApi.markAllRead();
		this.items = this.items.map((n) => ({
			...n,
			is_read: true,
			read_at: n.read_at ?? new Date().toISOString(),
		}));
		this.unreadCount = 0;
	}

	async remove(id: string) {
		const item = this.items.find((n) => n.id === id);
		await notificationsApi.remove(id);
		this.items = this.items.filter((n) => n.id !== id);
		if (item && !item.is_read) {
			this.unreadCount = Math.max(0, this.unreadCount - 1);
		}
	}

	destroy() {
		if (this.channel) {
			const supabase = getClient();
			supabase.removeChannel(this.channel);
			this.channel = null;
		}
		this.items = [];
		this.unreadCount = 0;
		this.isOpen = false;
		this.page = 1;
		this.hasMore = true;
	}
}

export const notificationCenter = new NotificationCenterStore();
