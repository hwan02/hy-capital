-- 임장 «갈 곳» 표시.
--
-- 구역이 139곳이라 화면에서 훑는 것만으로는 「어디 갈지」가 안 남는다.
-- 모아타운·신통을 보다가 눈에 걸린 구역을 그 자리에서 찍어두고,
-- 「임장예정」 탭에서 그 목록만 모아 본다.
alter table public.zones
  add column if not exists visit_plan boolean not null default false;

-- 언제 가기로 했나 / 뭘 보러 가나. 없어도 되지만 있으면 동선이 잡힌다.
alter table public.zones
  add column if not exists visit_on date;
alter table public.zones
  add column if not exists visit_memo text;

create index if not exists zones_visit_plan_idx
  on public.zones (user_id, visit_plan)
  where visit_plan;
