-- Defense in depth after the initial adjustment rollout.
revoke delete on public.daily_entry_adjustments from authenticated;

-- Ordinary operators may record only today or yesterday. This prevents quiet
-- backdating or future-dating while allowing an overnight close. Admins retain
-- explicit backfill ability, which remains visible in the audit history.
drop policy if exists "approved_entries_insert" on public.daily_entries;
create policy "approved_entries_insert" on public.daily_entries
for insert to authenticated with check (
  (select private.is_approved())
  and created_by = (select auth.uid())
  and (
    entry_date between current_date - 1 and current_date
    or (select private.is_admin())
  )
);
