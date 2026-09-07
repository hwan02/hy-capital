-- 0049_zone_subs.sql
-- 모아타운 한 구역은 «세부구역»(A2-1, A3-1 …)으로 쪼개져 각각 단계가 다르다.
-- 타깃은 «조합설립 진행 중»(인가 전 = 승계 가능), 인가완료·사업시행은 제외.
-- subs = [{ "code":"A3-1", "status":"조합설립 진행 중", "rating":"4" }, ...]

alter table public.zones
  add column if not exists subs jsonb not null default '[]'::jsonb;
