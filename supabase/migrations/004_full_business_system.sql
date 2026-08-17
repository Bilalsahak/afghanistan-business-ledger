-- Full operating system: protected capital, monthly close, quarterly governance,
-- immutable audit history, and role-based access.

create type public.record_status as enum ('draft', 'submitted', 'reviewed', 'locked');

alter table public.daily_entries
  add column if not exists status public.record_status not null default 'submitted',
  add column if not exists reviewed_by uuid references public.profiles(id),
  add column if not exists reviewed_at timestamptz;

create unique index if not exists daily_entries_one_per_day_idx on public.daily_entries(entry_date);

create table public.business_settings (
  id smallint primary key default 1 check (id = 1),
  business_name text not null default 'Afghanistan Business',
  currency text not null default 'AFN' check (currency = 'AFN'),
  accounting_start_date date,
  cash_difference_warning numeric(14,2) not null default 500,
  updated_by uuid references public.profiles(id),
  updated_at timestamptz not null default now()
);

create table public.partners (
  id uuid primary key default gen_random_uuid(),
  display_order smallint not null default 0,
  name text not null,
  name_local text not null default '',
  capital_afn numeric(14,2) not null default 0 check (capital_afn >= 0),
  ownership_percent numeric(7,4) check (ownership_percent between 0 and 100),
  contribution_basis text not null default '',
  is_confirmed boolean not null default false,
  notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.monthly_closes (
  id uuid primary key default gen_random_uuid(),
  month_start date not null unique check (extract(day from month_start) = 1),
  beginning_inventory numeric(14,2) not null default 0 check (beginning_inventory >= 0),
  ending_inventory numeric(14,2) not null default 0 check (ending_inventory >= 0),
  rent numeric(14,2) not null default 0 check (rent >= 0),
  salaries numeric(14,2) not null default 0 check (salaries >= 0),
  utilities numeric(14,2) not null default 0 check (utilities >= 0),
  transport numeric(14,2) not null default 0 check (transport >= 0),
  other_expenses numeric(14,2) not null default 0 check (other_expenses >= 0),
  closing_cash numeric(14,2) not null default 0 check (closing_cash >= 0),
  receivables numeric(14,2) not null default 0 check (receivables >= 0),
  payables numeric(14,2) not null default 0 check (payables >= 0),
  notes text not null default '' check (char_length(notes) <= 3000),
  status public.record_status not null default 'submitted',
  created_by uuid not null default auth.uid() references public.profiles(id),
  reviewed_by uuid references public.profiles(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.quarterly_reviews (
  id uuid primary key default gen_random_uuid(),
  year integer not null check (year between 2020 and 2100),
  quarter smallint not null check (quarter between 1 and 4),
  retained_profit numeric(14,2) not null default 0 check (retained_profit >= 0),
  distributions numeric(14,2) not null default 0 check (distributions >= 0),
  inventory_actions text not null default '',
  cash_actions text not null default '',
  major_decisions text not null default '',
  approved_by_partners text not null default '',
  status public.record_status not null default 'submitted',
  created_by uuid not null default auth.uid() references public.profiles(id),
  reviewed_by uuid references public.profiles(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(year, quarter)
);

create table public.startup_summary (
  id smallint primary key default 1 check (id = 1),
  transaction_count integer not null default 0 check (transaction_count >= 0),
  total_afn numeric(14,2) not null default 0 check (total_afn >= 0),
  total_usd numeric(14,2) not null default 0 check (total_usd >= 0),
  notes text not null default '',
  updated_at timestamptz not null default now()
);

create table public.audit_events (
  id bigint generated always as identity primary key,
  table_name text not null,
  record_id text not null,
  action text not null check (action in ('INSERT','UPDATE','DELETE')),
  actor_id uuid,
  old_data jsonb,
  new_data jsonb,
  occurred_at timestamptz not null default now()
);
create index audit_events_record_idx on public.audit_events(table_name, record_id, occurred_at desc);

create or replace function private.is_manager_or_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists(
    select 1 from public.profiles
    where id = (select auth.uid()) and status = 'approved'
      and role in ('admin','manager')
  );
$$;
revoke all on function private.is_manager_or_admin() from public;
grant execute on function private.is_manager_or_admin() to authenticated;

create or replace function private.write_audit_event() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.audit_events(table_name, record_id, action, actor_id, old_data, new_data)
  values(
    tg_table_name,
    coalesce((case when tg_op = 'DELETE' then old else new end).id::text, 'singleton'),
    tg_op,
    (select auth.uid()),
    case when tg_op in ('UPDATE','DELETE') then to_jsonb(old) end,
    case when tg_op in ('INSERT','UPDATE') then to_jsonb(new) end
  );
  return coalesce(new, old);
end;
$$;
revoke all on function private.write_audit_event() from public, anon, authenticated;

create trigger audit_daily_entries after insert or update or delete on public.daily_entries
for each row execute function private.write_audit_event();
create trigger audit_monthly_closes after insert or update or delete on public.monthly_closes
for each row execute function private.write_audit_event();
create trigger audit_quarterly_reviews after insert or update or delete on public.quarterly_reviews
for each row execute function private.write_audit_event();
create trigger audit_partners after insert or update or delete on public.partners
for each row execute function private.write_audit_event();
create trigger audit_business_settings after insert or update or delete on public.business_settings
for each row execute function private.write_audit_event();

alter table public.business_settings enable row level security;
alter table public.partners enable row level security;
alter table public.monthly_closes enable row level security;
alter table public.quarterly_reviews enable row level security;
alter table public.startup_summary enable row level security;
alter table public.audit_events enable row level security;

create policy "approved_settings_read" on public.business_settings for select to authenticated using ((select private.is_approved()));
create policy "admin_settings_write" on public.business_settings for all to authenticated using ((select private.is_admin())) with check ((select private.is_admin()));
create policy "approved_partners_read" on public.partners for select to authenticated using ((select private.is_approved()));
create policy "admin_partners_write" on public.partners for all to authenticated using ((select private.is_admin())) with check ((select private.is_admin()));
create policy "approved_monthly_read" on public.monthly_closes for select to authenticated using ((select private.is_approved()));
create policy "manager_monthly_insert" on public.monthly_closes for insert to authenticated with check ((select private.is_manager_or_admin()) and created_by = (select auth.uid()));
create policy "admin_monthly_update" on public.monthly_closes for update to authenticated using ((select private.is_admin())) with check ((select private.is_admin()));
create policy "admin_monthly_delete" on public.monthly_closes for delete to authenticated using ((select private.is_admin()));
create policy "approved_quarterly_read" on public.quarterly_reviews for select to authenticated using ((select private.is_approved()));
create policy "manager_quarterly_insert" on public.quarterly_reviews for insert to authenticated with check ((select private.is_manager_or_admin()) and created_by = (select auth.uid()));
create policy "admin_quarterly_update" on public.quarterly_reviews for update to authenticated using ((select private.is_admin())) with check ((select private.is_admin()));
create policy "admin_quarterly_delete" on public.quarterly_reviews for delete to authenticated using ((select private.is_admin()));
create policy "approved_startup_read" on public.startup_summary for select to authenticated using ((select private.is_approved()));
create policy "admin_startup_write" on public.startup_summary for all to authenticated using ((select private.is_admin())) with check ((select private.is_admin()));
create policy "admin_audit_read" on public.audit_events for select to authenticated using ((select private.is_admin()));

-- Ordinary users submit daily records but cannot rewrite them afterward.
drop policy if exists "owner_entry_update" on public.daily_entries;
create policy "admin_entry_update" on public.daily_entries for update to authenticated
using ((select private.is_admin())) with check ((select private.is_admin()));

grant select, insert, update, delete on public.business_settings, public.partners, public.monthly_closes, public.quarterly_reviews, public.startup_summary to authenticated;
grant select on public.audit_events to authenticated;
revoke all on public.business_settings, public.partners, public.monthly_closes, public.quarterly_reviews, public.startup_summary, public.audit_events from anon;

insert into public.business_settings(id, business_name, currency)
values (1, 'Afghanistan Business', 'AFN') on conflict (id) do nothing;

insert into public.partners(display_order, name, name_local, capital_afn, contribution_basis, is_confirmed, notes)
select * from (values
  (1::smallint, 'Mohammad Idrees', 'محمد ادریس', 655500::numeric, '$10,000 × 65.55', true, ''),
  (2::smallint, 'Attiqullah', 'عتیق الله', 700000::numeric, 'Direct AFN contribution', true, ''),
  (3::smallint, 'Bilal', 'بلال', 525500::numeric, '$8,000 × 65.68 (agreed rounded value)', true, ''),
  (4::smallint, 'Other partner group', 'شریک دیگر', 0::numeric, '50% partner — contribution to be confirmed', false, 'Ownership and contributed capital require written confirmation')
) as seed(display_order,name,name_local,capital_afn,contribution_basis,is_confirmed,notes)
where not exists (select 1 from public.partners);

insert into public.startup_summary(id, transaction_count, total_afn, total_usd, notes)
values (1, 69, 3192003, 3030.30, 'Historical startup register preserved from the Excel system.')
on conflict (id) do nothing;
