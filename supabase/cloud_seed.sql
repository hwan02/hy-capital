-- HY CAPITAL 클라우드 시드 (고정 계정 + 데이터)  ※ Supabase SQL Editor 에서 1회 Run
-- 계정: demo@hycapital.app / CHANGE_ME_PASSWORD  (앱이 이 계정으로 자동 로그인)
-- 전략 문서 실제 수치 + 홍대포포(1호점) 거래 83건 포함.

-- 1) 고정 로그인 계정 생성 (GoTrue 호환: 토큰 컬럼 빈 문자열)
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at,
  raw_app_meta_data, raw_user_meta_data, is_sso_user, is_anonymous,
  confirmation_token, recovery_token, email_change,
  email_change_token_new, email_change_token_current,
  phone_change, phone_change_token, reauthentication_token
) values (
  '00000000-0000-0000-0000-000000000000', 'd0d0d0d0-0000-4000-a000-000000000001',
  'authenticated','authenticated','demo@hycapital.app',
  extensions.crypt('CHANGE_ME_PASSWORD', extensions.gen_salt('bf')),
  now(), now(), now(),
  '{"provider":"email","providers":["email"]}', '{"display_name":"HY 대표"}',
  false, false, '', '', '', '', '', '', '', ''
) on conflict (id) do nothing;

insert into auth.identities (
  provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at
) values (
  'demo@hycapital.app','d0d0d0d0-0000-4000-a000-000000000001',
  '{"sub":"d0d0d0d0-0000-4000-a000-000000000001","email":"demo@hycapital.app"}','email', now(), now(), now()
) on conflict (provider_id, provider) do nothing;

