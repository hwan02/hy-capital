// 경매 물건 정보를 붙여넣기 한 판으로 등록한다.
//
// 사용자는 추천 매물을 카톡 텍스트나 경매사이트 화면에서 받는다. 두 형식이
// 섞여 오므로 라벨을 넓게 잡고, 못 뽑은 칸은 사람이 채운다.
// 사이트를 크롤링하지 않는다 — 구조가 자주 바뀌고 차단된다.
import '../../core/format/won_parse.dart';

/// 붙여넣은 텍스트에서 뽑아낸 값. 못 뽑은 건 null / 0.
class ParsedAuction {
  final String? title;
  final String? caseNo;
  final String? address;
  final String? court;
  final String? propertyKind;
  final double appraisalPrice;
  final double minPrice;
  final double deposit;
  final DateTime? bidDate;
  final double areaSqm;

  // ── 자동 감지 플래그 ──
  /// 위반건축물 키워드 감지 여부.
  final bool violationDetected;
  /// HUG 보증 키워드 감지 여부.
  final bool hugDetected;
  /// 유찰 횟수 (감정가/최저가 비율로 추정, 또는 텍스트에서 직접 추출).
  final int failedBids;
  /// 전용면적 (㎡). areaSqm 과 별도로 '전용' 라벨이 붙은 값.
  final double exclusiveArea;

  const ParsedAuction({
    this.title,
    this.caseNo,
    this.address,
    this.court,
    this.propertyKind,
    this.appraisalPrice = 0,
    this.minPrice = 0,
    this.deposit = 0,
    this.bidDate,
    this.areaSqm = 0,
    this.violationDetected = false,
    this.hugDetected = false,
    this.failedBids = 0,
    this.exclusiveArea = 0,
  });

  /// 보증금이 안 적혀 있으면 최저가의 10%(통상 기준).
  double get depositOrTenth => deposit > 0 ? deposit : minPrice * 0.1;

  /// 패스 기준 해당 여부 — 위반건축물이 감지되면 true.
  bool get shouldPass => violationDetected;

  /// 최저가/감정가 비율로 유찰 횟수를 추정한다.
  /// 80% → 1회, 64% → 2회, 51% → 3회, 41% → 4회, 33% → 5회.
  int get estimatedFailedBids {
    if (failedBids > 0) return failedBids;
    if (appraisalPrice <= 0 || minPrice <= 0) return 0;
    final ratio = minPrice / appraisalPrice;
    if (ratio > 0.85) return 0;
    if (ratio > 0.68) return 1;
    if (ratio > 0.54) return 2;
    if (ratio > 0.44) return 3;
    if (ratio > 0.35) return 4;
    return 5;
  }

  int get filledCount => [
        title,
        caseNo,
        address,
        court,
        propertyKind,
        appraisalPrice > 0 ? 'y' : null,
        minPrice > 0 ? 'y' : null,
        bidDate,
      ].where((e) => e != null).length;
}

/// 라벨 뒤의 금액을 찾는다. `최저가 (80%) 760,800,000` 도
/// `최저입찰가 : 7억 6,080만원` 도 같은 함수로 처리한다.
///
/// 비율 표기 `(80%)` 를 먼저 지운다 — 안 지우면 80 을 금액으로 읽는다.
/// 감정가·최저가·보증금은 최소 만원 단위이므로 1만 미만은 오독으로 본다.
double _money(String text, List<String> labels) {
  for (final label in labels) {
    final i = text.indexOf(label);
    if (i < 0) continue;
    var seg = text.substring(i + label.length);
    final nl = seg.indexOf('\n'); // 같은 줄만 본다
    if (nl >= 0) seg = seg.substring(0, nl);
    seg = seg
        .replaceAll(RegExp(r'\(\s*\d+(\.\d+)?\s*%\s*\)'), ' ')
        .replaceAll(RegExp(r'\d+(\.\d+)?\s*%'), ' ');
    final m =
        RegExp(r'([0-9][0-9,\.]*\s*억?\s*[0-9,]*\s*만?)').firstMatch(seg);
    if (m == null) continue;
    final v = parseWon(m.group(1));
    if (v >= 10000) return v;
  }
  return 0;
}

String? _first(String text, RegExp re, [int group = 0]) {
  final m = re.firstMatch(text);
  return m?.group(group)?.trim();
}

