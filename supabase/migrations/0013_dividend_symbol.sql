-- 배당 종목에 티커 심볼(국장=6자리 코드, 미장=심볼) 컬럼 추가 — 실시간 시세/배당 조회용.
alter table public.dividend_holdings add column if not exists symbol text;
