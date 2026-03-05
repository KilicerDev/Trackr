-- Prevent ticket creation for organizations without a support tier (no contract).

DROP POLICY IF EXISTS "tickets_insert" ON public.support_tickets;

CREATE POLICY "tickets_insert"
  ON public.support_tickets FOR INSERT
  TO authenticated
  WITH CHECK (
    public.authorize('support_tickets', 'create', organization_id, customer_id = auth.uid())
    AND EXISTS (
      SELECT 1 FROM public.organizations o
      WHERE o.id = organization_id
        AND o.support_tier_id IS NOT NULL
    )
  );
