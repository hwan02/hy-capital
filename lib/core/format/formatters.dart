import 'package:intl/intl.dart';

/// 통화/숫자 포맷 유틸 (원화 한국식 표기).
class Won {
  static final _comma = NumberFormat('#,###');

  /// 1,234,000 → "1,234,000원"
  static String plain(num v) => '${_comma.format(v.round())}원';

  /// 큰 금액을 억/만 단위로 압축. 842000000 → "8.42억"
  static String compact(num v) {
    final n = v.abs();
    final sign = v < 0 ? '-' : '';
    if (n >= 100000000) {
      final eok = n / 100000000;
      return '$sign${_trim(eok)}억';
    }
    if (n >= 10000) {
      final man = n / 10000;
      return '$sign${_trim(man)}만';
    }
    return '$sign${_comma.format(n.round())}';
  }

  /// 대시보드 KPI용: 앞에 통화 느낌 없이 압축값만.
  static String short(num v) => compact(v);

  static String _trim(double d) {
    // 소수 1자리, 정수면 소수 제거.
    final s = d.toStringAsFixed(d >= 100 ? 0 : 1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }
}

class Pct {
  static String of(num v, {int digits = 0}) => '${v.toStringAsFixed(digits)}%';
  static String signed(num v, {int digits = 1}) =>
      '${v >= 0 ? '+' : ''}${v.toStringAsFixed(digits)}%';
}

class Dates {
  static final _ymd = DateFormat('yyyy.MM.dd');
  static final _ym = DateFormat('yy.MM');
  static final _md = DateFormat('M월 d일');

  static String ymd(DateTime d) => _ymd.format(d);
  static String ym(DateTime d) => _ym.format(d);
  static String md(DateTime d) => _md.format(d);

  /// D-day: 미래면 "D-42", 지났으면 "D+3".
  static String dday(DateTime target) {
    final now = DateTime.now();
    final days = DateTime(target.year, target.month, target.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    if (days == 0) return 'D-DAY';
    return days > 0 ? 'D-$days' : 'D+${-days}';
  }
}
