-- 낙찰·명도가 끝이 아니다. 수리 → 출구(매도·전세) → 정산까지 간다.
-- 그 사이 대출이자가 매달 나가므로 «비어 있는 날이 곧 비용»이다.
-- 그래서 수리·출구에도 목표일을 둔다.
alter table public.auction_properties
  add column if not exists repair_due date,  -- 수리 완료 목표일
  add column if not exists exit_due   date;  -- 매도·전세 세팅 목표일

comment on column public.auction_properties.exit_due is
  '출구 목표일. 늦어질수록 대출이자만큼 수익이 깎인다.';

create index if not exists auction_repair_due_idx
  on public.auction_properties (user_id, repair_due)
  where repair_due is not null;

create index if not exists auction_exit_due_idx
  on public.auction_properties (user_id, exit_due)
  where exit_due is not null;
