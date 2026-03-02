import { api } from "$lib/api";
import type { TicketFilters } from "$lib/api/tickets";

export type Ticket = {
  id: string;
  subject: string;
  status: string;
  priority: string;
  category: string | null;
  customer: {
    id: string;
    full_name: string;
    email: string;
    avatar_url: string | null;
  } | null;
  agent: {
    id: string;
    full_name: string;
    avatar_url: string | null;
  } | null;
  [key: string]: unknown;
};

class TicketStore {
  items = $state<Ticket[]>([]);
  count = $state(0);
  loading = $state(false);
  error = $state<string | null>(null);
  activeTicket = $state<Ticket | null>(null);

  async load(orgId?: string | null, filters?: TicketFilters, page = 1) {
    this.loading = true;
    this.error = null;

    try {
      const { data, count } = await api.tickets.getAll(
        orgId,
        filters,
        page
      );
      this.items = data as Ticket[];
      this.count = count;
    } catch (e) {
      this.error =
        e instanceof Error ? e.message : "Failed to load tickets";
    } finally {
      this.loading = false;
    }
  }

  async loadById(id: string) {
    this.loading = true;
    try {
      this.activeTicket = (await api.tickets.getById(id)) as Ticket;
    } catch (e) {
      this.error =
        e instanceof Error ? e.message : "Ticket not found";
    } finally {
      this.loading = false;
    }
  }

  async create(input: Parameters<typeof api.tickets.create>[0]) {
    try {
      const ticket = (await api.tickets.create(input)) as Ticket;
      this.items = [ticket, ...this.items];
      this.count++;
      return ticket;
    } catch (e) {
      this.error =
        e instanceof Error ? e.message : "Failed to create ticket";
      throw e;
    }
  }

  async resolve(ticketId: string) {
    this.items = this.items.map((t) =>
      t.id === ticketId ? { ...t, status: "resolved" } : t
    );

    try {
      await api.tickets.resolve(ticketId);
    } catch {
      await this.load(this.items[0]?.organization_id as string);
    }
  }

  clear() {
    this.items = [];
    this.count = 0;
    this.activeTicket = null;
    this.error = null;
  }
}

export const ticketStore = new TicketStore();