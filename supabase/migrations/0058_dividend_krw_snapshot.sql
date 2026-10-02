-- 배당 기록에 «원화 총액» 스냅샷을 남긴다.
--
-- monthly_entries 의 배당 줄은 주당 분배금(amount)만 들고 있고, 받은 돈은
-- 앱이 «× 보유 수량 × 환율»로 매번 계산했다. 2026-10-02 경매 자금 마련으로
-- 배당 종목을 전부 팔고 지웠더니 수량이 사라져 3~9월 배당이 전부 0 이 됐다.
-- (기록 18줄은 남아 있다 — ref_id 에 외래키가 없어 같이 지워지지 않았다.)
--
-- 이제 기록할 때 krw 를 같이 저장하고, 앱은 krw 가 있으면 그걸 쓴다.

alter table public.monthly_entries
  add column if not exists krw numeric(14,0);

-- 지난 배당 복구 — 지우기 전 보유 수량(이전 작업 기록에 남아 있던 값)으로.
--   TIME KOREA 플러스배당액티브 1,197주 · AGNC 757주(미장, 환율 1,400 가정)
--   KODEX 일본 부동산리츠(H) 5주 · KoAct 배당성장액티브 1주
-- 이미 krw 가 있는 줄은 건드리지 않는다.
update public.monthly_entries set krw = round(amount * 1197)
 where category = 'dividend' and krw is null
   and ref_id = 'e9cb6fbf-e5b8-4e86-a509-8cf9c6a521ce';
update public.monthly_entries set krw = round(amount * 757 * 1400)
 where category = 'dividend' and krw is null
   and ref_id = 'ba4ca922-e96a-49cf-af22-3336a19e32a7';
update public.monthly_entries set krw = round(amount * 5)
 where category = 'dividend' and krw is null
   and ref_id = '50da5657-b80a-4912-815f-89942a3cfbaa';
update public.monthly_entries set krw = round(amount * 1)
 where category = 'dividend' and krw is null
   and ref_id = 'a2511ac5-b4a6-46a4-9174-97176202119e';

-- 실행 기록 (0053 이 만든 표).
insert into public.hy_migrations (name) values ('0058_dividend_krw_snapshot')
  on conflict (name) do nothing;
