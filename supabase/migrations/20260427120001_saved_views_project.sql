-- ============================================
-- SAVED VIEWS: optional per-project scoping for views shown on /projects/<id>
-- ============================================

ALTER TABLE public.saved_views
  ADD COLUMN project_id uuid REFERENCES public.projects(id) ON DELETE CASCADE;

CREATE INDEX idx_saved_views_user_scope_project
  ON public.saved_views (user_id, scope, project_id);
