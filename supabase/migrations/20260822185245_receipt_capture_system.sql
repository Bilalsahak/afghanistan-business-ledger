create type public.receipt_category as enum (
  'sale',
  'inventory_purchase',
  'operating_expense',
  'other_money_in',
  'other_money_out'
);

create table public.receipts (
  id uuid primary key default gen_random_uuid(),
  daily_entry_id uuid references public.daily_entries(id) on delete set null,
  receipt_date date not null,
  category public.receipt_category not null,
  vendor text not null default '' check (char_length(vendor) <= 250),
  receipt_number text not null default '' check (char_length(receipt_number) <= 100),
  amount_afn numeric(14,2) not null check (amount_afn > 0),
  image_path text not null unique,
  raw_text text not null default '' check (char_length(raw_text) <= 12000),
  extraction_confidence numeric(5,2) check (extraction_confidence between 0 and 100),
  notes text not null default '' check (char_length(notes) <= 1000),
  created_by uuid not null default auth.uid() references public.profiles(id),
  verified_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index receipts_date_idx on public.receipts(receipt_date desc);
create index receipts_daily_entry_idx on public.receipts(daily_entry_id) where daily_entry_id is not null;
create index receipts_creator_idx on public.receipts(created_by);

alter table public.receipts enable row level security;

create policy "approved_receipts_read" on public.receipts
for select to authenticated using ((select private.is_approved()));

create policy "approved_receipts_insert" on public.receipts
for insert to authenticated with check (
  (select private.is_approved()) and created_by = (select auth.uid())
);

create policy "admin_receipts_delete" on public.receipts
for delete to authenticated using ((select private.is_admin()));

grant select, insert, delete on public.receipts to authenticated;
revoke all on public.receipts from anon;

create trigger audit_receipts after insert or delete on public.receipts
for each row execute function private.write_audit_event();

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'business-receipts',
  'business-receipts',
  false,
  10485760,
  array['image/jpeg','image/png','image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy "approved_receipt_images_read" on storage.objects
for select to authenticated using (
  bucket_id = 'business-receipts' and (select private.is_approved())
);

create policy "approved_receipt_images_upload" on storage.objects
for insert to authenticated with check (
  bucket_id = 'business-receipts'
  and (select private.is_approved())
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

create policy "receipt_owner_or_admin_delete" on storage.objects
for delete to authenticated using (
  bucket_id = 'business-receipts'
  and (owner_id = (select auth.uid())::text or (select private.is_admin()))
);
