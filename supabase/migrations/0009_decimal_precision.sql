-- 주당 값·주당 분배금은 소수점이 필요하다 (예: AGNC 월 주당 배당 $0.12).
-- 기존 numeric(_,0) 은 소수점을 버려 0 으로 저장되던 문제를 수정.

alter table public.monthly_entries
  alter column amount type numeric(18,6);

alter table public.dividend_holdings
  alter column market_value type numeric(18,6),
  alter column purchase_amount type numeric(18,6);
