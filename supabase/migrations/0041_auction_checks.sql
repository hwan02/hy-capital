-- 물건별 손품·발품 체크리스트 상태(체크박스 key→bool).
alter table public.auction_properties add column if not exists checks jsonb default '{}'::jsonb;
