-- 숏폼 채널에 링크(URL) 추가
alter table public.shorts_channels
  add column if not exists link text;
