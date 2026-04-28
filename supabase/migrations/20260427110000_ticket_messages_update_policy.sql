-- ============================================
-- TICKET MESSAGES: allow message authors to update their own messages
--
-- The original policy set on `support_ticket_messages` only had SELECT, INSERT
-- and DELETE. Without an UPDATE policy RLS default-denies, which silently broke
-- `api.tickets.updateMessageAttachments(...)` — clients could attach files
-- locally but the `attachment_ids[]` column never persisted, so other viewers
-- (agents, etc.) saw the message without its attachments.
--
-- Allow UPDATE by the message author, or by anyone with `support_tickets.update`
-- in the message's org. Use the same expression for USING and WITH CHECK so the
-- policy is unambiguous on PG 17.
-- ============================================

CREATE POLICY "ticket_messages_update"
  ON public.support_ticket_messages
  FOR UPDATE
  TO authenticated
  USING (
    sender_id = auth.uid()
    OR public.authorize('support_tickets', 'update', public.ticket_org_id(ticket_id))
  )
  WITH CHECK (
    sender_id = auth.uid()
    OR public.authorize('support_tickets', 'update', public.ticket_org_id(ticket_id))
  );
