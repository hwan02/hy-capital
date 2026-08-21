# HY CAPITAL

개인 CFO 앱. Flutter 웹 + Supabase, Vercel 배포(https://hy-capital.vercel.app). 사용자 혼자 쓴다.

## 절대 규칙

- **글자 크기는 `AppFont.*` 토큰만 쓴다.** 임의 숫자(`13`, `14.5`) 금지 — `lib/core/theme/app_theme.dart:44`.
  `hero 34 · display 22 · title 18 · section 16 · body 14 · label 12.5 · caption 11.5 · micro 10.5`
- **마이그레이션은 사용자가 Supabase SQL Editor에서 직접 실행한다.** `supabase/migrations/`에 파일을 만들고 실행을 부탁한다. 실행됐다고 가정하지 않는다.
- **공개 저장소다** (github.com/hwan02/hy-capital). 비밀번호·이메일·토큰을 코드나 커밋에 넣지 않는다. 시크릿은 `String.fromEnvironment` + `env.local.json`(gitignore) + Vercel 환경변수.
- 사용자 회사(한샘) 관련 내용은 이 저장소에 넣지 않는다.

## 새 화면을 만들 때

화면은 `ModulePage`로 감싼다 (`lib/core/widgets/module_page.dart:9`) — `title` · `icon` · `color` · `action`(헤더 버튼) · `fab`(우하단 고정, 페이지가 길 때) · `children`.

**새 위젯을 쓰기 전에 이미 있는 것을 찾는다:**

| 필요한 것 | 쓸 것 | 위치 |
|---|---|---|
| 카드 | `GlassCard` | `lib/core/widgets/common.dart:7` |
| 섹션 제목(+trailing) | `SectionHeader` | `common.dart:44` |
| 작은 배지 | `Pill` | `common.dart:194` |
| 진행바 | `ProgressBar` | `common.dart:167` |
| 빈 상태 | `EmptyState` | `common.dart:220` |
| 로딩/에러 | `AsyncStatus.loading` / `.error` | `common.dart:248` |
| 추가 버튼 | `AddButton` | `lib/core/edit/builtin_crud.dart:55` |
| 카드 수정/삭제 메뉴 | `RecordMenu` | `builtin_crud.dart:81` |
| 반응형 그리드 | `ResponsiveGrid` | `module_page.dart:114` |
| 월별 추이 | `MonthlyTracker` | `lib/core/widgets/monthly_tracker.dart:16` |

**포맷:** 금액 표시는 `Won.compact` (`lib/core/format/formatters.dart:4`), D-day는 `Dates.dday` (`formatters.dart:41`), "4.5억"·"45,000만"·"760800000" 파싱은 `parseWon` (`lib/core/format/won_parse.dart`).

**금액 «입력»은 `MoneyField` 만 쓴다** (`lib/core/widgets/money_field.dart`). `TextField`를 직접 쓰지 않는다 — 콤마 자동 삽입과 오른쪽 한글 환산(«1,000만원»)이 앱 전체에서 같아야 한다. 촘촘한 곳은 `dense: true`.

## 데이터

- Riverpod. 프로바이더는 `lib/core/data/data_providers.dart`. **쓰기 후 `invalidateAll(ref)`** (`data_providers.dart:544`).
- 모델은 `lib/models/models.dart`. Supabase 컬럼은 snake_case, Dart는 camelCase — `fromMap`에서 변환.
- **편집 폼은 화면에 직접 만들지 않는다.** `BuiltinSpec`에 필드를 선언하고(`lib/core/edit/builtin_specs.dart:6`) `editBuiltinRecord(context, ref, spec)` / `deleteBuiltinRecord(...)`를 호출한다. 필드 타입은 `FieldSpec`(`lib/core/edit/field_spec.dart:63`) — `text·longtext·number·money·percent·date·boolean·select`.
- 새 테이블은 RLS 필수. 기존 마이그레이션의 `own - select/insert/update/delete` 정책을 복사한다.

## Flutter 웹 함정 (실제로 물린 것들)

- `launchUrl`에 **`webOnlyWindowName: '_blank'`** 를 넣지 않으면 새 탭이 안 열린다.
- **가로 스크롤을 쓰지 않는다.** 스와이프가 브라우저 뒤로가기로 먹힌다. 칩·태그·필터는 `Wrap`.
- `PopupMenuButton`은 `icon`과 `child`를 **동시에** 줄 수 없다 (assert).
- 한글은 `main.dart.js`에서 `\uXXXX`로 나온다 — 배포 검증 시 문자열 grep이 안 된다.
- 브라우저가 이전 JS 모듈을 캐시해서 "안 고쳐졌다"로 보일 수 있다. 캐시 삭제 후 새로고침으로 확인한다.
- 미리보기 브라우저는 팝업을 막는다 — **링크 열림은 검증할 수 없다.** 확인 못 했다고 말한다.

## 배포

`vercel.json` → `bash build.sh`. **`buildCommand`는 256자 제한**이라 인라인 금지, 반드시 스크립트에 위임한다.
`main`에 푸시하면 Vercel이 자동 배포한다. `build.sh`가 Flutter를 클론하고 `--dart-define`으로 시크릿을 주입한다.

배포·검증 절차는 `/hy-ship` 스킬을 쓴다.

## 도메인 (사용자 맥락)

`knowledge/*.json` = 자료실 원본. **화면 방향을 정하기 전에 여기를 먼저 읽는다** — 사용자가 확정해둔 투자 전략과 자금 조건이 여기 있고, 앱이 그것과 어긋나 있는 경우가 실제로 있었다. 앱에서는 **경매 → 자료실** 탭.

새 자료를 넣을 때는 `/hy-knowledge`, 메뉴 방향을 잡을 때는 `/hy-plan`.
