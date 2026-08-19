-- 월별 추적 / 목표 / 사업자금 / 자금 분배 확장
-- 홍대포포(에어비앤비 1호점) 엑셀 구조를 반영한 거래 장부 포함.

-- ────────────────────────────────────────────────────────────
-- airbnb_transactions : 호점별 거래 장부 (엑셀 '홍대포포' 시트 구조)
--   순수익 = 정산금 + 추가지급 − 청소비 − 변동비 − 고정비
-- ────────────────────────────────────────────────────────────
create table public.airbnb_transactions (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  unit_id       uuid not null references public.airbnb_units(id) on delete cascade,
  txn_date      date not null,
  nights        numeric(6,1) not null default 0,   -- 박
  guest_payment numeric(12,0) not null default 0,  -- 게스트결제금액
  payout        numeric(12,0) not null default 0,  -- 에어비앤비정산금
  extra_income  numeric(12,0) not null default 0,  -- 추가지급받은금액
  cleaning_cost numeric(12,0) not null default 0,  -- 청소비
  variable_cost numeric(12,0) not null default 0,  -- 변동비(비품/소모품)
  fixed_cost    numeric(12,0) not null default 0,  -- 고정비(월세/공과금 등)
  memo          text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index airbnb_txn_unit_idx on public.airbnb_transactions (unit_id, txn_date);
create index airbnb_txn_user_idx on public.airbnb_transactions (user_id);

-- 월별 손익 집계 뷰 (RLS 는 기반 테이블을 따르도록 security_invoker)
create view public.airbnb_monthly
with (security_invoker = on) as
select
  user_id,
  unit_id,
  date_trunc('month', txn_date)::date as month,
  sum(payout + extra_income)                                          as revenue,
  sum(cleaning_cost)                                                  as cleaning,
  sum(variable_cost)                                                  as variable_cost,
  sum(fixed_cost)                                                     as fixed_cost,
  sum(cleaning_cost + variable_cost + fixed_cost)                     as total_cost,
  sum(payout + extra_income - cleaning_cost - variable_cost - fixed_cost) as net_profit,
  count(*) filter (where nights > 0)                                  as bookings,
  sum(nights)                                                         as nights
from public.airbnb_transactions
group by user_id, unit_id, date_trunc('month', txn_date);

-- ────────────────────────────────────────────────────────────
-- 사업 엔진 월 목표
-- ────────────────────────────────────────────────────────────
alter table public.airbnb_units      add column if not exists monthly_target numeric(12,0) not null default 0;
alter table public.shorts_channels   add column if not exists monthly_target numeric(12,0) not null default 0;
alter table public.dividend_holdings add column if not exists monthly_target numeric(12,0) not null default 0;

-- ────────────────────────────────────────────────────────────
-- 토지 사업자금 (에비는 이미 reserve_fund/target_fund 보유)
-- ────────────────────────────────────────────────────────────
alter table public.land_projects add column if not exists reserve_fund numeric(16,0) not null default 0;
alter table public.land_projects add column if not exists target_fund  numeric(16,0) not null default 0;

-- ────────────────────────────────────────────────────────────
-- monthly_entries : 숏폼/배당 등 월별 실적 (범용)
--   category ∈ shorts | dividend | airbnb | custom
-- ────────────────────────────────────────────────────────────
create table public.monthly_entries (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  category   text not null,
  ref_id     uuid,           -- 연결 대상(채널/종목/호점) — 선택
  ref_name   text,           -- 표시용 이름
  month      date not null,  -- 해당 월 1일
  amount     numeric(14,0) not null default 0,
  memo       text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, category, ref_id, month)
);
create index monthly_entries_user_idx on public.monthly_entries (user_id, category, month);

-- ────────────────────────────────────────────────────────────
-- allocations : 자금 분배 계획 (월급자금/사업자금 → 배분처)
--   pool ∈ salary | business
-- ────────────────────────────────────────────────────────────
create table public.allocations (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references auth.users(id) on delete cascade,
  pool           text not null,                 -- salary | business
  label          text not null,                 -- 배분처(생활비/에비2 준비금/ETF 등)
  monthly_amount numeric(14,0) not null default 0,
  memo           text,
  sort_order     int not null default 0,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create index allocations_user_idx on public.allocations (user_id, pool, sort_order);

-- ────────────────────────────────────────────────────────────
-- updated_at 트리거 + RLS
-- ────────────────────────────────────────────────────────────
do $$
declare t text;
begin
  foreach t in array array['airbnb_transactions','monthly_entries','allocations'] loop
    execute format('create trigger set_updated_at before update on public.%I
       for each row execute function public.set_updated_at();', t);
    execute format('alter table public.%I enable row level security;', t);
    execute format('create policy "own - select" on public.%I for select using (auth.uid() = user_id);', t);
    execute format('create policy "own - insert" on public.%I for insert with check (auth.uid() = user_id);', t);
    execute format('create policy "own - update" on public.%I for update using (auth.uid() = user_id);', t);
    execute format('create policy "own - delete" on public.%I for delete using (auth.uid() = user_id);', t);
  end loop;
end $$;
