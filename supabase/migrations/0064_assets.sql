-- 자산 한눈에 — 계좌·사업별 잔액을 한 줄씩 적어 «지금 내 돈이 어디에 얼마»를 본다.
--
-- financial_snapshots 는 순자산 «합계» 한 칸뿐이라 어디에 있는 돈인지 안 보였다.
-- 항목마다 분류(category)를 달아 대시보드에서 분류별로 묶어 보여 준다.
--   사업 · 투자 · 현금·예금 · 연금 · 부동산 · 부채(빼는 쪽)
-- 금액은 «지금 잔액»을 손으로 고친다. 언제 고쳤는지(updated_at)를 같이 보여 줘서
-- 오래된 숫자가 티 나게 한다.

create table if not exists public.assets (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,

  name        text not null,
  category    text not null default '현금·예금',
  amount      numeric(16,0) not null default 0,
  memo        text,
  sort_order  int not null default 0,

  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists assets_user_idx on public.assets (user_id, sort_order);

create trigger set_updated_at before update on public.assets
  for each row execute function public.set_updated_at();

alter table public.assets enable row level security;
create policy "own - select" on public.assets for select using (auth.uid() = user_id);
create policy "own - insert" on public.assets for insert with check (auth.uid() = user_id);
create policy "own - update" on public.assets for update using (auth.uid() = user_id);
create policy "own - delete" on public.assets for delete using (auth.uid() = user_id);

-- 처음 칸 — 이름과 분류만. 금액은 앱에서 채운다(공개 저장소라 숫자는 넣지 않는다).
-- 혼자 쓰는 앱이라 계정은 하나다. 이미 항목이 있으면 넣지 않는다.
insert into public.assets (user_id, name, category, sort_order)
select u.id, v.name, v.category, v.ord
  from (select id from auth.users order by created_at limit 1) u,
       (values ('에비 1호 (보증금·시설)', '사업',     1),
               ('주식 계좌',             '투자',     2),
               ('ISA',                  '투자',     3),
               ('입찰 자금',             '현금·예금', 4),
               ('비상금',               '현금·예금', 5),
               ('연금저축',             '연금',     6),
               ('IRP',                  '연금',     7),
               ('예금담보대출',          '부채',     8)) v(name, category, ord)
 where not exists (select 1 from public.assets);

-- 실행 기록 (0053 이 만든 표).
insert into public.hy_migrations (name) values ('0064_assets')
  on conflict (name) do nothing;
