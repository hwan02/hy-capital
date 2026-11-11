import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hy_capital/core/data/data_providers.dart';
import 'package:hy_capital/features/plan/plan_screen.dart';
import 'package:hy_capital/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

PlanItem p(String id, String title, {String? detail, String? note, bool done = false}) => PlanItem(
      id: id,
      horizon: '1주',
      track: '재무',
      title: title,
      detail: detail,
      done: done,
      sortOrder: 0,
      note: note,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final w in [1280.0, 390.0]) {
    testWidgets('할 일을 누르면 «적기» 창 — 제목이 질문 · 적은 건 밑에 보인다 · 폭 $w', (t) async {
      await t.binding.setSurfaceSize(Size(w, 2400));
      await t.pumpWidget(ProviderScope(
        overrides: [
          planItemsProvider.overrideWith((ref) async => [
                p('a', '월 현금흐름이 어디서 나올지 3줄 적기', detail: '에비, 공간 사업, 월세, 배당 같은 거.'),
                p('b', '가고 싶은 곳 10개 먼저 적기', note: '아이슬란드\n파타고니아'),
              ]),
          assetsProvider.overrideWith((ref) async => <Asset>[]),
          moduleIncomeByMonthProvider.overrideWith((ref) async => <String, Map<String, double>>{}),
        ],
        child: const MaterialApp(home: Scaffold(body: PlanScreen())),
      ));
      await t.pumpAndSettle();
      expect(find.text('아이슬란드\n파타고니아'), findsOneWidget); // 적은 것
      expect(find.text('적기'), findsOneWidget); // 안 적은 것엔 «적기»

      await t.tap(find.text('월 현금흐름이 어디서 나올지 3줄 적기'));
      await t.pumpAndSettle();
      expect(find.widgetWithText(TextField, '내가 적은 것'), findsOneWidget);
      expect(find.text('월 현금흐름이 어디서 나올지 3줄 적기'), findsWidgets); // 창 제목
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('1주 계획은 주마다 따로 — 다음 주는 비어 있고, 앞 칸에서 가져올 수 있다', (t) async {
    await t.binding.setSurfaceSize(const Size(1280, 2400));
    final today = DateTime.now();
    final nextWeek = today.add(const Duration(days: 7));
    PlanItem w(String id, String title, DateTime day, {bool done = false}) => PlanItem(
          id: id,
          horizon: '1주',
          track: '재무',
          title: title,
          done: done,
          sortOrder: 0,
          periodStart: day,
          createdAt: today,
        );
    await t.pumpWidget(ProviderScope(
      overrides: [
        planItemsProvider.overrideWith((ref) async => [
              w('a', '이번 주 할 일', today),
              w('b', '이번 주 끝낸 일', today, done: true),
              w('c', '다음 주 할 일', nextWeek),
            ]),
        assetsProvider.overrideWith((ref) async => <Asset>[]),
        moduleIncomeByMonthProvider.overrideWith((ref) async => <String, Map<String, double>>{}),
      ],
      child: const MaterialApp(home: Scaffold(body: PlanScreen())),
    ));
    await t.pumpAndSettle();
    expect(find.text('이번 주 할 일'), findsOneWidget);
    expect(find.text('다음 주 할 일'), findsNothing);
    expect(find.text('이번 주'), findsOneWidget); // 지금 칸 표시

    await t.tap(find.byTooltip('다음 칸'));
    await t.pumpAndSettle();
    expect(find.text('다음 주 할 일'), findsOneWidget);
    expect(find.text('이번 주 할 일'), findsNothing);
    expect(find.text('이번 주로'), findsOneWidget);

    await t.tap(find.byTooltip('다음 칸'));
    await t.pumpAndSettle();
    expect(find.text('이 칸에 적힌 계획이 없습니다'), findsOneWidget);
    expect(find.textContaining('앞 칸에서 가져오기 — 안 끝난 일 1개'), findsOneWidget);

    await t.tap(find.text('이번 주로'));
    await t.pumpAndSettle();
    expect(find.text('이번 주 할 일'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
