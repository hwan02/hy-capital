-- 로드맵 배분 항목에 '월 계획(매달 넣을 금액)' 추가.
-- 예: 에비2호자금 → 목표(amount) 3,350만 + 월 계획(monthly_amount) 450만.
alter table public.plan_allocations
  add column if not exists monthly_amount numeric(18,2);
