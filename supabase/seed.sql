-- ============================================
-- SEED: Comprehensive test data
-- ============================================
-- All user passwords: 091424
--
-- Fixed UUIDs:
-- Users:        b0000000-0000-0000-0000-00000000000X
-- Orgs:         c0000000-0000-0000-0000-00000000000X
-- Projects:     d0000000-0000-0000-0000-00000000000X
-- Tasks:        e0000000-0000-0000-0000-00000000000X
-- Tickets:      f0000000-0000-0000-0000-00000000000X
-- Roles (init): a0000000-0000-0000-0000-00000000000X
-- SLA tiers:    10000000-0000-0000-0000-00000000000X
--
-- Roles: 01=owner, 02=admin, 03=manager, 04=agent, 05=client
-- Tiers: 01=Basic, 02=Standard, 03=Premium, 04=Gold


-- ============================================
-- 1. ORGANIZATIONS
-- ============================================

INSERT INTO public.organizations (id, name, slug, domain, logo_url, support_tier_id, is_active, website_url, notes) VALUES
  ('c0000000-0000-0000-0000-000000000001', 'Kılıç Software',       'kilic-software',       'kilicsoftware.com',     null, null,                                        true, 'https://kilicsoftware.com',     'Platform organization'),
  ('c0000000-0000-0000-0000-000000000002', 'Müller GmbH',           'mueller-gmbh',          'mueller-gmbh.de',       null, '10000000-0000-0000-0000-000000000004', true, 'https://mueller-gmbh.de',       'Manufacturing client – Gold tier'),
  ('c0000000-0000-0000-0000-000000000003', 'Schmidt & Partner AG',  'schmidt-partner',       'schmidt-partner.de',    null, '10000000-0000-0000-0000-000000000003', true, 'https://schmidt-partner.de',    'Law firm – Premium tier'),
  ('c0000000-0000-0000-0000-000000000004', 'TechStart GmbH',        'techstart',             'techstart.io',          null, '10000000-0000-0000-0000-000000000001', true, 'https://techstart.io',          'Startup – Basic tier'),
  ('c0000000-0000-0000-0000-000000000005', 'Weber Industries',      'weber-industries',      'weber-industries.com',  null, '10000000-0000-0000-0000-000000000002', true, 'https://weber-industries.com',  'Logistics – Standard tier'),
  ('c0000000-0000-0000-0000-000000000006', 'Semotion',              'semotion',              'semotion.de',           null, null,                                        true, 'https://semotion.de',           'Partner agency – no support tier');


-- ============================================
-- 2. AUTH USERS (trigger handle_new_user creates public.users)
-- ============================================

INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, is_super_admin,
  email_change, email_change_token_new, recovery_token
) VALUES
  -- Platform org: Kılıç Software
  ('b0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
   'ertugul.kilic@icloud.com', crypt('091424', gen_salt('bf')), now(),
   '{"provider": "email", "providers": ["email"]}',
   '{"full_name": "Ertuğul Kılıç", "username": "kilicer"}',
   now(), now(), '', false, '', '', ''),

  ('b0000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
   'anna.weber@kilicsoftware.com', crypt('091424', gen_salt('bf')), now(),
   '{"provider": "email", "providers": ["email"]}',
   '{"full_name": "Anna Weber", "username": "annaw"}',
   now(), now(), '', false, '', '', ''),

  ('b0000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
   'lukas.braun@kilicsoftware.com', crypt('091424', gen_salt('bf')), now(),
   '{"provider": "email", "providers": ["email"]}',
   '{"full_name": "Lukas Braun", "username": "lukasb"}',
   now(), now(), '', false, '', '', ''),

  ('b0000000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
   'maria.schmidt@kilicsoftware.com', crypt('091424', gen_salt('bf')), now(),
   '{"provider": "email", "providers": ["email"]}',
   '{"full_name": "Maria Schmidt", "username": "marias"}',
   now(), now(), '', false, '', '', ''),

  ('b0000000-0000-0000-0000-00000000000c', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
   'julia.klein@kilicsoftware.com', crypt('091424', gen_salt('bf')), now(),
   '{"provider": "email", "providers": ["email"]}',
   '{"full_name": "Julia Klein", "username": "juliak"}',
   now(), now(), '', false, '', '', ''),

  -- Client: Müller GmbH
  ('b0000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
   'sarah.mueller@example.com', crypt('091424', gen_salt('bf')), now(),
   '{"provider": "email", "providers": ["email"]}',
   '{"full_name": "Sarah Müller", "username": "sarahm"}',
   now(), now(), '', false, '', '', ''),

  ('b0000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
   'nicholas@kilohertz.dev', crypt('091424', gen_salt('bf')), now(),
   '{"provider": "email", "providers": ["email"]}',
   '{"full_name": "Nicholas Hinke", "username": "nicholas"}',
   now(), now(), '', false, '', '', ''),

  -- Client: Schmidt & Partner AG
  ('b0000000-0000-0000-0000-000000000007', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
   'thomas.fischer@schmidt-partner.de', crypt('091424', gen_salt('bf')), now(),
   '{"provider": "email", "providers": ["email"]}',
   '{"full_name": "Thomas Fischer", "username": "thomasf"}',
   now(), now(), '', false, '', '', ''),

  ('b0000000-0000-0000-0000-000000000008', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
   'laura.becker@schmidt-partner.de', crypt('091424', gen_salt('bf')), now(),
   '{"provider": "email", "providers": ["email"]}',
   '{"full_name": "Laura Becker", "username": "laurab"}',
   now(), now(), '', false, '', '', ''),

  -- Client: TechStart GmbH
  ('b0000000-0000-0000-0000-000000000009', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
   'max.wagner@techstart.io', crypt('091424', gen_salt('bf')), now(),
   '{"provider": "email", "providers": ["email"]}',
   '{"full_name": "Max Wagner", "username": "maxw"}',
   now(), now(), '', false, '', '', ''),

  ('b0000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
   'elena.hoffmann@techstart.io', crypt('091424', gen_salt('bf')), now(),
   '{"provider": "email", "providers": ["email"]}',
   '{"full_name": "Elena Hoffmann", "username": "elenah"}',
   now(), now(), '', false, '', '', ''),

  -- Client: Weber Industries
  ('b0000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
   'kai.richter@weber-industries.com', crypt('091424', gen_salt('bf')), now(),
   '{"provider": "email", "providers": ["email"]}',
   '{"full_name": "Kai Richter", "username": "kair"}',
   now(), now(), '', false, '', '', ''),

  -- Partner: Semotion
  ('b0000000-0000-0000-0000-00000000000d', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
   'lisa@semotion.de', crypt('091424', gen_salt('bf')), now(),
   '{"provider": "email", "providers": ["email"]}',
   '{"full_name": "Lisa Berger", "username": "lisab"}',
   now(), now(), '', false, '', '', '');


-- ============================================
-- 2b. AUTH IDENTITIES
-- ============================================

