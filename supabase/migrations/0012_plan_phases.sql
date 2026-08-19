-- ════════════════════════════════════════════════════════════
-- 재무 로드맵(Phase) — 단계 · 나가는 돈 기본세팅(배분) · 전환 조건
-- ════════════════════════════════════════════════════════════

-- 단계(phase)
create table if not exists public.plan_phases (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  phase_no      int not null,
  title         text not null,
  summary       text,
  target_date   date,               -- 목표일
  achieved_date date,               -- 실제 달성일
  is_current    boolean not null default false,
  sort_order    int not null default 0,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (user_id, phase_no)
);

-- 단계별 배분 (나가는 돈 기본세팅 + 목표 현금흐름 구성)
-- side : 'out'(나가는 돈 배분) | 'in'(현금흐름 구성 목표)
-- kind : 'monthly'(월 정기 금액) | 'percent'(비중 %) | 'target'(누적 목표액) | 'rule'(규칙/메모)
create table if not exists public.plan_allocations (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  phase_no    int not null,
  side        text not null default 'out',
  category    text not null,
  kind        text not null,
  amount      numeric(18,2),
  percent     numeric(6,2),
  note        text,
  sort_order  int not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- 단계별 전환 조건 / 마일스톤 체크리스트
-- kind : 'cashflow'(월급제외 현금흐름 목표, 자동 진행률) | 'manual'(수동 체크)
create table if not exists public.plan_conditions (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  phase_no      int not null,
  label         text not null,
  kind          text not null default 'manual',
  target_value  numeric(18,2),
  target_date   date,
  achieved_date date,
  done          boolean not null default false,
  sort_order    int not null default 0,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index if not exists plan_phases_user_idx on public.plan_phases (user_id, phase_no);
create index if not exists plan_alloc_user_idx on public.plan_allocations (user_id, phase_no, sort_order);
create index if not exists plan_cond_user_idx on public.plan_conditions (user_id, phase_no, sort_order);

create trigger set_updated_at before update on public.plan_phases
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.plan_allocations
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.plan_conditions
  for each row execute function public.set_updated_at();

do $$
declare t text;
begin
  foreach t in array array['plan_phases','plan_allocations','plan_conditions'] loop
    execute format('alter table public.%I enable row level security;', t);
    execute format('create policy "own - select" on public.%I for select using (auth.uid() = user_id);', t);
    execute format('create policy "own - insert" on public.%I for insert with check (auth.uid() = user_id);', t);
    execute format('create policy "own - update" on public.%I for update using (auth.uid() = user_id);', t);
    execute format('create policy "own - delete" on public.%I for delete using (auth.uid() = user_id);', t);
  end loop;
end $$;
