-- ────────────────────────────────────────────────────────────
-- 0053 · 단계 축에 «관리처분계획인가» 칸을 끼운다
--
-- 축에 사업시행인가는 있는데 «관리처분인가»가 없었다. 둘은 다른 일이다:
--   사업시행계획인가 — 이 사업을 «어떤 설계·규모»로 할지 인가받는 단계.
--                      직후에 종전자산 감정평가 → 분양공고 → 분양신청이 돈다.
--                      여기서 분양신청을 «안 하면» 그대로 현금청산이다.
--   관리처분계획인가 — 조합원별 «기존 자산을 얼마로 보고», 새 아파트를 «어떻게
--                      배분»하고, «분담금»을 얼마 낼지 정해서 인가받는 단계.
--                      이때 주택이 «입주권»으로 바뀐다. 이후 거래는 입주권 거래.
--
-- 칸을 «사이»에 끼우므로 뒤 칸 번호가 하나씩 밀린다.
--   모아  11 사업시행인가 → «12 관리처분인가» → 13 이주·착공 → 14 준공
--   신통   9 사업시행인가 → «10 관리처분인가» → 11 이주·착공 → 12 준공
--
-- 이미 들어가 있는 구역의 stage 를 그만큼 밀어 준다. 안 밀면 「이주·착공」이던
-- 구역이 「관리처분인가」로 둔갑한다.
--
-- 매수 밴드는 안 바뀐다 — 모아 9↑ · 신통 8↑ 는 그대로 «진입 불가»다.
--
-- 【두 번 돌리면 안 된다】
-- 이건 «자리 옮기기»라 두 번 돌면 단계가 두 칸 밀린다. 그래서 돌린 기록을
-- 남기고, 이미 돌렸으면 «아무것도 안 하고» 끝낸다. 마이그레이션을 손으로
-- 돌리는 저장소라 「이거 돌렸던가?」가 실제로 헷갈린다.
-- ────────────────────────────────────────────────────────────

-- 손으로 돌린 마이그레이션 기록 (앞으로도 쓴다)
create table if not exists public.hy_migrations (
  name   text primary key,
  run_at timestamptz not null default now()
);
comment on table public.hy_migrations is
  '손으로 돌린 마이그레이션 기록. 두 번 돌리면 안 되는 것만 여기 남긴다.';

-- 사용자 데이터가 아니라 «스키마 장부»다. 앱(anon/authenticated)은 볼 일이
-- 없으므로 RLS 만 켜고 정책은 «하나도 안 만든다» → 클라이언트는 전부 차단.
-- SQL Editor(postgres)는 RLS 를 우회하므로 그대로 쓴다.
alter table public.hy_migrations enable row level security;

do $$
declare moved_moa int := 0; moved_sin int := 0;
begin
  if exists (select 1 from public.hy_migrations where name = '0053') then
    raise notice '0053 은 이미 돌렸다 — 아무것도 안 한다.';
    return;
  end if;

  -- 큰 번호부터 밀어야 겹치지 않는다.
  update public.zones set stage = stage + 1
  where kind <> '신통기획' and stage between 12 and 13;
  get diagnostics moved_moa = row_count;

  update public.zones set stage = stage + 1
  where kind = '신통기획' and stage between 10 and 11;
  get diagnostics moved_sin = row_count;

  insert into public.hy_migrations (name) values ('0053');
  raise notice '단계 +1 — 모아 %곳 · 신통 %곳', moved_moa, moved_sin;
end $$;

-- 확인 — 조합설립(모아 9 · 신통 8) 이후 칸만 본다
select z.kind                              as 종류,
       z.stage                             as 단계,
       count(*)                            as 구역수
from public.zones z
where (z.kind <> '신통기획' and z.stage >= 9)
   or (z.kind =  '신통기획' and z.stage >= 8)
group by z.kind, z.stage
order by z.kind, z.stage;
