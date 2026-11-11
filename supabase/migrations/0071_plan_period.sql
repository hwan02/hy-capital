-- 계획에 «어느 주·달의 계획인가» 칸.
--
-- 1주 계획은 한 번이 아니라 매주(1주차·2주차 … 10년치), 1개월 계획은 매달 있어야 한다.
-- period_start 는 그 기간 안의 아무 날 — 앱이 이 날짜가 든 칸(몇 주차·몇 개월차)에 둔다.
-- 기한(due_date)과 따로 둔다: 기한은 «언제까지», period_start 는 «어느 칸의 계획».

alter table public.plan_items add column if not exists period_start date;

insert into public.hy_migrations (name) values ('0071_plan_period')
  on conflict (name) do nothing;
