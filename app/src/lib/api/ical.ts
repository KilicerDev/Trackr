export type IcalTokenStatus = {
  exists: boolean;
  created_at: string | null;
  last_used_at: string | null;
};

export const ical = {
  /** Check whether the current user has an active iCal token. */
  async getStatus(): Promise<IcalTokenStatus> {
    const res = await fetch("/api/ical/token");
    if (!res.ok) throw new Error("Failed to check iCal token status");
    return res.json();
  },

  /** Generate (or regenerate) an iCal token. Returns the plaintext token once. */
  async generateToken(): Promise<string> {
    const res = await fetch("/api/ical/token", { method: "POST" });
    if (!res.ok) throw new Error("Failed to generate iCal token");
    const data = await res.json();
    return data.token;
  },

  /** Revoke the current user's iCal token. */
  async revokeToken(): Promise<void> {
    const res = await fetch("/api/ical/token", { method: "DELETE" });
    if (!res.ok) throw new Error("Failed to revoke iCal token");
  },
};
