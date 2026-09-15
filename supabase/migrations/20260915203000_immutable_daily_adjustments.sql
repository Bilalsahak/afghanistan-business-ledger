-- Append-only correction workflow. Submitted daily records and their evidence
-- cannot be directly rewritten or deleted by application users, including admins.

create table public.daily_entry_adjustments (
  id uuid primary key default gen_random_uuid(),
  daily_entry_id uuid not null references public.daily_entries(id),
  reason text not null check (char_length(trim(reason)) between 10 and 1000),
  evidence_path text not null unique check (char_length(evidence_path) between 5 and 1000),
  opening_cash_delta numeric(14,2) not null default 0,
  sales_revenue_delta numeric(14,2) not null default 0,
  inventory_purchases_delta numeric(14,2) not null default 0,
  operating_expenses_delta numeric(14,2) not null default 0,
  other_money_in_delta numeric(14,2) not null default 0,
  other_money_out_delta numeric(14,2) not null default 0,
  closing_cash_delta numeric(14,2) not null default 0,
  status public.approval_status not null default 'pending',
  original_snapshot jsonb not null default '{}'::jsonb,
  submitted_by uuid not null default auth.uid() references public.profiles(id),
  reviewed_by uuid references public.profiles(id),
  review_note text not null default '' check (char_length(review_note) <= 1000),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  constraint adjustment_changes_something check (
    opening_cash_delta <> 0 or sales_revenue_delta <> 0 or
    inventory_purchases_delta <> 0 or operating_expenses_delta <> 0 or
    other_money_in_delta <> 0 or other_money_out_delta <> 0 or
    closing_cash_delta <> 0
  )
);

create index daily_entry_adjustments_entry_idx
  on public.daily_entry_adjustments(daily_entry_id, created_at desc);
create index daily_entry_adjustments_submitter_idx
  on public.daily_entry_adjustments(submitted_by, created_at desc);
create index daily_entry_adjustments_reviewer_idx
  on public.daily_entry_adjustments(reviewed_by) where reviewed_by is not null;
create index daily_entry_adjustments_pending_idx
  on public.daily_entry_adjustments(created_at) where status = 'pending';
create unique index daily_entry_adjustments_one_pending_idx
  on public.daily_entry_adjustments(daily_entry_id, submitted_by) where status = 'pending';

alter table public.daily_entry_adjustments enable row level security;

create policy "approved_adjustments_read" on public.daily_entry_adjustments
for select to authenticated using ((select private.is_approved()));

create policy "operator_adjustments_insert" on public.daily_entry_adjustments
for insert to authenticated with check (
  (select private.is_approved())
  and submitted_by = (select auth.uid())
  and status = 'pending'
  and reviewed_by is null
  and reviewed_at is null
  and exists (
    select 1 from public.daily_entries e
    where e.id = daily_entry_id
      and (
        (e.created_by = (select auth.uid()) and e.entry_date >= current_date - 7)
        or (select private.is_admin())
      )
  )
);

-- Admins may change only the review columns because column-level grants below
-- do not grant UPDATE on amounts, evidence, reason, submitter, or entry link.
create policy "independent_admin_adjustment_review" on public.daily_entry_adjustments
for update to authenticated
using (
  (select private.is_admin())
  and status = 'pending'
  and submitted_by <> (select auth.uid())
)
with check (
  (select private.is_admin())
  and status in ('approved','rejected')
  and submitted_by <> (select auth.uid())
  and reviewed_by = (select auth.uid())
  and reviewed_at is not null
);

revoke update, delete on public.daily_entry_adjustments from authenticated;
grant select, insert on public.daily_entry_adjustments to authenticated;
grant update(status, reviewed_by, reviewed_at, review_note)
  on public.daily_entry_adjustments to authenticated;
revoke all on public.daily_entry_adjustments from anon;

create function private.capture_adjustment_original() returns trigger
language plpgsql security definer set search_path = '' as $$
declare original public.daily_entries%rowtype;
begin
  select * into original from public.daily_entries where id = new.daily_entry_id;
  if not found then raise exception 'Daily record not found'; end if;
  new.original_snapshot = jsonb_build_object(
    'entry_date', original.entry_date,
    'opening_cash', original.opening_cash,
    'sales_revenue', original.sales_revenue,
    'inventory_purchases', original.inventory_purchases,
    'operating_expenses', original.operating_expenses,
    'other_money_in', original.other_money_in,
    'other_money_out', original.other_money_out,
    'closing_cash', original.closing_cash,
    'notes', original.notes,
    'created_by', original.created_by,
    'created_at', original.created_at
  );
  return new;
