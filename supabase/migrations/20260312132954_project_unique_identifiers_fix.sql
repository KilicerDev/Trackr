-- ============================================
-- Fix: scope task short_id uniqueness per project
-- and enforce project identifier uniqueness per org
-- ============================================

-- 1. Drop the old global unique index on tasks.short_id
DROP INDEX IF EXISTS public.idx_tasks_short_id_unique;

-- 2. Re-create it scoped to project_id
CREATE UNIQUE INDEX idx_tasks_short_id_unique
  ON public.tasks (project_id, short_id)
  WHERE short_id IS NOT NULL AND deleted_at IS NULL;

-- 3. Enforce unique project identifier per organization
CREATE UNIQUE INDEX idx_projects_identifier_per_org
  ON public.projects (organization_id, identifier)
  WHERE deleted_at IS NULL;
