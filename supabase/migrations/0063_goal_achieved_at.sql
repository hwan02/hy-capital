-- 목표 «달성일» — 달성한 목표는 대시보드에서 빼고 Goals의 «달성한 목표»로 보관한다.
-- 현재값이 목표값에 닿거나 상태를 done으로 바꾸는 순간 DB가 날짜를 찍는다
-- (앱에서 따로 쓰지 않는다). 다시 목표값 아래로 내려가면 지운다.

alter table public.goals add column if not exists achieved_at date;

create or replace function public.goals_set_achieved_at()
returns trigger
language plpgsql
as $$
begin
  if (new.target_value > 0 and new.current_value >= new.target_value)
     or new.status = 'done' then
    if new.achieved_at is null then
      new.achieved_at = current_date;
    end if;
  else
    new.achieved_at = null;
  end if;
  return new;
end;
$$;

drop trigger if exists goals_achieved_at on public.goals;
create trigger goals_achieved_at
  before insert or update on public.goals
  for each row execute function public.goals_set_achieved_at();

-- 이미 달성한 목표 — 마지막 수정일을 달성일로 본다.
update public.goals
   set achieved_at = updated_at::date
 where achieved_at is null
   and ((target_value > 0 and current_value >= target_value) or status = 'done');
