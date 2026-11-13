-- 오늘 해야 할 일 «순서» — 대시보드에서 끌어서 옮긴 순서를 남긴다.
-- 비어 있으면(새로 적은 것) 맨 아래.

alter table public.tasks add column if not exists sort_order int;

insert into public.hy_migrations (name) values ('0072_task_order')
  on conflict (name) do nothing;
