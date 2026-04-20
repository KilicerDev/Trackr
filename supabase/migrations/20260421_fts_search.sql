-- ============================================
-- FTS SEARCH: replace pgvector with Postgres full-text search
-- ============================================

DROP FUNCTION IF EXISTS public.universal_search(vector, uuid[], text[], float, int);

DROP INDEX IF EXISTS public.search_documents_embedding_idx;

ALTER TABLE public.search_documents
  DROP COLUMN IF EXISTS embedding;

ALTER TABLE public.search_documents
  ADD COLUMN search_vector tsvector
  GENERATED ALWAYS AS (
    to_tsvector(
      'simple',
      coalesce(title, '') || ' ' || coalesce(content, '')
    )
  ) STORED;

CREATE INDEX idx_search_documents_fts
  ON public.search_documents
  USING GIN (search_vector);

-- ============================================
-- UNIVERSAL SEARCH RPC (FTS)
-- ============================================

CREATE OR REPLACE FUNCTION public.universal_search(
  query_text     text,
  filter_org_ids uuid[],
  filter_types   text[] DEFAULT NULL,
  match_count    int    DEFAULT 20
)
RETURNS TABLE (
  id          uuid,
  source_type text,
  source_id   uuid,
  parent_id   uuid,
  title       text,
  preview     text,
  metadata    jsonb,
  rank        real
)
LANGUAGE sql STABLE
AS $$
  WITH q AS (
    SELECT websearch_to_tsquery('simple', query_text) AS tsq
  )
  SELECT
    d.id,
    d.source_type,
    d.source_id,
    d.parent_id,
    d.title,
    d.preview,
    d.metadata,
    ts_rank(d.search_vector, q.tsq) AS rank
  FROM public.search_documents d, q
  WHERE d.search_vector @@ q.tsq
    AND d.org_id = ANY(filter_org_ids)
    AND (filter_types IS NULL OR d.source_type = ANY(filter_types))
  ORDER BY rank DESC
  LIMIT match_count;
$$;

GRANT EXECUTE ON FUNCTION public.universal_search(text, uuid[], text[], int)
  TO authenticated;
