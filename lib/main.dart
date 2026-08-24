import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/env.dart';
import 'core/data/data_providers.dart';
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
      // signInWithPassword 가 끝나도 supabase_flutter 는 REST 클라이언트의
      // Authorization 헤더를 내부 리스너(마이크로태스크)로 갱신한다. 그 전에
      // runApp 하면 첫 조회가 익명으로 나가 RLS 에 막혀 빈 화면이 뜬다.
      // Duration.zero 한 틱으로는 부족해서, 헤더에 토큰이 실제로 반영될 때까지
      // 짧게 기다린다(최대 2초). 그래도 안 되면 아래 _AuthRefresh 가 받아준다.
      final token = auth.currentSession?.accessToken;
      for (var i = 0; i < 40 && token != null; i++) {
        final h = Supabase.instance.client.rest.headers['Authorization'];
        if (h != null && h.contains(token)) break;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    } catch (_) {
      // 세션 확보 실패해도 앱은 실행 (연결/시드 전 상태).
    }
  }

  runApp(const ProviderScope(child: HyCapitalApp()));
}

class HyCapitalApp extends ConsumerStatefulWidget {
  const HyCapitalApp({super.key});

  @override
  ConsumerState<HyCapitalApp> createState() => _HyCapitalAppState();
}

class _HyCapitalAppState extends ConsumerState<HyCapitalApp> {
  StreamSubscription<AuthState>? _authSub;

  /// 이미 데이터를 읽어온 사용자 id. 같은 사용자로 다시 signedIn 이 와도
  /// 다시 읽지 않는다(탭 복귀 시 재발행되는 경우가 있다).
  String? _loadedFor;

  @override
  void initState() {
    super.initState();
    // 앱 시작 시 이미 세션이 있으면 그 사용자로 표시해 둔다 —
    // 곧바로 도착하는 signedIn 이벤트로 한 번 더 읽지 않게.
    _loadedFor = Supabase.instance.client.auth.currentSession?.user.id;
    // 로그인이 앱 시작 뒤에 완료되면(느린 네트워크 등) 첫 조회가 익명으로 나가
    // 빈 화면이 남는다. 세션이 «처음» 잡히는 순간에만 다시 읽는다.
    //
    // tokenRefreshed 로는 다시 읽지 않는다 — 토큰은 주기적으로, 그리고 탭에
    // 다시 들어올 때마다 갱신된다. 그때마다 invalidateAll 을 돌리면 화면
    // 전체가 로딩으로 깜빡인다(실제로 그랬다). 헤더는 클라이언트가 알아서
    // 바꾸므로 데이터를 다시 읽을 이유가 없다.
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((s) {
      if (s.event != AuthChangeEvent.signedIn) return;
      final uid = s.session?.user.id;
      if (uid == null || uid == _loadedFor) return; // 같은 사용자면 무시
      _loadedFor = uid;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) invalidateAll(ref);
      });
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'HY CAPITAL',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: router,
    );
  }
}
