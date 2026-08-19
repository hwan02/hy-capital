-- ────────────────────────────────────────────────────────────
-- auction_properties : 부동산 경매 투자 판단 워크스페이스
-- 경매사이트 정보를 재구축하지 않고, 관심 물건의 투자판단·자금계획만 관리.
-- 필요현금/예상순수익/ROI/최대입찰가는 앱에서 deterministic 계산.
-- ────────────────────────────────────────────────────────────
create table if not exists public.auction_properties (
  id                  uuid primary key default gen_random_uuid(),
  user_id             uuid not null references auth.users(id) on delete cascade,
  title               text not null,                 -- 물건명/단지
  address             text,                          -- 주소
  case_no             text,                          -- 사건번호
  status              text not null default 'interest', -- interest|researching|visited|bidding|won|sold|pass
  current_price       numeric(16,0) not null default 0, -- 현재시세
  expected_sale_price numeric(16,0) not null default 0, -- 예상매도가
  min_price           numeric(16,0) not null default 0, -- 최저가
  bid_price           numeric(16,0) not null default 0, -- 예상입찰가
  loan_amount         numeric(16,0) not null default 0, -- 경락잔금대출
  acquisition_cost    numeric(16,0) not null default 0, -- 취득·등기비
  repair_cost         numeric(16,0) not null default 0, -- 수리/인테리어
  eviction_cost       numeric(16,0) not null default 0, -- 명도비
  other_cost          numeric(16,0) not null default 0, -- 기타/예비비/미납관리비
  sale_cost           numeric(16,0) not null default 0, -- 매도비용(중개 등)
  finance_cost        numeric(16,0) not null default 0, -- 대출이자/금융비용
  target_profit       numeric(16,0) not null default 0, -- 목표수익
  score               numeric(5,2)  not null default 0, -- 투자점수 0~100
  verdict             text not null default 'HOLD',     -- GO|HOLD|PASS
  memo                text,                              -- 조사·메모(태그 자유서식)
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);
create index if not exists auction_user_idx on public.auction_properties (user_id);

create trigger set_updated_at before update on public.auction_properties
  for each row execute function public.set_updated_at();

alter table public.auction_properties enable row level security;
create policy "own - select" on public.auction_properties for select using (auth.uid() = user_id);
create policy "own - insert" on public.auction_properties for insert with check (auth.uid() = user_id);
create policy "own - update" on public.auction_properties for update using (auth.uid() = user_id);
create policy "own - delete" on public.auction_properties for delete using (auth.uid() = user_id);
