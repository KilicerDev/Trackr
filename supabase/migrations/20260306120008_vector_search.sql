-- ============================================
-- VECTOR SEARCH: pgvector + unified search_documents
-- ============================================

CREATE EXTENSION IF NOT EXISTS vector;

-- ============================================
-- 1. SEARCH_DOCUMENTS TABLE
-- ============================================

CREATE TABLE public.search_documents (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_type  text NOT NULL,
  source_id    uuid NOT NULL,
  parent_id    uuid,
  title        text NOT NULL,
  preview      text,
  content      text NOT NULL,
  metadata     jsonb DEFAULT '{}',
  embedding    vector(768),
  org_id       uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),

  UNIQUE(source_type, source_id)
);

CREATE INDEX search_documents_embedding_idx
  ON public.search_documents
  USING hnsw (embedding vector_cosine_ops);

CREATE INDEX idx_search_documents_org_id
  ON public.search_documents (org_id);

CREATE INDEX idx_search_documents_source
  ON public.search_documents (source_type, source_id);

ALTER TABLE public.search_documents ENABLE ROW LEVEL SECURITY;

-- service_role can do everything (used by Go service via direct DB connection)
CREATE POLICY "search_documents_service_all"
  ON public.search_documents
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- authenticated users can read documents in their organization
CREATE POLICY "search_documents_select"
  ON public.search_documents
  FOR SELECT
  TO authenticated
  USING (public.is_member_of(org_id));

-- ============================================
-- 2. UNIVERSAL SEARCH RPC
-- ============================================

CREATE OR REPLACE FUNCTION universal_search(
  query_embedding vector(768),
  filter_org_ids uuid[],
  filter_types text[] DEFAULT NULL,
  match_threshold float DEFAULT 0.4,
  match_count int DEFAULT 20
)
RETURNS TABLE (
  id uuid,
  source_type text,
  source_id uuid,
  parent_id uuid,
  title text,
  preview text,
  metadata jsonb,
  similarity float
)
LANGUAGE sql STABLE
AS $$
  SELECT
    d.id,
    d.source_type,
    d.source_id,
    d.parent_id,
    d.title,
    d.preview,
    d.metadata,
    1 - (d.embedding <=> query_embedding) AS similarity
  FROM public.search_documents d
  WHERE d.embedding IS NOT NULL
    AND d.org_id = ANY(filter_org_ids)
    AND (filter_types IS NULL OR d.source_type = ANY(filter_types))
    AND 1 - (d.embedding <=> query_embedding) >= match_threshold
  ORDER BY d.embedding <=> query_embedding
  LIMIT match_count;
$$;
