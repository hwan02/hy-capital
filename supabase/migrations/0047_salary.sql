-- ────────────────────────────────────────────────────────────
-- 월급 — 들어온 돈을 «매달 어디에 쓸지» 미리 나눠두고, 실제로 얼마
-- 썼는지를 항목마다 채워 넣는다.
--
--   월급(net)  −  고정비 계획 합계  =  남는 돈
--   고정비 항목마다   쓴 돈 / 배정액   진행바
--
-- 자금 흐름(flow_entries)은 «일어난 거래»의 장부다. 여기는 «계획»이라
-- 테이블을 나눈다. 같은 표에 섞으면 계획과 실적이 구분되지 않는다.
--
-- 이 화면은 PIN 으로 잠근다. RLS 가 이미 남의 계정을 막지만, 잠금은
-- 다른 문제를 막는다 — 로그인된 화면을 «옆에서 보는 것».
-- ────────────────────────────────────────────────────────────

-- ── 월별 월급 ────────────────────────────────────────────────
create table if not exists public.salary_months (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,

  month       date not null,                    -- 해당 월 1일
  net         numeric not null default 0,       -- 실수령액 — 화면에서 쓰는 값
  gross       numeric,                          -- 세전 (알면 적는다)
  paid_on     date,                             -- 실제 들어온 날
  memo        text,

  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (user_id, month)
);

-- ── 고정비 항목 (매달 반복되는 정의) ──────────────────────────
create table if not exists public.budget_items (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,

  name        text not null,                    -- 월세 · 통신비 · 보험 · 적금 …
  category    text not null default '고정비',    -- 고정비 | 할부 | 저축·투자 | 생활비
  amount      numeric not null default 0,       -- 매달 배정액(계획)
  pay_day     int,                              -- 며칠에 나가나 (1~31)
  sort_order  int not null default 0,
  active      boolean not null default true,    -- 끄면 이번 달부터 제외
  memo        text,

  -- ── 할부 ────────────────────────────────────────────────
  -- 할부는 «끝나는 날이 있는» 고정비다. 표를 나누지 않고 이 두 칸으로
  -- 구분한다: months 가 있으면 할부, 없으면 계속 나가는 고정비.
  --   끝나는 달 = start_month + (months - 1)개월
  --   남은 회차 = months − 지난 회차
  -- 시작 전·끝난 뒤 달에는 그 달 배정 합계에서 자동으로 빠진다.
  start_month date,                             -- 첫 회차 달 (해당 월 1일)
  months      int,                              -- 총 회차. null = 무기한
  total       numeric,                          -- 총액(원금+이자). 알면 적는다

  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists budget_items_user_idx
  on public.budget_items (user_id, active, sort_order);

-- ── 월별 실제 사용액 ─────────────────────────────────────────
-- 항목 × 월 로 한 칸. 안 적은 달은 행이 없다(0 으로 본다).
create table if not exists public.budget_spends (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  item_id     uuid not null references public.budget_items(id) on delete cascade,

  month       date not null,                    -- 해당 월 1일
  spent       numeric not null default 0,
  memo        text,

  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (user_id, item_id, month)
);

create index if not exists budget_spends_month_idx
  on public.budget_spends (user_id, month);

-- ── 화면 잠금 ────────────────────────────────────────────────
-- PIN 원문은 저장하지 않는다. sha256(salt + pin) 만 둔다.
-- 브라우저에서 대조하므로 «암호화»가 아니라 «잠금»이다 —
-- 계정에 로그인한 사람이 DB 를 직접 열면 잠금은 의미가 없다.
-- 막으려는 건 옆에서 화면을 보는 것이다.
create table if not exists public.salary_lock (
  user_id     uuid primary key references auth.users(id) on delete cascade,
  pin_hash    text,
  salt        text,
  updated_at  timestamptz not null default now()
);

-- ── 트리거 ───────────────────────────────────────────────────
create trigger set_updated_at before update on public.salary_months
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.budget_items
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.budget_spends
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.salary_lock
  for each row execute function public.set_updated_at();

-- ── RLS ──────────────────────────────────────────────────────
alter table public.salary_months enable row level security;
create policy "own - select" on public.salary_months for select using (auth.uid() = user_id);
create policy "own - insert" on public.salary_months for insert with check (auth.uid() = user_id);
create policy "own - update" on public.salary_months for update using (auth.uid() = user_id);
create policy "own - delete" on public.salary_months for delete using (auth.uid() = user_id);

alter table public.budget_items enable row level security;
create policy "own - select" on public.budget_items for select using (auth.uid() = user_id);
create policy "own - insert" on public.budget_items for insert with check (auth.uid() = user_id);
create policy "own - update" on public.budget_items for update using (auth.uid() = user_id);
create policy "own - delete" on public.budget_items for delete using (auth.uid() = user_id);

alter table public.budget_spends enable row level security;
create policy "own - select" on public.budget_spends for select using (auth.uid() = user_id);
create policy "own - insert" on public.budget_spends for insert with check (auth.uid() = user_id);
create policy "own - update" on public.budget_spends for update using (auth.uid() = user_id);
create policy "own - delete" on public.budget_spends for delete using (auth.uid() = user_id);

alter table public.salary_lock enable row level security;
create policy "own - select" on public.salary_lock for select using (auth.uid() = user_id);
create policy "own - insert" on public.salary_lock for insert with check (auth.uid() = user_id);
create policy "own - update" on public.salary_lock for update using (auth.uid() = user_id);
create policy "own - delete" on public.salary_lock for delete using (auth.uid() = user_id);
