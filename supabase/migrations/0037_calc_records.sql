-- 경매 계산기 이력 — 계산 입력값을 저장/수정/삭제한다. inputs는 계산기 필드 전체(jsonb).
create table if not exists public.calc_records (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  label      text not null default '',
  inputs     jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists calc_records_user_idx on public.calc_records (user_id, created_at desc);
alter table public.calc_records enable row level security;
create policy "own - select" on public.calc_records for select using (auth.uid() = user_id);
create policy "own - insert" on public.calc_records for insert with check (auth.uid() = user_id);
create policy "own - update" on public.calc_records for update using (auth.uid() = user_id);
create policy "own - delete" on public.calc_records for delete using (auth.uid() = user_id);
create trigger set_updated_at before update on public.calc_records
  for each row execute function public.set_updated_at();