INSERT INTO auth.identities (
  id, user_id, identity_data, provider, provider_id,
  last_sign_in_at, created_at, updated_at
) VALUES
  ('b0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001',
   jsonb_build_object('sub','b0000000-0000-0000-0000-000000000001','email','ertugul.kilic@icloud.com','email_verified',true,'full_name','Ertuğul Kılıç','username','kilicer'),
   'email','b0000000-0000-0000-0000-000000000001', now(), now(), now()),

  ('b0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000002',
   jsonb_build_object('sub','b0000000-0000-0000-0000-000000000002','email','sarah.mueller@example.com','email_verified',true,'full_name','Sarah Müller','username','sarahm'),
   'email','b0000000-0000-0000-0000-000000000002', now(), now(), now()),

  ('b0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000003',
   jsonb_build_object('sub','b0000000-0000-0000-0000-000000000003','email','nicholas@kilohertz.dev','email_verified',true,'full_name','Nicholas Hinke','username','nicholas'),
   'email','b0000000-0000-0000-0000-000000000003', now(), now(), now()),

  ('b0000000-0000-0000-0000-000000000004', 'b0000000-0000-0000-0000-000000000004',
   jsonb_build_object('sub','b0000000-0000-0000-0000-000000000004','email','anna.weber@kilicsoftware.com','email_verified',true,'full_name','Anna Weber','username','annaw'),
   'email','b0000000-0000-0000-0000-000000000004', now(), now(), now()),

  ('b0000000-0000-0000-0000-000000000005', 'b0000000-0000-0000-0000-000000000005',
   jsonb_build_object('sub','b0000000-0000-0000-0000-000000000005','email','lukas.braun@kilicsoftware.com','email_verified',true,'full_name','Lukas Braun','username','lukasb'),
   'email','b0000000-0000-0000-0000-000000000005', now(), now(), now()),

  ('b0000000-0000-0000-0000-000000000006', 'b0000000-0000-0000-0000-000000000006',
   jsonb_build_object('sub','b0000000-0000-0000-0000-000000000006','email','maria.schmidt@kilicsoftware.com','email_verified',true,'full_name','Maria Schmidt','username','marias'),
   'email','b0000000-0000-0000-0000-000000000006', now(), now(), now()),

  ('b0000000-0000-0000-0000-000000000007', 'b0000000-0000-0000-0000-000000000007',
   jsonb_build_object('sub','b0000000-0000-0000-0000-000000000007','email','thomas.fischer@schmidt-partner.de','email_verified',true,'full_name','Thomas Fischer','username','thomasf'),
   'email','b0000000-0000-0000-0000-000000000007', now(), now(), now()),

  ('b0000000-0000-0000-0000-000000000008', 'b0000000-0000-0000-0000-000000000008',
   jsonb_build_object('sub','b0000000-0000-0000-0000-000000000008','email','laura.becker@schmidt-partner.de','email_verified',true,'full_name','Laura Becker','username','laurab'),
   'email','b0000000-0000-0000-0000-000000000008', now(), now(), now()),

  ('b0000000-0000-0000-0000-000000000009', 'b0000000-0000-0000-0000-000000000009',
   jsonb_build_object('sub','b0000000-0000-0000-0000-000000000009','email','max.wagner@techstart.io','email_verified',true,'full_name','Max Wagner','username','maxw'),
   'email','b0000000-0000-0000-0000-000000000009', now(), now(), now()),

  ('b0000000-0000-0000-0000-00000000000a', 'b0000000-0000-0000-0000-00000000000a',
   jsonb_build_object('sub','b0000000-0000-0000-0000-00000000000a','email','elena.hoffmann@techstart.io','email_verified',true,'full_name','Elena Hoffmann','username','elenah'),
   'email','b0000000-0000-0000-0000-00000000000a', now(), now(), now()),

  ('b0000000-0000-0000-0000-00000000000b', 'b0000000-0000-0000-0000-00000000000b',
   jsonb_build_object('sub','b0000000-0000-0000-0000-00000000000b','email','kai.richter@weber-industries.com','email_verified',true,'full_name','Kai Richter','username','kair'),
   'email','b0000000-0000-0000-0000-00000000000b', now(), now(), now()),

  ('b0000000-0000-0000-0000-00000000000c', 'b0000000-0000-0000-0000-00000000000c',
   jsonb_build_object('sub','b0000000-0000-0000-0000-00000000000c','email','julia.klein@kilicsoftware.com','email_verified',true,'full_name','Julia Klein','username','juliak'),
   'email','b0000000-0000-0000-0000-00000000000c', now(), now(), now()),

  ('b0000000-0000-0000-0000-00000000000d', 'b0000000-0000-0000-0000-00000000000d',
   jsonb_build_object('sub','b0000000-0000-0000-0000-00000000000d','email','lisa@semotion.de','email_verified',true,'full_name','Lisa Berger','username','lisab'),
   'email','b0000000-0000-0000-0000-00000000000d', now(), now(), now());


-- ============================================
-- 3. UPDATE PUBLIC USERS (set org + preferences)
-- ============================================

-- Platform: Kılıç Software
UPDATE public.users SET organization_id = 'c0000000-0000-0000-0000-000000000001', timezone = 'Europe/Istanbul', locale = 'tr', last_seen_at = now() WHERE id = 'b0000000-0000-0000-0000-000000000001';
UPDATE public.users SET organization_id = 'c0000000-0000-0000-0000-000000000001', timezone = 'Europe/Berlin',   locale = 'de', last_seen_at = now() WHERE id = 'b0000000-0000-0000-0000-000000000004';
UPDATE public.users SET organization_id = 'c0000000-0000-0000-0000-000000000001', timezone = 'Europe/Berlin',   locale = 'de', last_seen_at = now() WHERE id = 'b0000000-0000-0000-0000-000000000005';
UPDATE public.users SET organization_id = 'c0000000-0000-0000-0000-000000000001', timezone = 'Europe/Berlin',   locale = 'de', last_seen_at = now() WHERE id = 'b0000000-0000-0000-0000-000000000006';
UPDATE public.users SET organization_id = 'c0000000-0000-0000-0000-000000000001', timezone = 'Europe/Berlin',   locale = 'de', last_seen_at = now() WHERE id = 'b0000000-0000-0000-0000-00000000000c';

-- Müller GmbH
UPDATE public.users SET organization_id = 'c0000000-0000-0000-0000-000000000002', timezone = 'Europe/Berlin',   locale = 'de', last_seen_at = now() WHERE id = 'b0000000-0000-0000-0000-000000000002';
UPDATE public.users SET organization_id = 'c0000000-0000-0000-0000-000000000002', timezone = 'Europe/Berlin',   locale = 'de', last_seen_at = now() WHERE id = 'b0000000-0000-0000-0000-000000000003';

-- Schmidt & Partner AG
UPDATE public.users SET organization_id = 'c0000000-0000-0000-0000-000000000003', timezone = 'Europe/Berlin',   locale = 'de', last_seen_at = now() WHERE id = 'b0000000-0000-0000-0000-000000000007';
UPDATE public.users SET organization_id = 'c0000000-0000-0000-0000-000000000003', timezone = 'Europe/Berlin',   locale = 'de', last_seen_at = now() WHERE id = 'b0000000-0000-0000-0000-000000000008';

-- TechStart GmbH
UPDATE public.users SET organization_id = 'c0000000-0000-0000-0000-000000000004', timezone = 'Europe/Berlin',   locale = 'de', last_seen_at = now() WHERE id = 'b0000000-0000-0000-0000-000000000009';
UPDATE public.users SET organization_id = 'c0000000-0000-0000-0000-000000000004', timezone = 'Europe/Berlin',   locale = 'de', last_seen_at = now() WHERE id = 'b0000000-0000-0000-0000-00000000000a';

-- Weber Industries
UPDATE public.users SET organization_id = 'c0000000-0000-0000-0000-000000000005', timezone = 'Europe/Berlin',   locale = 'de', last_seen_at = now() WHERE id = 'b0000000-0000-0000-0000-00000000000b';

-- Semotion
UPDATE public.users SET organization_id = 'c0000000-0000-0000-0000-000000000006', timezone = 'Europe/Berlin',   locale = 'de', last_seen_at = now() WHERE id = 'b0000000-0000-0000-0000-00000000000d';


-- ============================================
-- 4. ORGANIZATION MEMBERS
-- ============================================
-- Roles: 01=owner, 02=admin, 03=manager, 04=agent, 05=client

INSERT INTO public.organization_members (organization_id, user_id, role_id) VALUES
  -- Kılıç Software (platform)
  ('c0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001'), -- Ertuğul  = owner
  ('c0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000002'), -- Anna     = admin
  ('c0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000006', 'a0000000-0000-0000-0000-000000000003'), -- Maria    = manager
  ('c0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000005', 'a0000000-0000-0000-0000-000000000004'), -- Lukas    = agent
  ('c0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-00000000000c', 'a0000000-0000-0000-0000-000000000004'), -- Julia    = agent

  -- Müller GmbH
  ('c0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000005'), -- Sarah    = client
  ('c0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000005'), -- Nicholas = client

  -- Schmidt & Partner AG
  ('c0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000007', 'a0000000-0000-0000-0000-000000000005'), -- Thomas   = client
  ('c0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000008', 'a0000000-0000-0000-0000-000000000005'), -- Laura    = client

  -- TechStart GmbH
  ('c0000000-0000-0000-0000-000000000004', 'b0000000-0000-0000-0000-000000000009', 'a0000000-0000-0000-0000-000000000005'), -- Max      = client
  ('c0000000-0000-0000-0000-000000000004', 'b0000000-0000-0000-0000-00000000000a', 'a0000000-0000-0000-0000-000000000005'), -- Elena    = client

  -- Weber Industries
  ('c0000000-0000-0000-0000-000000000005', 'b0000000-0000-0000-0000-00000000000b', 'a0000000-0000-0000-0000-000000000005'), -- Kai      = client

  -- Semotion (partner org)
  ('c0000000-0000-0000-0000-000000000006', 'b0000000-0000-0000-0000-00000000000d', 'a0000000-0000-0000-0000-000000000003'); -- Lisa     = manager


