-- 0021 실행 후 Storage API 가 "Bucket not found" 를 반환할 때 쓴다.
-- files 컬럼은 생겼는데 버킷만 없는 상태를 진단하고 고친다.
--
-- ① 아래 SELECT 3개를 먼저 실행해 무엇이 빠졌는지 본다.
-- ② 버킷이 없으면 INSERT 를, 정책이 없으면 정책 블록을 실행한다.
--    (Dashboard → Storage → New bucket 으로 'knowledge' 를 Public 끄고
--     만들어도 결과는 같다. 그게 더 확실하면 그렇게 해도 된다.)

-- ── ① 진단 ──────────────────────────────────────────────
-- 버킷이 있는가? (0행이면 없다)
select id, name, public, created_at
from storage.buckets
where id = 'knowledge';

-- Storage 정책이 걸렸는가? (4행 나와야 정상)
select policyname, cmd
from pg_policies
where schemaname = 'storage'
  and tablename = 'objects'
  and policyname like 'knowledge files%'
order by policyname;

-- files 컬럼은 있는가? (1행 = jsonb)
select column_name, data_type, column_default
from information_schema.columns
where table_schema = 'public'
  and table_name = 'knowledge_notes'
  and column_name = 'files';

-- ── ② 버킷이 없으면 이것만 실행 ─────────────────────────
insert into storage.buckets (id, name, public, file_size_limit)
values ('knowledge', 'knowledge', false, 26214400)   -- 25MB
on conflict (id) do update
  set public = false,
      file_size_limit = 26214400;

-- 확인: 1행이 나오면 성공
select id, public, file_size_limit from storage.buckets where id = 'knowledge';
