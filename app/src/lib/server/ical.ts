/**
 * iCal (RFC 5545) generation for Trackr tasks and tickets.
 * No external dependencies — pure string generation.
 */

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export type IcalTask = {
  id: string;
  title: string;
  description?: string | null;
  status: string;
  priority: string;
  type?: string;
  start_at?: string | null;
  end_at?: string | null;
  updated_at: string;
  created_at: string;
  project?: { id: string; name: string } | null;
};

export type IcalTicket = {
  id: string;
  subject: string;
  description?: string | null;
  status: string;
  priority: string;
  sla_deadline?: string | null;
  updated_at: string;
  created_at: string;
};

export type IcalOptions = {
  calendarName: string;
  calendarDescription?: string;
  tasks?: IcalTask[];
  tickets?: IcalTicket[];
};

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** SHA-256 hash using Web Crypto API — returns lowercase hex string. */
export async function sha256(input: string): Promise<string> {
  const encoded = new TextEncoder().encode(input);
  const buffer = await crypto.subtle.digest("SHA-256", encoded);
  return Array.from(new Uint8Array(buffer))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

/** Escape text per RFC 5545 §3.3.11 (backslash, semicolon, comma, newlines). */
function escapeText(text: string): string {
  return text
    .replace(/\\/g, "\\\\")
    .replace(/;/g, "\\;")
    .replace(/,/g, "\\,")
    .replace(/\r?\n/g, "\\n");
}

/** Format a JS date/ISO string as iCal UTC datetime: YYYYMMDDTHHMMSSZ */
function formatDate(input: string | Date): string {
  const d = typeof input === "string" ? new Date(input) : input;
  const pad = (n: number) => n.toString().padStart(2, "0");
  return (
    `${d.getUTCFullYear()}${pad(d.getUTCMonth() + 1)}${pad(d.getUTCDate())}` +
    `T${pad(d.getUTCHours())}${pad(d.getUTCMinutes())}${pad(d.getUTCSeconds())}Z`
  );
}

/** Fold long lines at 75 octets per RFC 5545 §3.1. */
function foldLine(line: string): string {
  if (line.length <= 75) return line;
  const parts: string[] = [line.slice(0, 75)];
  let i = 75;
  while (i < line.length) {
    parts.push(" " + line.slice(i, i + 74));
    i += 74;
  }
  return parts.join("\r\n");
}

/** Map Trackr priority to iCal priority (1-9). */
function mapPriority(priority: string): number {
  switch (priority) {
    case "urgent":
      return 1;
    case "high":
      return 3;
    case "medium":
      return 5;
    case "low":
      return 7;
    case "none":
    default:
      return 9;
  }
}

/** Map any Trackr status to iCal VEVENT status. */
function mapEventStatus(status: string): string {
  switch (status) {
    case "done":
    case "resolved":
    case "closed":
      return "CONFIRMED";
    case "cancelled":
      return "CANCELLED";
    default:
      return "TENTATIVE";
  }
}

/** Check if two ISO date strings fall on the same calendar day (UTC). */
function isSameDay(a: string, b: string): boolean {
  const da = new Date(a);
  const db = new Date(b);
  return (
    da.getUTCFullYear() === db.getUTCFullYear() &&
    da.getUTCMonth() === db.getUTCMonth() &&
    da.getUTCDate() === db.getUTCDate()
  );
}

/** Format as iCal all-day date: YYYYMMDD (VALUE=DATE). */
function formatAllDayDate(input: string | Date): string {
  const d = typeof input === "string" ? new Date(input) : input;
  const pad = (n: number) => n.toString().padStart(2, "0");
  return `${d.getUTCFullYear()}${pad(d.getUTCMonth() + 1)}${pad(d.getUTCDate())}`;
}

/** Get the next day for all-day DTEND (iCal all-day events use exclusive end). */
function nextDay(input: string | Date): string {
  const d = typeof input === "string" ? new Date(input) : input;
  const next = new Date(d);
  next.setUTCDate(next.getUTCDate() + 1);
  return formatAllDayDate(next);
}

// ---------------------------------------------------------------------------
// Component builders
// ---------------------------------------------------------------------------

function buildLines(pairs: [string, string | null | undefined][]): string {
  return pairs
    .filter(([, v]) => v != null && v !== "")
    .map(([k, v]) => foldLine(`${k}:${v}`))
    .join("\r\n");
}

/**
 * Build a VEVENT with specific start/end times (same-day time block).
 */
function formatTimedEvent(
  id: string,
  summary: string,
  description: string | null | undefined,
  startAt: string,
  endAt: string,
  priority: string,
  status: string,
  updatedAt: string,
  createdAt: string,
  categories?: string | null
): string {
  const lines: [string, string | null | undefined][] = [
    ["BEGIN", "VEVENT"],
    ["UID", `${id}@trackr`],
    ["DTSTAMP", formatDate(updatedAt)],
    ["DTSTART", formatDate(startAt)],
    ["DTEND", formatDate(endAt)],
    ["SUMMARY", escapeText(summary)],
    ["DESCRIPTION", description ? escapeText(description.slice(0, 1000)) : null],
    ["PRIORITY", mapPriority(priority).toString()],
    ["STATUS", mapEventStatus(status)],
    ["LAST-MODIFIED", formatDate(updatedAt)],
    ["CREATED", formatDate(createdAt)],
    ["CATEGORIES", categories ?? null],
    ["END", "VEVENT"],
  ];
  return buildLines(lines);
}

/**
 * Build an all-day VEVENT on a specific date (deadline / due date marker).
 * All-day events use VALUE=DATE format and exclusive DTEND (next day).
 */
function formatAllDayEvent(
  id: string,
  summary: string,
  description: string | null | undefined,
  date: string,
  priority: string,
  status: string,
  updatedAt: string,
  createdAt: string,
  categories?: string | null
): string {
  const lines: [string, string | null | undefined][] = [
    ["BEGIN", "VEVENT"],
    ["UID", `${id}@trackr`],
    ["DTSTAMP", formatDate(updatedAt)],
    ["DTSTART;VALUE=DATE", formatAllDayDate(date)],
    ["DTEND;VALUE=DATE", nextDay(date)],
    ["SUMMARY", escapeText(summary)],
    ["DESCRIPTION", description ? escapeText(description.slice(0, 1000)) : null],
    ["PRIORITY", mapPriority(priority).toString()],
    ["STATUS", mapEventStatus(status)],
    ["LAST-MODIFIED", formatDate(updatedAt)],
    ["CREATED", formatDate(createdAt)],
    ["CATEGORIES", categories ?? null],
    ["END", "VEVENT"],
  ];
  return buildLines(lines);
}

// ---------------------------------------------------------------------------
// Main generator
// ---------------------------------------------------------------------------

/**
 * Converts tasks/tickets to iCal VEVENTs. Logic:
 *
 * - Task with start_at + end_at on SAME day → timed VEVENT (time block)
 * - Task with start_at + end_at on DIFFERENT days → all-day VEVENT on end_at (deadline)
 * - Task with only end_at → all-day VEVENT on end_at (deadline)
 * - Task with no dates → skipped (nothing to show on calendar)
 * - Ticket with sla_deadline → all-day VEVENT on deadline
 * - Ticket without deadline → skipped
 *
 * Everything is VEVENT for maximum compatibility (Apple Calendar, Google Calendar,
 * Outlook). VTODO is intentionally avoided — it's not supported by subscribed
 * calendar feeds on most platforms.
 */
export function generateIcal(options: IcalOptions): string {
  const { calendarName, calendarDescription, tasks = [], tickets = [] } = options;

  const components: string[] = [];

  for (const task of tasks) {
    if (task.start_at && task.end_at && isSameDay(task.start_at, task.end_at)) {
      // Same-day time block → timed VEVENT
      components.push(
        formatTimedEvent(
          task.id, task.title, task.description,
          task.start_at, task.end_at,
          task.priority, task.status,
          task.updated_at, task.created_at, task.type
        )
      );
    } else if (task.end_at) {
      // Has a deadline (multi-day range or just end_at) → all-day on deadline
      components.push(
        formatAllDayEvent(
          task.id, task.title, task.description,
          task.end_at,
          task.priority, task.status,
          task.updated_at, task.created_at, task.type
        )
      );
    } else if (task.start_at) {
      // Only start_at, no deadline → all-day on start date
      components.push(
        formatAllDayEvent(
          task.id, task.title, task.description,
          task.start_at,
          task.priority, task.status,
          task.updated_at, task.created_at, task.type
        )
      );
    }
    // No dates at all → skip, nothing useful for calendar
  }

  for (const ticket of tickets) {
    if (ticket.sla_deadline) {
      components.push(
        formatAllDayEvent(
          ticket.id, ticket.subject, ticket.description,
          ticket.sla_deadline,
          ticket.priority, ticket.status,
          ticket.updated_at, ticket.created_at, "ticket"
        )
      );
    }
    // No SLA deadline → skip
  }

  const header = [
    "BEGIN:VCALENDAR",
    "VERSION:2.0",
    "PRODID:-//Trackr//iCal Feed//EN",
    `X-WR-CALNAME:${escapeText(calendarName)}`,
    calendarDescription
      ? `X-WR-CALDESC:${escapeText(calendarDescription)}`
      : null,
    "CALSCALE:GREGORIAN",
    "METHOD:PUBLISH",
  ]
    .filter(Boolean)
    .join("\r\n");

  const footer = "END:VCALENDAR";

  const body = components.length > 0 ? "\r\n" + components.join("\r\n") : "";

  return header + body + "\r\n" + footer + "\r\n";
}
