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
            body: CustomScrollView(slivers: [SaleCalendarView()]),
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

  // 들어오면 «보는 중»(관심·임장·입찰예정)만 — 「전체」를 눌러야 나머지가 보인다.
  Future<void> showAll(WidgetTester t) async {
    await t.tap(find.textContaining('전체 '));
    await t.pumpAndSettle();
  }

  testWidgets('들어오면 보는 중만 · 전체/미표시로 바꿔 본다', (t) async {
    final now = DateTime.now();
    final d = DateTime(now.year, now.month, 3);
    await pump(t, [
      it('a', d, tag: '관심'),
      it('b', d, tag: '임장'),
      it('c', d, tag: '입찰예정'),
      it('d', d, tag: '패스'),
      it('e', d),
    ], 1200);
    final cases = find.textContaining('2025타경102886', findRichText: true);
    expect(find.text('보는 중 3'), findsOneWidget);
    expect(cases, findsNWidgets(3));
    await showAll(t);
    expect(cases, findsNWidgets(5));
    await t.tap(find.text('미표시 1'));
    await t.pumpAndSettle();
    expect(cases, findsOneWidget);
  });

  testWidgets('보는 중이 없는 달 — 전체에서 표시하라고 알려 준다', (t) async {
    final now = DateTime.now();
    await pump(t, [it('a', DateTime(now.year, now.month, 3))], 1200);
    expect(find.textContaining('보는 중인 물건이 없어요'), findsOneWidget);
  });

  testWidgets('물건 있는 달 · 격자', (t) async {
    final now = DateTime.now();
    await pump(t, [
      it('a', DateTime(now.year, now.month, 3), tag: '관심'),
      it('b', DateTime(now.year, now.month, 3)),
    ], 1200);
    await showAll(t);
    expect(
      find.textContaining('2025타경102886', findRichText: true),
      findsNWidgets(2),
    );
    expect(find.text('관심'), findsWidgets);
  });

  testWidgets('좁은 화면 · 목록', (t) async {
    final now = DateTime.now();
    await pump(t, [it('a', DateTime(now.year, now.month, 3))], 400);
    await showAll(t);
    expect(
      find.textContaining('2025타경102886', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('칸을 누르면 상세·태그 창이 뜬다', (t) async {
    final now = DateTime.now();
    await pump(t, [it('a', DateTime(now.year, now.month, 3))], 1200);
    await showAll(t);
    await t.tap(find.textContaining('2025타경102886', findRichText: true).first);
    await t.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    final dialog = find.byType(AlertDialog);
    for (final tag in ['관심', '임장', '입찰예정', '패스']) {
      expect(find.descendant(of: dialog, matching: find.text(tag)), findsOneWidget);
    }
    expect(find.text('삭제'), findsOneWidget);
    expect(find.text('사건번호 복사'), findsOneWidget);
    expect(find.text('웹으로 열기'), findsOneWidget);
    expect(find.textContaining('오답노트 쓰기'), findsOneWidget);
    expect(find.text('저장'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  test('행크옥션 검색 주소 — 경매는 연도·번호로, 공매는 관리번호 그대로', () {
    expect(
      hankSearchUrl('2025타경9749'),
      'https://www.hauction.co.kr/search/auction?unique_year=2025&unique_number=9749&status=%EC%A0%84%EC%B2%B4%EB%B3%B4%EA%B8%B0',
    );
    expect(
      hankSearchUrl('2026-10740-004', source: '공매'),
      'https://www.hauction.co.kr/search/public-auction?unique_id=2026-10740-004&status=%EC%A0%84%EC%B2%B4%EB%B3%B4%EA%B8%B0',
    );
    // 적어 둔 링크가 있으면 그걸 쓴다.
    final it = SaleItem(
      id: 'x',
      zone: 'z',
      caseNo: '2025타경1',
      source: '경매',
      appraisal: 0,
      minPrice: 0,
      fails: 0,
      saleDate: DateTime(2026, 11, 3),
      url: 'https://www.hauction.co.kr/search/auction/1420766',
    );
    expect(hankUrlOf(it), 'https://www.hauction.co.kr/search/auction/1420766');
  });

  test('공매는 3일 입찰 — 월·화·수에 다 꽂히고 날마다 한 줄', () {
    final g = SaleItem(
      id: 'g',
      zone: '(가)독산4',
      caseNo: '2026-02835-001',
      source: '공매',
      appraisal: 217000000,
      minPrice: 173600000,
      fails: 0,
      saleDate: DateTime(2026, 12, 23),
    );
    expect(saleDaysOf(g), [DateTime(2026, 12, 21), DateTime(2026, 12, 22), DateTime(2026, 12, 23)]);
    expect(gongmaeDayNote(g, DateTime(2026, 12, 21)), '입찰 시작 14시 · 12/23 마감');
    expect(gongmaeDayNote(g, DateTime(2026, 12, 22)), '입찰 2일째 · 12/23 마감');
    expect(gongmaeDayNote(g, DateTime(2026, 12, 23)), '입찰 마감 17시');
    expect(saleDaysOf(it('a', DateTime(2026, 12, 23))), [DateTime(2026, 12, 23)]); // 경매는 하루
  });
}
