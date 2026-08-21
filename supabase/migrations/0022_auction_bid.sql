-- ────────────────────────────────────────────────────────────
-- 경매 물건: 입찰 정보를 필드로 승격
--
-- 지금까지 입찰일·법원·감정가·보증금이 memo 안에 문장으로 들어가 있었다.
-- 입찰일은 놓치면 끝나는 값인데 D-day 계산도, 정렬도 못 했다.
--
-- deposit(입찰보증금)은 통상 최저가의 10% 지만 재매각 물건은 20~30% 라
-- 계산으로 유추하지 않고 별도 저장한다. 가용현금과 비교하는 '자금 게이트'의
-- 기준값이므로 틀리면 판정 자체가 무의미해진다.
-- ────────────────────────────────────────────────────────────
alter table public.auction_properties
  add column if not exists bid_date        timestamptz,        -- 매각기일
  add column if not exists court           text,               -- 법원·계
  add column if not exists appraisal_price numeric(16,0) not null default 0, -- 감정가
  add column if not exists deposit         numeric(16,0) not null default 0, -- 입찰보증금
  add column if not exists property_kind   text;               -- 아파트|빌라|다세대|오피스텔|기타

-- 입찰일 임박순 정렬용
create index if not exists auction_bid_date_idx
  on public.auction_properties (user_id, bid_date);

-- 이미 등록된 서초힐스: 메모에 있던 값을 필드로 옮긴다.
-- (사건번호로 특정 — 없으면 아무 것도 안 바뀐다)
update public.auction_properties
set bid_date        = coalesce(bid_date, timestamptz '2026-09-30 10:00+09'),
    court           = coalesce(court, '서울중앙지방법원'),
    property_kind   = coalesce(property_kind, '아파트'),
    deposit         = case when deposit = 0 then round(min_price * 0.1) else deposit end
where case_no = '2022타경112817';
