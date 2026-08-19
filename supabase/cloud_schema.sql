-- HY CAPITAL 클라우드 스키마 (통합)

-- ==== supabase/migrations/0001_init.sql ====
-- HY CAPITAL — 개인 CFO 운영체제 스키마
-- 월급이 아닌 현금흐름으로 경제적 자유를 달성하기 위한 데이터 모델
-- 모든 테이블은 auth.users 기준 행 단위 소유. RLS 로 본인 데이터만 접근.

-- ────────────────────────────────────────────────────────────
-- 공통: updated_at 자동 갱신 트리거 함수
-- ────────────────────────────────────────────────────────────
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ────────────────────────────────────────────────────────────
-- profiles : 사용자 프로필 + 재무 자유 기준선
-- ────────────────────────────────────────────────────────────
create table public.profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  -- 경제적 자유 계산 기준
  monthly_expenses      numeric(14,0) not null default 3000000,  -- 월 생활비(자유 기준선)
  net_worth_goal        numeric(16,0) not null default 1500000000, -- 순자산 목표(15억)
  currency              text not null default 'KRW',
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- 신규 가입 시 프로필 자동 생성
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1)));
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ────────────────────────────────────────────────────────────
-- financial_snapshots : 순자산/현금/현금흐름 시계열 (대시보드 KPI 원천)
-- ────────────────────────────────────────────────────────────
create table public.financial_snapshots (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade,
  as_of        date not null,
  net_worth              numeric(16,0) not null default 0,  -- 순자산
  cash                   numeric(16,0) not null default 0,  -- 현금
  non_salary_cashflow    numeric(14,0) not null default 0,  -- 월급 제외 월 현금흐름
  salary_cashflow        numeric(14,0) not null default 0,  -- 월급 현금흐름(참고)
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (user_id, as_of)
);

