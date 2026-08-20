-- 자료실 항목에 원문 링크 추가 (카페 글·유튜브 등으로 바로 이동)
alter table public.knowledge_notes
  add column if not exists url text;
