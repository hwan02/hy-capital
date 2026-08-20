-- ────────────────────────────────────────────────────────────
-- reference_accounts : 롤모델 계정 (벤치마킹할 인스타/유튜브/틱톡)
-- 내 채널(shorts_channels)과 분리해서, 참고할 계정 링크를 계속 쌓는다.
-- ────────────────────────────────────────────────────────────
create table if not exists public.reference_accounts (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  platform   text not null default 'Instagram', -- Instagram|YouTube|TikTok|기타
  name       text not null,                     -- 계정명 / 채널명
  url        text,                              -- 프로필·릴스 링크
  category   text,                              -- 부동산·재테크·브이로그 등
  followers  numeric(14,0) not null default 0,
  memo       text,                              -- 벤치마킹 포인트
  starred    boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists ref_acct_user_idx on public.reference_accounts (user_id, created_at desc);

create trigger set_updated_at before update on public.reference_accounts
  for each row execute function public.set_updated_at();

alter table public.reference_accounts enable row level security;
create policy "own - select" on public.reference_accounts for select using (auth.uid() = user_id);
create policy "own - insert" on public.reference_accounts for insert with check (auth.uid() = user_id);
create policy "own - update" on public.reference_accounts for update using (auth.uid() = user_id);
create policy "own - delete" on public.reference_accounts for delete using (auth.uid() = user_id);
