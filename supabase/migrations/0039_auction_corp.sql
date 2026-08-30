-- 물건별 «법인 취득세 가능여부» 태그.
--   ok    = 수도권 공시가(시가표준액) 1억 이하 + 정비/사업시행구역 중과제외 예외에 안 걸림 → 법인도 기본세율(~1.1%)
--   heavy = 중과 대상(공시가 1억 초과 또는 사업시행구역 등) → 법인 취득세 12% 구간
--   check = 확인 필요(사업시행구역 지정 여부 등 물건별 확인 전)
--   null  = 미판정
alter table public.auction_properties add column if not exists corp_status text;
