-- ════════════════════════════════════════════════════════════
-- HY CAPITAL 로컬 개발용 시드 데이터
-- 데모 계정:  demo@hycapital.app  /  CHANGE_ME_PASSWORD
-- ════════════════════════════════════════════════════════════

-- 데모 사용자 (고정 UUID)
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at,
  raw_app_meta_data, raw_user_meta_data, is_sso_user, is_anonymous,
  -- GoTrue 는 아래 토큰 컬럼이 NULL 이면 "Database error querying schema" 를 냄 → 빈 문자열로 채움
  confirmation_token, recovery_token, email_change,
  email_change_token_new, email_change_token_current,
  phone_change, phone_change_token, reauthentication_token
) values (
  '00000000-0000-0000-0000-000000000000',
  'd0d0d0d0-0000-4000-a000-000000000001',
  'authenticated', 'authenticated',
  'demo@hycapital.app',
  crypt('CHANGE_ME_PASSWORD', gen_salt('bf')),
  now(), now(), now(),
  '{"provider":"email","providers":["email"]}',
  '{"display_name":"데모 대표"}',
  false, false,
  '', '', '', '', '', '', '', ''
) on conflict (id) do nothing;

-- 이메일 로그인용 identity (GoTrue 요구)
insert into auth.identities (
  provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at
) values (
  'demo@hycapital.app',
  'd0d0d0d0-0000-4000-a000-000000000001',
  '{"sub":"d0d0d0d0-0000-4000-a000-000000000001","email":"demo@hycapital.app"}',
  'email', now(), now(), now()
) on conflict (provider_id, provider) do nothing;

-- 트리거로 profiles 가 생성되지만, 기준선 값 갱신
update public.profiles
   set display_name = '데모 대표',
       monthly_expenses = 3500000,
       net_worth_goal   = 1500000000,
       freedom_target   = 10000000
 where id = 'd0d0d0d0-0000-4000-a000-000000000001';

-- 혹시 트리거 미동작 시 대비
insert into public.profiles (id, display_name, monthly_expenses, net_worth_goal)
values ('d0d0d0d0-0000-4000-a000-000000000001', '데모 대표', 3500000, 1500000000)
on conflict (id) do nothing;

