-- 경공매 오답노트 — 달력 물건 하나에 «내 예상 → 실제 결과 → 왜 → 나중에 다시 보기»를 붙인다.
--
-- 매각 전에 «얼마에 낙찰될까»를 적어 두고, 매각 뒤 실제 낙찰가·응찰자·2위 가격과 견준다.
-- 왜 그 가격이 나왔는지(요인 태그 + 글)를 남기고, 몇 달 뒤 다시 열어 그 분석이 맞았는지 판정한다.
-- 새 테이블을 만들지 않는다 — 물건 하나(sale_items 한 줄)가 진실의 원천이다.
-- 금액은 앱 전체와 같이 «원».

alter table public.sale_items
  add column if not exists guess_price  numeric(16,0),            -- 내 예상 낙찰가 (매각 전에 적는다)
  add column if not exists my_bid       numeric(16,0),            -- 내 입찰가 (입찰 안 했으면 비움)
  add column if not exists result       text,                     -- 낙찰 | 유찰 | 변경·취하 | null(아직)
  add column if not exists sold_price   numeric(16,0),            -- 낙찰가
  add column if not exists bidders      int,                      -- 응찰자 수
  add column if not exists second_price numeric(16,0),            -- 2위 입찰가
  add column if not exists reasons      text[] not null default '{}', -- 왜 이 가격 — 요인 태그
  add column if not exists why          text,                     -- 왜 이 가격에 낙찰됐나
  add column if not exists lesson       text,                     -- 다음엔 이렇게
  add column if not exists review_on    date,                     -- 다시 볼 날
  add column if not exists review_note  text,                     -- 다시 보니 — 분석이 맞았나
  add column if not exists verdict      text;                     -- 맞았다 | 반반 | 틀렸다

-- 「다시 볼 날」 순으로 꺼내 본다.
create index if not exists sale_items_user_review_idx
  on public.sale_items (user_id, review_on)
  where review_on is not null;

-- RLS 는 0067 의 own - select/insert/update/delete 정책이 그대로 덮는다(같은 테이블).
