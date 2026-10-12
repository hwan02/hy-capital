-- 에어비앤비 호점별 «월세» — 매월 10일 고정비로 자동 기록한다.
--
-- 월세는 매달 같은 날 같은 금액이 나가는데 손으로 넣다 보니 빠지는 달이
-- 생겼다. 호점에 월세를 적어 두면 매일 아침 배치(scripts/airbnb_rent.py)가
-- 그 달 10일 이후 «월세 (자동)» 고정비 거래를 한 번 만든다.
-- 그 달에 메모에 «월세»가 들어간 거래가 이미 있으면(손으로 넣은 것 포함)
-- 만들지 않는다 — 두 번 빠지지 않게.

alter table public.airbnb_units
  add column if not exists monthly_rent numeric(12,0) not null default 0;

-- 실행 기록 (0053 이 만든 표).
insert into public.hy_migrations (name) values ('0060_airbnb_rent')
  on conflict (name) do nothing;
