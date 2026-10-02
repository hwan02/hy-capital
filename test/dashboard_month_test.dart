// 대시보드 「자금 흐름」 카드가 «어느 달»을 보여주나.
//
// 10월 에어비앤비 정산을 넣었는데 카드가 9월에 머물렀다. 기준 달을
// «수동 기록»에서만 뽑고 모듈 수익(에어비앤비·배당·숏폼·토지)은
// 달 판정에서 빠져 있었기 때문이다.
import 'package:flutter_test/flutter_test.dart';

/// dashboard_screen 의 기준 달 계산과 «같은 규칙».
DateTime? latestMonth({
  required List<DateTime> manualDates,
  required Map<String, Map<String, double>> moduleByMonth,
}) {
  DateTime? latest;
  void bump(DateTime m) {
    if (latest == null || m.isAfter(latest!)) latest = m;
  }
  for (final d in manualDates) {
    bump(DateTime(d.year, d.month));
  }
  moduleByMonth.forEach((k, v) {
    if (v.values.any((x) => x != 0)) bump(DateTime.parse(k));
  });
  return latest;
}

void main() {
  final sep = DateTime(2026, 9);
  final oct = DateTime(2026, 10);

  test('★ 수동 기록은 9월까지인데 10월 에어비앤비가 들어오면 → 10월', () {
    final m = latestMonth(
      manualDates: [DateTime(2026, 9, 25)],
      moduleByMonth: {
        '2026-09-01': {'에어비앤비': 1200000, '배당': 0},
        '2026-10-01': {'에어비앤비': 1500000, '배당': 0},
      },
    );
    expect(m, oct);
  });

  test('모듈 수익이 없으면 수동 기록 기준 그대로', () {
    final m = latestMonth(
      manualDates: [DateTime(2026, 9, 25)],
      moduleByMonth: const {},
    );
    expect(m, sep);
  });

  test('수동 기록이 더 늦으면 그쪽을 쓴다 — 둘 중 «늦은 쪽»', () {
    final m = latestMonth(
      manualDates: [DateTime(2026, 10, 2)],
      moduleByMonth: {
        '2026-09-01': {'에어비앤비': 1200000},
      },
    );
    expect(m, oct);
  });

  test('값이 0인 달은 «데이터 있는 달»로 치지 않는다', () {
    // 10월 칸이 0 으로 미리 만들어져 있어도 그 달로 넘어가면 안 된다.
    final m = latestMonth(
      manualDates: [DateTime(2026, 9, 25)],
      moduleByMonth: {
        '2026-09-01': {'에어비앤비': 1200000},
        '2026-10-01': {'에어비앤비': 0, '배당': 0, '숏폼': 0, '토지': 0},
      },
    );
    expect(m, sep);
  });

  test('아무 데이터도 없으면 null', () {
    expect(latestMonth(manualDates: const [], moduleByMonth: const {}), isNull);
  });
}
