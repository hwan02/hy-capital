-- ────────────────────────────────────────────────────────────
-- 경매 진행 — 물건 하나를 「찾기 → 권리분석 → 임장 → 입찰 →
-- 낙찰·잔금 → 명도」 순서로 끌고 가기 위한 일정 칼럼.
--
-- status 는 이미 있다 (interest|researching|visited|bidding|won|sold|pass).
-- 여기에 «evicting»(명도 중)을 하나 더 쓴다 — text 라 제약 변경 불필요.
--
-- 단계별 할 일 체크는 기존 checklist jsonb 에 그대로 넣는다.
-- 새 테이블을 만들지 않는다 — 물건 하나가 진실의 원천이다.
-- ────────────────────────────────────────────────────────────
alter table public.auction_properties
  add column if not exists won_date      date,  -- 낙찰일 (잔금 기한 기산점)
  add column if not exists balance_due   date,  -- 잔금 납부 기한 (법원 지정)
  add column if not exists evict_due     date,  -- 명도 목표일 / 합의 이사일
  add column if not exists sold_date     date;  -- 매도·전세 세팅 완료일

comment on column public.auction_properties.balance_due is
  '잔금 납부 기한. 넘기면 입찰보증금을 몰수당한다 — 제일 무서운 날짜.';

-- 기한이 다가오는 물건을 뽑을 때 쓴다 (슬랙 알림·진행 화면).
create index if not exists auction_balance_due_idx
  on public.auction_properties (user_id, balance_due)
  where balance_due is not null;

create index if not exists auction_evict_due_idx
  on public.auction_properties (user_id, evict_due)
  where evict_due is not null;
