-- 매각기일 알림 받기 — 물건별로 켜면 D-3·2·1 리마인더 대상이 된다.
alter table public.auction_properties
  add column if not exists alert_enabled boolean not null default false;
