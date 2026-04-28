-- ============================================
-- SAVED VIEWS: add scope so the same table serves both /tasks and /tickets
-- ============================================

ALTER TABLE public.saved_views
  ADD COLUMN scope text NOT NULL DEFAULT 'tasks';

CREATE INDEX idx_saved_views_user_scope ON public.saved_views (user_id, scope);
