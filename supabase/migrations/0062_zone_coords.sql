-- 구역 «좌표» — 행크옥션 부동산지도를 그 구역 위치로 바로 연다.
--
-- 행크옥션 경매검색은 주소로 조건을 못 받지만, 부동산지도는
--   /search/map?lat=…&lng=…&isActiveAuction=true&isActiveOnbid=true&type=연립/다세대
-- 로 열면 지도가 그 위치로 가고 시/구/동까지 채운다(2026-10-12 확인).
-- 구역에는 좌표가 없어서, 매일 배치(scripts/geocode_zones.py)가 카카오
-- 주소검색으로 «대표 지번 → 좌표»를 한 번 채운다.

alter table public.zones
  add column if not exists lat double precision,
  add column if not exists lng double precision,
  -- 무엇으로 찾았나(«신림동 610-220») — 엉뚱한 곳이 찍혔을 때 원인을 본다.
  add column if not exists geo_query text;

-- 실행 기록 (0053 이 만든 표).
insert into public.hy_migrations (name) values ('0062_zone_coords')
  on conflict (name) do nothing;
