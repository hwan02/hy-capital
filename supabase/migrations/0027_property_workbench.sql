-- ────────────────────────────────────────────────────────────
-- 부동산 작업대 — 구역 · 단지 · 시세조사 · 임장
--
-- 지금까지 시세조사와 사진이 «경매 물건»에 붙어 있었다. 그래서
--   · 같은 단지가 다시 나오면 조사를 처음부터 다시 했다
--   · 경매로 안 나온 단지는 조사해 둘 곳이 없었다 → 발굴이 막힌다
--
-- 조사·임장을 «단지»에 붙이면 한 번 조사한 게 계속 쓰이고,
-- 급매를 만나도 그 자리에서 판단할 수 있다.
--
-- 흐름: 기준(자료실) → 구역 → 단지 → 매물(경매·급매)
-- ────────────────────────────────────────────────────────────

-- ── 구역 (모아타운·신통기획 선정지) ─────────────────────────
create table if not exists public.zones (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users(id) on delete cascade,
  name            text not null,                    -- 강서구 화곡동 354
  kind            text not null default '모아타운',  -- 모아타운|신통기획|일반
  district        text,                             -- 자치구
  consent_rate    numeric(5,2) not null default 0,  -- 조합설립 동의율 %
  union_expected  date,                             -- 조합설립 예상 시기
  memo            text,
  starred         boolean not null default false,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index if not exists zones_user_idx on public.zones (user_id, consent_rate desc);

-- ── 단지 (조사·임장이 붙는 단위) ────────────────────────────
-- zone_id 는 nullable — 구역 밖 단지도 조사할 수 있다.
create table if not exists public.complexes (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  zone_id     uuid references public.zones(id) on delete set null,
  name        text not null,                        -- 남성아트빌
  address     text,
  kind        text not null default '빌라',          -- 빌라|다세대|연립|아파트|기타
  memo        text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists complexes_user_idx on public.complexes (user_id, zone_id);

-- ── 시세조사 (단지당 여러 시점 — 추이를 남긴다) ─────────────
-- sources: [{"label":"네이버","sale":145000000,"jeonse":125000000,"at":"desk"}]
--   at = desk(책상: 네이버·실거래·KB) | field(현장: 부동산)
-- 평균·전세비율은 저장하지 않고 계산한다. 빈 칸은 평균에서 제외된다.
create table if not exists public.price_surveys (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade,
  complex_id   uuid not null references public.complexes(id) on delete cascade,
  surveyed_on  date not null default current_date,
  sources      jsonb not null default '[]'::jsonb,
  memo         text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index if not exists surveys_complex_idx
  on public.price_surveys (user_id, complex_id, surveyed_on desc);

-- ── 임장 (단지에 붙는다 — 매물이 없어도 간다) ───────────────
-- checks : {"exterior": true, "parking": false, ...}
-- photos : [{"path":"<uid>/visits/...","name":"외관.jpg","tag":"외관"}]
-- memos  : [{"at":"14:26","text":"주차 불가"}]
-- heard  : [{"who":"화곡부동산","sale":140000000,"jeonse":123000000}]
create table if not exists public.visits (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  complex_id  uuid not null references public.complexes(id) on delete cascade,
  visited_at  timestamptz not null default now(),
  checks      jsonb not null default '{}'::jsonb,
  photos      jsonb not null default '[]'::jsonb,
  memos       jsonb not null default '[]'::jsonb,
  heard       jsonb not null default '[]'::jsonb,
  done        boolean not null default false,
  memo        text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists visits_complex_idx
  on public.visits (user_id, complex_id, visited_at desc);

-- ── 매물: 단지에 연결 + 취득 경로 ───────────────────────────
-- 경매만이 아니다. 급매(일반 매매)도 같은 계산 틀을 쓴다 —
-- 다른 것은 입찰가/협상가라는 이름뿐.
alter table public.auction_properties
  add column if not exists complex_id  uuid references public.complexes(id) on delete set null,
  add column if not exists acquisition text not null default 'auction'; -- auction|quick_sale
create index if not exists auction_complex_idx
  on public.auction_properties (user_id, complex_id);

-- ── 매수 예산 (경매 전용이 아니게 됐다) ─────────────────────
comment on column public.profiles.auction_budget is
  '매수 예산 — 경매 보증금·급매 계약금 공통 기준';

-- ── 트리거 ──────────────────────────────────────────────────
create trigger set_updated_at before update on public.zones
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.complexes
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.price_surveys
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.visits
  for each row execute function public.set_updated_at();

-- ── RLS ─────────────────────────────────────────────────────
alter table public.zones          enable row level security;
alter table public.complexes      enable row level security;
alter table public.price_surveys  enable row level security;
alter table public.visits         enable row level security;

create policy "own - select" on public.zones for select using (auth.uid() = user_id);
create policy "own - insert" on public.zones for insert with check (auth.uid() = user_id);
create policy "own - update" on public.zones for update using (auth.uid() = user_id);
create policy "own - delete" on public.zones for delete using (auth.uid() = user_id);

create policy "own - select" on public.complexes for select using (auth.uid() = user_id);
create policy "own - insert" on public.complexes for insert with check (auth.uid() = user_id);
create policy "own - update" on public.complexes for update using (auth.uid() = user_id);
create policy "own - delete" on public.complexes for delete using (auth.uid() = user_id);

create policy "own - select" on public.price_surveys for select using (auth.uid() = user_id);
create policy "own - insert" on public.price_surveys for insert with check (auth.uid() = user_id);
create policy "own - update" on public.price_surveys for update using (auth.uid() = user_id);
create policy "own - delete" on public.price_surveys for delete using (auth.uid() = user_id);

create policy "own - select" on public.visits for select using (auth.uid() = user_id);
create policy "own - insert" on public.visits for insert with check (auth.uid() = user_id);
create policy "own - update" on public.visits for update using (auth.uid() = user_id);
create policy "own - delete" on public.visits for delete using (auth.uid() = user_id);

-- ── 기존 3건을 단지로 옮긴다 (조사 내용이 날아가지 않게) ────
-- 물건명에서 단지를 만들고 연결한다. 이미 연결됐으면 건너뛴다.
insert into public.complexes (user_id, name, address, kind)
select p.user_id,
       case
         when p.title like '%서초힐스%'  then '서초힐스'
         when p.title like '%메가트리아%' then '래미안 안양 메가트리아'
         when p.title like '%남성아트빌%' then '남성아트빌'
         else p.title
       end,
       p.address,
       coalesce(p.property_kind, '빌라')
from public.auction_properties p
where p.complex_id is null
  and not exists (
    select 1 from public.complexes c
    where c.user_id = p.user_id
      and c.name = case
            when p.title like '%서초힐스%'  then '서초힐스'
            when p.title like '%메가트리아%' then '래미안 안양 메가트리아'
            when p.title like '%남성아트빌%' then '남성아트빌'
            else p.title
          end
  );

update public.auction_properties p
set complex_id = c.id
from public.complexes c
where p.complex_id is null
  and c.user_id = p.user_id
  and c.name = case
        when p.title like '%서초힐스%'  then '서초힐스'
        when p.title like '%메가트리아%' then '래미안 안양 메가트리아'
        when p.title like '%남성아트빌%' then '남성아트빌'
        else p.title
      end;
