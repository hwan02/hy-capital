-- 0048_zone_docs.sql
-- 구역에 «자료»(링크·PDF)를 붙인다. 구역 카드에서 눌러 열람·미리보기.
-- docs = [{ "title": "...", "url": "https://...", "type": "pdf"|"link" }, ...]

alter table public.zones
  add column if not exists docs jsonb not null default '[]'::jsonb;

-- PDF 등 파일 보관용 공개 버킷.
insert into storage.buckets (id, name, public)
values ('zone-docs', 'zone-docs', true)
on conflict (id) do nothing;

-- 공개 버킷이라 읽기는 누구나, 쓰기/수정/삭제는 로그인 사용자.
drop policy if exists "zone-docs read"   on storage.objects;
drop policy if exists "zone-docs write"  on storage.objects;
drop policy if exists "zone-docs update" on storage.objects;
drop policy if exists "zone-docs delete" on storage.objects;

create policy "zone-docs read" on storage.objects
  for select using (bucket_id = 'zone-docs');
create policy "zone-docs write" on storage.objects
  for insert to authenticated with check (bucket_id = 'zone-docs');
create policy "zone-docs update" on storage.objects
  for update to authenticated using (bucket_id = 'zone-docs');
create policy "zone-docs delete" on storage.objects
  for delete to authenticated using (bucket_id = 'zone-docs');
