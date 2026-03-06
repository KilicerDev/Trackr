import { api } from "$lib/api";

export type ClientTicket = {
  id: string;
  subject: string;
  status: string;
  priority: string;
  category: string | null;
  created_at: string;
  updated_at: string;
  [key: string]: unknown;
};

class ClientPortalState {
  tickets = $state<ClientTicket[]>([]);
  count = $state(0);
  loading = $state(false);
  error = $state<string | null>(null);

  async loadTickets(orgId: string, customerId: string) {
    this.loading = true;
    this.error = null;
    try {
      const { data, count } = await api.tickets.getAll(orgId, {
        customer_id: customerId,
      });
      this.tickets = data as ClientTicket[];
      this.count = count;
    } catch (e) {
      this.error =
        e instanceof Error ? e.message : "Failed to load tickets";
    } finally {
      this.loading = false;
    }
  }

  addTicket(ticket: ClientTicket) {
    this.tickets = [ticket, ...this.tickets];
    this.count++;
  }

  clear() {
    this.tickets = [];
    this.count = 0;
    this.error = null;
  }
}

export const clientPortal = new ClientPortalState();
