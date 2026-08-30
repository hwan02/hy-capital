-- 모아타운 단타 판정용 물건 필드 (은천동 복제 6게이트).
alter table public.auction_properties add column if not exists official_price numeric;  -- 공시가(시가표준액) 원
alter table public.auction_properties add column if not exists land_share    numeric;  -- 대지지분 ㎡
alter table public.auction_properties add column if not exists project_zone   text;     -- 사업시행구역: out(미해당)|in(해당)|unknown
alter table public.auction_properties add column if not exists recent_deals   integer;  -- 최근 6~12개월 실거래 건수
alter table public.auction_properties add column if not exists listings_count integer;  -- 현재 매물 수
alter table public.auction_properties add column if not exists moa_note       text;     -- 권리산정일·입주권 승계·기타 임장 메모
