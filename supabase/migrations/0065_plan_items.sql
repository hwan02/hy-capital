-- 계획 — 10년 비전을 5년·3년·1년·6개월·3개월·1개월·1주로 쪼갠 할 일 목록.
--
-- 재무 로드맵(plan_phases)은 «돈이 어느 단계에 있나»만 본다. 그보다 위의
-- 큰 목표(자산·사람·여행)를 기간별로 내려 «이번 주에 뭘 하나»까지 잇는다.
--   horizon: 10년 · 5년 · 3년 · 1년 · 6개월 · 3개월 · 1개월 · 1주
--   track:   비전(맨 위 큰 목표) · 경공매 · 사업 · 인스타 · 재무 · 여행
-- 내용은 앱에서 채운다(공개 저장소라 여기 넣지 않는다).

create table if not exists public.plan_items (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,

  horizon     text not null,
  track       text not null,
  title       text not null,
  detail      text,
  due_date    date,
  done        boolean not null default false,
  done_at     date,
  sort_order  int not null default 0,

  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists plan_items_user_idx on public.plan_items (user_id, horizon, sort_order);

create trigger set_updated_at before update on public.plan_items
  for each row execute function public.set_updated_at();

-- 체크한 날 — 앱에서 따로 쓰지 않는다. 체크를 풀면 지운다.
create or replace function public.plan_items_set_done_at()
returns trigger
language plpgsql
as $$
begin
  if new.done then
    if new.done_at is null then
      new.done_at = current_date;
    end if;
  else
    new.done_at = null;
  end if;
  return new;
end;
$$;

drop trigger if exists plan_items_done_at on public.plan_items;
create trigger plan_items_done_at
  before insert or update on public.plan_items
  for each row execute function public.plan_items_set_done_at();

alter table public.plan_items enable row level security;
create policy "own - select" on public.plan_items for select using (auth.uid() = user_id);
create policy "own - insert" on public.plan_items for insert with check (auth.uid() = user_id);
create policy "own - update" on public.plan_items for update using (auth.uid() = user_id);
create policy "own - delete" on public.plan_items for delete using (auth.uid() = user_id);

-- 실행 기록 (0053 이 만든 표).
insert into public.hy_migrations (name) values ('0065_plan_items')
  on conflict (name) do nothing;
