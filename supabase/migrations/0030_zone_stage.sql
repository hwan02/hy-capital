-- ────────────────────────────────────────────────────────────
-- 구역 단계 — 물건이 어느 모아타운 단계에 있는지 판정하기 위한 값.
--
-- stage: 0=미정, 1~7 (대상지선정→관리계획→조합설립→건축심의→사업시행인가→이주/착공→준공)
-- 물건 주소를 이 구역명(동+번지)과 매칭해 단계를 보여준다.
-- ────────────────────────────────────────────────────────────
alter table public.zones
  add column if not exists stage            smallint    not null default 0,
  add column if not exists stage_source     text,
  add column if not exists stage_checked_at timestamptz;

-- 강서구 화곡동 모아타운 구역 시드 (demo 계정) — 이미 있으면 건너뜀
insert into public.zones (user_id, name, kind, district, stage, stage_source, stage_checked_at)
select 'd0d0d0d0-0000-4000-a000-000000000001', v.name, '모아타운', '강서구',
       v.stage, v.src, now()
from (values
  ('화곡1동 354번지 일대',  4::smallint, '강서구청 · 제2-2/2-4구역 시공자선정 입찰'),
  ('화곡6동 957번지 일대',  3::smallint, '강서구청 · A1구역 조합설립'),
  ('화곡1동 359번지 일대',  2::smallint, '강서구청 관리계획 고시'),
  ('화곡1동 1087번지 일대', 2::smallint, '강서구청 관리계획 고시'),
  ('화곡6동 1130-7 일대',   2::smallint, '강서구청 관리계획 고시'),
  ('화곡1동 424번지 일대',  2::smallint, '강서구청 관리계획 승인요청')
) as v(name, stage, src)
where not exists (
  select 1 from public.zones z
  where z.user_id = 'd0d0d0d0-0000-4000-a000-000000000001'
    and z.name = v.name
);
