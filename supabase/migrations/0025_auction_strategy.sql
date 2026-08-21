-- ────────────────────────────────────────────────────────────
-- 경매 전략 유형 — 물건마다 셈이 다르다
--
-- flip (아파트 차익): 낙찰 → 수리 → 매도. 핵심 지표는 ROI.
--   필요현금 = 낙찰가 − 대출 + 부대비용
--
-- plus (모아·신속 빌라 플피): 낙찰 → 전세로 회수 → 조합설립 프리미엄 → 매매.
--   자료실 `2026-08-20_행크특강_모아신속경매전략` 의 확정 전략.
--   핵심 지표는 ROI 가 아니라 «실투자금» 이다.
--   실투자금 = 낙찰가 + 취득·등기 + 수리 + 명도 + 기타 − 전세보증금
--   음수면 플피(돈이 남는다). 전세가 ≥ 낙찰가 가 이 전략의 성립 조건.
--
-- 전세를 놓으면 경락잔금대출은 통상 같이 쓰지 못하므로(선순위 문제)
-- plus 계산에서는 대출을 빼지 않는다.
-- ────────────────────────────────────────────────────────────
alter table public.auction_properties
  add column if not exists strategy      text not null default 'flip', -- flip|plus
  add column if not exists jeonse_price  numeric(16,0) not null default 0, -- 전세 시세
  add column if not exists district_type text; -- 모아타운|신통기획|없음

-- 서초힐스는 아파트 차익형(그대로 flip).
update public.auction_properties
set strategy = 'flip'
where property_kind = '아파트' and strategy is null;
