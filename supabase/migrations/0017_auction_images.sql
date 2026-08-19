-- 경매 물건 스크린샷(base64 data URL 배열) 저장.
alter table public.auction_properties
  add column if not exists images jsonb not null default '[]'::jsonb;
