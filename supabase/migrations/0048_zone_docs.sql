-- 0048_zone_docs.sql
-- 구역에 «자료»(링크·PDF)를 붙인다. 구역 카드에서 눌러 열람·미리보기.
-- docs 항목:
--   링크:  { "title": "...", "url": "https://...", "type": "link" }
--   PDF :  { "title": "...", "path": "zone-docs/...", "type": "pdf", "bucket": "knowledge" }
--          (PDF는 기존 비공개 'knowledge' 버킷에 올리고, 열 때 서명URL 생성)

alter table public.zones
  add column if not exists docs jsonb not null default '[]'::jsonb;
