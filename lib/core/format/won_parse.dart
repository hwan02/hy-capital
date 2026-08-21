// 한국식 금액 표기를 원(₩) 숫자로 바꾼다. Flutter 의존성 없음 — 단독 실행/테스트 가능.

/// '4.5억' · '45,000만' · '7억 6,080만원' · '760800000' 을 모두 원 단위로 바꾼다.
/// 못 읽으면 0.
double parseWon(String? s) {
  if (s == null) return 0;
  s = s.replaceAll(',', '').replaceAll(' ', '').trim();
  if (s.isEmpty) return 0;
  final eok = RegExp(r'([\d.]+)\s*억').firstMatch(s);
  final man = RegExp(r'([\d.]+)\s*만').firstMatch(s);
  double v = 0;
  if (eok != null) v += (double.tryParse(eok.group(1)!) ?? 0) * 1e8;
  if (man != null) v += (double.tryParse(man.group(1)!) ?? 0) * 1e4;
  if (eok == null && man == null) v = double.tryParse(s) ?? 0;
  return v;
}
