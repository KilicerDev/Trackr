import { getClient } from "./client";

export type UserPrefs = Record<string, unknown>;

export const userPreferences = {
  async getPrefs(): Promise<UserPrefs> {
    const { data, error } = await getClient()
      .from("user_preferences")
      .select("prefs")
      .maybeSingle();
    if (error) throw error;
    return (data?.prefs as UserPrefs | null) ?? {};
  },

  async setPrefs(prefs: UserPrefs): Promise<void> {
    const client = getClient();
    const { data: userData, error: userError } = await client.auth.getUser();
    if (userError) throw userError;
    const userId = userData.user?.id;
    if (!userId) return;
    const { error } = await client
      .from("user_preferences")
      .upsert({ user_id: userId, prefs });
    if (error) throw error;
  },
};
