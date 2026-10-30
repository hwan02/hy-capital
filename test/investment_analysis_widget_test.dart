import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hy_capital/core/data/data_providers.dart';
import 'package:hy_capital/features/auction/investment_analysis_tab.dart';
import 'package:hy_capital/models/models.dart';

AuctionProperty get property => AuctionProperty.fromMap({
  'id': 'candidate-a', 'title': '검증용 물건', 'min_price': 100000000,
  'deposit': 20000000, 'expected_sale_price': 0,
});

Future<void> showTab(WidgetTester tester, {List<CalcRecord> records = const [], double width = 1100}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ProviderScope(overrides: [
    calcRecordsProvider.overrideWith((ref) async => records),
    profileProvider.overrideWith((ref) async => null),
  ], child: MaterialApp(theme: ThemeData.dark(),
    home: Scaffold(body: InvestmentAnalysisTab(property: property)))));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('신규 물건은 감정가/미입력 세율로 추천하지 않음, 좁은 화면도 표시', (tester) async {
    await showTab(tester, width: 390);
    expect(find.text('입력 필요'), findsOneWidget);
    expect(find.text('입찰 검토'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('다른 물건의 분석 이력을 섞어 불러오지 않음', (tester) async {
    await showTab(tester, records: [CalcRecord(id: 'foreign', label: '다른 물건',
      createdAt: DateTime(2026, 10, 30), inputs: {
        '_kind': 'investment', 'property_id': 'candidate-b',
        'analysis': {'version': 99},
      })]);
    expect(find.text('새 분석 초안'), findsOneWidget);
    expect(find.text('입력 필요'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('다른 물건ID의 조사 JSON은 가져오기 거부, 초안 유지', (tester) async {
    await showTab(tester);
    await tester.tap(find.text('조사 결과 가져오기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), jsonEncode({'property_id': 'candidate-b'}));
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.textContaining('다른 물건 결과예요'), findsOneWidget);
    expect(find.text('새 분석 초안'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
