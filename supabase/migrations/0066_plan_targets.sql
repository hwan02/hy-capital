-- 계획에 «숫자 목표»를 붙인다 — 순자산 · 법인 현금흐름 · 개인 현금흐름.
--
-- 같은 plan_items 표에 칸 두 개만 더한다.
--   metric: 순자산 · 법인 현금흐름 · 개인 현금흐름 (없으면 그냥 할 일)
--   target: 목표 금액(원). 현금흐름은 «한 달에».
-- target 이 있는 줄 = 그 기간의 숫자 목표(track 은 «목표»).
-- target 없이 metric 만 있는 줄 = 그 목표를 위한 할 일 — 화면에서 목표 아래에 붙는다.
-- 비전 줄에 metric 이 있으면 10년 숫자 목표들을 그 비전의 «서브»로 보여 준다.
-- 내용은 앱에서 채운다(공개 저장소라 여기 넣지 않는다).

alter table public.plan_items add column if not exists metric text;
alter table public.plan_items add column if not exists target numeric;

-- 실행 기록 (0053 이 만든 표).
insert into public.hy_migrations (name) values ('0066_plan_targets')
  on conflict (name) do nothing;
