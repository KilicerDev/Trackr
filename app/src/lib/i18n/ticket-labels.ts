import * as m from "$lib/paraglide/messages";

export function tStatus(s: string): string {
  switch (s) {
    case "open": return m.client_status_open();
    case "in_progress": return m.client_status_in_progress();
    case "paused": return m.client_status_paused();
    case "waiting_on_customer": return m.client_status_waiting_on_customer();
    case "waiting_on_agent": return m.client_status_waiting_on_agent();
    case "resolved": return m.client_status_resolved();
    case "closed": return m.client_status_closed();
    default: return s;
  }
}

export function tPriority(p: string): string {
  switch (p) {
    case "low": return m.client_priority_low();
    case "medium": return m.client_priority_medium();
    case "high": return m.client_priority_high();
    case "urgent": return m.client_priority_urgent();
    default: return p;
  }
}

export function tCategory(c: string | null | undefined): string {
  switch (c) {
    case "billing": return m.client_category_billing();
    case "technical_issue": return m.client_category_technical_issue();
    case "feature_request": return m.client_category_feature_request();
    case "general": return m.client_category_general();
    default: return c ?? "";
  }
}
