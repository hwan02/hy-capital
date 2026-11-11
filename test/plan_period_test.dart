import 'package:flutter_test/flutter_test.dart';
import 'package:hy_capital/features/plan/plan_period.dart';

void main() {
  // 계획 시작 2026-11-05(목) — 1주차는 그 주 월요일 11/2 부터.
  final p = PlanPeriods(DateTime(2026, 11, 5));

  test('주 — 월~일 칸, 시작 주가 1주차', () {
    expect(p.indexOf('1주', DateTime(2026, 11, 2)), 0);
    expect(p.indexOf('1주', DateTime(2026, 11, 8)), 0);
    expect(p.indexOf('1주', DateTime(2026, 11, 9)), 1);
    expect(p.indexOf('1주', DateTime(2026, 11, 12)), 1);
    expect(p.name('1주', 1), '2주차');
    expect(p.range('1주', 1), '11/9 ~ 11/15');
    expect(p.startOf('1주', 9), DateTime(2027, 1, 4)); // 해가 바뀌어도
    expect(p.count('1주'), greaterThan(520));
  });

  test('달 — 시작한 달이 1개월차, 120칸', () {
    expect(p.indexOf('1개월', DateTime(2026, 11, 30)), 0);
    expect(p.indexOf('1개월', DateTime(2026, 12, 1)), 1);
    expect(p.indexOf('1개월', DateTime(2027, 11, 1)), 12);
    expect(p.range('1개월', 2), '2027년 1월');
    expect(p.endOf('1개월', 3), DateTime(2027, 2, 28));
    expect(p.count('1개월'), 120);
  });

  test('3개월·1년·5년·10년', () {
    expect(p.range('3개월', 0), '26.11 ~ 27.01');
    expect(p.indexOf('3개월', DateTime(2027, 2, 5)), 1);
    expect(p.name('1년', 1), '2년차');
    expect(p.range('1년', 0), '26.11 ~ 27.10');
    expect(p.count('5년'), 2);
    expect(p.count('10년'), 1);
    expect(p.indexOf('10년', DateTime(2036, 10, 31)), 0);
  });

  test('지금 칸 — 범위 밖이면 끝 칸에 붙는다', () {
    expect(p.current('1개월', DateTime(2026, 11, 12)), 0);
    expect(p.current('1개월', DateTime(2040, 1, 1)), 119);
    expect(p.current('1주', DateTime(2020, 1, 1)), 0);
  });
}
