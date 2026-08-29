-- 부동산 세제·규제 타임라인 — 시행일별 이벤트(하드코딩 대신 DB).
create table if not exists public.tax_events (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  event_date  date not null,
  title       text not null,
  description text,
  kind        text not null default '세제',   -- 세제 | 정비
  pending     boolean not null default false, -- 국회 통과 전(확정 아님)
  source      text,
  created_at  timestamptz not null default now()
);
create index if not exists tax_events_user_idx on public.tax_events (user_id, event_date);
alter table public.tax_events enable row level security;
create policy "own - select" on public.tax_events for select using (auth.uid() = user_id);
create policy "own - insert" on public.tax_events for insert with check (auth.uid() = user_id);
create policy "own - update" on public.tax_events for update using (auth.uid() = user_id);
create policy "own - delete" on public.tax_events for delete using (auth.uid() = user_id);

-- 현재 확인된 항목 시드 (demo 계정) — 이미 있으면 skip
insert into public.tax_events (user_id, event_date, title, description, kind, pending, source)
select 'd0d0d0d0-0000-4000-a000-000000000001', v.d::date, v.t, v.dsc, v.k, v.p::boolean, v.src
from (values
  ('2020-08-12','법인 주택 취득세 12% 중과','법인이 주택 취득 시 대부분 12%. 공시가 1억 이하 등은 예외.','세제','false','지방세법'),
  ('2026-02-27','모아타운 조합설립 동의율 완화','소규모재건축 75%→70%, 소규모재개발 80%→75%.','정비','false','소규모주택정비법 §23'),
  ('2026-07-10','모아주택 심의기준 손질','준주거 상향·용적률 최대 500%·제2종 층수제한 폐지(중고층 가능).','정비','false','서울시 보도자료 2026.7.10'),
  ('2026-08-18','조합설립 기간 1년→4개월','추진위 조기구성 + 75%↑ 동의 시 병행 처리. 365일→120일.','정비','false','서울시 보도자료 2026.8.19'),
  ('2026-10-01','일시적 2주택 처분기간 3년→2년','조정대상지역. 2026 세제개편안.','세제','true','2026 세제개편안'),
  ('2027-01-01','종부세 인상 + 양도세 공제 확대','고가·다주택 보유세 인상(1주택 공제 거주 14억/비거주 9억, 공정시장가액비율 60→70%·3주택+ 80%). 양도세 10년 거주 1주택 기본공제 250만→2,500만.','세제','true','2026 세제개편안'),
  ('2028-01-01','장기보유특별공제 거주 중심 개편','거주 연 8% + 보유 연 2%, 최대 80%. 보유공제 → 거주공제로 이동.','세제','true','2026 세제개편안')
) as v(d,t,dsc,k,p,src)
where not exists (
  select 1 from public.tax_events te
  where te.user_id = 'd0d0d0d0-0000-4000-a000-000000000001'
    and te.event_date = v.d::date and te.title = v.t
);
