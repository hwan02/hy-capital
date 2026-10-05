-- ────────────────────────────────────────────────────────────
-- 0060 · 「서울시 표에만 있고 포털 대상지에는 없는 구역」을 표시한다
--
-- 【왜】
-- 자양2동 681 을 매수 후보로 올렸는데 «2026.07.16 대상지 해제»된 곳이었다.
-- 그 사실은 이 저장소 안에 이미 두 군데 적혀 있었다 —
--   lib/features/auction/buy_band.dart (해제 사례 경고문)
--   knowledge/2026-09-05_구역축소_지정전.json
-- 그런데도 올렸다. 서울시 「모아타운 추진현황」 표(2026-09-08)가 해제된
-- 구역을 «두 달이 지나도록 그대로 싣고 있었고», 그 표를 그대로 믿었다.
--
-- 【더 큰 잘못 — 검증 안 한 가정】
-- 표 133행 중 포털에 없는 22곳을 「포털이 주민제안을 거의 안 준다」고
-- 단정하고 넘겼다. 세어보니 «틀렸다» — 포털은 주민제안 44곳 중 23곳을 준다.
-- 즉 포털에 없다는 건 「포털이 빠뜨린 것」이 아니라 «대상지가 아닐 수 있다»는
-- 신호였다. 그 22곳 안에 해제된 자양2동 681 과 지번이 의심스러운
-- 미아동 791-1134 가 들어 있었다.
--
-- 【그래서 기록을 남긴다】
-- 포털 동기화(sync_moa_zones.py)가 돌 때마다 구역이 «포털 대상지 목록에
-- 있는지»를 적는다. 없으면 화면에 「포털 미등재」로 뜨고, 매수 판정에서
-- 보류로 뺀다. 지우지는 않는다 — 포털이 늦게 올리는 경우도 있어서
-- 「없다」가 곧 「해제」는 아니다. 확인은 구청 전화로 한다.
-- ────────────────────────────────────────────────────────────

alter table public.zones
  add column if not exists portal_listed     boolean,
  add column if not exists portal_checked_at timestamptz;

comment on column public.zones.portal_listed is
  '서울도시공간포털 «대상지 목록»에 이 구역이 있나. false 면 해제·오기 의심 — '
  '지우지 말고 구청에 확인한다. null 은 아직 대조 안 함.';
comment on column public.zones.portal_checked_at is
  '마지막으로 포털 목록과 대조한 시각.';

create index if not exists zones_portal_missing_idx
  on public.zones (user_id)
  where portal_listed is false;
