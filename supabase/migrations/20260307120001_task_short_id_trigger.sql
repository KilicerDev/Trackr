-- ============================================
-- Auto-generate task short_id on insert
-- Format: {PROJECT_IDENTIFIER}-{SEQUENTIAL_NUMBER}
-- e.g. MARKE-1, MARKE-2, PLAT-1
-- ============================================

CREATE OR REPLACE FUNCTION public.set_task_short_id()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  _identifier text;
  _next_num   int;
BEGIN
  IF NEW.short_id IS NOT NULL THEN
    RETURN NEW;
  END IF;

  SELECT identifier INTO _identifier
  FROM public.projects
  WHERE id = NEW.project_id;

  IF _identifier IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT COALESCE(MAX(
    CASE
      WHEN t.short_id ~ ('^' || _identifier || '-[0-9]+$')
      THEN CAST(substring(t.short_id FROM '-([0-9]+)$') AS int)
      ELSE 0
    END
  ), 0) + 1
  INTO _next_num
  FROM public.tasks t
  WHERE t.project_id = NEW.project_id;

  NEW.short_id := _identifier || '-' || _next_num;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_set_task_short_id
  BEFORE INSERT ON public.tasks
  FOR EACH ROW
  EXECUTE FUNCTION public.set_task_short_id();


-- ============================================
-- Backfill existing tasks that have NULL short_id
-- ============================================

WITH numbered AS (
  SELECT
    t.id,
    p.identifier,
    ROW_NUMBER() OVER (PARTITION BY t.project_id ORDER BY t.created_at) AS rn
  FROM public.tasks t
  JOIN public.projects p ON p.id = t.project_id
  WHERE t.short_id IS NULL
)
UPDATE public.tasks
SET short_id = numbered.identifier || '-' || numbered.rn
FROM numbered
WHERE public.tasks.id = numbered.id;

-- Unique constraint to prevent duplicates under concurrency
CREATE UNIQUE INDEX idx_tasks_short_id_unique
  ON public.tasks (short_id)
  WHERE short_id IS NOT NULL AND deleted_at IS NULL;
