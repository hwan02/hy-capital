-- ────────────────────────────────────────────────────────────
-- 자료실 항목에 파일(PDF 등) 첨부
--
-- 파일 본체는 Storage 의 비공개 버킷 'knowledge' 에 둔다.
-- (base64 로 테이블에 넣으면 4.8MB PDF 가 6.5MB 텍스트가 되어
--  목록 조회가 느려진다. 경로만 저장하고 열 때 서명 URL 을 만든다.)
--
-- files 형태:
--   [{"name":"강의자료.pdf","path":"<uid>/1755..._강의자료.pdf","size":4830937}]
-- ────────────────────────────────────────────────────────────
alter table public.knowledge_notes
  add column if not exists files jsonb not null default '[]'::jsonb;

-- 비공개 버킷. public=false 이므로 서명 URL 없이는 접근 불가.
insert into storage.buckets (id, name, public)
values ('knowledge', 'knowledge', false)
on conflict (id) do nothing;

-- 본인 폴더(<user_id>/…)만 읽고 쓴다.
-- storage.foldername(name)[1] 이 경로의 첫 번째 폴더 = user_id.
drop policy if exists "knowledge files - select" on storage.objects;
create policy "knowledge files - select" on storage.objects
  for select using (
    bucket_id = 'knowledge'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "knowledge files - insert" on storage.objects;
create policy "knowledge files - insert" on storage.objects
  for insert with check (
    bucket_id = 'knowledge'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "knowledge files - update" on storage.objects;
create policy "knowledge files - update" on storage.objects
  for update using (
    bucket_id = 'knowledge'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "knowledge files - delete" on storage.objects;
create policy "knowledge files - delete" on storage.objects
  for delete using (
    bucket_id = 'knowledge'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
