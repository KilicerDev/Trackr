export type NotificationType = 'loading' | 'success' | 'error';

export interface Notification {
	id: string;
	type: NotificationType;
	message: string;
	description?: string;
}

export interface ActionHandle {
	success: (message: string) => void;
	error: (message: string, description?: string) => void;
}

let counter = 0;
function uid(): string {
	return `n-${++counter}-${Date.now()}`;
}

class NotificationStore {
	items = $state<Notification[]>([]);
	private timers = new Map<string, ReturnType<typeof setTimeout>>();

	add(
		type: NotificationType,
		message: string,
		description?: string,
		duration?: number
	): string {
		const id = uid();
		this.items = [...this.items, { id, type, message, description }];

		const ms = duration ?? (type === 'success' ? 4000 : 0);
		if (ms > 0) this.autoDismiss(id, ms);

		return id;
	}

	dismiss(id: string) {
		this.clearTimer(id);
		this.items = this.items.filter((n) => n.id !== id);
	}

	clear() {
		for (const id of this.timers.keys()) this.clearTimer(id);
		this.items = [];
	}

	action(message: string): ActionHandle {
		const id = this.add('loading', message);

		return {
			success: (msg: string) => {
				this.update(id, { type: 'success', message: msg });
				this.autoDismiss(id, 4000);
			},
			error: (msg: string, desc?: string) => {
				this.update(id, { type: 'error', message: msg, description: desc });
			}
		};
	}

	private update(id: string, patch: Partial<Omit<Notification, 'id'>>) {
		this.items = this.items.map((n) =>
			n.id === id ? { ...n, ...patch } : n
		);
	}

	private autoDismiss(id: string, ms: number) {
		this.clearTimer(id);
		this.timers.set(
			id,
			setTimeout(() => {
				this.timers.delete(id);
				this.dismiss(id);
			}, ms)
		);
	}

	private clearTimer(id: string) {
		const t = this.timers.get(id);
		if (t) {
			clearTimeout(t);
			this.timers.delete(id);
		}
	}
}

export const notifications = new NotificationStore();
