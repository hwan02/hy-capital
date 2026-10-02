-- 책 «회독» — 한 권을 여러 번 읽는다.
--
-- 전에는 started_on · read_on 한 쌍뿐이라, 다시 읽으면 처음 읽은 기록을
-- 덮어써야 했다. reads 에 회독마다 {start, end, done} 을 쌓는다.
-- status · started_on · read_on 은 «마지막 회독»을 따라가도록 앱이 같이 쓴다
-- (다른 화면이 그 칸을 보므로 남겨 둔다).
--
-- 달력 탭이 reads 로 «언제 무엇을 읽었나»를 그린다.

alter table public.books
  add column if not exists reads jsonb not null default '[]'::jsonb;

-- 지금까지의 기록을 1회독으로 옮긴다. 이미 옮긴 책은 건드리지 않는다.
update public.books
   set reads = jsonb_build_array(jsonb_build_object(
         'start', started_on,
         'end',   read_on,
         'done',  status = 'done'))
 where reads = '[]'::jsonb
   and status in ('reading', 'done');

-- 실행 기록 (0053 이 만든 표).
insert into public.hy_migrations (name) values ('0059_book_reads')
  on conflict (name) do nothing;
