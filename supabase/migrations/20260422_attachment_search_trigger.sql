-- ============================================
-- ATTACHMENT SEARCH SYNC: keep search_documents in sync with attachments
-- ============================================
--
-- The web path calls /api/index-document after an upload, which populates
-- search_documents with extracted text (OCR / PDF text / etc.). Non-web
-- insert paths (MCP server, future bulk imports) skip that step, so this
-- trigger writes a minimal filename-only row so the attachment is at least
-- FTS-searchable by file_name. A later reindex can upgrade the row to the
-- full extracted-text version.

CREATE OR REPLACE FUNCTION public.sync_attachment_search_document()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF (TG_OP = 'INSERT') THEN
    INSERT INTO public.search_documents (
      source_type, source_id, parent_id, org_id, title, preview, content, metadata
    )
    VALUES (
      'attachment',
      NEW.id,
      NEW.entity_id,
      NEW.org_id,
      NEW.file_name,
      NULL,
      NEW.file_name,
      jsonb_build_object(
        'file_name',   NEW.file_name,
        'mime_type',   NEW.mime_type,
        'entity_type', NEW.entity_type,
        'entity_id',   NEW.entity_id
      )
    )
    ON CONFLICT (source_type, source_id) DO NOTHING;
    RETURN NEW;
  ELSIF (TG_OP = 'UPDATE') THEN
    IF NEW.deleted_at IS NOT NULL AND OLD.deleted_at IS NULL THEN
      DELETE FROM public.search_documents
      WHERE source_type = 'attachment' AND source_id = NEW.id;
    END IF;
    RETURN NEW;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER attachments_search_sync
AFTER INSERT OR UPDATE ON public.attachments
FOR EACH ROW EXECUTE FUNCTION public.sync_attachment_search_document();
