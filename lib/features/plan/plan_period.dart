// 계획 기간을 «칸»으로 — 1주 계획은 매주(1주차·2주차 …), 1개월 계획은 매달,
// 3개월·6개월·1년·3년·5년도 각각 이어지는 칸이 10년치 있다.
//
// 칸은 계획을 시작한 날(가장 먼저 적은 계획)부터 센다.
//   1주   — 그 주 월요일부터 7일씩 (월~일)
//   1개월 — 그 달 1일부터 한 달씩. 3개월·6개월·1년·3년·5년·10년도 «달 수» 단위.
// 계획 한 줄이 어느 칸인지는 «그 칸 안의 아무 날»(period_start)로 정한다.

class PlanPeriods {
  PlanPeriods(DateTime start) : _start = DateTime(start.year, start.month, start.day);

  final DateTime _start;

  static const _months = {
    '1개월': 1,
    '3개월': 3,
    '6개월': 6,
    '1년': 12,
    '3년': 36,
    '5년': 60,
    '10년': 120,
  };

  static int _days(DateTime a, DateTime b) =>
      DateTime.utc(b.year, b.month, b.day)
          .difference(DateTime.utc(a.year, a.month, a.day))
          .inDays;

  DateTime get _week0 => _start.subtract(Duration(days: _start.weekday - 1));

  /// [d] 가 든 칸의 번호(0부터).
  int indexOf(String horizon, DateTime d) {
    final m = _months[horizon];
    if (m == null) {
      final monday = DateTime(d.year, d.month, d.day - (d.weekday - 1));
      return (_days(_week0, monday) / 7).floor();
    }
    final mb = (d.year - _start.year) * 12 + d.month - _start.month;
    return (mb / m).floor();
  }

  DateTime startOf(String horizon, int i) {
    final m = _months[horizon];
    if (m == null) return DateTime(_week0.year, _week0.month, _week0.day + 7 * i);
    return DateTime(_start.year, _start.month + i * m);
  }

  /// 칸의 마지막 날.
  DateTime endOf(String horizon, int i) {
    final m = _months[horizon];
    if (m == null) {
      final s = startOf(horizon, i);
      return DateTime(s.year, s.month, s.day + 6);
    }
    return DateTime(_start.year, _start.month + (i + 1) * m, 0);
  }

  /// 10년 안의 칸 수 — 1주는 약 522칸, 1개월은 120칸, 10년은 1칸.
  int count(String horizon) {
    final m = _months[horizon];
    if (m == null) {
      final end = DateTime(_start.year + 10, _start.month, _start.day);
      return _days(_week0, end) ~/ 7 + 1;
    }
    return 120 ~/ m;
  }

  int current(String horizon, [DateTime? today]) =>
      indexOf(horizon, today ?? DateTime.now()).clamp(0, count(horizon) - 1);

  /// «2주차» · «1개월차» · «1년차» · «2번째».
  String name(String horizon, int i) => switch (horizon) {
        '1주' => '${i + 1}주차',
        '1개월' => '${i + 1}개월차',
        '1년' => '${i + 1}년차',
        _ => '${i + 1}번째 $horizon',
      };

  /// «11/9 ~ 11/15» · «2026년 11월» · «26.11 ~ 27.01».
  String range(String horizon, int i) {
    final s = startOf(horizon, i), e = endOf(horizon, i);
    String yymm(DateTime d) =>
        '${(d.year % 100).toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';
    return switch (horizon) {
      '1주' => '${s.month}/${s.day} ~ ${e.month}/${e.day}',
      '1개월' => '${s.year}년 ${s.month}월',
      _ => '${yymm(s)} ~ ${yymm(e)}',
    };
  }

  /// «이번 주» · «이번 달» · «지금».
  static String nowWord(String horizon) =>
      horizon == '1주' ? '이번 주' : horizon == '1개월' ? '이번 달' : '지금';
}
