-- 나가는 돈 — 실제로 입금(이체)했는지 체크.
-- 적어둔 것과 실제로 나간 것은 다르다. 체크해야 「이번 달 아직 안 낸 것」이 보인다.
alter table public.flow_entries
  add column if not exists paid boolean not null default false,
  add column if not exists paid_at timestamptz;

-- 지난 달까지의 기록은 이미 지나간 일이므로 완료로 본다.
-- 이번 달·앞으로의 것만 미납으로 남겨 체크하게 한다.
update public.flow_entries
   set paid = true, paid_at = entry_date::timestamptz
 where paid = false
   and entry_date < date_trunc('month', now())::date;

-- 미납 조회용
create index if not exists flow_entries_unpaid_idx
  on public.flow_entries (user_id, paid, entry_date)
  where direction = '나가는 돈';
