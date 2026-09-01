import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/shell/app_shell.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/money_flow/money_flow_screen.dart';
import '../../features/airbnb/airbnb_screen.dart';
import '../../features/airbnb/airbnb_detail_screen.dart';
import '../../features/shorts/shorts_screen.dart';
import '../../features/land/land_screen.dart';
import '../../features/auction/auction_screen.dart';
import '../../features/auction/auction_detail_screen.dart';
import '../../features/knowledge/knowledge_screen.dart';
import '../../features/ipo/ipo_screen.dart';
import '../../features/property/visit_screen.dart';
import '../../features/questions/lecture_questions_screen.dart';
import '../../features/dividend/dividend_screen.dart';
import '../../features/goals/goals_screen.dart';
import '../../features/books/books_screen.dart';
import '../../features/custom/custom_module_screen.dart';
import '../supabase/supabase_providers.dart';

/// 셸 내부 페이지는 전환 애니메이션 없이 즉시 교체 (좌우 슬라이드 버그 방지).
Page<void> _noTransition(Widget child) =>
    NoTransitionPage<void>(child: child);

/// 인증 상태 변화를 GoRouter 에 알리는 리스너.
class _AuthNotifier extends ChangeNotifier {
  late final StreamSubscription _sub;
  _AuthNotifier(SupabaseClient sb) {
    _sub = sb.auth.onAuthStateChange.listen((_) => notifyListeners());
  }
  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final sb = ref.watch(supabaseProvider);
  final notifier = _AuthNotifier(sb);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: notifier,
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/dashboard', pageBuilder: (_, __) => _noTransition(const DashboardScreen())),
          GoRoute(path: '/money', pageBuilder: (_, __) => _noTransition(const MoneyFlowScreen())),
          GoRoute(path: '/airbnb', pageBuilder: (_, __) => _noTransition(const AirbnbScreen())),
          GoRoute(
            path: '/airbnb/:id',
            pageBuilder: (_, state) => _noTransition(
                AirbnbDetailScreen(unitId: state.pathParameters['id']!)),
          ),
          GoRoute(path: '/shorts', pageBuilder: (_, __) => _noTransition(const ShortsScreen())),
          GoRoute(path: '/land', pageBuilder: (_, __) => _noTransition(const LandScreen())),
          GoRoute(path: '/auction', pageBuilder: (_, __) => _noTransition(const AuctionScreen())),
          GoRoute(
            path: '/auction/:id',
            pageBuilder: (_, state) => _noTransition(
                AuctionDetailScreen(id: state.pathParameters['id']!)),
          ),
          GoRoute(path: '/knowledge', pageBuilder: (_, __) => _noTransition(const KnowledgeScreen())),
          GoRoute(path: '/ipo', pageBuilder: (_, __) => _noTransition(const IpoScreen())),
          GoRoute(
              path: '/visit/:id',
              pageBuilder: (_, st) => _noTransition(
                  VisitScreen(visitId: st.pathParameters['id']!))),
          GoRoute(path: '/questions', pageBuilder: (_, __) => _noTransition(const LectureQuestionsScreen())),
          GoRoute(path: '/dividend', pageBuilder: (_, __) => _noTransition(const DividendScreen())),
          GoRoute(path: '/books', pageBuilder: (_, __) => _noTransition(const BooksScreen())),
          GoRoute(path: '/goals', pageBuilder: (_, __) => _noTransition(const GoalsScreen())),
          GoRoute(
            path: '/m/:id',
            pageBuilder: (_, state) => _noTransition(
              CustomModuleScreen(moduleId: state.pathParameters['id']!),
            ),
          ),
        ],
      ),
    ],
  );
});
