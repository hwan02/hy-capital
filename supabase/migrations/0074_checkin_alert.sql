-- 에비 체크인 날 아침 8:30 — 슬랙으로 «오늘 체크인, 이거 했나?»를 보낸다.
--
-- 왜 DB 에서 보내나
--   · GitHub Actions 예약 실행은 몇 시간씩 늦게 뜬다(daily.yml 주석: 06:00 예약이 08~09시에 떴다).
--     «8:30» 처럼 시각이 중요한 알림은 Actions 로는 못 지킨다.
--   · 맥 launchd 는 맥이 꺼져 있으면 안 돈다.
--   · Supabase 의 pg_cron 은 DB 안에서 정확히 돈다. 보내는 건 pg_net(http_post).
--
-- 무엇을 보나
--   airbnb_reservations(0073) — 매시 배치(scripts/airbnb_mail.py)가 확정 메일을 읽을 때마다
--   예약을 남기는 표. 체크인일이 «오늘(서울)»이고 취소되지 않은 예약이 있을 때만 보낸다.
--   ※ 0073 이 먼저 실행돼 있어야 한다.
--
-- 슬랙 웹훅은 저장소(공개)에 넣지 않는다. Vault 에 'slack_webhook' 이름으로 따로 넣는다:
--   select vault.create_secret('https://hooks.slack.com/services/…', 'slack_webhook');
--
-- 시험:  select public.checkin_alert(true);   -- 오늘 체크인이 없어도 한 번 보낸다

create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;

create or replace function public.checkin_alert(force boolean default false)
returns text
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  today   date := (now() at time zone 'Asia/Seoul')::date;
  hook    text;
  r       record;
  n       int := 0;
  stays   text := '';
  outs    int;
  msg     text;
  dow     text[] := array['일','월','화','수','목','금','토'];
begin
  select decrypted_secret into hook
    from vault.decrypted_secrets where name = 'slack_webhook' limit 1;
  if hook is null or hook = '' then
    return 'slack_webhook 이 Vault 에 없음';
  end if;

  for r in
    select distinct on (code) checkin, checkout, nights
      from public.airbnb_reservations
     where checkin = today and status <> 'cancelled'
     order by code
  loop
    n := n + 1;
    stays := stays || format(E'• %s(%s) 체크인 → %s(%s) 체크아웃 · %s박\n',
      to_char(r.checkin, 'FMMM/FMDD'), dow[extract(dow from r.checkin)::int + 1],
      to_char(coalesce(r.checkout, r.checkin + r.nights), 'FMMM/FMDD'),
      dow[extract(dow from coalesce(r.checkout, r.checkin + r.nights))::int + 1],
      r.nights);
  end loop;

  if n = 0 and not force then
    return '오늘 체크인 없음';
  end if;

  -- 같은 날 나가는 예약이 있으면 청소 시간이 빠듯하다.
  select count(*) into outs
    from public.airbnb_reservations
   where coalesce(checkout, checkin + nights) = today and status <> 'cancelled';

  msg := case when n = 0
           then E'🏠 *에비 — 시험 알림* (오늘 체크인은 없어요)\n'
           else format(E'🏠 *에비 — 오늘 체크인 %s건*\n', n) end
      || stays
      || case when outs > 0 then E'• 오늘 나가는 손님도 있어요 — 청소 시간 확인\n' else '' end
      || E'\n*확인할 것*\n'
      || E'☐ 도어락 비밀번호 바꿨나 → 게스트에게 보냈나\n'
      || E'☐ 체크인 시간 · 체크아웃 시간 안내했나';

  perform net.http_post(
    url     := hook,
    body    := jsonb_build_object('text', msg),
    headers := '{"Content-Type": "application/json"}'::jsonb
  );
  return format('보냄 — 체크인 %s건', n);
end;
$$;

-- 앱(anon·로그인 사용자)이 부를 수 없게 — cron(postgres)만 부른다.
revoke all on function public.checkin_alert(boolean) from public, anon, authenticated;

-- 매일 08:30 KST = 23:30 UTC (pg_cron 은 UTC 로 돈다). 같은 이름이면 덮어쓴다.
select cron.schedule('checkin-alert', '30 23 * * *', $$select public.checkin_alert()$$);

insert into public.hy_migrations (name) values ('0074_checkin_alert')
  on conflict (name) do nothing;
