-- 배당 종목 시장 구분 (국장/미장)
alter table public.dividend_holdings
  add column if not exists market text not null default '미장';
