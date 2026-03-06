-- ============================================
-- Remove support_tickets permissions from agent role
-- Agents are project/task collaborators and should not interact with the ticket system
-- ============================================

DELETE FROM public.role_permissions
WHERE role_id = 'a0000000-0000-0000-0000-000000000004'
  AND permission_id IN (
    SELECT id FROM public.permissions
    WHERE resource = 'support_tickets' AND action IN ('read', 'update')
  );