do $$
declare uid uuid := 'd0d0d0d0-0000-4000-a000-000000000001';
begin
  -- ── 재무 스냅샷 (최근 6개월) ────────────────────────────────
  insert into public.financial_snapshots (user_id, as_of, net_worth, cash, non_salary_cashflow, salary_cashflow) values
    (uid, date_trunc('month', now())::date - interval '5 month', 620000000, 45000000, 3200000, 4500000),
    (uid, date_trunc('month', now())::date - interval '4 month', 655000000, 52000000, 3900000, 4500000),
    (uid, date_trunc('month', now())::date - interval '3 month', 690000000, 48000000, 4600000, 4500000),
    (uid, date_trunc('month', now())::date - interval '2 month', 742000000, 61000000, 5300000, 4500000),
    (uid, date_trunc('month', now())::date - interval '1 month', 795000000, 58000000, 6100000, 4500000),
    (uid, date_trunc('month', now())::date,                      842000000, 67000000, 6800000, 4500000);

  -- ── 머니플로우 ────────────────────────────────────────────
  insert into public.cash_flows (user_id, occurred_on, source, target, amount, is_salary, memo) values
    (uid, now()::date, '월급',   '생활비',   3500000, true,  '고정 생활비'),
    (uid, now()::date, '월급',   '재투자',   1000000, true,  'ETF 적립'),
    (uid, now()::date, '사업수익','사업확장', 4200000, false, '에비/숏폼 재투자'),
    (uid, now()::date, '배당',   '재투자',    850000, false, '배당 재투자'),
    (uid, now()::date, '숏폼',   '에비확장',  1800000, false, '숏폼 수익 → 에비2'),
    (uid, now()::date, '토지매도','에비확장', 0,        false, '매도 대기');

  -- ── 에어비앤비 ────────────────────────────────────────────
  insert into public.airbnb_units (user_id, name, status, reserve_fund, target_fund, expected_open, monthly_profit, roi, occupancy, sort_order) values
    (uid, '에비1 · 강릉', 'open',      0,        60000000, now()::date - interval '8 month', 3100000, 62.0, 84.0, 1),
    (uid, '에비2 · 속초', 'preparing', 38000000, 55000000, now()::date + interval '2 month', 0,       0.0,  0.0,  2),
    (uid, '에비3 · 제주', 'planning',  8000000,  70000000, now()::date + interval '7 month', 0,       0.0,  0.0,  3);

  -- ── 숏폼 ──────────────────────────────────────────────────
  insert into public.shorts_channels (user_id, name, platform, uploads, views, rpm, revenue, net_profit, roi, reinvest_ratio) values
    (uid, '자유의사업가', 'YouTube',   142, 8600000, 320.0, 2752000, 1900000, 145.0, 60.0),
    (uid, '머니루틴',     'TikTok',    98,  4200000, 90.0,  378000,  260000,  70.0,  40.0);

  -- ── 토지 ──────────────────────────────────────────────────
  insert into public.land_projects (user_id, name, analysis, catalyst, principal, target_price, expert_opinion, status) values
    (uid, '평택 고덕 인근', '삼성 반도체 배후 수요, 도로 개통 예정', 'GTX 연장 · 산단 확장', 180000000, 320000000, '3년 내 2배 가능성, 보유 추천', 'holding'),
    (uid, '새만금 인접지',  '개발 초기, 변동성 큼',               '국가산단 · 관광 개발',   90000000,  200000000, '장기 관점 접근 필요',       'reviewing');

  -- ── 배당 ──────────────────────────────────────────────────
  insert into public.dividend_holdings (user_id, ticker, market_value, monthly_dividend, annual_dividend, reinvest_rate) values
    (uid, 'SCHD',  42000000, 145000, 1740000, 100.0),
    (uid, 'JEPI',  28000000, 210000, 2520000, 80.0),
    (uid, 'O',     15000000, 78000,  936000,  100.0),
    (uid, '삼성전자우', 22000000, 61000, 732000, 50.0);

  -- ── 목표 ──────────────────────────────────────────────────
  insert into public.goals (user_id, title, target_value, current_value, unit, target_date, status, sort_order) values
    (uid, '월급 제외 월 현금흐름 1,000만원', 10000000, 6800000,   'KRW',   now()::date + interval '14 month', 'active', 1),
    (uid, '에비 2호점 오픈',                 1,        0,         'count', now()::date + interval '2 month',  'active', 2),
    (uid, '에비 3호점 오픈',                 1,        0,         'count', now()::date + interval '9 month',  'active', 3),
    (uid, '방배 아파트 매수',                1,        0,         'count', now()::date + interval '30 month', 'active', 4),
    (uid, '순자산 15억',                     1500000000, 842000000, 'KRW', now()::date + interval '36 month', 'active', 5);

  -- ── 오늘 할 일 ────────────────────────────────────────────
  insert into public.tasks (user_id, title, module, due_date, done) values
    (uid, '에비2 인테리어 견적 3곳 비교', 'airbnb',   now()::date, false),
    (uid, '숏폼 이번주 5개 업로드 확인',  'shorts',   now()::date, false),
    (uid, '평택 토지 등기 서류 검토',     'land',     now()::date, false),
    (uid, 'SCHD 추가 매수 100만원',       'dividend', now()::date, true);

  -- ── 주간 리뷰 ────────────────────────────────────────────
  insert into public.weekly_reviews (user_id, week_start, wins, misses, next_actions, freedom_score) values
    (uid, date_trunc('week', now())::date, '숏폼 매출 최고치 · 에비2 준비금 38M 달성', '토지 매도 지연', '에비2 오픈 일정 확정, 배당 재투자 자동화', 194.0);

  -- ── AI CFO 리포트 ────────────────────────────────────────
  insert into public.ai_reports (user_id, report_date, summary, payload) values
    (uid, now()::date,
     '자유까지 순항 중 — 현재 속도라면 14개월 내 월 1,000만 현금흐름 달성 예상',
     jsonb_build_object(
       'current_pace', '월 현금흐름 +11% MoM',
       'goal_eta',     (now()::date + interval '14 month')::text,
       'airbnb_reco',  '에비2 준비금 우선 충당(잔여 17M) 후 에비3는 6개월 뒤 착수',
       'land_ok',      false,
       'land_reason',  '토지는 유동성 잠김 — 에비2 오픈 전까지 신규 진입 보류',
       'etf_rebalance','SCHD 비중 45%→50%, JEPI 30% 유지',
       'shorts_reinvest', '순이익의 55% 재투자 권장(현 60% → 소폭 완화)'
     ));
end $$;
