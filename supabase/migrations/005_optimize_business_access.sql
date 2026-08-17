create index business_settings_updated_by_idx on public.business_settings(updated_by);
create index daily_entries_reviewed_by_idx on public.daily_entries(reviewed_by);
create index monthly_closes_created_by_idx on public.monthly_closes(created_by);
create index monthly_closes_reviewed_by_idx on public.monthly_closes(reviewed_by);
create index quarterly_reviews_created_by_idx on public.quarterly_reviews(created_by);
create index quarterly_reviews_reviewed_by_idx on public.quarterly_reviews(reviewed_by);

drop policy "admin_settings_write" on public.business_settings;
create policy "admin_settings_insert" on public.business_settings for insert to authenticated with check((select private.is_admin()));
create policy "admin_settings_update" on public.business_settings for update to authenticated using((select private.is_admin())) with check((select private.is_admin()));
create policy "admin_settings_delete" on public.business_settings for delete to authenticated using((select private.is_admin()));
drop policy "admin_partners_write" on public.partners;
create policy "admin_partners_insert" on public.partners for insert to authenticated with check((select private.is_admin()));
create policy "admin_partners_update" on public.partners for update to authenticated using((select private.is_admin())) with check((select private.is_admin()));
create policy "admin_partners_delete" on public.partners for delete to authenticated using((select private.is_admin()));
drop policy "admin_startup_write" on public.startup_summary;
create policy "admin_startup_insert" on public.startup_summary for insert to authenticated with check((select private.is_admin()));
create policy "admin_startup_update" on public.startup_summary for update to authenticated using((select private.is_admin())) with check((select private.is_admin()));
create policy "admin_startup_delete" on public.startup_summary for delete to authenticated using((select private.is_admin()));
