import { api } from "$lib/api";
import type { TaskFilters } from "$lib/api/tasks";

function extractErrorMessage(e: unknown, fallback: string): string {
  if (e instanceof Error) return e.message;
  if (e && typeof e === "object" && "message" in e && typeof (e as { message: unknown }).message === "string")
    return (e as { message: string }).message;
  return fallback;
}

export type Task = {
  id: string;
  title: string;
  status: string;
  priority: string;
  type: string;
  short_id: string;
  project_id: string;
  created_by: string;
  project: {
    id: string;
    name: string;
    identifier: string;
    color: string;
  } | null;
  assignments: {
    user_id: string;
    role: string;
    user: {
      id: string;
      full_name: string;
      username: string;
      avatar_url: string | null;
    };
  }[];
  created_by_user: {
    id: string;
    full_name: string;
    avatar_url: string | null;
  } | null;
  [key: string]: unknown;
};

class TaskStore {
  items = $state<Task[]>([]);
  count = $state(0);
  loading = $state(false);
  error = $state<string | null>(null);
  activeTask = $state<Task | null>(null);
  filters = $state<TaskFilters>({ parent_id: null });
  page = $state(1);

  async load(filters?: TaskFilters, page = 1) {
    this.loading = true;
    this.error = null;

    try {
      const f = filters ?? this.filters;
      const { data, count } = await api.tasks.getAll(f, page);
      this.items = data as Task[];
      this.count = count;
      this.filters = f;
      this.page = page;
    } catch (e) {
      console.error("[TaskStore.load]", e);
      this.error = extractErrorMessage(e, "Failed to load tasks");
    } finally {
      this.loading = false;
    }
  }

  async loadById(id: string) {
    this.loading = true;
    try {
      this.activeTask = (await api.tasks.getById(id)) as Task;
    } catch (e) {
      this.error = extractErrorMessage(e, "Task not found");
    } finally {
      this.loading = false;
    }
  }

  async loadByShortId(shortId: string) {
    this.loading = true;
    try {
      this.activeTask = (await api.tasks.getByShortId(
        shortId
      )) as Task;
    } catch (e) {
      this.error = extractErrorMessage(e, "Task not found");
    } finally {
      this.loading = false;
    }
  }

  async create(input: Parameters<typeof api.tasks.create>[0]) {
    try {
      const task = (await api.tasks.create(input)) as Task;
      this.items = [task, ...this.items];
      this.count++;
      return task;
    } catch (e) {
      this.error = extractErrorMessage(e, "Failed to create task");
      throw e;
    }
  }

  async updateStatus(taskId: string, status: string) {
    const prev = this.items.find((t) => t.id === taskId);
    const prevStatus = prev?.status;

    // Optimistic
    this.items = this.items.map((t) =>
      t.id === taskId ? { ...t, status } : t
    );
    if (this.activeTask?.id === taskId) {
      this.activeTask = { ...this.activeTask, status };
    }

    try {
      await api.tasks.updateStatus(taskId, status);
    } catch {
      // Revert
      this.items = this.items.map((t) =>
        t.id === taskId ? { ...t, status: prevStatus! } : t
      );
      if (this.activeTask?.id === taskId) {
        this.activeTask = { ...this.activeTask, status: prevStatus! };
      }
    }
  }

  async updatePriority(taskId: string, priority: string) {
    const prev = this.items.find((t) => t.id === taskId);
    const prevPriority = prev?.priority;

    this.items = this.items.map((t) =>
      t.id === taskId ? { ...t, priority } : t
    );

    try {
      await api.tasks.updatePriority(taskId, priority);
    } catch {
      this.items = this.items.map((t) =>
        t.id === taskId ? { ...t, priority: prevPriority! } : t
      );
    }
  }

  async remove(taskId: string) {
    const prev = [...this.items];
    this.items = this.items.filter((t) => t.id !== taskId);
    this.count--;

    try {
      await api.tasks.delete(taskId);
    } catch {
      this.items = prev;
      this.count++;
    }
  }

  async refresh() {
    await this.load(this.filters, this.page);
  }

  clear() {
    this.items = [];
    this.count = 0;
    this.activeTask = null;
    this.error = null;
  }
}

export const taskStore = new TaskStore();