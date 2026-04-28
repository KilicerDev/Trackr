-- ============================================
-- ATTACHMENTS: allow common video MIME types in the storage bucket
--
-- App-side `ALLOWED_MIME_TYPES` already gates uploads, but the Supabase
-- storage bucket has its own `allowed_mime_types` enforcement that would
-- reject videos before the app sees them. Keep the two lists in sync.
-- ============================================

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'storage' AND table_name = 'buckets' AND column_name = 'allowed_mime_types'
  ) THEN
    UPDATE storage.buckets
    SET allowed_mime_types = ARRAY[
      'image/png', 'image/jpeg', 'image/gif', 'image/webp', 'image/svg+xml',
      'video/mp4', 'video/quicktime', 'video/webm',
      'application/pdf',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'application/vnd.ms-excel',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'application/vnd.ms-powerpoint',
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'text/plain', 'text/csv'
    ]
    WHERE id = 'attachments';
  END IF;
END $$;
