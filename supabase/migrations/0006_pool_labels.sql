-- 자금 분배 풀 표시 이름 (사용자가 변경 가능)
alter table public.profiles
  add column if not exists pool_business_label text not null default '사업자금',
  add column if not exists pool_salary_label   text not null default '월급·개인자금';
