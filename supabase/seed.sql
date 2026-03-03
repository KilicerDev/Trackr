-- ============================================
-- SEED: Initial test data
-- ============================================

-- Fixed UUIDs for referencing
-- User 1 (owner):    b0000000-0000-0000-0000-000000000001
-- User 2 (client):   b0000000-0000-0000-0000-000000000002
-- Org:               c0000000-0000-0000-0000-000000000001
-- Project 1:         d0000000-0000-0000-0000-000000000001
-- Project 2:         d0000000-0000-0000-0000-000000000002
-- Tasks:             e0000000-0000-0000-0000-00000000000X
-- Tickets:           f0000000-0000-0000-0000-00000000000X
-- Roles (from migration): a0000000-0000-0000-0000-00000000000X


-- ============================================
-- 1. AUTH USERS
-- ============================================

INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, is_super_admin,
  email_change, email_change_token_new, recovery_token
) VALUES (
  'b0000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated',
  'ertugul.kilic@icloud.com',
  crypt('091424', gen_salt('bf')),
  now(),
  '{"provider": "email", "providers": ["email"]}',
  '{"full_name": "Ertuğul Kılıç", "username": "kilicer"}',
  now(), now(), '', false,
  '', '', ''
), (
  'b0000000-0000-0000-0000-000000000002',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated',
  'sarah.mueller@example.com',
  crypt('testtest', gen_salt('bf')),
  now(),
  '{"provider": "email", "providers": ["email"]}',
  '{"full_name": "Sarah Müller", "username": "sarahm"}',
  now(), now(), '', false,
  '', '', ''
);

INSERT INTO auth.identities (
  id, user_id, identity_data, provider, provider_id,
  last_sign_in_at, created_at, updated_at
) VALUES (
  'b0000000-0000-0000-0000-000000000001',
  'b0000000-0000-0000-0000-000000000001',
  jsonb_build_object(
    'sub', 'b0000000-0000-0000-0000-000000000001',
    'email', 'ertugul.kilic@icloud.com',
    'email_verified', true,
    'full_name', 'Ertuğul Kılıç',
    'username', 'kilicer'
  ),
  'email', 'b0000000-0000-0000-0000-000000000001',
  now(), now(), now()
), (
  'b0000000-0000-0000-0000-000000000002',
  'b0000000-0000-0000-0000-000000000002',
  jsonb_build_object(
    'sub', 'b0000000-0000-0000-0000-000000000002',
    'email', 'sarah.mueller@example.com',
    'email_verified', true,
    'full_name', 'Sarah Müller',
    'username', 'sarahm'
  ),
  'email', 'b0000000-0000-0000-0000-000000000002',
  now(), now(), now()
);


-- ============================================
-- 2. ORGANIZATION (must come before users referencing it)
-- ============================================

INSERT INTO public.organizations (id, name, slug, domain, logo_url, support_tier_id, is_active, website_url, notes) VALUES
  ('c0000000-0000-0000-0000-000000000001', 'Kılıç Software', 'kilic-software', 'kilicsoftware.com', null, '10000000-0000-0000-0000-000000000004', true, 'https://kilicsoftware.com', 'Main organization');


-- ============================================
-- 3. PUBLIC USERS (after org exists)
-- ============================================

INSERT INTO public.users (id, email, full_name, username, avatar_url, timezone, locale, organization_id, is_active, last_seen_at) VALUES
  ('b0000000-0000-0000-0000-000000000001', 'ertugul.kilic@icloud.com', 'Ertuğul Kılıç', 'kilicer', null, 'Europe/Istanbul', 'tr', 'c0000000-0000-0000-0000-000000000001', true, now()),
  ('b0000000-0000-0000-0000-000000000002', 'sarah.mueller@example.com', 'Sarah Müller', 'sarahm', null, 'Europe/Berlin', 'de', 'c0000000-0000-0000-0000-000000000001', true, now());


-- ============================================
-- 4. ORGANIZATION MEMBERS
-- ============================================

INSERT INTO public.organization_members (organization_id, user_id, role_id) VALUES
  ('c0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001'),
  ('c0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000005');


-- ============================================
-- 5. PROJECTS
-- ============================================

INSERT INTO public.projects (id, name, identifier, description, status, owner_id, organization_id, start_at, color, icon) VALUES
  ('d0000000-0000-0000-0000-000000000001', 'Platform MVP', 'PLAT', 'Main SaaS platform development', 'active', 'b0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', now() - interval '30 days', '#3B82F6', '🚀'),
  ('d0000000-0000-0000-0000-000000000002', 'Marketing Website', 'MKTG', 'Public-facing marketing site redesign', 'planning', 'b0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', now() - interval '5 days', '#10B981', '🌐');


-- ============================================
-- 6. PROJECT MEMBERS
-- ============================================

INSERT INTO public.project_members (project_id, user_id, role_id) VALUES
  ('d0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001'),
  ('d0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001');


-- ============================================
-- 7. TASKS
-- ============================================

