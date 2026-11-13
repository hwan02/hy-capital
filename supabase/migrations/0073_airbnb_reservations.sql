-- 에비 예약 — 확정 메일을 «처음 본 순간» 적어 둔다.
--
-- 카카오 메일함은 IMAP 으로 «최근 400통»만 보여 준다(2026-11-13 확인: 받은편지함이
-- 딱 400통, 가장 오래된 게 8/27, 하루 사이 예약 메일이 27통 → 26통으로 줄었다).
-- 두세 달 앞서 잡힌 예약은 체크인 날이 오기 전에 확정 메일이 밀려나서, 매시 배치가
-- 체크인 날 장부에 넣으려 할 때 메일이 없다 — 11/12~18 예약이 그렇게 빠졌다.
--
-- 그래서 scripts/airbnb_mail.py 가 메일을 읽을 때마다 예약을 이 표에 남기고,
-- 체크인 날에는 메일이 아니라 이 표를 보고 장부(airbnb_transactions)에 넣는다.
-- 이 표가 없으면 스크립트는 예전처럼 메일만 보고 돈다(대신 밀려난 예약은 못 넣는다).

create table if not exists public.airbnb_reservations (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,

  code        text not null,                      -- 확인 코드 HM………
  checkin     date not null,
  checkout    date,
  nights      int not null,
  payout      numeric(12,0) not null default 0,   -- 호스트 수입 (수수료 뗀 금액)
  status      text not null default 'confirmed',  -- confirmed | cancelled
  entered_at  timestamptz,                        -- 장부에 넣은(또는 이미 있던 걸 확인한) 때

  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (user_id, code)
);

create index if not exists airbnb_reservations_user_checkin_idx
  on public.airbnb_reservations (user_id, checkin);

create trigger set_updated_at before update on public.airbnb_reservations
  for each row execute function public.set_updated_at();

alter table public.airbnb_reservations enable row level security;
create policy "own - select" on public.airbnb_reservations for select using (auth.uid() = user_id);
create policy "own - insert" on public.airbnb_reservations for insert with check (auth.uid() = user_id);
create policy "own - update" on public.airbnb_reservations for update using (auth.uid() = user_id);
create policy "own - delete" on public.airbnb_reservations for delete using (auth.uid() = user_id);

insert into public.hy_migrations (name) values ('0073_airbnb_reservations')
  on conflict (name) do nothing;