-- ============================================
-- 5. PROJECTS
-- ============================================

INSERT INTO public.projects (id, name, identifier, description, status, owner_id, organization_id, start_at, color, icon) VALUES
  -- Kılıç Software (platform)
  ('d0000000-0000-0000-0000-000000000001', 'Platform MVP',          'PLAT', 'Main SaaS platform development',                         'active',    'b0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', now() - interval '60 days',  '#3B82F6', '🚀'),
  ('d0000000-0000-0000-0000-000000000002', 'Marketing Website',     'MKTG', 'Public-facing marketing site redesign',                   'planning',  'b0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', now() - interval '5 days',   '#10B981', '🌐'),
  ('d0000000-0000-0000-0000-000000000003', 'Mobile App',            'MOBL', 'iOS and Android companion app',                           'active',    'b0000000-0000-0000-0000-000000000004', 'c0000000-0000-0000-0000-000000000001', now() - interval '30 days',  '#8B5CF6', '📱'),
  ('d0000000-0000-0000-0000-000000000004', 'API Gateway',           'APIG', 'Public API gateway with rate limiting and docs',           'active',    'b0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', now() - interval '45 days',  '#F59E0B', '🔌'),
  ('d0000000-0000-0000-0000-000000000005', 'Documentation Portal',  'DOCS', 'Self-service knowledge base and API docs',                'planning',  'b0000000-0000-0000-0000-000000000006', 'c0000000-0000-0000-0000-000000000001', now() + interval '10 days',  '#EC4899', '📖'),
  ('d0000000-0000-0000-0000-000000000006', 'Analytics Dashboard',   'ANLY', 'Internal analytics and reporting for support metrics',    'paused',    'b0000000-0000-0000-0000-000000000004', 'c0000000-0000-0000-0000-000000000001', now() - interval '90 days',  '#06B6D4', '📊'),

  -- Müller GmbH (client)
  ('d0000000-0000-0000-0000-000000000007', 'Website Redesign',      'MWEB', 'Full redesign of corporate website with CMS',             'active',    'b0000000-0000-0000-0000-000000000004', 'c0000000-0000-0000-0000-000000000002', now() - interval '20 days',  '#E11D48', '🎨'),
  ('d0000000-0000-0000-0000-000000000008', 'CRM Integration',       'MCRM', 'Connect Müller CRM with our platform via API',            'planning',  'b0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000002', now() + interval '5 days',   '#7C3AED', '🔗'),

  -- Schmidt & Partner AG (client)
  ('d0000000-0000-0000-0000-000000000009', 'Legal Document Portal', 'SLEG', 'Secure portal for document exchange with clients',        'active',    'b0000000-0000-0000-0000-000000000006', 'c0000000-0000-0000-0000-000000000003', now() - interval '35 days',  '#0891B2', '⚖️'),
  ('d0000000-0000-0000-0000-00000000000a', 'Client Onboarding App', 'SONB', 'Digital onboarding flow for new legal clients',            'planning',  'b0000000-0000-0000-0000-000000000004', 'c0000000-0000-0000-0000-000000000003', now() + interval '15 days',  '#059669', '📋'),

  -- TechStart GmbH (client)
  ('d0000000-0000-0000-0000-00000000000b', 'Startup Dashboard',     'TSDH', 'Analytics dashboard for startup KPIs and metrics',        'active',    'b0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000004', now() - interval '15 days',  '#D97706', '📊'),
  ('d0000000-0000-0000-0000-00000000000c', 'Investor Report Tool',  'TINV', 'Automated monthly investor report generation',             'active',    'b0000000-0000-0000-0000-000000000005', 'c0000000-0000-0000-0000-000000000004', now() - interval '25 days',  '#DC2626', '💰'),

  -- Weber Industries (client)
  ('d0000000-0000-0000-0000-00000000000d', 'Logistics Tracker',     'WLOG', 'Real-time shipment tracking dashboard',                    'active',    'b0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000005', now() - interval '40 days',  '#4F46E5', '🚛'),
  ('d0000000-0000-0000-0000-00000000000e', 'Warehouse Inventory',   'WINV', 'Inventory management system for warehouses',               'planning',  'b0000000-0000-0000-0000-000000000004', 'c0000000-0000-0000-0000-000000000005', now() + interval '7 days',   '#15803D', '📦');


-- ============================================
-- 6. PROJECT MEMBERS
-- ============================================

INSERT INTO public.project_members (project_id, user_id, role_id) VALUES
  -- Platform MVP: everyone
  ('d0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001'),
  ('d0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000002'),
  ('d0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000005', 'a0000000-0000-0000-0000-000000000004'),
  ('d0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-00000000000c', 'a0000000-0000-0000-0000-000000000004'),

  -- Marketing Website
  ('d0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001'),
  ('d0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000006', 'a0000000-0000-0000-0000-000000000003'),

  -- Mobile App
  ('d0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000001'),
  ('d0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000005', 'a0000000-0000-0000-0000-000000000004'),

  -- API Gateway
  ('d0000000-0000-0000-0000-000000000004', 'b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001'),
  ('d0000000-0000-0000-0000-000000000004', 'b0000000-0000-0000-0000-00000000000c', 'a0000000-0000-0000-0000-000000000004'),

  -- Documentation Portal
  ('d0000000-0000-0000-0000-000000000005', 'b0000000-0000-0000-0000-000000000006', 'a0000000-0000-0000-0000-000000000003'),
  ('d0000000-0000-0000-0000-000000000005', 'b0000000-0000-0000-0000-000000000005', 'a0000000-0000-0000-0000-000000000004'),

  -- Analytics Dashboard
  ('d0000000-0000-0000-0000-000000000006', 'b0000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000001'),
  ('d0000000-0000-0000-0000-000000000006', 'b0000000-0000-0000-0000-000000000006', 'a0000000-0000-0000-0000-000000000003'),

  -- Lisa (Semotion) on Mobile App as manager
  ('d0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-00000000000d', 'a0000000-0000-0000-0000-000000000003'),

  -- Müller GmbH projects
  ('d0000000-0000-0000-0000-000000000007', 'b0000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000001'),
  ('d0000000-0000-0000-0000-000000000007', 'b0000000-0000-0000-0000-000000000005', 'a0000000-0000-0000-0000-000000000004'),
  ('d0000000-0000-0000-0000-000000000008', 'b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001'),

  -- Schmidt & Partner AG projects
  ('d0000000-0000-0000-0000-000000000009', 'b0000000-0000-0000-0000-000000000006', 'a0000000-0000-0000-0000-000000000003'),
  ('d0000000-0000-0000-0000-000000000009', 'b0000000-0000-0000-0000-00000000000c', 'a0000000-0000-0000-0000-000000000004'),
  ('d0000000-0000-0000-0000-00000000000a', 'b0000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000001'),

  -- TechStart GmbH projects
  ('d0000000-0000-0000-0000-00000000000b', 'b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001'),
  ('d0000000-0000-0000-0000-00000000000b', 'b0000000-0000-0000-0000-00000000000c', 'a0000000-0000-0000-0000-000000000004'),
  ('d0000000-0000-0000-0000-00000000000c', 'b0000000-0000-0000-0000-000000000005', 'a0000000-0000-0000-0000-000000000004'),

  -- Weber Industries projects
  ('d0000000-0000-0000-0000-00000000000d', 'b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001'),
  ('d0000000-0000-0000-0000-00000000000d', 'b0000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000002'),
  ('d0000000-0000-0000-0000-00000000000e', 'b0000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000001'),
  ('d0000000-0000-0000-0000-00000000000e', 'b0000000-0000-0000-0000-000000000006', 'a0000000-0000-0000-0000-000000000003');


