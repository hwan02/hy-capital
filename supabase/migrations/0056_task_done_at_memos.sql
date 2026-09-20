-- ────────────────────────────────────────────────────────────
-- 1) tasks.done_at — «언제» 체크했나
--
-- 지금까지는 done(true/false)만 있어서, 체크한 일을 목록에서 치우면
-- 그게 어제 한 건지 지난달 건지 알 방법이 없었다.
-- 대시보드는 체크하면 바로 사라지고, 「지난 완료」는 done_at 으로 «날짜별»로 묶는다.
--
-- 기존 완료분은 언제 체크했는지 기록이 없다 → updated_at 으로 백필한다.
-- 정확한 시각은 아니지만(마지막 수정 시각), 비워두면 지난 기록이
-- 통째로 「날짜 없음」이 되어 더 쓸모없다.
-- ────────────────────────────────────────────────────────────
alter table public.tasks add column if not exists done_at timestamptz;

update public.tasks
   set done_at = updated_at
 where done and done_at is null;

create index if not exists tasks_done_at_idx
  on public.tasks (user_id, done, done_at desc);

-- ────────────────────────────────────────────────────────────
-- 2) memos — 대시보드 «빠른 메모»
--
-- 자료실(knowledge_notes)은 «투자 자료»다. 출처·태그·전문가가 붙는다.
-- 여기는 그런 게 붙기 전의 것 — 통화하다 들은 숫자, 오늘 확인할 것,
-- 아직 할 일인지도 모르는 한 줄. 제목을 짓게 하면 안 쓰게 되므로
-- 본문 하나만 받는다.
--
-- pinned 는 위로 고정 — 계속 눈에 둬야 하는 한두 개.
-- ────────────────────────────────────────────────────────────
create table if not exists public.memos (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,

  body        text not null,
  pinned      boolean not null default false,

  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists memos_user_idx
  on public.memos (user_id, pinned desc, created_at desc);

create trigger set_updated_at before update on public.memos
  for each row execute function public.set_updated_at();

alter table public.memos enable row level security;
create policy "own - select" on public.memos for select using (auth.uid() = user_id);
create policy "own - insert" on public.memos for insert with check (auth.uid() = user_id);
create policy "own - update" on public.memos for update using (auth.uid() = user_id);
create policy "own - delete" on public.memos for delete using (auth.uid() = user_id);

-- 실행 기록 (0053 이 만든 표).
insert into public.hy_migrations (name) values ('0056_task_done_at_memos')
  on conflict (name) do nothing;
