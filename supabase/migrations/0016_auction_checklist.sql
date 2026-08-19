-- 경매 물건에 '입찰 전 체크리스트' 저장 (온라인/오프라인/권리/최종점검 → JSONB).
alter table public.auction_properties
  add column if not exists checklist jsonb not null default '{}'::jsonb;
