-- 배당 종목: 매입금액·수량·연배당률 추가 (재투자율은 미사용)
alter table public.dividend_holdings
  add column if not exists purchase_amount numeric(14,0) not null default 0,
  add column if not exists shares          numeric(14,2) not null default 0,
  add column if not exists annual_yield    numeric(6,2)  not null default 0;
