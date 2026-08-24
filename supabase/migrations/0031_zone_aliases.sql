-- ────────────────────────────────────────────────────────────
-- 구역 포함 번지(aliases) — 구역명 번지(대표) 외에 실제로 그 구역에 속하는
-- 다른 번지들. 물건 주소가 이 목록의 번지를 포함하면 해당 구역으로 인식한다.
-- 예: '화곡1동 1087번지 일대' 모아타운에 1072-13 물건이 포함됨.
-- ────────────────────────────────────────────────────────────
alter table public.zones
  add column if not exists aliases text[] not null default '{}';

-- 화곡1동 1087 모아타운(A1구역)에 1072 편입 (demo 계정)
update public.zones z
set aliases = (
  select array(select distinct e
               from unnest(z.aliases || array['1072']) as e
               where e <> '')
)
where z.user_id = 'd0d0d0d0-0000-4000-a000-000000000001'
  and z.name = '화곡1동 1087번지 일대';
