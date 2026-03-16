import { getAdminClient } from "./supabase-admin";

/**
 * Extracts text content from a file stored in Supabase Storage.
 * Used for search indexing - extracts readable text from supported file types.
 */
export async function extractText(storagePath: string, mimeType: string): Promise<string | null> {
  // Only extract text from plain text and CSV files
  if (mimeType === "text/plain" || mimeType === "text/csv") {
    try {
      const admin = getAdminClient();
      const { data, error } = await admin.storage
        .from("attachments")
        .download(storagePath);

      if (error || !data) return null;
      return await data.text();
    } catch {
      return null;
    }
  }

  // For other file types (PDF, Office docs), just return null
  // Text extraction for these types can be added later with appropriate libraries
  return null;
}