-- ────────────────────────────────────────────────────────────
-- cash_flows : 머니플로우 원장 (월급→생활비, 사업수익→확장 등)
-- ────────────────────────────────────────────────────────────
create table public.cash_flows (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade,
  occurred_on  date not null,
  source       text not null,                 -- 유입원: 월급/사업수익/배당/토지매도/숏폼
  target       text not null,                 -- 배분처: 생활비/사업확장/재투자/에비확장
  amount       numeric(14,0) not null,
  is_salary    boolean not null default false, -- 월급 여부(월급 제외 현금흐름 계산용)
  memo         text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index cash_flows_user_date_idx on public.cash_flows (user_id, occurred_on desc);

-- ────────────────────────────────────────────────────────────
-- airbnb_units : 에어비앤비 호점 (확장 로드맵)
-- ────────────────────────────────────────────────────────────
create table public.airbnb_units (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references auth.users(id) on delete cascade,
  name           text not null,                       -- 호점 이름 (에비1, 에비2 …)
  status         text not null default 'planning',    -- planning|preparing|open
  reserve_fund   numeric(14,0) not null default 0,    -- 준비금
  target_fund    numeric(14,0) not null default 0,    -- 목표자금
  expected_open  date,                                -- 예상 오픈일
  monthly_profit numeric(12,0) not null default 0,    -- 월 순이익
  roi            numeric(6,2)  not null default 0,     -- ROI(%)
  occupancy      numeric(5,2)  not null default 0,     -- 점유율(%)
  sort_order     int not null default 0,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create index airbnb_user_idx on public.airbnb_units (user_id, sort_order);

-- ────────────────────────────────────────────────────────────
-- shorts_channels : 숏폼 사업 KPI
-- ────────────────────────────────────────────────────────────
create table public.shorts_channels (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references auth.users(id) on delete cascade,
  name           text not null,                       -- 채널명
  platform       text not null default 'YouTube',     -- YouTube|TikTok|Instagram
  uploads        int not null default 0,              -- 업로드 수
  views          bigint not null default 0,           -- 조회수
  rpm            numeric(8,2) not null default 0,      -- RPM
  revenue        numeric(12,0) not null default 0,     -- 매출
  net_profit     numeric(12,0) not null default 0,     -- 순이익
  roi            numeric(6,2)  not null default 0,     -- ROI(%)
  reinvest_ratio numeric(5,2)  not null default 0,     -- 재투자 비율(%)
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create index shorts_user_idx on public.shorts_channels (user_id);

-- ────────────────────────────────────────────────────────────
-- land_projects : 토지 투자 프로젝트
-- ────────────────────────────────────────────────────────────
create table public.land_projects (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references auth.users(id) on delete cascade,
  name           text not null,                       -- 후보지
  analysis       text,                                -- 분석
  catalyst       text,                                -- 개발호재
  principal      numeric(16,0) not null default 0,    -- 원금
  target_price   numeric(16,0) not null default 0,    -- 목표 매도가
  expert_opinion text,                                -- 전문가 의견
  status         text not null default 'reviewing',   -- reviewing|holding|sold
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create index land_user_idx on public.land_projects (user_id);

-- ────────────────────────────────────────────────────────────
-- dividend_holdings : 배당 성장 관리
-- ────────────────────────────────────────────────────────────
create table public.dividend_holdings (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references auth.users(id) on delete cascade,
  ticker           text not null,                     -- 종목
  market_value     numeric(14,0) not null default 0,  -- 평가금
  monthly_dividend numeric(12,0) not null default 0,  -- 월배당
  annual_dividend  numeric(12,0) not null default 0,  -- 연배당
  reinvest_rate    numeric(5,2)  not null default 0,   -- 재투자율(%)
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create index dividend_user_idx on public.dividend_holdings (user_id);

-- ────────────────────────────────────────────────────────────
-- goals : 목표 마일스톤 (월급제외 월1000, 에비2/3, 방배 아파트, 순자산 15억)
-- ────────────────────────────────────────────────────────────
create table public.goals (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  title         text not null,
  target_value  numeric(16,0) not null default 0,
  current_value numeric(16,0) not null default 0,
  unit          text not null default 'KRW',          -- KRW|count|percent
  target_date   date,
  status        text not null default 'active',        -- active|done
  sort_order    int not null default 0,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index goals_user_idx on public.goals (user_id, sort_order);

-- ────────────────────────────────────────────────────────────
-- tasks : 오늘 해야 할 일
-- ────────────────────────────────────────────────────────────
create table public.tasks (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  title       text not null,
  module      text,                                    -- dashboard|airbnb|shorts|land|dividend …
  due_date    date,
  done        boolean not null default false,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index tasks_user_idx on public.tasks (user_id, done, due_date);

-- ────────────────────────────────────────────────────────────
-- weekly_reviews : 주간 리뷰
-- ────────────────────────────────────────────────────────────
create table public.weekly_reviews (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  week_start    date not null,
  wins          text,
  misses        text,
  next_actions  text,
  freedom_score numeric(6,2),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (user_id, week_start)
);

-- ────────────────────────────────────────────────────────────
-- ai_reports : AI CFO 매일 자동 분석 결과
-- ────────────────────────────────────────────────────────────
create table public.ai_reports (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade,
  report_date  date not null,
  summary      text,                          -- 한줄 요약
  payload      jsonb not null default '{}',   -- 현재속도/목표달성예상일/에비추천/토지가능여부/ETF비중/숏폼재투자
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (user_id, report_date)
);

-- ────────────────────────────────────────────────────────────
-- updated_at 트리거 일괄 부착
-- ────────────────────────────────────────────────────────────
do $$
declare t text;
begin
  foreach t in array array[
    'profiles','financial_snapshots','cash_flows','airbnb_units','shorts_channels',
    'land_projects','dividend_holdings','goals','tasks','weekly_reviews','ai_reports'
  ] loop
    execute format(
      'create trigger set_updated_at before update on public.%I
       for each row execute function public.set_updated_at();', t);
  end loop;
end $$;

-- ────────────────────────────────────────────────────────────
-- RLS : 본인 데이터만 접근
-- ────────────────────────────────────────────────────────────
do $$
declare t text;
begin
  foreach t in array array[
    'profiles','financial_snapshots','cash_flows','airbnb_units','shorts_channels',
    'land_projects','dividend_holdings','goals','tasks','weekly_reviews','ai_reports'
  ] loop
    execute format('alter table public.%I enable row level security;', t);
  end loop;
end $$;

-- profiles 는 id 컬럼이 곧 소유자
create policy "own profile - select" on public.profiles for select using (auth.uid() = id);
create policy "own profile - update" on public.profiles for update using (auth.uid() = id);
create policy "own profile - insert" on public.profiles for insert with check (auth.uid() = id);

-- 나머지 테이블은 user_id 로 소유. select/insert/update/delete 정책 일괄 생성.
do $$
declare t text;
begin
  foreach t in array array[
    'financial_snapshots','cash_flows','airbnb_units','shorts_channels',
    'land_projects','dividend_holdings','goals','tasks','weekly_reviews','ai_reports'
  ] loop
    execute format('create policy "own - select" on public.%I for select using (auth.uid() = user_id);', t);
    execute format('create policy "own - insert" on public.%I for insert with check (auth.uid() = user_id);', t);
    execute format('create policy "own - update" on public.%I for update using (auth.uid() = user_id);', t);
    execute format('create policy "own - delete" on public.%I for delete using (auth.uid() = user_id);', t);
  end loop;
end $$;

-- ==== supabase/migrations/0002_custom_modules.sql ====
-- 사용자 정의 모듈 : 사용자가 직접 메뉴(모듈)와 필드를 정의하고 데이터를 관리.
-- fields 는 FieldSpec 배열(jsonb): [{ "key","label","type","required" }, ...]
--   type ∈ text | longtext | number | money | percent | date | bool

create table public.custom_modules (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  name        text not null,
  icon        text not null default 'widgets',   -- Material 아이콘 키
  color       text not null default '38BDF8',    -- hex(RRGGBB)
  fields      jsonb not null default '[]',
  sort_order  int not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index custom_modules_user_idx on public.custom_modules (user_id, sort_order);

create table public.custom_records (
  id          uuid primary key default gen_random_uuid(),
  module_id   uuid not null references public.custom_modules(id) on delete cascade,
  user_id     uuid not null references auth.users(id) on delete cascade,
  data        jsonb not null default '{}',
  sort_order  int not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index custom_records_module_idx on public.custom_records (module_id, sort_order);

create trigger set_updated_at before update on public.custom_modules
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.custom_records
  for each row execute function public.set_updated_at();

alter table public.custom_modules enable row level security;
alter table public.custom_records enable row level security;

create policy "own - select" on public.custom_modules for select using (auth.uid() = user_id);
create policy "own - insert" on public.custom_modules for insert with check (auth.uid() = user_id);
create policy "own - update" on public.custom_modules for update using (auth.uid() = user_id);
create policy "own - delete" on public.custom_modules for delete using (auth.uid() = user_id);

create policy "own - select" on public.custom_records for select using (auth.uid() = user_id);
create policy "own - insert" on public.custom_records for insert with check (auth.uid() = user_id);
create policy "own - update" on public.custom_records for update using (auth.uid() = user_id);
create policy "own - delete" on public.custom_records for delete using (auth.uid() = user_id);

-- ==== supabase/migrations/0003_freedom_target.sql ====
-- Freedom Score 기준선: 월 목표 현금흐름(기본 1,000만원).
-- Freedom Score = 월급 제외 현금흐름 / freedom_target × 100.
alter table public.profiles
  add column if not exists freedom_target numeric(14,0) not null default 10000000;

-- ==== supabase/migrations/0004_monthly_tracking.sql ====
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

-- ==== supabase/migrations/0005_dividend_market.sql ====
-- 배당 종목 시장 구분 (국장/미장)
alter table public.dividend_holdings
  add column if not exists market text not null default '미장';

-- ==== supabase/migrations/0006_pool_labels.sql ====
-- 자금 분배 풀 표시 이름 (사용자가 변경 가능)
alter table public.profiles
  add column if not exists pool_business_label text not null default '사업자금',
  add column if not exists pool_salary_label   text not null default '월급·개인자금';

-- ==== supabase/migrations/0007_dividend_fields.sql ====
-- 배당 종목: 매입금액·수량·연배당률 추가 (재투자율은 미사용)
alter table public.dividend_holdings
  add column if not exists purchase_amount numeric(14,0) not null default 0,
  add column if not exists shares          numeric(14,2) not null default 0,
  add column if not exists annual_yield    numeric(6,2)  not null default 0;

-- ==== supabase/migrations/0008_income_sources.sql ====
-- 들어오는 돈(수입원) 직접 관리 목록
create table public.income_sources (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references auth.users(id) on delete cascade,
  label          text not null,
  monthly_amount numeric(14,0) not null default 0,
  sort_order     int not null default 0,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create index income_sources_user_idx on public.income_sources (user_id, sort_order);
create trigger set_updated_at before update on public.income_sources
  for each row execute function public.set_updated_at();
alter table public.income_sources enable row level security;
create policy "own - select" on public.income_sources for select using (auth.uid() = user_id);
create policy "own - insert" on public.income_sources for insert with check (auth.uid() = user_id);
create policy "own - update" on public.income_sources for update using (auth.uid() = user_id);
create policy "own - delete" on public.income_sources for delete using (auth.uid() = user_id);
