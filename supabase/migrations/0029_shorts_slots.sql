-- ────────────────────────────────────────────────────────────
-- shorts_slots : 숏폼 편성표
--
-- 지금까지 42개가 Dart 코드에 박혀 있어서 고칠 수 없었고, 완료 체크도
-- 세션 안에서만 유지돼 새로고침하면 사라졌다.
-- 달력에서 «보고 고치는» 것이 목적이므로 테이블로 옮긴다.
-- ────────────────────────────────────────────────────────────
create table if not exists public.shorts_slots (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  slot_date   date not null,
  cat         text not null default 'fire',  -- fire|film|mind|data|trophy|swap
  title       text not null,
  hook        text,                          -- 한 줄 훅
  src         text,                          -- 출처
  url         text,                          -- 원문 링크
  prio        text default '4',              -- 우선순위 표기 (5 · 4.5 · ?)
  done        boolean not null default false,
  memo        text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists shorts_slots_user_idx
  on public.shorts_slots (user_id, slot_date);

create trigger set_updated_at before update on public.shorts_slots
  for each row execute function public.set_updated_at();

alter table public.shorts_slots enable row level security;
create policy "own - select" on public.shorts_slots for select using (auth.uid() = user_id);
create policy "own - insert" on public.shorts_slots for insert with check (auth.uid() = user_id);
create policy "own - update" on public.shorts_slots for update using (auth.uid() = user_id);
create policy "own - delete" on public.shorts_slots for delete using (auth.uid() = user_id);
