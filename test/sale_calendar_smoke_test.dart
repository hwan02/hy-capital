import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hy_capital/core/data/data_providers.dart';
import 'package:hy_capital/features/auction/sale_calendar_view.dart';
import 'package:hy_capital/models/models.dart';

void main() {
  SaleItem it(String id, DateTime d, {String? tag}) => SaleItem(
    id: id,
    zone: '신림5',
    caseNo: '2025타경102886',
    source: '경매',
    kind: '다세대',
    appraisal: 348000000,
    minPrice: 348000000,
    fails: 1,
    saleDate: d,
    address: '서울 관악구',
    tag: tag,
  );

  Future<void> pump(WidgetTester t, List<SaleItem> items, double width) async {
    await t.binding.setSurfaceSize(Size(width, 1200));
    await t.pumpWidget(
      ProviderScope(
        overrides: [saleItemsProvider.overrideWith((ref) async => items)],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: SaleCalendarView()),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('빈 달 · 넓은 화면', (t) async {
    await pump(t, [], 1200);
    expect(find.textContaining('물건이 없어요'), findsOneWidget);
  });

  testWidgets('물건 있는 달 · 격자', (t) async {
    final now = DateTime.now();
    await pump(t, [
      it('a', DateTime(now.year, now.month, 3), tag: '관심'),
      it('b', DateTime(now.year, now.month, 3)),
    ], 1200);
    expect(
      find.textContaining('2025타경102886', findRichText: true),
      findsNWidgets(2),
    );
    expect(find.text('관심'), findsWidgets);
  });

  testWidgets('좁은 화면 · 목록', (t) async {
    final now = DateTime.now();
    await pump(t, [it('a', DateTime(now.year, now.month, 3))], 400);
    expect(
      find.textContaining('2025타경102886', findRichText: true),
      findsOneWidget,
    );
  });
}
