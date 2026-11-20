-- 에비 체크인 알림에 «몇 명»도 — 확정 메일 「게스트」 아래 줄(「성인 4명」)을 적어 둔다.
--
-- scripts/airbnb_mail.py 가 확정 메일을 읽을 때 guests 를 채운다(이미 적힌 예약도 다음 배치에 채움).
-- 알림 줄: «• 11/20(금) 체크인 → 11/24(화) 체크아웃 · 4박 · 성인 4명»
-- ※ 0073(예약 표)·0074(체크인 알림)가 먼저 실행돼 있어야 한다.

alter table public.airbnb_reservations add column if not exists guests text;

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
    select distinct on (code) checkin, checkout, nights, guests
      from public.airbnb_reservations
     where checkin = today and status <> 'cancelled'
     order by code
  loop
    n := n + 1;
    stays := stays || format(E'• %s(%s) 체크인 → %s(%s) 체크아웃 · %s박%s\n',
      to_char(r.checkin, 'FMMM/FMDD'), dow[extract(dow from r.checkin)::int + 1],
      to_char(coalesce(r.checkout, r.checkin + r.nights), 'FMMM/FMDD'),
      dow[extract(dow from coalesce(r.checkout, r.checkin + r.nights))::int + 1],
      r.nights,
      case when coalesce(r.guests, '') <> '' then ' · ' || r.guests else '' end);
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

revoke all on function public.checkin_alert(boolean) from public, anon, authenticated;
