import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/env.dart';
import 'core/data/data_providers.dart';
import 'core/data/swr_client.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/save_key.dart';
import 'core/widgets/tab_dedupe.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 한글 글꼴을 «첫 화면 전에» 받는다(아래 준비와 동시에 시작).
  // 캐시로 데이터가 글꼴보다 먼저 그려지게 되자, 글꼴이 늦게 오면 글자 폭이 바뀌는데
  // IntrinsicHeight 가 옛 높이를 그대로 써서 경공매 달력 칸이 잘렸다
  // (Flutter 가 글꼴 변경 때 문단의 intrinsic 캐시를 안 지운다). 네모 글자도 안 보인다.
  // 글꼴이 2.5초 넘게 안 오면(처음 여는 기기·느린 망) 그냥 띄운다.
  GoogleFonts.notoSansKrTextTheme();
  final fonts = GoogleFonts.pendingFonts()
      .timeout(const Duration(milliseconds: 2500), onTimeout: () => const [])
      .catchError((_) => const <void>[]);
  await initializeDateFormatting('ko_KR', null);
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabaseAnonKey,
    // 읽기는 지난번에 받은 것을 먼저 보여 주고 뒤에서 새로 받는다(swr_client.dart).
    httpClient: SwrClient(),
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
      // 여기서 더 기다리지 않는다. 예전엔 REST 헤더에 토큰이 들어올 때까지
      // 최대 2초를 돌았는데, 지금 supabase 는 요청마다 currentSession 에서
      // 토큰을 꺼내 쓴다(AuthHttpClient) — 헤더는 끝내 안 바뀌어서 새 기기의
      // 첫 화면이 매번 2초씩 늦었다(2026-11-11 측정).
    } catch (_) {
      // 세션 확보 실패해도 앱은 실행 (연결/시드 전 상태).
    }
  }

  await fonts;
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
    // 저장해 둔 것을 먼저 보여 준 뒤 서버 내용이 달랐다 — 다시 읽힌다
    // (이때는 방금 받은 것을 쓰므로 조회가 또 나가지 않는다).
    SwrClient.onChanged = () {
      if (mounted) invalidateAll(ref);
    };
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
      // 팝업 폼에서 한글 입력 후 Tab 이 두 칸 넘어가는 것 방지.
      builder: (context, child) =>
          TabDedupe(child: SaveKeyScope(child: child!)),
    );
  }
}
