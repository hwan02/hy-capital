-- 자금 흐름 거래 장부 (에어비앤비 거래 장부처럼 날짜별 유입/지출 기록)
-- direction : '들어오는 돈' | '나가는 돈'
create table public.flow_entries (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  entry_date  date not null,
  direction   text not null,            -- 들어오는 돈 | 나가는 돈
  label       text not null,            -- 항목명 (월급, 에어비앤비, 연금저축 …)
  amount      numeric(18,2) not null default 0,
  memo        text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index flow_entries_user_idx on public.flow_entries (user_id, entry_date);
create trigger set_updated_at before update on public.flow_entries
  for each row execute function public.set_updated_at();
alter table public.flow_entries enable row level security;
create policy "own - select" on public.flow_entries for select using (auth.uid() = user_id);
create policy "own - insert" on public.flow_entries for insert with check (auth.uid() = user_id);
create policy "own - update" on public.flow_entries for update using (auth.uid() = user_id);
create policy "own - delete" on public.flow_entries for delete using (auth.uid() = user_id);

-- 기존 '들어오는 돈 계획(income_sources)'·'나가는 돈 계획(allocations)' 을
-- 이번 달(2026-08) 거래로 시드해 장부가 비지 않게 한다.
insert into public.flow_entries (user_id, entry_date, direction, label, amount)
select user_id, date '2026-08-01', '들어오는 돈', label, monthly_amount
from public.income_sources;

insert into public.flow_entries (user_id, entry_date, direction, label, amount)
select user_id, date '2026-08-01', '나가는 돈', label, monthly_amount
from public.allocations;
