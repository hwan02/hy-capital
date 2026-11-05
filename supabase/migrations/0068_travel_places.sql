-- 여행 버킷리스트 — 가고 싶은 곳을 한 줄씩 적으면 지도에 핀으로 꽂힌다.
--
-- 계획의 비전 «가고 싶은 곳 전부 여행하기»(버킷리스트 100곳)를 실제로 적는 곳.
-- 좌표는 앱이 이름(+나라)으로 OpenStreetMap 에서 찾아 넣는다 — 손으로 적지 않는다.
-- 남극처럼 이름으로 못 찾는 곳은 지도를 눌러 찍는다(pinned) — 이름을 바꿔도 좌표는 그대로.
-- geo_name 은 지도가 찾은 정식 이름. 엉뚱한 곳을 찾았는지 목록에서 보이게 한다.
-- 다녀오면 visited_on 에 날짜 — 비어 있으면 아직 «가고 싶은 곳».
-- 내용은 앱에서 채운다(공개 저장소라 여기 넣지 않는다).

create table if not exists public.travel_places (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,

  name        text not null,
  country     text,
  memo        text,
  visited_on  date,

  lat         double precision,
  lng         double precision,
  geo_name    text,
  pinned      boolean not null default false,

  sort_order  int not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists travel_places_user_idx on public.travel_places (user_id, sort_order);

create trigger set_updated_at before update on public.travel_places
  for each row execute function public.set_updated_at();

alter table public.travel_places enable row level security;
create policy "own - select" on public.travel_places for select using (auth.uid() = user_id);
create policy "own - insert" on public.travel_places for insert with check (auth.uid() = user_id);
create policy "own - update" on public.travel_places for update using (auth.uid() = user_id);
create policy "own - delete" on public.travel_places for delete using (auth.uid() = user_id);

-- 실행 기록 (0053 이 만든 표).
insert into public.hy_migrations (name) values ('0068_travel_places')
  on conflict (name) do nothing;
