create index if not exists daily_entry_adjustments_reviewer_idx
  on public.daily_entry_adjustments(reviewed_by) where reviewed_by is not null;