-- 2) 데이터 시드
do $$
declare uid uuid := 'd0d0d0d0-0000-4000-a000-000000000001'; unit1 uuid; m0 date := date_trunc('month', now())::date;
begin
  insert into public.profiles(id,display_name,monthly_expenses,net_worth_goal,freedom_target)
    values (uid,'HY 대표',3500000,1500000000,10000000)
    on conflict (id) do update set freedom_target=10000000, net_worth_goal=1500000000;

  insert into public.financial_snapshots(user_id,as_of,net_worth,cash,non_salary_cashflow,salary_cashflow) values
    (uid,m0-interval '5 month',620000000,45000000,900000,4800000),
    (uid,m0-interval '4 month',655000000,52000000,1100000,4800000),
    (uid,m0-interval '3 month',690000000,48000000,1300000,4800000),
    (uid,m0-interval '2 month',742000000,61000000,1500000,4800000),
    (uid,m0-interval '1 month',795000000,58000000,1700000,4800000),
    (uid,m0,842000000,67000000,1900000,4800000)
  on conflict (user_id,as_of) do nothing;

  insert into public.cash_flows(user_id,occurred_on,source,target,amount,is_salary,memo) values
    (uid,now()::date,'월급','생활비',3500000,true,'고정 생활비'),
    (uid,now()::date,'월급','재투자',1300000,true,'연금/IRP/비상금'),
    (uid,now()::date,'에어비앤비','사업확장',1500000,false,'홍대포포 → 에비2'),
    (uid,now()::date,'배당','재투자',400000,false,'배당 재투자'),
    (uid,now()::date,'숏폼','재투자',0,false,'초기 단계');

  insert into public.airbnb_units(user_id,name,status,reserve_fund,target_fund,expected_open,monthly_profit,monthly_target,roi,occupancy,sort_order)
    values (uid,'에비1 · 홍대포포','open',0,60000000,now()::date-interval '8 month',1500000,2000000,62,84,1)
    returning id into unit1;
  insert into public.airbnb_units(user_id,name,status,reserve_fund,target_fund,expected_open,monthly_profit,monthly_target,roi,occupancy,sort_order) values
    (uid,'에비2 · 속초','preparing',38000000,55000000,now()::date+interval '2 month',0,2000000,0,0,2),
    (uid,'에비3 · 제주','planning',8000000,70000000,now()::date+interval '7 month',0,2000000,0,0,3);

  insert into public.airbnb_transactions(user_id,unit_id,txn_date,nights,guest_payment,payout,extra_income,cleaning_cost,variable_cost,fixed_cost,memo) values
    (uid,unit1,'2026-05-10',1.0,153500,127328,0,0,160000,0,'후기작업'),
    (uid,unit1,'2026-05-10',0.0,0,0,0,0,0,400000,'보일러수리비 빼고 5월 월세'),
    (uid,unit1,'2026-05-11',1.0,148500,123180,0,0,150000,0,'후기작업'),
    (uid,unit1,'2026-05-12',1.0,148500,123180,0,0,150000,0,'후기작업'),
    (uid,unit1,'2026-05-13',1.0,148500,123180,0,0,150000,0,'후기작업'),
    (uid,unit1,'2026-05-13',0.0,0,0,0,0,85000,0,'대문현판'),
    (uid,unit1,'2026-05-14',1.0,148500,123180,0,0,150000,0,'후기작업'),
    (uid,unit1,'2026-05-15',1.0,241000,189914,0,0,0,0,''),
    (uid,unit1,'2026-05-16',1.0,201000,158393,0,50000,30000,0,'에어컨 고장, 이영숙청소비'),
    (uid,unit1,'2026-05-19',4.0,651500,513398,0,50000,0,0,'이영숙청소비'),
    (uid,unit1,'2026-05-19',0.0,0,0,0,0,363000,0,'에어컨 설치비'),
    (uid,unit1,'2026-05-23',2.0,324500,255716,0,40000,30000,0,'김유정청소비,보일러출장비'),
    (uid,unit1,'2026-05-25',0.0,0,0,0,0,700170,0,'에어컨 구매 및 기타'),
    (uid,unit1,'2026-05-25',0.0,0,0,0,0,27560,0,'커튼봉'),
    (uid,unit1,'2026-05-26',1.0,198500,159345,0,0,167732,0,'구조다름, 모기, 계단으로 인한 환불'),
    (uid,unit1,'2026-05-27',0.0,0,0,0,0,13860,0,'홈키파'),
    (uid,unit1,'2026-05-27',0.0,0,0,0,0,19800,0,'현관문방충망'),
    (uid,unit1,'2026-05-29',1.0,236500,189850,0,0,180000,0,'예약 잘못'),
    (uid,unit1,'2026-05-30',1.0,214000,168638,0,50000,0,0,'이정임자매청소비'),
    (uid,unit1,'2026-05-31',1.0,155000,122144,0,50000,0,0,'이정임자매청소비'),
    (uid,unit1,'2026-06-01',3.0,499000,400572,0,50000,237500,0,'이영숙청소비 전기기사 도어락 수리'),
    (uid,unit1,'2026-06-02',0.0,0,0,0,0,239260,0,'이불커버, 베개커버, 걸레, 선풍기, 일회용장갑'),
    (uid,unit1,'2026-06-04',0.0,0,0,0,0,187500,0,'전기 등'),
    (uid,unit1,'2026-06-04',0.0,0,0,0,0,50000,0,'현관문 수리'),
    (uid,unit1,'2026-06-04',0.0,0,0,0,0,105780,0,'선풍기'),
    (uid,unit1,'2026-06-05',2.0,318000,250592,0,50000,0,0,'윤형권청소비'),
    (uid,unit1,'2026-06-05',0.0,0,0,0,0,900000,0,'프로포즈 식당 예약'),
    (uid,unit1,'2026-06-07',2.0,355000,284976,0,50000,0,0,'이정임청소비'),
    (uid,unit1,'2026-06-09',2.0,290000,217993,0,50000,0,0,'이정임청소비'),
    (uid,unit1,'2026-06-10',0.0,0,0,0,0,0,700000,'6월 월세'),
    (uid,unit1,'2026-06-10',0.0,0,0,0,0,32820,0,'돌돌이 리필, 베이킹소다과탄산소다, 이어플러그'),
    (uid,unit1,'2026-06-11',2.0,425000,341169,0,50000,0,0,'이정임청소비'),
    (uid,unit1,'2026-06-11',0.0,0,0,0,0,0,23100,'인터넷'),
    (uid,unit1,'2026-06-13',2.0,380000,299450,0,50000,76000,0,'에어컨 고장, 이정임청소비'),
    (uid,unit1,'2026-06-14',0.0,0,0,0,0,380000,0,'에어컨 구매 2'),
    (uid,unit1,'2026-06-16',0.0,0,0,0,0,280000,0,'에어컨 설치비2'),
    (uid,unit1,'2026-06-16',4.0,760000,598900,0,0,0,0,''),
    (uid,unit1,'2026-06-17',0.0,0,0,0,0,0,30570,'전기세'),
    (uid,unit1,'2026-06-18',0.0,0,0,0,0,19570,0,'아이스크림, 각티슈'),
    (uid,unit1,'2026-06-19',0.0,0,0,0,0,55990,0,'웨건'),
    (uid,unit1,'2026-06-19',0.0,0,0,0,0,19190,0,'고무장갑, 롱청소솔, 틈새세척솔'),
    (uid,unit1,'2026-06-20',2.0,339680,267678,0,0,0,0,''),
    (uid,unit1,'2026-06-23',1.0,160508,126484,0,50000,0,0,'윤형권청소비'),
    (uid,unit1,'2026-06-24',4.0,810000,650228,0,50000,0,0,'이정임자매청소비'),
    (uid,unit1,'2026-06-28',24.0,3108000,2449182,0,0,0,0,''),
    (uid,unit1,'2026-06-30',0.0,0,0,0,0,28710,0,'초파리, 하수구 트랩'),
    (uid,unit1,'2026-06-30',0.0,0,0,0,0,0,23290,'도시가스비'),
    (uid,unit1,'2026-07-01',0.0,0,0,0,0,49480,0,'바디워시, 트리트먼트, 샴푸'),
    (uid,unit1,'2026-07-02',0.0,0,0,0,0,3590,0,'탐사 배수구 세정제'),
    (uid,unit1,'2026-07-03',0.0,0,0,0,0,22900,0,'하수구 악취 세정 서버'),
    (uid,unit1,'2026-07-03',0.0,0,0,0,0,1880,0,'USB to C 컨버터'),
    (uid,unit1,'2026-07-05',0.0,0,0,0,0,135410,0,'CCTV스티커, IoT콘센트, 샌디스크'),
    (uid,unit1,'2026-07-05',0.0,0,0,0,0,375760,0,'프로포즈 꽃, 가위, 풍선, 풍선펌프 등등'),
    (uid,unit1,'2026-07-07',0.0,0,0,0,55000,0,0,'24박 중간청소, 이정임청소비'),
    (uid,unit1,'2026-07-10',0.0,0,0,0,0,0,700000,'7월 월세'),
    (uid,unit1,'2026-07-10',0.0,0,0,0,0,25700,0,'스카치브라이트쓰리엠수세미, 홈스타 욕실용&곰팡이'),
    (uid,unit1,'2026-07-10',0.0,0,0,0,0,17860,0,'돌돌이 리필'),
    (uid,unit1,'2026-07-10',0.0,0,0,0,0,37900,0,'LED 프로포즈 will you merry me'),
    (uid,unit1,'2026-07-10',0.0,0,0,0,0,7080,0,'반지케이스 + 배송비'),
    (uid,unit1,'2026-07-11',0.0,0,0,0,0,4970,0,'듀얼 아이폰 갤럭시 USB 플러그'),
    (uid,unit1,'2026-07-12',0.0,0,0,0,0,27800,0,'외도민 비상구, 비상조명등, 일산화탄소경보기'),
    (uid,unit1,'2026-07-13',0.0,0,0,0,0,119000,0,'CCTV'),
    (uid,unit1,'2026-07-13',0.0,0,0,0,0,15500,0,'카카오퀵꽃배달'),
    (uid,unit1,'2026-07-13',0.0,0,0,0,0,10770,0,'프로포즈 사진인화'),
    (uid,unit1,'2026-07-13',0.0,0,0,0,0,0,23100,'SK텔레콤 통신비'),
    (uid,unit1,'2026-07-15',0.0,0,0,0,55000,0,0,'24박 중간청소2, 이정임청소비'),
    (uid,unit1,'2026-07-16',0.0,0,0,0,0,4440,0,'대형깔망'),
    (uid,unit1,'2026-07-19',0.0,0,0,0,0,1880,0,'USB to C 컨버터'),
    (uid,unit1,'2026-07-20',0.0,0,0,0,0,90000,0,'리빙박스 4개'),
    (uid,unit1,'2026-07-22',0.0,0,0,0,55000,0,0,'24박 종료, 이정임청소비'),
    (uid,unit1,'2026-07-22',0.0,0,0,0,0,29370,0,'홈매트'),
    (uid,unit1,'2026-07-22',0.0,0,0,0,0,20000,0,'물'),
    (uid,unit1,'2026-07-23',2.0,455000,365251,0,55000,0,0,'이정임청소비'),
    (uid,unit1,'2026-07-25',5.0,930000,732865,0,55000,0,0,'이정임청소비'),
    (uid,unit1,'2026-07-25',0.0,0,0,0,0,5000,0,''),
    (uid,unit1,'2026-07-26',0.0,0,0,1354890,0,0,0,'식당대리예약및프로포즈용품'),
    (uid,unit1,'2026-07-27',0.0,0,0,0,0,17800,0,'샴푸'),
    (uid,unit1,'2026-07-27',0.0,0,0,0,0,0,26710,'전기비'),
    (uid,unit1,'2026-07-27',0.0,0,0,0,0,0,23100,'전기비'),
    (uid,unit1,'2026-07-29',0.0,0,0,0,0,26990,0,'리빙박스'),
    (uid,unit1,'2026-07-29',0.0,0,0,0,0,21990,0,'두루마리 휴지'),
    (uid,unit1,'2026-07-30',0.0,0,0,17799,0,0,0,'샴푸대리구매'),
    (uid,unit1,'2026-07-30',0.0,0,0,0,0,68400,0,'마이크');

  insert into public.shorts_channels(user_id,name,platform,uploads,views,rpm,revenue,net_profit,roi,reinvest_ratio,monthly_target) values
    (uid,'자유의사업가','YouTube',142,8600000,320,0,0,0,100,1500000),
    (uid,'머니루틴','TikTok',98,4200000,90,0,0,0,100,1500000);

  insert into public.land_projects(user_id,name,analysis,catalyst,principal,target_price,expert_opinion,status,reserve_fund,target_fund) values
    (uid,'평택 고덕 인근','삼성 반도체 배후 수요','GTX 연장·산단 확장',180000000,320000000,'3년 내 2배 가능성, 보유 추천','holding',45000000,180000000),
    (uid,'새만금 인접지','개발 초기, 변동성 큼','국가산단·관광 개발',90000000,200000000,'장기 관점 접근','reviewing',10000000,90000000);

  insert into public.dividend_holdings(user_id,ticker,market,market_value,monthly_dividend,annual_dividend,reinvest_rate,monthly_target) values
    (uid,'SCHD','미장',42000000,150000,1800000,100,400000),(uid,'JEPI','미장',28000000,120000,1440000,80,300000),
    (uid,'O','미장',15000000,70000,840000,100,150000),(uid,'삼성전자우','국장',22000000,60000,720000,50,150000);

  insert into public.goals(user_id,title,target_value,current_value,unit,target_date,status,sort_order) values
    (uid,'월급 제외 월 현금흐름 1,000만원',10000000,1900000,'KRW',now()::date+interval '14 month','active',1),
    (uid,'에비 2호점 오픈',1,0,'count',now()::date+interval '2 month','active',2),
    (uid,'에비 3호점 오픈',1,0,'count',now()::date+interval '9 month','active',3),
    (uid,'방배 아파트 매수',1,0,'count',now()::date+interval '30 month','active',4),
    (uid,'순자산 15억',1500000000,842000000,'KRW',now()::date+interval '36 month','active',5);

  insert into public.tasks(user_id,title,module,due_date,done) values
    (uid,'에비2 인테리어 견적 3곳 비교','airbnb',now()::date,false),
    (uid,'숏폼 이번주 5개 업로드 확인','shorts',now()::date,false),
    (uid,'평택 토지 등기 서류 검토','land',now()::date,false),
    (uid,'SCHD 추가 매수','dividend',now()::date,true);

  insert into public.weekly_reviews(user_id,week_start,wins,misses,next_actions,freedom_score) values
    (uid,date_trunc('week',now())::date,'홍대포포 6월 순이익 최고치','토지 매도 지연','에비2 오픈 일정 확정',19)
  on conflict (user_id,week_start) do nothing;

  insert into public.allocations(user_id,pool,label,monthly_amount,sort_order) values
    (uid,'business','에비 2호 준비',4700000,1),(uid,'business','숏폼 운영',100000,2),(uid,'business','토지 투자',0,3),
    (uid,'salary','연금저축',800000,4),(uid,'salary','IRP',200000,5),(uid,'salary','비상금',400000,6),(uid,'salary','여행·취미',100000,7);

  insert into public.monthly_entries(user_id,category,month,amount) values
    (uid,'dividend',m0-interval '5 month',370000),(uid,'dividend',m0-interval '4 month',380000),
    (uid,'dividend',m0-interval '3 month',390000),(uid,'dividend',m0-interval '2 month',400000),
    (uid,'dividend',m0-interval '1 month',400000),(uid,'dividend',m0,400000),
    (uid,'shorts',m0-interval '3 month',0),(uid,'shorts',m0-interval '2 month',120000),
    (uid,'shorts',m0-interval '1 month',0),(uid,'shorts',m0,0);

  raise notice 'HY CAPITAL 클라우드 시드 완료';
end $$;
