-- ────────────────────────────────────────────────────────────
-- 책 — 읽는 «순서»를 나무로 관리한다.
--
--   뿌리(입문) → 줄기(분야) → 가지(개별 책)
--
-- 목록이 아니라 «트리»인 이유: 어떤 책은 앞의 책을 읽어야 읽힌다.
-- 순서를 모르면 어려운 책을 먼저 집었다가 덮는다.
--
-- category 로 분야를 나눈다 (지금은 '부동산' 하나. 나중에 늘린다).
-- ────────────────────────────────────────────────────────────
create table if not exists public.books (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,

  category    text not null default '부동산',   -- 부동산 | (추후) 사업 | 마인드 …
  branch      text not null,                    -- 줄기 — 입문 · 경매 · 아파트·수익형 · 토지 · 법인
  sort_order  int  not null default 0,          -- 줄기 안에서 «읽는 순서»

  title       text not null,
  author      text,
  level       int  not null default 1,          -- 난이도 1~5
  tags        text[] not null default '{}',
  cover       text,                             -- 표지 이미지 (base64 data URL)
  link        text,                             -- 구매·정보 링크

  -- 읽기 기록
  status      text not null default 'todo',     -- todo | reading | done
  started_on  date,
  read_on     date,                             -- 다 읽은 날
  rating      int,                              -- 1~5 (내 평가)
  memo        text,                             -- 읽고 남긴 것

  why         text,                             -- 이 자리에 왜 있나 (읽는 이유)

  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists books_user_idx
  on public.books (user_id, category, branch, sort_order);

create trigger set_updated_at before update on public.books
  for each row execute function public.set_updated_at();

alter table public.books enable row level security;
create policy "own - select" on public.books for select using (auth.uid() = user_id);
create policy "own - insert" on public.books for insert with check (auth.uid() = user_id);
create policy "own - update" on public.books for update using (auth.uid() = user_id);
create policy "own - delete" on public.books for delete using (auth.uid() = user_id);
