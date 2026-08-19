-- Freedom Score 기준선: 월 목표 현금흐름(기본 1,000만원).
-- Freedom Score = 월급 제외 현금흐름 / freedom_target × 100.
alter table public.profiles
  add column if not exists freedom_target numeric(14,0) not null default 10000000;
