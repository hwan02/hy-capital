-- ────────────────────────────────────────────────────────────
-- 권리산정기준일 — 「사면 안 되는 물건」을 가르는 날짜.
--
-- 이 날 다음날부터 분할·신축된 것은 입주권이 안 나오고 «현금청산»된다.
-- 서울도시공간포털이 구역마다 이 날짜를 준다(107곳 전부 확보).
-- 그런데 컬럼이 없어서 stage_source 문자열 안에 묻혀 있었다 —
-- 텍스트에 있으면 «비교»를 못 한다.
--
-- 물건 쪽에는 «사용승인일»을 받아 둘을 대조한다:
--   사용승인일 > 권리산정기준일  →  입주권 없음
-- ────────────────────────────────────────────────────────────
alter table public.zones
  add column if not exists rights_date date;

comment on column public.zones.rights_date is
  '권리산정기준일. 이 날 다음날부터 분할·신축된 물건은 현금청산 대상.';

alter table public.auction_properties
  add column if not exists approved_on date;

comment on column public.auction_properties.approved_on is
  '건축물대장 사용승인일. 구역 권리산정기준일보다 늦으면 입주권이 없다.';

create index if not exists zones_rights_date_idx
  on public.zones (user_id, rights_date)
  where rights_date is not null;
