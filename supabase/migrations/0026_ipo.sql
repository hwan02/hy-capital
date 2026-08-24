-- ────────────────────────────────────────────────────────────
-- ipo_subscriptions : 공모주 청약 기록
--
-- 대시보드·자금흐름과 연동하지 않는다. 사용자가 "그냥 체크하는 정도"라고
-- 명시했다. 총 수익금만 이 화면 안에서 보여준다.
--
-- 수익금·수익률은 «저장하지 않는다» — 앱에서 계산한다:
--   수익금 = (매도가 − 공모가) × 수량
--   수익률 = (매도가 − 공모가) ÷ 공모가 × 100      (주당 기준)
-- 실제 기록 9건으로 검산 완료(전부 일치).
--
-- invested(청약금)은 공모가 × 청약주수라서 배정수량으로는 유도할 수 없다
-- (예: 공모가 26,000 · 청약금 260,000 = 10주 청약 · 배정 1주) → 별도 입력.
-- ────────────────────────────────────────────────────────────
create table if not exists public.ipo_subscriptions (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references auth.users(id) on delete cascade,
  broker            text,                          -- 증권사
  name              text not null,                 -- 종목
  offer_price       numeric(16,0) not null default 0, -- 공모가 (주당)
  invested          numeric(16,0) not null default 0, -- 청약금(증거금)
  competition_rate  numeric(12,2) not null default 0, -- 경쟁률
  shares            integer       not null default 0, -- 배정 수량
  listing_date      date,                          -- 상장일
  sell_price        numeric(16,0) not null default 0, -- 매도가 (0 = 미매도)
  memo              text,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);
create index if not exists ipo_user_idx
  on public.ipo_subscriptions (user_id, listing_date desc);

create trigger set_updated_at before update on public.ipo_subscriptions
  for each row execute function public.set_updated_at();

alter table public.ipo_subscriptions enable row level security;
create policy "own - select" on public.ipo_subscriptions for select using (auth.uid() = user_id);
create policy "own - insert" on public.ipo_subscriptions for insert with check (auth.uid() = user_id);
create policy "own - update" on public.ipo_subscriptions for update using (auth.uid() = user_id);
create policy "own - delete" on public.ipo_subscriptions for delete using (auth.uid() = user_id);
