-- ────────────────────────────────────────────────────────────
-- lecture_answers : 강의 질문에 받은 답을 적어둔다
--
-- 지금까지 '물어봤음' 체크가 메모리에만 있어 새로고침하면 사라졌다.
-- 강의장에서 폰으로 체크하고 답을 적는 용도라 반드시 저장돼야 한다.
--
-- qkey = '<섹션인덱스>-<질문인덱스>' (예: '2-1').
-- question 에 질문 원문을 함께 남겨, 나중에 질문 목록을 고쳐 순서가
-- 밀렸을 때 어긋난 것을 눈으로 찾을 수 있게 한다.
-- ────────────────────────────────────────────────────────────
create table if not exists public.lecture_answers (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  qkey       text not null,
  question   text,                             -- 질문 원문(드리프트 확인용)
  asked      boolean not null default false,   -- 물어봤는지
  answer     text,                             -- 강사에게 받은 답
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, qkey)
);
create index if not exists lecture_answers_user_idx
  on public.lecture_answers (user_id, qkey);

create trigger set_updated_at before update on public.lecture_answers
  for each row execute function public.set_updated_at();

alter table public.lecture_answers enable row level security;
create policy "own - select" on public.lecture_answers for select using (auth.uid() = user_id);
create policy "own - insert" on public.lecture_answers for insert with check (auth.uid() = user_id);
create policy "own - update" on public.lecture_answers for update using (auth.uid() = user_id);
create policy "own - delete" on public.lecture_answers for delete using (auth.uid() = user_id);
