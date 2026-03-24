-- ============================================
-- SAVED VIEWS: per-user saved filter presets for the tasks page
-- ============================================

-- 1. Table
CREATE TABLE public.saved_views (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  name       text NOT NULL,
  filters    jsonb NOT NULL DEFAULT '{}',
  view_mode  text NOT NULL DEFAULT 'list',
  group_by   text NOT NULL DEFAULT 'status',
  sort_order int  NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- 2. Indexes
CREATE INDEX idx_saved_views_user ON public.saved_views (user_id);

-- 3. RLS
ALTER TABLE public.saved_views ENABLE ROW LEVEL SECURITY;

CREATE POLICY saved_views_select ON public.saved_views
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY saved_views_insert ON public.saved_views
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY saved_views_update ON public.saved_views
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY saved_views_delete ON public.saved_views
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());