-- ============================================
-- 7. TASKS
-- ============================================

INSERT INTO public.tasks (id, title, description, status, priority, type, project_id, created_by, short_id, start_at, end_at) VALUES
  -- Platform MVP
  ('e0000000-0000-0000-0000-000000000001', 'Set up authentication flow',          'Implement Supabase auth with email/password and OAuth providers.',                              'in_progress', 'high',   'feature',     'd0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'PLAT-1',  now() - interval '10 days', now() + interval '5 days'),
  ('e0000000-0000-0000-0000-000000000002', 'Design dashboard layout',             'Create the main dashboard wireframe and component structure.',                                  'done',        'medium', 'task',        'd0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'PLAT-2',  now() - interval '20 days', now() - interval '12 days'),
  ('e0000000-0000-0000-0000-000000000003', 'Fix login redirect loop',             'After login the user gets redirected back to login page on Safari.',                            'todo',        'urgent', 'bug',         'd0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'PLAT-3',  null, null),
  ('e0000000-0000-0000-0000-000000000004', 'RBAC permission system',              'Implement role-based access control with scoped permissions.',                                  'in_progress', 'high',   'feature',     'd0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'PLAT-4',  now() - interval '3 days',  now() + interval '14 days'),
  ('e0000000-0000-0000-0000-000000000006', 'API rate limiting middleware',         'Add rate limiting to public API endpoints. 100 req/min for basic, 1000 for enterprise.',        'backlog',     'medium', 'feature',     'd0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'PLAT-5',  null, null),
  ('e0000000-0000-0000-0000-000000000008', 'Implement notification system',       'Real-time notifications with Supabase Realtime subscriptions and toast UI.',                    'done',        'high',   'feature',     'd0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000004', 'PLAT-6',  now() - interval '25 days', now() - interval '15 days'),
  ('e0000000-0000-0000-0000-000000000009', 'Ticket detail panel',                 'Slide-over panel showing ticket properties, messages, and work logs.',                          'done',        'high',   'feature',     'd0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'PLAT-7',  now() - interval '15 days', now() - interval '5 days'),
  ('e0000000-0000-0000-0000-00000000000a', 'Organization settings page',          'Admin page for managing org-level settings like auto-assign, default priority, etc.',           'in_review',   'medium', 'task',        'd0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000004', 'PLAT-8',  now() - interval '7 days',  now() + interval '2 days'),
  ('e0000000-0000-0000-0000-00000000000b', 'Dark mode toggle',                    'Add system/light/dark theme switcher to settings.',                                             'done',        'low',    'improvement', 'd0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000005', 'PLAT-9',  now() - interval '12 days', now() - interval '8 days'),
  ('e0000000-0000-0000-0000-00000000000c', 'Fix sidebar flicker on page load',    'Sidebar briefly shows expanded state before collapsing when pinned=false.',                     'todo',        'low',    'bug',         'd0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000005', 'PLAT-10', null, null),
  ('e0000000-0000-0000-0000-00000000000d', 'User invitation flow',                'Email-based invitation with org + role pre-assignment.',                                        'in_progress', 'high',   'feature',     'd0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000004', 'PLAT-11', now() - interval '2 days',  now() + interval '7 days'),
  ('e0000000-0000-0000-0000-00000000000e', 'Client portal route /c',              'Dedicated portal for client users: ticket creation, detail view, messaging.',                   'todo',        'high',   'feature',     'd0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'PLAT-12', null, null),

  -- Marketing Website
  ('e0000000-0000-0000-0000-000000000005', 'Write copy for landing page',          'Draft headline, subheadline, feature sections, and CTA copy.',                                 'backlog',     'low',    'task',        'd0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001', 'MKTG-1',  null, null),
  ('e0000000-0000-0000-0000-00000000000f', 'Design pricing page',                 'Create pricing tiers comparison with feature matrix.',                                          'todo',        'medium', 'task',        'd0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000006', 'MKTG-2',  null, null),
  ('e0000000-0000-0000-0000-000000000010', 'SEO meta tags',                        'Add proper OpenGraph and Twitter card meta tags to all pages.',                                 'backlog',     'low',    'task',        'd0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000006', 'MKTG-3',  null, null),

  -- Mobile App
  ('e0000000-0000-0000-0000-000000000011', 'Set up React Native project',          'Initialize Expo project with TypeScript, navigation, and auth.',                               'done',        'high',   'task',        'd0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000004', 'MOBL-1',  now() - interval '28 days', now() - interval '22 days'),
  ('e0000000-0000-0000-0000-000000000012', 'Push notification integration',        'Configure FCM/APNs for push notifications on ticket updates.',                                 'in_progress', 'medium', 'feature',     'd0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000005', 'MOBL-2',  now() - interval '5 days',  now() + interval '10 days'),
  ('e0000000-0000-0000-0000-000000000013', 'Offline ticket drafts',                'Allow users to draft tickets offline, sync when back online.',                                 'backlog',     'low',    'feature',     'd0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000004', 'MOBL-3',  null, null),

  -- API Gateway
  ('e0000000-0000-0000-0000-000000000014', 'JWT validation middleware',            'Validate and decode Supabase JWTs on every API request.',                                      'done',        'urgent', 'task',        'd0000000-0000-0000-0000-000000000004', 'b0000000-0000-0000-0000-000000000001', 'APIG-1',  now() - interval '40 days', now() - interval '35 days'),
  ('e0000000-0000-0000-0000-000000000015', 'OpenAPI spec generation',              'Auto-generate OpenAPI 3.1 docs from route definitions.',                                       'in_progress', 'medium', 'task',        'd0000000-0000-0000-0000-000000000004', 'b0000000-0000-0000-0000-00000000000c', 'APIG-2',  now() - interval '10 days', now() + interval '5 days'),
  ('e0000000-0000-0000-0000-000000000016', 'Webhook delivery system',              'Reliable webhook delivery with retries and signature verification.',                           'todo',        'high',   'feature',     'd0000000-0000-0000-0000-000000000004', 'b0000000-0000-0000-0000-000000000001', 'APIG-3',  null, null),

  -- Documentation Portal
  ('e0000000-0000-0000-0000-000000000017', 'Set up VitePress project',             'Initialize VitePress with custom theme matching platform branding.',                           'todo',        'medium', 'task',        'd0000000-0000-0000-0000-000000000005', 'b0000000-0000-0000-0000-000000000006', 'DOCS-1',  null, null),
  ('e0000000-0000-0000-0000-000000000018', 'API reference auto-generation',        'Pull from OpenAPI spec and render interactive API docs.',                                      'backlog',     'medium', 'feature',     'd0000000-0000-0000-0000-000000000005', 'b0000000-0000-0000-0000-000000000006', 'DOCS-2',  null, null),

  -- Analytics Dashboard
  ('e0000000-0000-0000-0000-000000000019', 'Ticket volume chart',                  'Bar chart showing ticket count per day/week/month.',                                           'done',        'medium', 'task',        'd0000000-0000-0000-0000-000000000006', 'b0000000-0000-0000-0000-000000000004', 'ANLY-1',  now() - interval '80 days', now() - interval '70 days'),
  ('e0000000-0000-0000-0000-00000000001a', 'SLA compliance report',                'Table and gauge showing SLA breach rates per org and tier.',                                   'todo',        'high',   'task',        'd0000000-0000-0000-0000-000000000006', 'b0000000-0000-0000-0000-000000000004', 'ANLY-2',  null, null),

  -- Müller GmbH: Website Redesign
  ('e0000000-0000-0000-0000-00000000001b', 'Design system setup',                  'Create color palette, typography scale, and component library.',                               'done',        'high',   'task',        'd0000000-0000-0000-0000-000000000007', 'b0000000-0000-0000-0000-000000000004', 'MWEB-1',  now() - interval '18 days', now() - interval '10 days'),
  ('e0000000-0000-0000-0000-00000000001c', 'Homepage wireframe',                   'Low-fi wireframe for the new homepage layout.',                                                'in_progress', 'medium', 'task',        'd0000000-0000-0000-0000-000000000007', 'b0000000-0000-0000-0000-000000000005', 'MWEB-2',  now() - interval '5 days',  now() + interval '5 days'),
  ('e0000000-0000-0000-0000-00000000001d', 'CMS content migration',                'Migrate 200+ blog posts and pages from old WordPress site.',                                   'todo',        'medium', 'task',        'd0000000-0000-0000-0000-000000000007', 'b0000000-0000-0000-0000-000000000004', 'MWEB-3',  null, null),
  ('e0000000-0000-0000-0000-00000000001e', 'Contact form with reCAPTCHA',          'Build contact form with spam protection and email notification.',                               'backlog',     'low',    'feature',     'd0000000-0000-0000-0000-000000000007', 'b0000000-0000-0000-0000-000000000005', 'MWEB-4',  null, null),

  -- Müller GmbH: CRM Integration
  ('e0000000-0000-0000-0000-00000000001f', 'API endpoint mapping',                 'Map Müller CRM endpoints to our internal data model.',                                         'todo',        'high',   'task',        'd0000000-0000-0000-0000-000000000008', 'b0000000-0000-0000-0000-000000000001', 'MCRM-1',  null, null),
  ('e0000000-0000-0000-0000-000000000020', 'OAuth2 connector',                      'Build OAuth2 flow for secure CRM API authentication.',                                         'todo',        'high',   'feature',     'd0000000-0000-0000-0000-000000000008', 'b0000000-0000-0000-0000-000000000001', 'MCRM-2',  null, null),

  -- Schmidt & Partner: Legal Document Portal
  ('e0000000-0000-0000-0000-000000000021', 'Document upload with encryption',      'Encrypted file upload with AES-256 at rest.',                                                  'in_progress', 'urgent', 'feature',     'd0000000-0000-0000-0000-000000000009', 'b0000000-0000-0000-0000-000000000006', 'SLEG-1',  now() - interval '30 days', now() + interval '3 days'),
  ('e0000000-0000-0000-0000-000000000022', 'Access audit log',                      'Track who viewed/downloaded each document with timestamps.',                                   'todo',        'high',   'feature',     'd0000000-0000-0000-0000-000000000009', 'b0000000-0000-0000-0000-00000000000c', 'SLEG-2',  null, null),
  ('e0000000-0000-0000-0000-000000000023', 'E-signature integration',               'Integrate DocuSign API for contract signing workflow.',                                        'backlog',     'medium', 'feature',     'd0000000-0000-0000-0000-000000000009', 'b0000000-0000-0000-0000-000000000006', 'SLEG-3',  null, null),

  -- Schmidt & Partner: Client Onboarding
  ('e0000000-0000-0000-0000-000000000024', 'Multi-step form wizard',                'Step-by-step onboarding with progress indicator and validation.',                              'todo',        'medium', 'task',        'd0000000-0000-0000-0000-00000000000a', 'b0000000-0000-0000-0000-000000000004', 'SONB-1',  null, null),
  ('e0000000-0000-0000-0000-000000000025', 'KYC document verification',             'Automated ID verification using third-party service.',                                        'todo',        'high',   'feature',     'd0000000-0000-0000-0000-00000000000a', 'b0000000-0000-0000-0000-000000000004', 'SONB-2',  null, null),

  -- TechStart: Startup Dashboard
  ('e0000000-0000-0000-0000-000000000026', 'Revenue chart widget',                  'Monthly recurring revenue chart with MoM growth indicator.',                                   'done',        'high',   'feature',     'd0000000-0000-0000-0000-00000000000b', 'b0000000-0000-0000-0000-000000000001', 'TSDH-1',  now() - interval '12 days', now() - interval '5 days'),
  ('e0000000-0000-0000-0000-000000000027', 'Burn rate calculator',                  'Calculate monthly burn rate and runway from financial data.',                                  'in_progress', 'medium', 'task',        'd0000000-0000-0000-0000-00000000000b', 'b0000000-0000-0000-0000-00000000000c', 'TSDH-2',  now() - interval '3 days',  now() + interval '7 days'),
  ('e0000000-0000-0000-0000-000000000028', 'Team activity feed',                     'Real-time feed showing commits, deploys, and milestones.',                                    'backlog',     'low',    'feature',     'd0000000-0000-0000-0000-00000000000b', 'b0000000-0000-0000-0000-000000000001', 'TSDH-3',  null, null),

  -- TechStart: Investor Report Tool
  ('e0000000-0000-0000-0000-000000000029', 'PDF report template',                   'Design branded PDF template with charts and tables.',                                         'in_progress', 'high',   'task',        'd0000000-0000-0000-0000-00000000000c', 'b0000000-0000-0000-0000-000000000005', 'TINV-1',  now() - interval '20 days', now() + interval '3 days'),
  ('e0000000-0000-0000-0000-00000000002a', 'Email scheduler',                       'Monthly automated email with PDF attachment to investor list.',                                'todo',        'medium', 'feature',     'd0000000-0000-0000-0000-00000000000c', 'b0000000-0000-0000-0000-000000000005', 'TINV-2',  null, null),

  -- Weber Industries: Logistics Tracker
  ('e0000000-0000-0000-0000-00000000002b', 'Map integration',                       'Interactive map showing shipment routes and current positions.',                               'done',        'high',   'feature',     'd0000000-0000-0000-0000-00000000000d', 'b0000000-0000-0000-0000-000000000001', 'WLOG-1',  now() - interval '35 days', now() - interval '20 days'),
  ('e0000000-0000-0000-0000-00000000002c', 'Delivery ETA prediction',               'ML-based ETA predictions using historical delivery data.',                                    'in_progress', 'high',   'feature',     'd0000000-0000-0000-0000-00000000000d', 'b0000000-0000-0000-0000-000000000004', 'WLOG-2',  now() - interval '10 days', now() + interval '14 days'),
  ('e0000000-0000-0000-0000-00000000002d', 'Driver mobile app',                      'Simple mobile app for drivers to update delivery status.',                                    'todo',        'medium', 'task',        'd0000000-0000-0000-0000-00000000000d', 'b0000000-0000-0000-0000-000000000001', 'WLOG-3',  null, null),
  ('e0000000-0000-0000-0000-00000000002e', 'Alert system for delays',                'SMS/email alerts when shipment exceeds expected delivery window.',                            'backlog',     'medium', 'feature',     'd0000000-0000-0000-0000-00000000000d', 'b0000000-0000-0000-0000-000000000004', 'WLOG-4',  null, null),

  -- Weber Industries: Warehouse Inventory
  ('e0000000-0000-0000-0000-00000000002f', 'Barcode scanner integration',            'Connect handheld barcode scanners for stock intake.',                                        'todo',        'high',   'feature',     'd0000000-0000-0000-0000-00000000000e', 'b0000000-0000-0000-0000-000000000004', 'WINV-1',  null, null),
  ('e0000000-0000-0000-0000-000000000030', 'Stock level dashboard',                  'Real-time stock levels with low-stock alerts.',                                               'todo',        'medium', 'task',        'd0000000-0000-0000-0000-00000000000e', 'b0000000-0000-0000-0000-000000000006', 'WINV-2',  null, null);

-- Subtask
INSERT INTO public.tasks (id, title, description, status, priority, type, project_id, created_by, short_id, parent_id) VALUES
  ('e0000000-0000-0000-0000-000000000007', 'Create permission check middleware', 'Middleware that calls user_has_permission() on every API route.', 'todo', 'high', 'task', 'd0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'PLAT-4a', 'e0000000-0000-0000-0000-000000000004');


-- ============================================
-- 8. TASK ASSIGNMENTS
-- ============================================

INSERT INTO public.task_assignments (task_id, user_id, role, assigned_by) VALUES
  ('e0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'assignee', 'b0000000-0000-0000-0000-000000000001'),
  ('e0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000005', 'assignee', 'b0000000-0000-0000-0000-000000000001'),
  ('e0000000-0000-0000-0000-000000000004', 'b0000000-0000-0000-0000-000000000001', 'assignee', 'b0000000-0000-0000-0000-000000000001'),
  ('e0000000-0000-0000-0000-000000000007', 'b0000000-0000-0000-0000-000000000001', 'assignee', 'b0000000-0000-0000-0000-000000000001'),
  ('e0000000-0000-0000-0000-000000000008', 'b0000000-0000-0000-0000-000000000004', 'assignee', 'b0000000-0000-0000-0000-000000000001'),
  ('e0000000-0000-0000-0000-000000000009', 'b0000000-0000-0000-0000-000000000001', 'assignee', 'b0000000-0000-0000-0000-000000000001'),
  ('e0000000-0000-0000-0000-00000000000a', 'b0000000-0000-0000-0000-000000000004', 'assignee', 'b0000000-0000-0000-0000-000000000004'),
  ('e0000000-0000-0000-0000-00000000000b', 'b0000000-0000-0000-0000-000000000005', 'assignee', 'b0000000-0000-0000-0000-000000000005'),
  ('e0000000-0000-0000-0000-00000000000c', 'b0000000-0000-0000-0000-000000000005', 'assignee', 'b0000000-0000-0000-0000-000000000001'),
  ('e0000000-0000-0000-0000-00000000000d', 'b0000000-0000-0000-0000-000000000004', 'assignee', 'b0000000-0000-0000-0000-000000000001'),
  ('e0000000-0000-0000-0000-00000000000e', 'b0000000-0000-0000-0000-000000000001', 'assignee', 'b0000000-0000-0000-0000-000000000001'),
  ('e0000000-0000-0000-0000-000000000011', 'b0000000-0000-0000-0000-000000000004', 'assignee', 'b0000000-0000-0000-0000-000000000004'),
  ('e0000000-0000-0000-0000-000000000012', 'b0000000-0000-0000-0000-000000000005', 'assignee', 'b0000000-0000-0000-0000-000000000004'),
  ('e0000000-0000-0000-0000-000000000014', 'b0000000-0000-0000-0000-000000000001', 'assignee', 'b0000000-0000-0000-0000-000000000001'),
  ('e0000000-0000-0000-0000-000000000015', 'b0000000-0000-0000-0000-00000000000c', 'assignee', 'b0000000-0000-0000-0000-000000000001'),
  ('e0000000-0000-0000-0000-000000000019', 'b0000000-0000-0000-0000-000000000004', 'assignee', 'b0000000-0000-0000-0000-000000000004');


-- ============================================
-- 9. TASK COMMENTS
-- ============================================

INSERT INTO public.task_comments (task_id, user_id, content) VALUES
  ('e0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'Started implementing the email/password flow. OAuth will come in a follow-up task.'),
  ('e0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000005', 'Reproduced on Safari 17.2. Looks like a cookie SameSite issue.'),
  ('e0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000001', 'Let''s try setting SameSite=Lax in the Supabase cookie config.'),
  ('e0000000-0000-0000-0000-000000000004', 'b0000000-0000-0000-0000-000000000001', 'Migration and seed files are ready. Moving on to the middleware integration.'),
  ('e0000000-0000-0000-0000-000000000008', 'b0000000-0000-0000-0000-000000000004', 'Realtime subscription is working. Toast UI renders correctly in both light and dark mode.'),
  ('e0000000-0000-0000-0000-000000000009', 'b0000000-0000-0000-0000-000000000001', 'Panel now supports inline editing for status, priority, category, and agent assignment.'),
  ('e0000000-0000-0000-0000-00000000000a', 'b0000000-0000-0000-0000-000000000004', 'Ready for review. All settings persist correctly through the API.'),
  ('e0000000-0000-0000-0000-00000000000d', 'b0000000-0000-0000-0000-000000000004', 'Edge function for sending invite emails is deployed. Testing with real SMTP now.'),
  ('e0000000-0000-0000-0000-000000000012', 'b0000000-0000-0000-0000-000000000005', 'FCM setup complete. APNs certificate needs renewal — waiting on Apple.'),
  ('e0000000-0000-0000-0000-000000000015', 'b0000000-0000-0000-0000-00000000000c', 'Using zod-to-openapi for schema generation. About 60% of routes documented.');


-- ============================================
-- 10. TASK ACTIVITIES
-- ============================================

INSERT INTO public.task_activities (task_id, user_id, action, field_name, old_value, new_value) VALUES
  ('e0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'created',       null,     null,          null),
  ('e0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'updated_field', 'status', 'todo',        'in_progress'),
  ('e0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001', 'updated_field', 'status', 'in_progress', 'done'),
  ('e0000000-0000-0000-0000-000000000004', 'b0000000-0000-0000-0000-000000000001', 'updated_field', 'priority', 'medium',    'high'),
  ('e0000000-0000-0000-0000-000000000008', 'b0000000-0000-0000-0000-000000000004', 'updated_field', 'status', 'in_progress', 'done'),
  ('e0000000-0000-0000-0000-000000000009', 'b0000000-0000-0000-0000-000000000001', 'updated_field', 'status', 'in_progress', 'done'),
  ('e0000000-0000-0000-0000-00000000000b', 'b0000000-0000-0000-0000-000000000005', 'updated_field', 'status', 'in_progress', 'done'),
  ('e0000000-0000-0000-0000-000000000011', 'b0000000-0000-0000-0000-000000000004', 'updated_field', 'status', 'in_progress', 'done'),
  ('e0000000-0000-0000-0000-000000000014', 'b0000000-0000-0000-0000-000000000001', 'updated_field', 'status', 'in_progress', 'done'),
  ('e0000000-0000-0000-0000-000000000019', 'b0000000-0000-0000-0000-000000000004', 'updated_field', 'status', 'in_progress', 'done');


-- ============================================
-- 11. SUPPORT TICKETS
-- ============================================

INSERT INTO public.support_tickets (id, customer_id, subject, description, status, priority, channel, assigned_agent_id, category, organization_id, satisfaction_score, first_response_at, resolved_at, metadata) VALUES
  -- Müller GmbH (Sarah)
  ('f0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000002', 'Cannot access billing page',           'I click on billing in settings but get a 403 error. I need to update my payment method.',     'open',                  'high',   'web_form', 'b0000000-0000-0000-0000-000000000001', 'billing',          'c0000000-0000-0000-0000-000000000002', null, now() - interval '4 hours',  null,                        '{"browser":"Chrome 121","os":"macOS 14.3"}'),
  ('f0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000002', 'Feature request: dark mode',           'Would love to have a dark mode toggle in the settings.',                                      'resolved',              'low',    'email',    'b0000000-0000-0000-0000-000000000001', 'feature_request',  'c0000000-0000-0000-0000-000000000002', 4,    now() - interval '10 days', now() - interval '3 days',   '{"browser":"Firefox 122","os":"Windows 11"}'),
  ('f0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000002', 'Export data as CSV',                    'We need to export our ticket history as CSV for our quarterly report.',                        'in_progress',           'medium', 'web_form', 'b0000000-0000-0000-0000-000000000005', 'feature_request',  'c0000000-0000-0000-0000-000000000002', null, now() - interval '2 hours',  null,                        null),
  ('f0000000-0000-0000-0000-000000000004', 'b0000000-0000-0000-0000-000000000002', 'Password reset not working',           'I requested a password reset but never received the email. Checked spam folder too.',          'waiting_on_customer',   'high',   'email',    'b0000000-0000-0000-0000-000000000005', 'technical_issue',  'c0000000-0000-0000-0000-000000000002', null, now() - interval '1 day',    null,                        null),

  -- Müller GmbH (Nicholas)
  ('f0000000-0000-0000-0000-000000000005', 'b0000000-0000-0000-0000-000000000003', 'API rate limit too low',               'We are hitting the rate limit during peak hours. Can it be increased for our plan?',           'open',                  'medium', 'api',      'b0000000-0000-0000-0000-00000000000c', 'technical_issue',  'c0000000-0000-0000-0000-000000000002', null, null,                        null,                        null),
  ('f0000000-0000-0000-0000-000000000006', 'b0000000-0000-0000-0000-000000000003', 'Webhook delivery failures',            'About 15% of our webhooks are returning 502 errors since yesterday.',                         'in_progress',           'urgent', 'api',      'b0000000-0000-0000-0000-000000000001', 'technical_issue',  'c0000000-0000-0000-0000-000000000002', null, now() - interval '30 minutes', null,                      '{"endpoint":"https://hooks.mueller-gmbh.de/trackr"}'),

  -- Schmidt & Partner AG (Thomas)
  ('f0000000-0000-0000-0000-000000000007', 'b0000000-0000-0000-0000-000000000007', 'Need SSO integration',                 'We require SAML SSO to comply with our IT security policy. Is this available?',                'open',                  'high',   'email',    'b0000000-0000-0000-0000-000000000004', 'feature_request',  'c0000000-0000-0000-0000-000000000003', null, null,                        null,                        null),
  ('f0000000-0000-0000-0000-000000000008', 'b0000000-0000-0000-0000-000000000007', 'Data retention policy question',       'How long is ticket data stored? We need to comply with GDPR Art. 17 requirements.',            'resolved',              'medium', 'email',    'b0000000-0000-0000-0000-000000000006', 'general',          'c0000000-0000-0000-0000-000000000003', 5,    now() - interval '5 days',   now() - interval '2 days',  null),
  ('f0000000-0000-0000-0000-000000000009', 'b0000000-0000-0000-0000-000000000007', 'Document upload not working',          'When I try to attach a PDF to a ticket, the upload spinner hangs indefinitely.',               'in_progress',           'high',   'web_form', 'b0000000-0000-0000-0000-000000000005', 'technical_issue',  'c0000000-0000-0000-0000-000000000003', null, now() - interval '3 hours',  null,                        '{"file_size":"4.2MB","file_type":"application/pdf"}'),

  -- Schmidt & Partner AG (Laura)
  ('f0000000-0000-0000-0000-00000000000a', 'b0000000-0000-0000-0000-000000000008', 'Mobile view broken on iPad',           'The ticket list overlaps the sidebar when viewed on iPad in portrait mode.',                   'open',                  'low',    'web_form', null,                                        'technical_issue',  'c0000000-0000-0000-0000-000000000003', null, null,                        null,                        '{"device":"iPad Pro 12.9","browser":"Safari 17"}'),
  ('f0000000-0000-0000-0000-00000000000b', 'b0000000-0000-0000-0000-000000000008', 'Add team member to our account',       'We hired a new paralegal and need to add them to our organization.',                           'resolved',              'medium', 'email',    'b0000000-0000-0000-0000-000000000004', 'general',          'c0000000-0000-0000-0000-000000000003', 5,    now() - interval '7 days',   now() - interval '6 days',  null),

  -- TechStart GmbH (Max)
  ('f0000000-0000-0000-0000-00000000000c', 'b0000000-0000-0000-0000-000000000009', 'Getting started questions',            'We just signed up. How do we add our first project and invite team members?',                  'resolved',              'low',    'web_form', 'b0000000-0000-0000-0000-00000000000c', 'general',          'c0000000-0000-0000-0000-000000000004', 4,    now() - interval '14 days',  now() - interval '13 days', null),
  ('f0000000-0000-0000-0000-00000000000d', 'b0000000-0000-0000-0000-000000000009', 'Pricing plan upgrade',                 'We want to upgrade from Basic to Premium. What''s the process and prorated cost?',             'waiting_on_agent',      'medium', 'email',    'b0000000-0000-0000-0000-000000000006', 'billing',          'c0000000-0000-0000-0000-000000000004', null, now() - interval '2 days',   null,                        null),
  ('f0000000-0000-0000-0000-00000000000e', 'b0000000-0000-0000-0000-000000000009', 'Slow page load on dashboard',          'Dashboard takes 8+ seconds to load. We only have ~20 tickets so it shouldn''t be this slow.',  'open',                  'high',   'web_form', 'b0000000-0000-0000-0000-000000000005', 'technical_issue',  'c0000000-0000-0000-0000-000000000004', null, null,                        null,                        '{"load_time_ms":8420}'),

  -- TechStart GmbH (Elena)
  ('f0000000-0000-0000-0000-00000000000f', 'b0000000-0000-0000-0000-00000000000a', 'Email notifications not arriving',     'I am not receiving email notifications when my tickets are updated.',                          'in_progress',           'medium', 'email',    'b0000000-0000-0000-0000-00000000000c', 'technical_issue',  'c0000000-0000-0000-0000-000000000004', null, now() - interval '1 day',    null,                        null),

  -- Weber Industries (Kai)
  ('f0000000-0000-0000-0000-000000000010', 'b0000000-0000-0000-0000-00000000000b', 'Bulk ticket import',                   'We have 500+ tickets in Zendesk that we need to migrate. Is there an import tool?',            'open',                  'medium', 'email',    'b0000000-0000-0000-0000-000000000001', 'feature_request',  'c0000000-0000-0000-0000-000000000005', null, null,                        null,                        null),
  ('f0000000-0000-0000-0000-000000000011', 'b0000000-0000-0000-0000-00000000000b', 'Custom fields on tickets',             'We need to add a "warehouse location" field to support tickets for logistics tracking.',       'open',                  'high',   'web_form', 'b0000000-0000-0000-0000-000000000006', 'feature_request',  'c0000000-0000-0000-0000-000000000005', null, null,                        null,                        null),
  ('f0000000-0000-0000-0000-000000000012', 'b0000000-0000-0000-0000-00000000000b', 'Two-factor authentication',            'Our security team requires 2FA for all external tools. When will this be available?',          'waiting_on_customer',   'high',   'email',    'b0000000-0000-0000-0000-000000000004', 'general',          'c0000000-0000-0000-0000-000000000005', null, now() - interval '3 days',   null,                        null),
  ('f0000000-0000-0000-0000-000000000013', 'b0000000-0000-0000-0000-00000000000b', 'SLA breach notification',              'We didn''t get notified when our last ticket breached the SLA response time.',                 'resolved',              'urgent', 'email',    'b0000000-0000-0000-0000-000000000001', 'technical_issue',  'c0000000-0000-0000-0000-000000000005', 3,    now() - interval '8 days',   now() - interval '7 days',  null);


-- ============================================
-- 12. SUPPORT TICKET MESSAGES
-- ============================================

INSERT INTO public.support_ticket_messages (ticket_id, sender_id, is_internal_note, body) VALUES
  -- Ticket 01: Cannot access billing
  ('f0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000002', false, 'Hi, I keep getting a 403 when trying to access the billing page. Can you help?'),
  ('f0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', true,  'Checked her permissions — client role does not have organizations.billing. Might need to handle this as a special case or show a contact-us form instead.'),
  ('f0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', false, 'Hi Sarah, thanks for reaching out. I''m looking into this now and will get back to you shortly.'),

  -- Ticket 02: Dark mode
  ('f0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000002', false, 'It would be great if you could add a dark mode option. My eyes hurt at night!'),
  ('f0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001', false, 'Great suggestion! We have this on our roadmap. Marking as resolved for now — we''ll notify you when it ships.'),
  ('f0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001', false, 'Update: Dark mode has been shipped! You can toggle it in Settings. Let us know if you have feedback.'),
  ('f0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000002', false, 'Just tried it — looks amazing! Thank you for the quick turnaround.'),

  -- Ticket 03: CSV export
  ('f0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000002', false, 'We need to export our ticket data as CSV for our quarterly compliance report. Is that possible?'),
  ('f0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000005', false, 'Hi Sarah! This feature is not available yet, but I''m working on it right now. Should be ready within the week.'),
  ('f0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000005', true,  'Need to add CSV export endpoint to the API gateway. Columns: id, subject, status, priority, created_at, resolved_at, customer_email, agent_name.'),

  -- Ticket 04: Password reset
  ('f0000000-0000-0000-0000-000000000004', 'b0000000-0000-0000-0000-000000000002', false, 'I requested a password reset 3 times but no email arrived. Already checked my spam folder.'),
  ('f0000000-0000-0000-0000-000000000004', 'b0000000-0000-0000-0000-000000000005', false, 'We have resent the password reset email. Could you check if sarah.mueller@example.com is the correct address?'),
  ('f0000000-0000-0000-0000-000000000004', 'b0000000-0000-0000-0000-000000000002', false, 'Yes that''s correct. Still nothing. Could you try sending to my personal email instead?'),
  ('f0000000-0000-0000-0000-000000000004', 'b0000000-0000-0000-0000-000000000005', true,  'Supabase logs show emails are being sent but bounced by their mail server. SPF record issue?'),

  -- Ticket 05: API rate limit
  ('f0000000-0000-0000-0000-000000000005', 'b0000000-0000-0000-0000-000000000003', false, 'We are consistently hitting the 100 req/min rate limit during business hours. Our integration syncs every 30 seconds.'),

  -- Ticket 06: Webhook failures
  ('f0000000-0000-0000-0000-000000000006', 'b0000000-0000-0000-0000-000000000003', false, 'Our webhook endpoint is returning 502 errors. This started yesterday around 14:00 CET.'),
  ('f0000000-0000-0000-0000-000000000006', 'b0000000-0000-0000-0000-000000000001', false, 'We identified the issue — our webhook delivery service had a misconfigured timeout. Deploying a fix now.'),
  ('f0000000-0000-0000-0000-000000000006', 'b0000000-0000-0000-0000-000000000001', true,  'Root cause: Cloudflare Workers timeout set to 10ms instead of 10s after last deploy. Fixed in commit abc123.'),
  ('f0000000-0000-0000-0000-000000000006', 'b0000000-0000-0000-0000-000000000003', false, 'Thanks for the quick response. Seeing successful deliveries again now.'),

  -- Ticket 07: SSO
  ('f0000000-0000-0000-0000-000000000007', 'b0000000-0000-0000-0000-000000000007', false, 'Our IT department requires SAML SSO integration. Without it, we cannot proceed with onboarding our full team.'),

  -- Ticket 08: Data retention
  ('f0000000-0000-0000-0000-000000000008', 'b0000000-0000-0000-0000-000000000007', false, 'For GDPR compliance: how long do you retain ticket data, and can we request deletion under Art. 17?'),
  ('f0000000-0000-0000-0000-000000000008', 'b0000000-0000-0000-0000-000000000006', false, 'Ticket data is retained for 2 years by default. You can request full deletion at any time via support, and we process it within 30 days as required by GDPR.'),
  ('f0000000-0000-0000-0000-000000000008', 'b0000000-0000-0000-0000-000000000007', false, 'Perfect, that aligns with our policy. Thank you!'),

  -- Ticket 09: Document upload
  ('f0000000-0000-0000-0000-000000000009', 'b0000000-0000-0000-0000-000000000007', false, 'Trying to upload a 4.2MB PDF but the spinner just hangs. Tried Chrome and Safari, same result.'),
  ('f0000000-0000-0000-0000-000000000009', 'b0000000-0000-0000-0000-000000000005', false, 'Thanks for reporting this. We''re investigating the file upload service. In the meantime, could you try uploading a smaller file (<2MB) to see if that works?'),
  ('f0000000-0000-0000-0000-000000000009', 'b0000000-0000-0000-0000-000000000005', true,  'Supabase Storage bucket has a 2MB limit by default. Need to increase to 10MB.'),

  -- Ticket 0c: Getting started
  ('f0000000-0000-0000-0000-00000000000c', 'b0000000-0000-0000-0000-000000000009', false, 'Just signed up and I''m a bit lost. How do I create my first project and invite my co-founder?'),
  ('f0000000-0000-0000-0000-00000000000c', 'b0000000-0000-0000-0000-00000000000c', false, 'Welcome to Trackr! Here''s a quick guide:\n1. Go to Projects and click "+ New Project"\n2. Go to User Management and use the "Invite" button\n\nLet me know if you need anything else!'),
  ('f0000000-0000-0000-0000-00000000000c', 'b0000000-0000-0000-0000-000000000009', false, 'That was super easy, thank you!'),

  -- Ticket 0d: Pricing upgrade
  ('f0000000-0000-0000-0000-00000000000d', 'b0000000-0000-0000-0000-000000000009', false, 'We''d like to upgrade from Basic to Premium. What''s the prorated cost for the remaining billing period?'),
  ('f0000000-0000-0000-0000-00000000000d', 'b0000000-0000-0000-0000-000000000006', false, 'Great to hear you want to upgrade! Let me calculate the prorated amount. I''ll get back to you by end of day.'),

  -- Ticket 0f: Email notifications
  ('f0000000-0000-0000-0000-00000000000f', 'b0000000-0000-0000-0000-00000000000a', false, 'I have notification preferences enabled, but I don''t receive any emails when my tickets are updated.'),
  ('f0000000-0000-0000-0000-00000000000f', 'b0000000-0000-0000-0000-00000000000c', false, 'We''re investigating this. Can you confirm the email address on your account is correct?'),
  ('f0000000-0000-0000-0000-00000000000f', 'b0000000-0000-0000-0000-00000000000a', false, 'Yes, it''s elena.hoffmann@techstart.io — that''s correct.'),
  ('f0000000-0000-0000-0000-00000000000f', 'b0000000-0000-0000-0000-00000000000c', true,  'Checked Resend dashboard — emails to techstart.io are bouncing due to missing MX record. Need customer to fix their DNS.'),

  -- Ticket 12: 2FA
  ('f0000000-0000-0000-0000-000000000012', 'b0000000-0000-0000-0000-00000000000b', false, 'When will two-factor authentication be available? This is a hard requirement from our security team.'),
  ('f0000000-0000-0000-0000-000000000012', 'b0000000-0000-0000-0000-000000000004', false, 'We are planning to release TOTP-based 2FA in Q2 2026. Would that timeline work for your team?'),
  ('f0000000-0000-0000-0000-000000000012', 'b0000000-0000-0000-0000-00000000000b', false, 'Q2 would be tight but acceptable. Can you keep us updated on the progress?'),

  -- Ticket 13: SLA breach
  ('f0000000-0000-0000-0000-000000000013', 'b0000000-0000-0000-0000-00000000000b', false, 'Our last ticket (#10) breached the 8-hour response SLA and we received no notification about it.'),
  ('f0000000-0000-0000-0000-000000000013', 'b0000000-0000-0000-0000-000000000001', false, 'You''re right, and I apologize for that. We found a bug in our SLA notification trigger. It has been fixed and we''ve added monitoring to prevent this in the future.'),
  ('f0000000-0000-0000-0000-000000000013', 'b0000000-0000-0000-0000-00000000000b', false, 'Appreciate the transparency. Thank you for the quick fix.');


-- ============================================
-- 13. TICKET WORK LOGS
-- ============================================

INSERT INTO public.ticket_work_logs (ticket_id, user_id, minutes, description, logged_at) VALUES
  ('f0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 30,  'Investigated permission model for billing access',              now() - interval '4 hours'),
  ('f0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001', 15,  'Reviewed request and added to roadmap',                          now() - interval '10 days'),
  ('f0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000005', 120, 'Building CSV export endpoint',                                   now() - interval '1 day'),
  ('f0000000-0000-0000-0000-000000000006', 'b0000000-0000-0000-0000-000000000001', 90,  'Diagnosed and fixed Cloudflare Workers timeout',                 now() - interval '5 hours'),
  ('f0000000-0000-0000-0000-000000000006', 'b0000000-0000-0000-0000-000000000001', 30,  'Verified webhook delivery after fix',                            now() - interval '3 hours'),
  ('f0000000-0000-0000-0000-000000000008', 'b0000000-0000-0000-0000-000000000006', 20,  'Drafted GDPR data retention response',                           now() - interval '5 days'),
  ('f0000000-0000-0000-0000-000000000009', 'b0000000-0000-0000-0000-000000000005', 45,  'Debugging file upload; identified Supabase Storage bucket limit', now() - interval '2 hours'),
  ('f0000000-0000-0000-0000-00000000000c', 'b0000000-0000-0000-0000-00000000000c', 10,  'Wrote onboarding guide for new customer',                        now() - interval '14 days'),
  ('f0000000-0000-0000-0000-000000000013', 'b0000000-0000-0000-0000-000000000001', 60,  'Fixed SLA notification trigger bug',                             now() - interval '7 days');


-- ============================================
-- 14. ORGANIZATION SETTINGS
-- ============================================

INSERT INTO public.organization_settings (organization_id, auto_assign_tickets, default_ticket_priority, require_ticket_category) VALUES
  ('c0000000-0000-0000-0000-000000000002', false,  'medium', true),
  ('c0000000-0000-0000-0000-000000000003', false,  'high',   true),
  ('c0000000-0000-0000-0000-000000000004', false,  'low',    false),
  ('c0000000-0000-0000-0000-000000000005', true,   'medium', true);


-- ============================================
-- 15. SET PLATFORM ORGANIZATION IN SYSTEM CONFIG
-- ============================================

UPDATE public.system_config
SET platform_organization_id = 'c0000000-0000-0000-0000-000000000001';
