-- 로드맵 배분 항목에 '이미 가진 돈(현재 보유액)' 추가.
-- 현재(누적) = held_amount(이미 가진 돈) + 지금까지 쌓인 나가는 돈 거래 합계.
-- 예: 에비 2호 자금 → 목표 3,350만 · 보유 1,000만 · 이번 달 적립 450만.
alter table public.plan_allocations
  add column if not exists held_amount numeric(18,2);
