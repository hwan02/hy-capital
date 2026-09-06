-- 0046_zone_loc_checks.sql
-- 구역 «입지 우선» 체크리스트 — 매수 밴드(단계)보다 입지가 먼저다.
-- 항목별 체크 상태를 jsonb 로 저장(예: {"station":true,"scale":true,...}).

alter table public.zones
  add column if not exists loc_checks jsonb not null default '{}'::jsonb;
