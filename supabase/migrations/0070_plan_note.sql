-- 계획 할 일에 «내가 적은 것» 칸.
--
-- 「월 현금흐름이 어디서 나올지 3줄 적기」처럼 적으라는 할 일이 있는데 적을 데가 없었다.
-- detail 은 할 일 설명이고, note 는 내가 쓴 답·메모다.

alter table public.plan_items add column if not exists note text;

insert into public.hy_migrations (name) values ('0070_plan_note')
  on conflict (name) do nothing;
