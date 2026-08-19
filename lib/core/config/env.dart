/// 환경 설정. 기본값은 클라우드 Supabase → 로컬 실행이든 배포본이든 같은 DB.
/// (도커 로컬 Supabase 는 더 이상 사용하지 않음)
/// anon key 는 공개용(publishable)이라 소스에 포함해도 안전 — 접근 제어는 RLS.
/// 필요 시 --dart-define 으로 다른 프로젝트를 가리킬 수 있다.
class Env {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://rbksmjnfaqglnzypgxqa.supabase.co',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJia3Ntam5mYXFnbG56eXBneHFhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU3MzIzNTMsImV4cCI6MjEwMTMwODM1M30.v7a-ZkdHr0neEwRuZBveCROrs6J80bVeBFd2jN4LGUI',
  );

  /// 자동 로그인 계정 — 소스에 넣지 않는다(공개 repo 대비).
  /// 로컬: env.local.json + `--dart-define-from-file=env.local.json`
  /// 배포: `flutter build web --dart-define-from-file=env.local.json`
  static const autoEmail = String.fromEnvironment('AUTO_EMAIL');
  static const autoPassword = String.fromEnvironment('AUTO_PASSWORD');
}
