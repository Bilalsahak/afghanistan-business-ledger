create type public.user_role as enum ('admin', 'user');
create type public.approval_status as enum ('pending', 'approved', 'rejected');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  full_name text not null default '',
  role public.user_role not null default 'user',
  status public.approval_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.daily_entries (
  id uuid primary key default gen_random_uuid(),
  entry_date date not null,
  opening_cash numeric(14,2) not null default 0 check (opening_cash >= 0),
  sales_revenue numeric(14,2) not null default 0 check (sales_revenue >= 0),
  inventory_purchases numeric(14,2) not null default 0 check (inventory_purchases >= 0),
  operating_expenses numeric(14,2) not null default 0 check (operating_expenses >= 0),
  other_money_in numeric(14,2) not null default 0 check (other_money_in >= 0),
  other_money_out numeric(14,2) not null default 0 check (other_money_out >= 0),
  closing_cash numeric(14,2) not null default 0 check (closing_cash >= 0),
  expected_closing_cash numeric(14,2) generated always as
    (opening_cash + sales_revenue + other_money_in - inventory_purchases - operating_expenses - other_money_out) stored,
  cash_difference numeric(14,2) generated always as
    (closing_cash - (opening_cash + sales_revenue + other_money_in - inventory_purchases - operating_expenses - other_money_out)) stored,
  notes text not null default '' check (char_length(notes) <= 2000),
  created_by uuid not null default auth.uid() references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index daily_entries_date_idx on public.daily_entries(entry_date desc);
create index daily_entries_creator_idx on public.daily_entries(created_by);

create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated;

create function private.is_admin() returns boolean language sql stable security definer
set search_path = '' as $$
  select exists(select 1 from public.profiles where id = (select auth.uid()) and role = 'admin' and status = 'approved');
$$;
create function private.is_approved() returns boolean language sql stable security definer
set search_path = '' as $$
  select exists(select 1 from public.profiles where id = (select auth.uid()) and status = 'approved');
$$;
revoke all on function private.is_admin() from public;
revoke all on function private.is_approved() from public;
grant execute on function private.is_admin() to authenticated;
grant execute on function private.is_approved() to authenticated;

create function private.handle_new_user() returns trigger language plpgsql security definer
set search_path = '' as $$
begin
  insert into public.profiles(id,email,full_name)
  values(new.id,coalesce(new.email,''),coalesce(new.raw_user_meta_data->>'full_name',''));
  return new;
end;
$$;
revoke all on function private.handle_new_user() from public, anon, authenticated;
create trigger on_auth_user_created after insert on auth.users for each row execute function private.handle_new_user();

alter table public.profiles enable row level security;
alter table public.daily_entries enable row level security;

create policy "profile_self_or_admin_read" on public.profiles for select to authenticated
using ((select auth.uid()) = id or (select private.is_admin()));
create policy "admin_profiles_update" on public.profiles for update to authenticated
using ((select private.is_admin())) with check ((select private.is_admin()));

create policy "approved_entries_read" on public.daily_entries for select to authenticated
using ((select private.is_approved()));
create policy "approved_entries_insert" on public.daily_entries for insert to authenticated
with check ((select private.is_approved()) and created_by = (select auth.uid()));
create policy "owner_entry_update" on public.daily_entries for update to authenticated
using ((created_by = (select auth.uid()) and (select private.is_approved())) or (select private.is_admin()))
with check ((created_by = (select auth.uid()) and (select private.is_approved())) or (select private.is_admin()));
create policy "admin_entry_delete" on public.daily_entries for delete to authenticated
using ((select private.is_admin()));

grant select on public.profiles to authenticated;
grant update(status, role, full_name) on public.profiles to authenticated;
grant select, insert, update, delete on public.daily_entries to authenticated;
revoke all on public.profiles, public.daily_entries from anon;

-- After signing up as the owner, run this once in the SQL editor, replacing the email:
-- update public.profiles set role='admin', status='approved' where email='owner@example.com';
