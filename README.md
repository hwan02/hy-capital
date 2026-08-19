# HY CAPITAL

> 월급이 아닌 **현금흐름**으로 경제적 자유를 달성하도록 돕는 개인 CFO 운영체제.

Flutter(웹·iOS·Android·macOS) + Supabase(PostgreSQL·Auth·Edge Functions)로 구현한
개인 재무 운영 대시보드. 기획서 `HY_CAPITAL 제품기획서 v1.0`의 9개 모듈을 실제 동작하는 앱으로 구현했다.

## 모듈 (기획서 대응)

| # | 모듈 | 내용 |
|---|------|------|
| ① | **Dashboard** | Freedom Score, 순자산·현금·월급제외 현금흐름, KPI 그리드, 현금흐름 추이 차트, 다음 목표, 사업 엔진 현황, 오늘 할 일 |
| ② | **Money Flow** | 자금 흐름 원장 (월급→생활비, 사업수익→확장, 배당→재투자 …) |
| ③ | **Airbnb** | 에어비앤비 확장 로드맵 — 호점별 준비금·진행률·ROI·점유율 |
| ④ | **Shorts** | 숏폼 KPI — 채널·업로드·조회수·RPM·매출·순이익·재투자율 |
| ⑤ | **Land** | 토지 투자 프로젝트 — 원금·목표매도가·개발호재·전문가 의견 |
| ⑥ | **Dividend** | 배당 성장 관리 — 종목별 평가금·월/연배당·배당률·재투자율 |
| ⑦ | **Goals** | 목표 마일스톤 — 진행률·D-day |
| ⑧ | **Weekly Review** | 주간 리뷰 — 잘한 것/아쉬운 것/다음 액션 |
| ⑨ | **AI CFO** | 매일 자동 분석 — 현재 속도, 목표 달성 예상일, 에비/토지/ETF/숏폼 추천 |

## 기술 스택

- **Frontend**: Flutter + Riverpod(상태) + go_router(라우팅) + fl_chart(차트)
- **Backend**: Supabase — PostgreSQL(+RLS), Auth, Edge Functions(Deno)
- **AI**: OpenAI API (선택) — 미설정 시 규칙 기반 분석으로 폴백

> 기획서는 차트에 ECharts를 제안했으나, Flutter 네이티브 렌더링을 위해 동등한 `fl_chart`로 대체.

## 빠른 시작

### 1. Supabase 로컬 기동 (Docker 필요)

```bash
supabase start          # 스키마 마이그레이션 + 시드 자동 적용
supabase functions serve --no-verify-jwt   # AI CFO 엣지 함수 (별도 터미널)
```

### 2. 앱 실행

```bash
flutter pub get
flutter run -d chrome    # 또는 web-server / ios / android / macos
```

기본값은 로컬 Supabase(`http://127.0.0.1:54321`)를 가리킨다.

### 데모 계정 (자동 로그인)

계정 정보는 소스에 넣지 않는다. 로컬은 `env.local.json`, 배포는 빌드 시 dart-define 으로 주입한다.

```jsonc
// env.local.json  (git 제외)
{ "AUTO_EMAIL": "you@example.com", "AUTO_PASSWORD": "your-password" }
```

```bash
flutter run --dart-define-from-file=env.local.json
flutter build web --release --dart-define-from-file=env.local.json
```

계정은 아래 시드 SQL 이 만든다(비밀번호는 실행 전 직접 변경).

시드 데이터(6개월 재무 스냅샷, 에비 3호점, 숏폼 2채널, 토지 2건, 배당 4종목, 목표 5개 등)가 미리 들어 있다.

## 배포용 설정

원격 Supabase / OpenAI 사용 시 `--dart-define`으로 주입:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<project>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<publishable-key>
```

Edge Function에 OpenAI 연동:

```bash
supabase secrets set OPENAI_API_KEY=sk-...
supabase functions deploy ai-cfo
```

## 구조

```
lib/
  core/            # config, theme, router, supabase, format, 공통 위젯, data providers
  models/          # 도메인 모델 (Supabase row 파싱)
  features/
    auth/          # 로그인/회원가입
    shell/         # 반응형 네비게이션 셸 (9개 모듈)
    dashboard/ money_flow/ airbnb/ shorts/ land/ dividend/ goals/ weekly/ ai_cfo/
supabase/
  migrations/0001_init.sql   # 11개 테이블 + RLS + 트리거
  seed.sql                   # 데모 계정 + 시드 데이터
  functions/ai-cfo/          # AI CFO 분석 엣지 함수
```

## 보안

- 모든 테이블에 **RLS** 적용 — 사용자는 자신의 데이터(`auth.uid()`)만 조회/수정.
- 신규 가입 시 트리거로 `profiles` 자동 생성.
