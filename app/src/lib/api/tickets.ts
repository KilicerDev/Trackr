// src/lib/api/tickets.ts

import { getClient } from "./client";
import { TICKET_SELECT } from "./queries";

export type TicketFilters = {
  status?: string;
  priority?: string;
  category?: string;
  customer_id?: string;
  assigned_agent_id?: string;
};

export type CreateTicketInput = {
  subject: string;
  description?: string;
  customer_id: string;
  organization_id: string;
  priority?: string;
  channel?: string;
  category?: string;
};

export const tickets = {
  async getAll(
    orgId?: string | null,
    filters?: TicketFilters,
    page = 1,
    perPage = 25
  ) {
    const supabase = getClient();
    const from = (page - 1) * perPage;
    const to = from + perPage - 1;

    let q = supabase
      .from("support_tickets")
      .select(TICKET_SELECT, { count: "exact" })
      .is("deleted_at", null);

    if (orgId) q = q.eq("organization_id", orgId);

    if (filters?.status) q = q.eq("status", filters.status);
    if (filters?.priority) q = q.eq("priority", filters.priority);
    if (filters?.category) q = q.eq("category", filters.category);
    if (filters?.customer_id)
      q = q.eq("customer_id", filters.customer_id);
    if (filters?.assigned_agent_id)
      q = q.eq("assigned_agent_id", filters.assigned_agent_id);

    const { data, error, count } = await q
      .order("created_at", { ascending: false })
      .range(from, to);

    if (error) throw error;
    return { data: data ?? [], count: count ?? 0 };
  },

  async getById(id: string) {
    const supabase = getClient();
    const { data, error } = await supabase
      .from("support_tickets")
      .select(TICKET_SELECT)
      .eq("id", id)
      .single();

    if (error) throw error;
    return data;
  },

  async create(input: CreateTicketInput) {
    const supabase = getClient();
    const { data, error } = await supabase
      .from("support_tickets")
      .insert(input)
      .select(TICKET_SELECT)
      .single();

    if (error) throw error;
    return data;
  },

  async update(id: string, values: Record<string, unknown>) {
    const supabase = getClient();
    const { data, error } = await supabase
      .from("support_tickets")
      .update(values)
      .eq("id", id)
      .select(TICKET_SELECT)
      .single();

    if (error) throw error;
    return data;
  },

  async assignAgent(ticketId: string, agentId: string) {
    return tickets.update(ticketId, { assigned_agent_id: agentId });
  },

  async resolve(ticketId: string) {
    return tickets.update(ticketId, {
      status: "resolved",
      resolved_at: new Date().toISOString(),
    });
  },

  async getMessages(ticketId: string) {
    const supabase = getClient();
    const { data, error } = await supabase
      .from("support_ticket_messages")
      .select(
        "*, sender:users(id, full_name, username, avatar_url)"
      )
      .eq("ticket_id", ticketId)
      .is("deleted_at", null)
      .order("created_at");

    if (error) throw error;
    return data ?? [];
  },

  async addMessage(
    ticketId: string,
    senderId: string,
    body: string,
    isInternal = false
  ) {
    const supabase = getClient();
    const { data, error } = await supabase
      .from("support_ticket_messages")
      .insert({
        ticket_id: ticketId,
        sender_id: senderId,
        body,
        is_internal_note: isInternal,
      })
      .select(
        "*, sender:users(id, full_name, username, avatar_url)"
      )
      .single();

    if (error) throw error;
    return data;
  },
};