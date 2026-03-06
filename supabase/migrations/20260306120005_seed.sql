-- ============================================
-- SEED: Permissions, roles, role permissions, support tiers, system config
-- ============================================


-- ============================================
-- 1. PERMISSIONS
-- ============================================

INSERT INTO public.permissions (id, resource, action, description) VALUES
  -- Tasks
  (gen_random_uuid(), 'tasks',              'create',       'Create new tasks'),
  (gen_random_uuid(), 'tasks',              'read',         'View tasks'),
  (gen_random_uuid(), 'tasks',              'update',       'Update tasks'),
  (gen_random_uuid(), 'tasks',              'delete',       'Delete tasks'),
  (gen_random_uuid(), 'tasks',              'assign',       'Assign tasks to users'),
  -- Support Tickets
  (gen_random_uuid(), 'support_tickets',    'create',       'Create support tickets'),
  (gen_random_uuid(), 'support_tickets',    'read',         'View support tickets'),
  (gen_random_uuid(), 'support_tickets',    'update',       'Update support tickets'),
  (gen_random_uuid(), 'support_tickets',    'delete',       'Delete support tickets'),
  (gen_random_uuid(), 'support_tickets',    'assign',       'Assign tickets to agents'),
  -- Projects
  (gen_random_uuid(), 'projects',           'create',       'Create projects'),
  (gen_random_uuid(), 'projects',           'read',         'View projects'),
  (gen_random_uuid(), 'projects',           'update',       'Update projects'),
  (gen_random_uuid(), 'projects',           'delete',       'Delete projects'),
  (gen_random_uuid(), 'projects',           'manage',       'Manage project settings and members'),
  -- Members
  (gen_random_uuid(), 'members',            'invite',       'Invite users to org or project'),
  (gen_random_uuid(), 'members',            'remove',       'Remove users from org or project'),
  (gen_random_uuid(), 'members',            'manage_roles', 'Change user roles'),
  -- Organization
  (gen_random_uuid(), 'organizations',      'update',       'Update organization settings'),
  (gen_random_uuid(), 'organizations',      'billing',      'Manage billing'),
  (gen_random_uuid(), 'organizations',      'delete',       'Delete organization');


-- ============================================
-- 2. SYSTEM ROLES
-- ============================================

INSERT INTO public.roles (id, name, slug, description, is_system, organization_id) VALUES
  ('a0000000-0000-0000-0000-000000000001', 'Owner',          'owner',   'Full access to everything. Cannot be restricted.',                      true, null),
  ('a0000000-0000-0000-0000-000000000002', 'Administration', 'admin',   'Full access to everything. Like the owner.',                            true, null),
  ('a0000000-0000-0000-0000-000000000003', 'Manager',        'manager', 'Manage tasks, tickets, and members within assigned organizations.',     true, null),
  ('a0000000-0000-0000-0000-000000000004', 'Agent',          'agent',   'Manage assigned projects and tasks within assigned organizations.',     true, null),
  ('a0000000-0000-0000-0000-000000000005', 'Client',         'client',  'Can create and view own support tickets.',                              true, null);


-- ============================================
-- 3. ROLE PERMISSIONS (final correct state)
-- ============================================

-- OWNER: everything -> scope: all
INSERT INTO public.role_permissions (id, role_id, permission_id, scope)
SELECT gen_random_uuid(), 'a0000000-0000-0000-0000-000000000001', p.id, 'all'
FROM public.permissions p;

-- ADMINISTRATION: everything -> scope: all
INSERT INTO public.role_permissions (id, role_id, permission_id, scope)
SELECT gen_random_uuid(), 'a0000000-0000-0000-0000-000000000002', p.id, 'all'
FROM public.permissions p;

-- MANAGER: tasks, tickets, members, project read/update
INSERT INTO public.role_permissions (id, role_id, permission_id, scope)
SELECT gen_random_uuid(), 'a0000000-0000-0000-0000-000000000003', p.id, 'all'
FROM public.permissions p
WHERE (p.resource = 'tasks')
   OR (p.resource = 'support_tickets')
   OR (p.resource = 'projects' AND p.action IN ('read', 'update'))
   OR (p.resource = 'members' AND p.action IN ('invite', 'remove'));

-- AGENT: tasks + projects only (NO support_tickets)
INSERT INTO public.role_permissions (id, role_id, permission_id, scope)
SELECT gen_random_uuid(), 'a0000000-0000-0000-0000-000000000004', p.id, 'own'
FROM public.permissions p
WHERE (p.resource = 'tasks' AND p.action IN ('create', 'read', 'update'))
   OR (p.resource = 'projects' AND p.action IN ('read', 'update'));

-- CLIENT: support_tickets create + read only (NO update), plus tasks.read (own)
INSERT INTO public.role_permissions (id, role_id, permission_id, scope)
SELECT gen_random_uuid(), 'a0000000-0000-0000-0000-000000000005', p.id, 'own'
FROM public.permissions p
WHERE (p.resource = 'support_tickets' AND p.action IN ('create', 'read'))
   OR (p.resource = 'tasks' AND p.action = 'read');


-- ============================================
-- 4. SUPPORT TIERS
-- ============================================

INSERT INTO public.support_tiers (id, name, slug, response_time_hours, resolution_time_hours, description, sort_order) VALUES
  ('10000000-0000-0000-0000-000000000001', 'Basic',    'basic',    48, 168, 'Standard support with relaxed SLA',     0),
  ('10000000-0000-0000-0000-000000000002', 'Standard', 'standard', 24,  72, 'Improved response and resolution times', 1),
  ('10000000-0000-0000-0000-000000000003', 'Premium',  'premium',   8,  24, 'Priority support for important clients', 2),
  ('10000000-0000-0000-0000-000000000004', 'Gold',     'gold',      2,   8, 'Top-tier SLA with fastest turnaround',  3);


-- ============================================
-- 5. SYSTEM CONFIG
-- ============================================

INSERT INTO public.system_config (
  app_name,
  support_email,
  default_support_tier_id
) VALUES (
  'Trackr',
  'support@kilicsoftware.com',
  '10000000-0000-0000-0000-000000000001'
);
