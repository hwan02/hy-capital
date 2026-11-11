import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hy_capital/core/data/data_providers.dart';
import 'package:hy_capital/features/auction/sale_calendar_view.dart';
import 'package:hy_capital/features/auction/sale_review.dart';
import 'package:hy_capital/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _today = DateTime(2026, 11, 8);

SaleItem item(
  String id, {
  DateTime? sale,
  String? tag,
  double? guess,
  String? result,
  double? sold,
  int? bidders,
  double? second,
  List<String> reasons = const [],
  String? why,
  DateTime? reviewOn,
  String? verdict,
  String zone = '화곡',
}) =>
    SaleItem(
      id: id,
      zone: zone,
      caseNo: '2025타경10958',
      source: '경매',
      kind: '다세대',
      appraisal: 340000000,
      minPrice: 217600000,
      fails: 3,
      saleDate: sale ?? DateTime(2026, 8, 6),
      tag: tag,
      guessPrice: guess,
      result: result,
      soldPrice: sold,
      bidders: bidders,
      secondPrice: second,
      reasons: reasons,
      why: why,
      reviewOn: reviewOn,
      verdict: verdict,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('단계', () {
    test('태그도 노트도 없으면 오답노트에 안 들어온다', () {
      expect(reviewStageOf(item('a'), _today), isNull);
    });
    test('패스는 노트를 쓴 것만 — 120건이 «결과 넣기»에 쌓이지 않게', () {
      expect(reviewStageOf(item('a', sale: DateTime(2026, 12, 1), tag: '패스'), _today), isNull);
      expect(reviewStageOf(item('a', tag: '패스'), _today), isNull);
      expect(reviewStageOf(item('a', tag: '패스', guess: 230000000), _today),
          ReviewStage.awaitingResult);
    });
    test('매각 전 관심 → 매각 전, 매각일 당일도 매각 전', () {
      expect(reviewStageOf(item('a', sale: DateTime(2026, 12, 1), tag: '관심'), _today),
          ReviewStage.upcoming);
      expect(reviewStageOf(item('a', sale: _today, tag: '관심'), _today), ReviewStage.upcoming);
    });
    test('결과 → 분석 → 다시 볼 날 → 판정', () {
      expect(reviewStageOf(item('a', result: '낙찰', sold: 263100000), _today),
          ReviewStage.needsAnalysis);
      expect(
          reviewStageOf(
              item('a', result: '낙찰', sold: 263100000, reasons: ['경쟁 과열'],
                  reviewOn: DateTime(2026, 12, 1)),
              _today),
          ReviewStage.waiting);
      expect(
          reviewStageOf(
              item('a', result: '낙찰', sold: 263100000, why: '6명', reviewOn: _today),
              _today),
          ReviewStage.reviewDue);
      expect(
          reviewStageOf(
              item('a', result: '낙찰', sold: 263100000, why: '6명', reviewOn: _today,
                  verdict: '맞았다'),
              _today),
          ReviewStage.done);
    });
  });

  test('통계 — 낙찰가율·예상 오차·구역별·이유', () {
    final s = ReviewStats.of([
      item('a', result: '낙찰', sold: 272000000, guess: 255000000, bidders: 6,
          reasons: ['경쟁 과열', '구역 기대감']), // 80%, 예상 +6.7%
      item('b', result: '낙찰', sold: 238000000, guess: 245000000, bidders: 2,
          reasons: ['경쟁 과열'], zone: '신림5'), // 70%, 예상 −2.9%
      item('c', result: '유찰', reasons: ['인수 부담'], verdict: '틀렸다'),
    ]);
    expect(s.sold, 2);
    expect(s.avgRate, closeTo(0.75, 1e-9));
    expect(s.avgBidders, 4);
    expect(s.errorN, 2);
    expect(s.avgError! > 0, isTrue); // 평균적으로 낮게 봤다
    expect(s.byZone.map((z) => z.key), containsAll(['화곡', '신림5']));
    expect(s.byReason.first.key, '경쟁 과열');
    expect(s.byReason.first.n, 2);
    expect(s.verdicts['틀렸다'], 1);
  });

  Future<void> pump(WidgetTester t, List<SaleItem> items, double width) async {
    await t.binding.setSurfaceSize(Size(width, 2400));
    await t.pumpWidget(ProviderScope(
      overrides: [saleItemsProvider.overrideWith((ref) async => items)],
      child: const MaterialApp(
        home: Scaffold(body: CustomScrollView(slivers: [SaleCalendarView()])),
      ),
    ));
    await t.pumpAndSettle();
  }

  for (final w in [1280.0, 390.0]) {
    testWidgets('오답노트 토글 → 단계별 목록 · 폭 $w', (t) async {
      await pump(t, [
        item('a', tag: '관심'), // 결과 넣기
        item('b', result: '낙찰', sold: 263100000, bidders: 6, second: 261920000,
            guess: 250000000, reasons: ['경쟁 과열'], why: '4차라 몰렸다',
            reviewOn: DateTime(2026, 11, 1)), // 다시 볼 날 됨
        item('c', sale: DateTime(2027, 1, 5), tag: '임장'), // 매각 전
      ], w);
      expect(find.text('오답노트 2'), findsOneWidget);
      await t.tap(find.text('오답노트 2'));
      await t.pumpAndSettle();
      expect(find.textContaining('다시 볼 날 됨 1'), findsOneWidget);
      expect(find.textContaining('결과 넣기 1'), findsOneWidget);
      expect(find.textContaining('매각 전 1'), findsOneWidget);
      expect(find.textContaining('예상보다 +5.2%'), findsOneWidget);
      // 매각 전 물건 — 같은 구역 기록으로 본 낙찰가율(77.4%)
      expect(find.textContaining('기록으로 보면 감정가의 77.4%'), findsWidgets);
      expect(t.takeException(), isNull);

      await t.tap(find.text('분석'));
      await t.pumpAndSettle();
      expect(find.text('평균 낙찰가율'), findsOneWidget);
      expect(find.text('유찰 횟수별'), findsOneWidget);
      expect(find.text('유찰 3회+'), findsOneWidget);
      expect(find.text('5명+'), findsOneWidget);
      expect(find.textContaining('낙찰 기록 1'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }

  for (final w in [1280.0, 390.0]) {
    testWidgets('오답노트 창 — 낙찰가를 넣으면 비교가 나오고, 저장하면 patch · 폭 $w', (t) async {
      await t.binding.setSurfaceSize(Size(w, 1400));
      Map<String, dynamic>? patch;
      var closed = false;
      final it = item('a', guess: 250000000);
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () async {
                patch = await showSaleReviewSheet(ctx, it);
                closed = true;
              },
              child: const Text('열기'),
            ),
          ),
        ),
      ));
      await t.tap(find.text('열기'));
      await t.pumpAndSettle();
      expect(find.textContaining('감정가의 73.5%'), findsOneWidget); // 2.5억/3.4억

      await t.tap(find.text('낙찰'));
      await t.pumpAndSettle();
      await t.enterText(find.widgetWithText(TextField, '낙찰가'), '263100000');
      await t.enterText(find.widgetWithText(TextField, '응찰자'), '6');
      await t.pumpAndSettle();
      expect(find.textContaining('낙찰가율 77.4%'), findsOneWidget);
      expect(find.textContaining('내 예상보다 +5.2%'), findsOneWidget);
      // 자동 분석 — 유찰 3회 → 최저가 64% → 응찰 6명 몰림
      expect(find.text('자동 분석'), findsOneWidget);
      expect(find.textContaining('유찰 3회로 최저가가 감정가의 64.0%'), findsOneWidget);
      expect(find.textContaining('응찰 6명 — 몰렸다'), findsOneWidget);
      // 추천 이유 + 글 한 번에 넣기
      final fill = find.textContaining('넣기');
      await t.ensureVisible(fill);
      await t.tap(fill);
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('저장'));
      await t.tap(find.text('저장'));
      await t.pumpAndSettle();
      expect(closed, isTrue);
      expect(patch!['result'], '낙찰');
      expect(patch!['sold_price'], 263100000);
      expect(patch!['bidders'], 6);
      expect(patch!['reasons'], containsAll(['경쟁 과열', '유찰 누적']));
      expect(patch!['why'], contains('응찰 6명'));
      // 다시 볼 날을 안 골랐으면 매각일 +90일
      expect(patch!['review_on'], '2026-11-04');
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('쓰다가 닫아도 임시저장 → 다시 열면 채워진다', (t) async {
    await t.binding.setSurfaceSize(const Size(1280, 1400));
    final it = item('a');
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => TextButton(
            onPressed: () => showSaleReviewSheet(ctx, it),
            child: const Text('열기'),
          ),
        ),
      ),
    ));
    await t.tap(find.text('열기'));
    await t.pumpAndSettle();
    await t.tap(find.text('유찰'));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextField, '왜 이 가격에 낙찰됐나'), '2위와 118만 차이');
    await t.pump(const Duration(seconds: 3));
    await t.tap(find.text('닫기'));
    await t.pumpAndSettle();

    await t.tap(find.text('열기'));
    await t.pumpAndSettle();
    expect(find.text('2위와 118만 차이'), findsOneWidget);
    expect(find.textContaining('임시저장된 내용을 불러왔습니다'), findsOneWidget);
    await t.tap(find.text('닫기'));
    await t.pumpAndSettle();
  });

  testWidgets('매각 전엔 ① 내 예상만 — 결과 칸은 «지금 열기»로', (t) async {
    await t.binding.setSurfaceSize(const Size(390, 1400));
    final it = item('a', sale: DateTime.now().add(const Duration(days: 5)), tag: '관심');
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => TextButton(
            onPressed: () => showSaleReviewSheet(ctx, it, history: [
              item('h', result: '낙찰', sold: 263100000), // 같은 구역 77.4%
            ]),
            child: const Text('열기'),
          ),
        ),
      ),
    ));
    await t.tap(find.text('열기'));
    await t.pumpAndSettle();
    expect(find.text('내 예상 낙찰가'), findsOneWidget);
    expect(find.textContaining('기록으로 보면 감정가의 77.4%'), findsOneWidget);
    expect(find.text('낙찰'), findsNothing);
    await t.tap(find.text('지금 열기'));
    await t.pumpAndSettle();
    expect(find.text('낙찰'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.tap(find.text('닫기'));
    await t.pumpAndSettle();
  });

  test('자동 분석 — 단독·박빙·감정가 초과', () {
    final it = item('x');
    final a = autoAnalysis(it: it, sold: 350000000, bidders: 1, second: 0);
    expect(a.tags, containsAll(['관심 적음', '구역 기대감']));
    final b = autoAnalysis(it: it, sold: 263100000, bidders: 3, second: 262000000);
    expect(b.lines.any((l) => l.contains('박빙')), isTrue);
  });
}
