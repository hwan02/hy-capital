-- 사용자 정의 모듈 : 사용자가 직접 메뉴(모듈)와 필드를 정의하고 데이터를 관리.
-- fields 는 FieldSpec 배열(jsonb): [{ "key","label","type","required" }, ...]
--   type ∈ text | longtext | number | money | percent | date | bool

create table public.custom_modules (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  name        text not null,
  icon        text not null default 'widgets',   -- Material 아이콘 키
  color       text not null default '38BDF8',    -- hex(RRGGBB)
  fields      jsonb not null default '[]',
  sort_order  int not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index custom_modules_user_idx on public.custom_modules (user_id, sort_order);

create table public.custom_records (
  id          uuid primary key default gen_random_uuid(),
  module_id   uuid not null references public.custom_modules(id) on delete cascade,
  user_id     uuid not null references auth.users(id) on delete cascade,
  data        jsonb not null default '{}',
  sort_order  int not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index custom_records_module_idx on public.custom_records (module_id, sort_order);

create trigger set_updated_at before update on public.custom_modules
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.custom_records
  for each row execute function public.set_updated_at();

alter table public.custom_modules enable row level security;
alter table public.custom_records enable row level security;

create policy "own - select" on public.custom_modules for select using (auth.uid() = user_id);
create policy "own - insert" on public.custom_modules for insert with check (auth.uid() = user_id);
create policy "own - update" on public.custom_modules for update using (auth.uid() = user_id);
create policy "own - delete" on public.custom_modules for delete using (auth.uid() = user_id);

create policy "own - select" on public.custom_records for select using (auth.uid() = user_id);
create policy "own - insert" on public.custom_records for insert with check (auth.uid() = user_id);
create policy "own - update" on public.custom_records for update using (auth.uid() = user_id);
create policy "own - delete" on public.custom_records for delete using (auth.uid() = user_id);
