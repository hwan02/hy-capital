-- ────────────────────────────────────────────────────────────
-- 모의투자 트레이닝 로그
--
-- 실제로 하기 전에 '모의'로 입찰가를 부르고, 나중에 실제 낙찰가를 적어
-- 내 판단이 맞았는지 회고한다. 이 데이터를 쌓아 감각을 키우는 게 목적.
--
-- mode        : sim(모의) | real(실제)
-- reason      : 입찰가/물건 선택의 판단 근거 (왜 그렇게 생각했나)
-- actual_price: 실제 낙찰가 (경매 결과)
-- review      : 원인분석 — 내 입찰가 vs 낙찰가, 왜 그런 결과였나
-- ────────────────────────────────────────────────────────────
alter table public.auction_properties
  add column if not exists mode         text not null default 'sim',
  add column if not exists actual_price numeric(16,0) not null default 0,
  add column if not exists reason       text,
  add column if not exists review       text;
