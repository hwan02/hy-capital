-- 목록에서 제외 — 삭제하지 않고 기본 목록에서만 숨긴다(정보는 보존).
alter table public.auction_properties
  add column if not exists excluded boolean not null default false;
