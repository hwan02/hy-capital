-- ────────────────────────────────────────────────────────────
-- 단지에도 자치구 — 구역에 속하지 않는 단지(급매로 만난 곳 등)도
-- 지역을 알아야 지역별로 묶어 볼 수 있다.
-- 구역이 있으면 구역의 자치구를 쓰고, 없으면 이 값을 쓴다.
-- ────────────────────────────────────────────────────────────
alter table public.complexes
  add column if not exists district text;

-- 이미 구역에 연결된 단지는 구역의 자치구를 물려받는다.
update public.complexes c
set district = z.district
from public.zones z
where c.zone_id = z.id and c.district is null and z.district is not null;
