// src/lib/api/tickets.ts

import { getClient } from "./client";
import { TICKET_SELECT } from "./queries";
import { indexDocument } from "./search-index";

/** Use "none" for assigned_agent_id to filter for unassigned tickets */
export type TicketFilters = {
  status?: string;
  priority?: string;
  category?: string;
  channel?: string;
  customer_id?: string;
  assigned_agent_id?: string | null;
  created_at_from?: string;
  created_at_to?: string;
  resolved_at_from?: string;
  resolved_at_to?: string;
  satisfaction_min?: number;
  satisfaction_max?: number;
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
    if (filters?.channel) q = q.eq("channel", filters.channel);
    if (filters?.customer_id)
      q = q.eq("customer_id", filters.customer_id);
    if (filters?.assigned_agent_id !== undefined) {
      if (filters.assigned_agent_id === null || filters.assigned_agent_id === "none")
        q = q.is("assigned_agent_id", null);
      else q = q.eq("assigned_agent_id", filters.assigned_agent_id);
    }
    if (filters?.created_at_from) q = q.gte("created_at", filters.created_at_from);
    if (filters?.created_at_to) q = q.lte("created_at", filters.created_at_to);
    if (filters?.resolved_at_from) q = q.gte("resolved_at", filters.resolved_at_from);
    if (filters?.resolved_at_to) q = q.lte("resolved_at", filters.resolved_at_to);
    if (filters?.satisfaction_min != null) q = q.gte("satisfaction_score", filters.satisfaction_min);
    if (filters?.satisfaction_max != null) q = q.lte("satisfaction_score", filters.satisfaction_max);

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

  async getCustomersByOrg(orgId: string) {
    const supabase = getClient();
    const { data, error } = await supabase
      .from("support_tickets")
      .select("customer_id, customer:users!customer_id(id, full_name, email, avatar_url)")
      .eq("organization_id", orgId)
      .is("deleted_at", null);

    if (error) throw error;
    const byId = new Map<string, { full_name: string; email: string; avatar_url: string | null }>();
    for (const row of data ?? []) {
      const c = row.customer as { id: string; full_name: string; email: string; avatar_url: string | null } | null;
      if (row.customer_id && c) byId.set(row.customer_id, { full_name: c.full_name, email: c.email, avatar_url: c.avatar_url });
    }
    return Array.from(byId.entries()).map(([id, c]) => ({ id, ...c }));
  },

  async create(input: CreateTicketInput) {
    const supabase = getClient();
    const { data, error } = await supabase
      .from("support_tickets")
      .insert(input)
      .select(TICKET_SELECT)
      .single();

    if (error) throw error;
    if (data) indexDocument("ticket", data.id);
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
    if (data) indexDocument("ticket", data.id);
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
    if (data) indexDocument("ticket_message", data.id);
    return data;
  },

  async getWorkLogs(ticketId: string) {
    const supabase = getClient();
    const { data, error } = await supabase
      .from("ticket_work_logs")
      .select("*, user:users(id, full_name, avatar_url)")
      .eq("ticket_id", ticketId)
      .order("logged_at", { ascending: false })
      .order("created_at", { ascending: false });

    if (error) throw error;
    return data ?? [];
  },

  async addWorkLog(
    ticketId: string,
    userId: string,
    minutes: number,
    description?: string,
    loggedAt?: string
  ) {
    const supabase = getClient();
    const row: Record<string, unknown> = {
      ticket_id: ticketId,
      user_id: userId,
      minutes,
    };
    if (description) row.description = description;
    if (loggedAt) row.logged_at = loggedAt;

    const { data, error } = await supabase
      .from("ticket_work_logs")
      .insert(row)
      .select("*, user:users(id, full_name, avatar_url)")
      .single();

    if (error) throw error;
    return data;
  },

  async deleteWorkLog(id: string) {
    const supabase = getClient();
    const { error } = await supabase
      .from("ticket_work_logs")
      .delete()
      .eq("id", id);

    if (error) throw error;
  },
};