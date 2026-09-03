-- 이 단계에 «언제» 들어갔는가.
--
-- 「기획 완료 = 매수 A」로 133곳을 다 띄우면 오해한다. 성수전략정비지구는
-- 기획 완료가 «2021년 3월»이다 — 66개월째 그 자리다. 공평15,16지구는 85개월.
-- 단계만 보면 다 같은 매수 A 인데, 실제로는 멈춘 구역과 굴러가는 구역이 섞여 있다.
--
-- 동의율(consent_rate)이 있으면 제일 좋지만 «공개 데이터가 아니다» —
-- 서울도시공간포털에도, 주민공람 공고문 169건 본문에도 숫자가 없다.
-- 추진일은 포털이 주므로, 이걸로 «정체»를 대신 읽는다.
alter table public.zones
  add column if not exists propel_dt date;

comment on column public.zones.propel_dt is
  '현재 추진단계에 들어간 날. 오래됐으면 사업이 멈춰 있다는 뜻.';

create index if not exists zones_propel_dt_idx
  on public.zones (user_id, propel_dt)
  where propel_dt is not null;
