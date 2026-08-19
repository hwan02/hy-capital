-- 들어오는 돈(수입원) 직접 관리 목록
create table public.income_sources (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references auth.users(id) on delete cascade,
  label          text not null,
  monthly_amount numeric(14,0) not null default 0,
  sort_order     int not null default 0,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create index income_sources_user_idx on public.income_sources (user_id, sort_order);
create trigger set_updated_at before update on public.income_sources
  for each row execute function public.set_updated_at();
alter table public.income_sources enable row level security;
create policy "own - select" on public.income_sources for select using (auth.uid() = user_id);
create policy "own - insert" on public.income_sources for insert with check (auth.uid() = user_id);
create policy "own - update" on public.income_sources for update using (auth.uid() = user_id);
create policy "own - delete" on public.income_sources for delete using (auth.uid() = user_id);
