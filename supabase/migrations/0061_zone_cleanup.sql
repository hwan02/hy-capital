-- ────────────────────────────────────────────────────────────
-- 0061 · 구역 정리 — 이름에 번지 붙이기 · 해제된 구역 삭제
--
-- 0060 이 「포털 대상지에 없는 구역」 25곳을 띄웠는데, 그중 넷은
-- «앱 구역명에 번지가 없어서» 대조 자체가 안 되는 것이었다.
-- 포털에서 실제 구역을 찾아 이름을 맞춘다.
--
--   중랑구 묵2동 일대      → 묵2동 243-7      (포털 63,449㎡ · 관리지역고시)
--   중랑구 신내1동 일대    → 신내1동 493-13   (포털 37,152㎡ · 관리지역고시)
--
-- 나머지 둘은 «확정하지 않는다» — 추측으로 고치면 또 틀린 걸 띄운다:
--   중랑구 면목동 4·6구역  — 세부구역 이름으로 보인다. 정비몽땅에 「면목역4구역」
--     (면목동 99-41) · 「면목역6구역」(면목동 86-19) 조합이 있는데, 어느
--     모아타운 구역 «안»인지는 공개 자료로 확정이 안 된다.
--   성동구 사근동 190-2 일원 — 성동구 모아타운은 마장동 457 · 금호동1가 129 ·
--     응봉동 265 «셋»뿐이고 사근동은 없다. 사근동에 있는 건 «신통기획»
--     「사근동 293번지 일대 주택정비형 재개발」(기획완료)인데 번지가 다르다.
--   → 둘 다 메모에 확인 요청만 남긴다.
--
-- 【삭제 — 광진구 자양2동 681】
-- 2026.07.16 «대상지 해제». 그런데 서울시 표(2026-09-08)에는 두 달 뒤까지
-- 「관리계획 수립 중」으로 남아 있었고, 그걸 믿고 매수 A 후보로 올렸다.
-- 해제가 확인됐으므로 지운다. 교훈은 코드와 자료실에 남아 있다 —
--   lib/features/auction/buy_band.dart (kDropRiskNote 의 해제 사례)
--   knowledge/2026-09-05_구역축소_지정전.json
-- 물건·단지가 걸려 있어도 zone_id 는 on delete set null 이라 안 지워진다.
-- ────────────────────────────────────────────────────────────

-- ── ① 지우기 전에 «뭐가 걸려 있는지» 본다 ─────────────────
select z.name                                       as 지울_구역,
       (select count(*) from public.complexes c where c.zone_id = z.id) as 단지수,
       z.memo
from public.zones z
where z.kind = '모아타운'
  and public.hy_zone_key(z.name) = '자양동 681';

-- ── ② 이름에 번지 붙이기 ────────────────────────────────
update public.zones
set name = '묵2동 243-7번지 일대',
    memo = btrim(coalesce(memo, '') || E'\n' ||
      '구역명에 번지가 없어 포털 대조가 안 됐다 → 「묵2동 243-7」로 맞춤 '
      '(포털 63,449㎡ · 관리지역고시, 2026-10-05).')
where kind = '모아타운' and district = '중랑구'
  and name like '%묵2동%' and name not like '%243-7%';

update public.zones
set name = '신내1동 493-13번지 일대',
    memo = btrim(coalesce(memo, '') || E'\n' ||
      '구역명에 번지가 없어 포털 대조가 안 됐다 → 「신내1동 493-13」으로 맞춤 '
      '(포털 37,152㎡ · 관리지역고시, 2026-10-05).')
where kind = '모아타운' and district = '중랑구'
  and name like '%신내1동%' and name not like '%493-13%';

-- ── ③ 확정 못 한 둘 — 메모만 남긴다 ─────────────────────
update public.zones
set memo = btrim(coalesce(memo, '') || E'\n' ||
      '⚠ 포털 모아타운 대상지에서 못 찾았다. 「면목역4구역(면목동 99-41)」 '
      '「면목역6구역(면목동 86-19)」 조합이 정비몽땅에 있으나 어느 모아타운 '
      '구역 안인지 확정 불가 — 중랑구청 주택과에 확인 필요. (2026-10-05)')
where kind = '모아타운' and district = '중랑구'
  and name like '%4·6구역%'
  and coalesce(memo, '') not like '%면목역4구역%';

update public.zones
set memo = btrim(coalesce(memo, '') || E'\n' ||
      '⚠ 성동구 모아타운은 마장동 457 · 금호동1가 129 · 응봉동 265 셋뿐이고 '
      '사근동은 없다. 사근동에 있는 건 «신통기획» 「사근동 293번지 일대」'
      '(기획완료)인데 번지가 다르다 — 종류·번지 확인 필요. (2026-10-05)')
where kind = '모아타운' and district = '성동구'
  and name like '%사근동%'
  and coalesce(memo, '') not like '%신통기획%';

-- ── ④ 해제 확인된 구역 삭제 ─────────────────────────────
delete from public.zones
where kind = '모아타운'
  and public.hy_zone_key(name) = '자양동 681';

-- ── ⑤ 확인 ──────────────────────────────────────────────
select name as 구역, district as 자치구, stage as 단계, portal_listed as 포털등재
from public.zones
where kind = '모아타운'
  and (name like '%묵2동%' or name like '%신내1동%'
       or name like '%4·6구역%' or name like '%사근동%'
       or public.hy_zone_key(name) = '자양동 681')
order by district, name;
