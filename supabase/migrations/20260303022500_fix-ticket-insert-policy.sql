-- Fix: allow agents/admins (scope=all) to create tickets on behalf of customers.
-- The previous policy had `AND customer_id = auth.uid()` which blocked all-scope
-- users from setting a different customer_id. The authorize() function already
-- handles own-scope via the _is_owner parameter.

DROP POLICY IF EXISTS "tickets_insert" ON public.support_tickets;

CREATE POLICY "tickets_insert"
  ON public.support_tickets FOR INSERT
  TO authenticated
  WITH CHECK (
    public.authorize('support_tickets', 'create', organization_id, customer_id = auth.uid())
  );