end;
$$;
revoke all on function private.capture_adjustment_original() from public, anon, authenticated;

create function private.apply_approved_adjustment() returns trigger
language plpgsql security definer set search_path = '' as $$
declare current_entry public.daily_entries%rowtype;
begin
  if old.status = 'pending' and new.status = 'approved' then
    if new.reviewed_by is null or new.reviewed_by = new.submitted_by then
      raise exception 'Independent admin approval is required';
    end if;
    select * into current_entry from public.daily_entries where id = new.daily_entry_id for update;
    if current_entry.opening_cash + new.opening_cash_delta < 0
      or current_entry.sales_revenue + new.sales_revenue_delta < 0
      or current_entry.inventory_purchases + new.inventory_purchases_delta < 0
      or current_entry.operating_expenses + new.operating_expenses_delta < 0
      or current_entry.other_money_in + new.other_money_in_delta < 0
      or current_entry.other_money_out + new.other_money_out_delta < 0
      or current_entry.closing_cash + new.closing_cash_delta < 0 then
      raise exception 'An approved correction cannot make a financial value negative';
    end if;
    update public.daily_entries set
      opening_cash = opening_cash + new.opening_cash_delta,
      sales_revenue = sales_revenue + new.sales_revenue_delta,
      inventory_purchases = inventory_purchases + new.inventory_purchases_delta,
      operating_expenses = operating_expenses + new.operating_expenses_delta,
      other_money_in = other_money_in + new.other_money_in_delta,
      other_money_out = other_money_out + new.other_money_out_delta,
      closing_cash = closing_cash + new.closing_cash_delta,
      updated_at = now()
    where id = new.daily_entry_id;
  end if;
  return new;
end;
$$;
revoke all on function private.apply_approved_adjustment() from public, anon, authenticated;

create trigger capture_daily_adjustment_original
before insert on public.daily_entry_adjustments
for each row execute function private.capture_adjustment_original();
create trigger apply_daily_adjustment
after update of status on public.daily_entry_adjustments
for each row execute function private.apply_approved_adjustment();
create trigger audit_daily_entry_adjustments
after insert or update on public.daily_entry_adjustments
for each row execute function private.write_audit_event();

-- The application has no direct rewrite or deletion route for submitted days.
drop policy if exists "admin_entry_update" on public.daily_entries;
drop policy if exists "admin_entry_delete" on public.daily_entries;
revoke update, delete on public.daily_entries from authenticated;

-- Evidence becomes immutable once its metadata references the storage object.
drop policy if exists "admin_receipts_delete" on public.receipts;
revoke delete on public.receipts from authenticated;
drop policy if exists "creator_or_admin_notebook_pages_delete" on public.daily_notebook_pages;
revoke delete on public.daily_notebook_pages from authenticated;
drop policy if exists "receipt_owner_or_admin_delete" on storage.objects;
create policy "unreferenced_business_image_delete" on storage.objects
for delete to authenticated using (
  bucket_id = 'business-receipts'
  and owner_id = (select auth.uid())::text
  and not exists (select 1 from public.receipts r where r.image_path = name)
  and not exists (select 1 from public.daily_notebook_pages n where n.image_path = name)
  and not exists (select 1 from public.daily_entry_adjustments a where a.evidence_path = name)
);

-- Partner requests are append-only. Admins can only record the decision fields,
-- and the requester can never approve their own request.
drop policy if exists "admin_partner_transactions_update" on public.partner_transactions;
drop policy if exists "admin_partner_transactions_delete" on public.partner_transactions;
revoke update, delete on public.partner_transactions from authenticated;
grant update(status, approved_by, approved_at) on public.partner_transactions to authenticated;
create policy "independent_admin_partner_review" on public.partner_transactions
for update to authenticated
using (
  (select private.is_admin()) and status = 'pending'
  and submitted_by <> (select auth.uid())
)
with check (
  (select private.is_admin()) and status in ('approved','rejected')
  and submitted_by <> (select auth.uid())
  and approved_by = (select auth.uid()) and approved_at is not null
);

comment on table public.daily_entry_adjustments is
  'Append-only, evidence-backed corrections. Originals remain in original_snapshot and audit_events.';