/// 붙여넣은 텍스트를 물건 정보로 파싱한다. 순수 함수 — 테스트 가능.
ParsedAuction parseAuctionText(String raw) {
  final text = raw.replaceAll('\r\n', '\n');

  // 사건번호: 2022타경102285
  final caseNo = _first(text, RegExp(r'\d{4}\s*타경\s*\d+'))?.replaceAll(' ', '');

  // 금액 — 라벨을 넓게. '최저입찰가'가 '최저가'보다 먼저 와야 한다.
  final appraisal = _money(text, ['감정가', '감정평가액']);
  final minPrice =
      _money(text, ['최저입찰가', '최저매각가격', '최저매각가', '최저가']);
  final deposit = _money(text, ['입찰보증금', '보증금']);

  // 법원: 수원지방법원 안양지원 4계
  final court = _first(
      text, RegExp(r'[가-힣]+지방법원(\s*[가-힣]+지원)?(\s*\d+계)?'));

  // 매각기일 — '2026년 9월 8일 오전 10시' / '2026.09.08 (화) (10:00)'
  DateTime? bidDate;
  final dm = RegExp(r'(20\d{2})\s*[.\-년]\s*(\d{1,2})\s*[.\-월]\s*(\d{1,2})')
      .firstMatch(text);
  if (dm != null) {
    var hour = 10; // 경매는 통상 오전 10시. 못 찾으면 이 값.
    final hm = RegExp(r'\((\d{1,2}):(\d{2})\)').firstMatch(text);
    final km = RegExp(r'(오전|오후)\s*(\d{1,2})\s*시').firstMatch(text);
    if (hm != null) {
      hour = int.parse(hm.group(1)!);
    } else if (km != null) {
      hour = int.parse(km.group(2)!);
      if (km.group(1) == '오후' && hour < 12) hour += 12;
    }
    bidDate = DateTime(int.parse(dm.group(1)!), int.parse(dm.group(2)!),
        int.parse(dm.group(3)!), hour);
  }

  // 주소: 시·도로 시작하는 줄
  String? address;
  for (final line in text.split('\n')) {
    final t = line.trim();
    if (RegExp(r'^(서울|경기|인천|부산|대구|대전|광주|울산|세종|강원|충북|충남|전북|전남|경북|경남|제주)')
            .hasMatch(t) &&
        RegExp(r'(시|군|구)').hasMatch(t)) {
      // '주소복사' 같은 버튼 텍스트는 잘라낸다.
      address = t.split(RegExp(r'\s{2,}|주소복사|새주소검색')).first.trim();
      break;
    }
  }

  final kind = _first(text, RegExp(r'아파트|빌라|다세대|연립|오피스텔|단독주택|상가|토지'));

  // 면적: 84.7㎡ 중 큰 쪽(건물면적)을 쓴다.
  double area = 0;
  for (final m in RegExp(r'([\d.]+)\s*㎡').allMatches(text)) {
    final v = double.tryParse(m.group(1)!) ?? 0;
    if (v > area) area = v;
  }

  // 전용면적: '전용' 라벨 뒤의 ㎡ 값.
  double exclusiveArea = 0;
  final exm = RegExp(r'전용\s*([\d.]+)\s*㎡').firstMatch(text);
  if (exm != null) exclusiveArea = double.tryParse(exm.group(1)!) ?? 0;
  // 전용이 못 잡히면 가장 작은 ㎡ 를 전용으로 추정 (건물면적 > 전용면적).
  if (exclusiveArea == 0 && area > 0) {
    double smallest = area;
    for (final m in RegExp(r'([\d.]+)\s*㎡').allMatches(text)) {
      final v = double.tryParse(m.group(1)!) ?? 0;
      if (v > 0 && v < smallest) smallest = v;
    }
    if (smallest < area) exclusiveArea = smallest;
  }

  // ── 자동 감지 플래그 ──
  final violation = RegExp(r'위반\s*건축물|무단\s*증축|이행\s*강제금|불법\s*건축', caseSensitive: false)
      .hasMatch(text);
  final hug = RegExp(r'HUG|주택도시보증|대항력\s*포기', caseSensitive: false)
      .hasMatch(text);

  // 유찰 횟수: '유찰 3회' / '3회 유찰' / '재매각' 패턴.
  int failed = 0;
  final fm = RegExp(r'(\d+)\s*회?\s*유찰|유찰\s*(\d+)\s*회').firstMatch(text);
  if (fm != null) {
    failed = int.tryParse(fm.group(1) ?? fm.group(2) ?? '') ?? 0;
  } else if (text.contains('재매각')) {
    failed = 1; // 재매각 = 최소 1회 유찰
  }

  // 물건명: 괄호 안 단지명 → 없으면 '래미안 …' 같은 브랜드 줄 → 없으면 첫 줄
  String? title;
  final paren = RegExp(r'\(([^()]*(?:아파트|빌라|타워|캐슬|파크|힐스|자이|푸르지오|래미안|e편한세상|더샵|메가트리아)[^()]*)\)')
      .firstMatch(text);
  if (paren != null) {
    title = paren.group(1)!.split(',').last.trim();
  }
  if (title == null || title.isEmpty) {
    for (final line in text.split('\n')) {
      final t = line.trim();
      if (t.isEmpty) continue;
      if (RegExp(r'(래미안|자이|푸르지오|힐스테이트|아이파크|e편한세상|더샵|캐슬|,?\s*\d+평)')
          .hasMatch(t)) {
        title = t.replaceAll(RegExp(r'[!]+'), '').trim();
        break;
      }
    }
  }
  if (title != null && title.length > 40) title = title.substring(0, 40);

  return ParsedAuction(
    title: (title ?? '').isEmpty ? null : title,
    caseNo: caseNo,
    address: address,
    court: court,
    propertyKind: kind,
    appraisalPrice: appraisal,
    minPrice: minPrice,
    deposit: deposit,
    bidDate: bidDate,
    areaSqm: area,
    violationDetected: violation,
    hugDetected: hug,
    failedBids: failed,
    exclusiveArea: exclusiveArea > 0 ? exclusiveArea : area,
  );
}
