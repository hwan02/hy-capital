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