INSERT INTO public.tasks (id, title, description, status, priority, type, project_id, created_by, short_id, start_at, end_at) VALUES
  ('e0000000-0000-0000-0000-000000000001', 'Set up authentication flow', 'Implement Supabase auth with email/password and OAuth providers.', 'in_progress', 'high', 'feature', 'd0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'PLAT-1', now() - interval '10 days', now() + interval '5 days'),
  ('e0000000-0000-0000-0000-000000000002', 'Design dashboard layout', 'Create the main dashboard wireframe and component structure.', 'done', 'medium', 'task', 'd0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'PLAT-2', now() - interval '20 days', now() - interval '12 days'),
  ('e0000000-0000-0000-0000-000000000003', 'Fix login redirect loop', 'After login the user gets redirected back to login page on Safari.', 'todo', 'urgent', 'bug', 'd0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'PLAT-3', null, null),
  ('e0000000-0000-0000-0000-000000000004', 'RBAC permission system', 'Implement role-based access control with scoped permissions.', 'in_progress', 'high', 'feature', 'd0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'PLAT-4', now() - interval '3 days', now() + interval '14 days'),
  ('e0000000-0000-0000-0000-000000000005', 'Write copy for landing page', 'Draft headline, subheadline, feature sections, and CTA copy.', 'backlog', 'low', 'task', 'd0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001', 'MKTG-1', null, null),
  ('e0000000-0000-0000-0000-000000000006', 'API rate limiting middleware', 'Add rate limiting to public API endpoints. 100 req/min for basic, 1000 for enterprise.', 'backlog', 'medium', 'feature', 'd0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'PLAT-5', null, null);

-- Subtask
INSERT INTO public.tasks (id, title, description, status, priority, type, project_id, created_by, short_id, parent_id) VALUES
  ('e0000000-0000-0000-0000-000000000007', 'Create permission check middleware', 'Middleware that calls user_has_permission() on every API route.', 'todo', 'high', 'task', 'd0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'PLAT-4a', 'e0000000-0000-0000-0000-000000000004');


-- ============================================
-- 8. TASK ASSIGNMENTS
-- ============================================

INSERT INTO public.task_assignments (task_id, user_id, role, assigned_by) VALUES
  ('e0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'assignee', 'b0000000-0000-0000-0000-000000000001'),
  ('e0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000001', 'assignee', 'b0000000-0000-0000-0000-000000000001'),
  ('e0000000-0000-0000-0000-000000000004', 'b0000000-0000-0000-0000-000000000001', 'assignee', 'b0000000-0000-0000-0000-000000000001'),
  ('e0000000-0000-0000-0000-000000000007', 'b0000000-0000-0000-0000-000000000001', 'assignee', 'b0000000-0000-0000-0000-000000000001');


-- ============================================
-- 9. TASK COMMENTS
-- ============================================

INSERT INTO public.task_comments (task_id, user_id, content) VALUES
  ('e0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'Started implementing the email/password flow. OAuth will come in a follow-up task.'),
  ('e0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000001', 'Reproduced on Safari 17.2. Looks like a cookie SameSite issue.'),
  ('e0000000-0000-0000-0000-000000000004', 'b0000000-0000-0000-0000-000000000001', 'Migration and seed files are ready. Moving on to the middleware integration.');


-- ============================================
-- 10. TASK ACTIVITIES
-- ============================================

INSERT INTO public.task_activities (task_id, user_id, action, field_name, old_value, new_value) VALUES
  ('e0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'updated_field', 'status', 'todo', 'in_progress'),
  ('e0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001', 'updated_field', 'status', 'in_progress', 'done'),
  ('e0000000-0000-0000-0000-000000000004', 'b0000000-0000-0000-0000-000000000001', 'updated_field', 'priority', 'medium', 'high'),
  ('e0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'created', null, null, null);


-- ============================================
-- 11. SUPPORT TICKETS
-- ============================================

INSERT INTO public.support_tickets (id, customer_id, subject, description, status, priority, channel, assigned_agent_id, category, organization_id, satisfaction_score, metadata) VALUES
  ('f0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000002', 'Cannot access billing page', 'I click on billing in settings but get a 403 error. I need to update my payment method.', 'open', 'high', 'web_form', 'b0000000-0000-0000-0000-000000000001', 'billing', 'c0000000-0000-0000-0000-000000000001', null, '{"browser": "Chrome 121", "os": "macOS 14.3"}'),
  ('f0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000002', 'Feature request: dark mode', 'Would love to have a dark mode toggle in the settings.', 'resolved', 'low', 'email', 'b0000000-0000-0000-0000-000000000001', 'feature_request', 'c0000000-0000-0000-0000-000000000001', 4, '{"browser": "Firefox 122", "os": "Windows 11"}');


-- ============================================
-- 12. SUPPORT TICKET MESSAGES
-- ============================================

INSERT INTO public.support_ticket_messages (ticket_id, sender_id, is_internal_note, body) VALUES
  ('f0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000002', false, 'Hi, I keep getting a 403 when trying to access the billing page. Can you help?'),
  ('f0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', true, 'Checked her permissions — client role does not have organizations.billing. Might need to handle this as a special case or show a contact-us form instead.'),
  ('f0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', false, 'Hi Sarah, thanks for reaching out. I''m looking into this now and will get back to you shortly.'),
  ('f0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000002', false, 'It would be great if you could add a dark mode option. My eyes hurt at night!'),
  ('f0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001', false, 'Great suggestion! We have this on our roadmap. Marking as resolved for now — we''ll notify you when it ships.');


-- ============================================
-- 13. ORGANIZATION SETTINGS
-- ============================================

INSERT INTO public.organization_settings (
  organization_id,
  auto_assign_tickets,
  default_ticket_priority,
  require_ticket_category
) VALUES (
  'c0000000-0000-0000-0000-000000000001',
  false,
  'medium',
  true
);

