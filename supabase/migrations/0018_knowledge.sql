-- ────────────────────────────────────────────────────────────
-- knowledge_notes : 부동산 지식 자료실
-- 강의 Q&A · 카페 칼럼 · 유튜브 요약 · 내 메모를 한 곳에 모아
-- 태그/키워드로 언제든 검색해서 꺼내본다.
-- ────────────────────────────────────────────────────────────
create table if not exists public.knowledge_notes (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  kind        text not null default 'qa',   -- qa|article|note|video
  title       text not null,                -- 질문 또는 제목
  body        text,                         -- 답변 또는 본문
  tags        text[] not null default '{}', -- 세금·대출·재개발·경매 …
  source      text,                         -- 출처(강의명/카페/유튜브)
  author      text,                         -- 답변자·작성자 (예: 부자되는세상)
  asker       text,                         -- 질문자 (Q&A인 경우)
  source_date date,                         -- 원본 일자
  starred     boolean not null default false,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists knowledge_user_idx on public.knowledge_notes (user_id, source_date desc);
create index if not exists knowledge_tags_idx on public.knowledge_notes using gin (tags);

create trigger set_updated_at before update on public.knowledge_notes
  for each row execute function public.set_updated_at();

alter table public.knowledge_notes enable row level security;
create policy "own - select" on public.knowledge_notes for select using (auth.uid() = user_id);
create policy "own - insert" on public.knowledge_notes for insert with check (auth.uid() = user_id);
create policy "own - update" on public.knowledge_notes for update using (auth.uid() = user_id);
create policy "own - delete" on public.knowledge_notes for delete using (auth.uid() = user_id);
