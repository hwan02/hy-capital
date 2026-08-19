import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/env.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR', null);
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabaseAnonKey,
  );

  // 로그인 화면 없이 자동으로 세션 확보 (단일 사용자, 고정 계정).
  // 계정은 시드 SQL 이 미리 만들어 둔다 → 어느 기기에서든 같은 데이터.
  final auth = Supabase.instance.client.auth;
  if (auth.currentSession == null &&
      Env.autoEmail.isNotEmpty &&
      Env.autoPassword.isNotEmpty) {
    try {
      await auth.signInWithPassword(
        email: Env.autoEmail,
        password: Env.autoPassword,
      );
      // signInWithPassword 직후에는 supabase_flutter 가 REST 클라이언트의
      // Authorization 헤더를 아직 갱신하지 않은 상태일 수 있다(내부 리스너가
      // 마이크로태스크로 처리). 이 상태로 runApp 하면 첫 데이터 조회가 익명으로
      // 나가 RLS 에 막혀 빈 화면이 뜬다. 이벤트 루프를 한 틱 넘겨 헤더 갱신을
      // 확실히 반영한 뒤 앱을 띄운다.
      await Future<void>.delayed(Duration.zero);
    } catch (_) {
      // 세션 확보 실패해도 앱은 실행 (연결/시드 전 상태).
    }
  }

  runApp(const ProviderScope(child: HyCapitalApp()));
}

class HyCapitalApp extends ConsumerWidget {
  const HyCapitalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'HY CAPITAL',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: router,
    );
  }
}
