-- Two invited users sharing the same email local-part (e.g. nicholas@a.com
-- and nicholas@b.com) used to collide on the unique username index, causing
-- GoTrue to fail with "Database error saving new user". Append a numeric
-- suffix until the username is free.

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  _invitation RECORD;
  _base_username text;
  _candidate text;
  _suffix int := 1;
BEGIN
  SELECT * INTO _invitation
  FROM public.organization_invitations
  WHERE email = NEW.email
    AND status = 'pending'
    AND expires_at > now()
  ORDER BY created_at ASC
  LIMIT 1;

  _base_username := COALESCE(
    NULLIF(NEW.raw_user_meta_data->>'username', ''),
    split_part(NEW.email, '@', 1)
  );
  _candidate := _base_username;

  WHILE EXISTS (
    SELECT 1 FROM public.users
    WHERE username = _candidate
      AND deleted_at IS NULL
  ) LOOP
    _suffix := _suffix + 1;
    _candidate := _base_username || '-' || _suffix::text;
  END LOOP;

  INSERT INTO public.users (id, email, full_name, username, organization_id)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    _candidate,
    _invitation.organization_id
  );

  RETURN NEW;
END;
$$;
