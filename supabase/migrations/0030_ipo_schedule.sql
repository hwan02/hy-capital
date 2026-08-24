-- ────────────────────────────────────────────────────────────
-- 공모주 청약 일정 — 「이번 주 뭐 있나」를 보려면 날짜가 필요하다.
--
-- 지금은 상장일만 있어서 이미 끝난 건만 기록할 수 있었다.
-- 앞으로 나올 건을 미리 넣어두고 청약일을 놓치지 않는 것이 목적.
--
-- 상태는 저장하지 않고 날짜로 계산한다:
--   오늘 < sub_start        → 예정
--   sub_start ≤ 오늘 ≤ sub_end → 청약중  ← 놓치면 끝
--   sub_end < 오늘 < listing → 배정·환불 대기
--   listing ≤ 오늘           → 상장
-- ────────────────────────────────────────────────────────────
alter table public.ipo_subscriptions
  add column if not exists sub_start   date,  -- 청약 시작
  add column if not exists sub_end     date,  -- 청약 마감
  add column if not exists refund_date date,  -- 환불일
  add column if not exists band_low    numeric(16,0), -- 희망공모가 하단
  add column if not exists band_high   numeric(16,0), -- 희망공모가 상단
  add column if not exists source      text;  -- 어디서 찾았나 (배치가 채운다)

create index if not exists ipo_sub_dates_idx
  on public.ipo_subscriptions (user_id, sub_start);
