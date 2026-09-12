-- Camera-captured notebook evidence attached to protected daily entries.
create table if not exists public.daily_notebook_pages (
  id uuid primary key default gen_random_uuid(),
  daily_entry_id uuid not null references public.daily_entries(id) on delete cascade,
  image_path text not null unique,
  page_number smallint not null check (page_number > 0),
  created_by uuid not null default auth.uid() references public.profiles(id),
  created_at timestamptz not null default now(),
  unique (daily_entry_id, page_number)
);

create index if not exists daily_notebook_pages_entry_idx
  on public.daily_notebook_pages(daily_entry_id, page_number);
create index if not exists daily_notebook_pages_creator_idx
  on public.daily_notebook_pages(created_by);

alter table public.daily_notebook_pages enable row level security;

create policy "approved_notebook_pages_read" on public.daily_notebook_pages
for select to authenticated using ((select private.is_approved()));

create policy "approved_notebook_pages_insert" on public.daily_notebook_pages
for insert to authenticated with check (
  (select private.is_approved()) and created_by = (select auth.uid())
);

create policy "creator_or_admin_notebook_pages_delete" on public.daily_notebook_pages
for delete to authenticated using (
  created_by = (select auth.uid()) or (select private.is_admin())
);

grant select, insert, delete on public.daily_notebook_pages to authenticated;
revoke all on public.daily_notebook_pages from anon;

create trigger audit_daily_notebook_pages
after insert or delete on public.daily_notebook_pages
for each row execute function private.write_audit_event();

comment on column public.daily_entries.sales_revenue is
  'Total sales at selling price, including cash sales and customer credit (Qarz) sales.';
comment on column public.daily_entries.other_money_in is
  'Customer Qarz collected in cash today from sales recognized on an earlier day.';
comment on column public.daily_entries.other_money_out is
  'Customer Qarz given today: selling-price value included in sales but not collected in cash.';
