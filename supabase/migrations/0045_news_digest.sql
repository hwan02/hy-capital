-- 0045_news_digest.sql
-- 아침 뉴스 다이제스트가 "이미 보낸 기사"를 기억해 중복 발송을 막는 표.
-- 매일 아침 트리거가: 후보 기사 수집 → 여기 없는 URL만 Slack 발송 → 발송분을 여기 insert.

create table if not exists public.news_digest (
  id uuid primary key default gen_random_uuid(),
  url text not null unique,          -- 기사 원문 URL (중복 판정 키)
  title text not null,
  source text,                       -- 매체명(디벨로퍼뉴스/하우징헤럴드 등)
  topic text,                        -- 신통 / 모아타운 / 민간도심복합
  published_on date,                 -- 기사 발행일(파악되면)
  sent_at timestamptz not null default now()
);

create index if not exists news_digest_sent_at_idx
  on public.news_digest (sent_at desc);

alter table public.news_digest enable row level security;

-- 데모 단일 사용자 앱이라 로그인 사용자면 읽기/쓰기 허용.
drop policy if exists "news_digest rw" on public.news_digest;
create policy "news_digest rw" on public.news_digest
  for all to authenticated using (true) with check (true);
