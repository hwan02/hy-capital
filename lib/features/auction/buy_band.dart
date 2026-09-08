// 매수 구간 판정 — «언제 사고 언제 파나»를 한 곳에서 정한다.
//
// 출처: 자료실 「가격이 뛰는 구간 — 모아·신통 단타 타이밍」(2026-08-31, 본인 정리)
//
//   가격은 단계마다 균등하게 오르지 않는다. «특정 이벤트»에서 크게 뛴다.
//   그 «직전»에 사서 그 «직후»에 판다. 종류에 따라 자리가 다르다:
//
//   • 모아타운 — 관리계획 수립·주민공람 때 «산다» → 위원회(통합)심의 직후 «판다».
//   • 신통기획 — 대상지 선정 후 6개월~1년 트래킹하다 값이 빠지면 «산다»
//                → 신통 확정(정비구역 지정고시) 직후 «판다».
//
// 공통 — «조합설립인가가 나면 끝»이다.
// 조합원 지위 양도가 막혀 낙찰받아도 승계가 안 되고 현금청산 대상이 된다.
// (2026-09-01 화곡1동 354 구역 조합 확인 — 승계 불가)
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/models.dart';

enum BuyBand {
  /// 아직 «오르는 중». 발표로 튄 값이 안 빠졌다 — 기다린다.
  /// 신통의 「후보지 선정」이 여기다 (토허가 발효까지 더 오른다).
  rising,

  /// 저점. 상승 2번 남음. 모아=관리계획 수립·공람 · 신통=기획 중~완료.
  early,

  /// 단계 2 — 고시 완료, 동의서 징구 구간. 상승 1번 남음.
  late_,

  /// 단계 3+ — 조합설립인가. 양도제한·현금청산. 들어가지 않는다.
  blocked,

  /// 구역을 못 찾음. 판단 보류.
  unknown,
}

extension BuyBandInfo on BuyBand {
  String get label => switch (this) {
        BuyBand.rising => '오르는 중',
        BuyBand.early => '매수 A',
        BuyBand.late_ => '매수 B',
        BuyBand.blocked => '진입 불가',
        BuyBand.unknown => '구역 미확인',
      };

  /// 칩에 쓰는 짧은 설명 — «지금 뭐가 진행 중인가».
  String get short => switch (this) {
        BuyBand.rising => '값 튄 구간 · 기다린다',
        BuyBand.early => '저점 — 매수 자리',
        BuyBand.late_ => '동의서 징구 · 마지막 매수',
        BuyBand.blocked => '조합설립 지남 · 승계 불가',
        BuyBand.unknown => '구역을 못 찾음',
      };

  /// 왜 이 판정인가 — 모아·신통을 나눠서 한 줄씩.
  String get why => switch (this) {
        BuyBand.rising =>
          '선정 발표로 값이 튄 구간. 모아는 통합심의 전, 신통은 지정고시 전 '
              '골짜기에서 산다.',
        BuyBand.early =>
          '모아 = 관리계획 수립·주민공람 때 산다. '
              '신통 = 대상지 선정 후 6개월~1년 트래킹하다 값이 빠지면 산다.',
        BuyBand.late_ =>
          '조합 동의서 징구 중 — 조합설립인가 «전» 마지막 매수 자리. '
              '인가가 나면 조합원 승계가 막힌다.',
        BuyBand.blocked =>
          '조합설립인가 지남 — 조합원 지위 양도 제한. '
              '낙찰받아도 승계가 안 되고 현금청산 대상이다.',
        BuyBand.unknown => '주소가 등록된 구역과 매칭되지 않았다. 구역부터 확인한다.',
      };

  Color get color => switch (this) {
        BuyBand.rising => AppColors.sky,
        BuyBand.early => AppColors.primary,
        BuyBand.late_ => AppColors.gold,
        BuyBand.blocked => AppColors.rose,
        BuyBand.unknown => AppColors.textFaint,
      };

  IconData get icon => switch (this) {
        BuyBand.rising => Icons.hourglass_top_rounded,
        BuyBand.early => Icons.trending_up_rounded,
        BuyBand.late_ => Icons.timelapse_rounded,
        BuyBand.blocked => Icons.block_rounded,
        BuyBand.unknown => Icons.help_outline_rounded,
      };

  /// 사도 되는 구간인가.
  bool get canBuy => this == BuyBand.early || this == BuyBand.late_;
}

/// 모아타운 — 교안 「단계별 시세 그래프」의 «골짜기»가 매수 자리다.
///
///   1 동의서징구시작 ┐
///   2 동의서달성     ├ 오르는 중
///   3 신규 선정      ┘  (발표로 튄 구간)
///   4 관리계획 수립     🟢 매수 A  ← 첫 골짜기
///   5 통합심의          오르는 중 (고시로 뛴다)
///   6 관리계획 승인고시  🟡 매수 B  (고시 직후 = 동의서 걷기 시작)
///   7 조합 동의서 징구   🟡 매수 B  ← 두 번째 골짜기
///   8+ 조합설립인가↑    🚫 양도 제한 · 승계 불가
BuyBand bandOfStage(int stage) => switch (stage) {
      4 => BuyBand.early,
      6 || 7 => BuyBand.late_,
      1 || 2 || 3 || 5 => BuyBand.rising,
      >= 8 => BuyBand.blocked,
      _ => BuyBand.unknown, // 0 = 미정
    };

/// 신속통합기획 — 골짜기 위치가 모아와 «다르다».
/// 「신규 선정」 뒤에 «토허가 발효»가 한 번 더 올리고, 「기획 완료」에서 빠진다.
///
///   1 동의서징구시작 ┐
///   2 동의서달성     ├ 오르는 중
///   3 신규 선정      ┘  (선정 발표로 튄다)
///   4 기획 중           🟢 매수 A  ← 저점(선정~확정 사이). 경매로 노리는 자리
///   5 기획 완료         🟢 매수 A  ← 지정고시 직전
///   6 정비구역 지정고시  오르는 중 (확정으로 튄다)
///   7 동의서 징구       🟡 매수 B  ← 두 번째 골짜기
///   8+ 조합설립인가↑    🚫 양도 제한 · 승계 불가
BuyBand bandOfSinStage(int stage) => switch (stage) {
      4 || 5 => BuyBand.early,
      7 => BuyBand.late_,
      1 || 2 || 3 || 6 => BuyBand.rising,
      >= 8 => BuyBand.blocked,
      _ => BuyBand.unknown,
    };

/// 구역 → 매수 구간. 종류에 따라 축이 다르다.
BuyBand bandOfZone(Zone? z) => z == null
    ? BuyBand.unknown
    : (z.isSin ? bandOfSinStage(z.stage) : bandOfStage(z.stage));

/// 이 구간에서 «다음에 팔 자리»는 어디인가 — 모아·신통을 나눠서.
String sellLineOf(BuyBand b) => switch (b) {
      BuyBand.early =>
        '모아 = 통합심의 직후. 신통 = 지정고시(확정) 직후. 늦어도 조합설립인가 전.',
      BuyBand.late_ => '조합설립인가 «직전» — 이 창을 놓치면 승계가 막혀 못 판다',
      BuyBand.rising => '지금은 살 자리가 아니다 — 다음 골짜기를 기다린다',
      _ => '—',
    };

/// 모아타운 기준 — 이 구간의 «사서 → 판다» 한 줄.
String moaPlan(BuyBand b) => switch (b) {
      BuyBand.early => '관리계획 수립·주민공람 때 사서 → 통합심의 직후 판다',
      BuyBand.late_ => '조합 동의서 징구 중 사서 → 조합설립인가 직전 판다',
      BuyBand.rising => '발표로 튄 구간 — 통합심의 전 골짜기까지 기다린다',
      _ => '조합설립인가 지남 — 양도 제한·승계 불가',
    };

/// 신통기획 기준 — 이 구간의 «사서 → 판다» 한 줄.
String sinPlan(BuyBand b) => switch (b) {
      BuyBand.early => '대상지 선정 후 6개월~1년 트래킹, 값 빠지면 사서 → 지정고시(확정) 직후 판다',
      BuyBand.late_ => '조합 동의서 징구 중 사서 → 조합설립인가 직전 판다',
      BuyBand.rising => '발표로 튄 구간 — 지정고시 전 골짜기까지 기다린다',
      _ => '조합설립인가 지남 — 양도 제한·승계 불가',
    };

/// 그 단계에서 «지금 진행 중인 일». 단계 이름은 «지나온 일»을 가리키므로
/// 정작 지금 뭐가 돌아가는지를 한 줄 더 준다 — 매수 자리가 여기서 갈린다.
const kStageDoing = <int, String>{
  1: '동의서 걷는 중',
  2: '동의율 달성 · 선정 대기',
  3: '선정 발표로 «오른» 구간',
  4: '관리계획 «수립» 중',
  5: '통합심의 중 — 고시 임박',
  6: '고시 완료 · 동의서 준비',
  7: '조합 동의서 «징구» 중',
  8: '조합 운영 · 건축계획',
  9: '시공자 선정',
  10: '이주 준비',
  11: '이주 · 착공',
  12: '입주',
};

/// 신통 버전.
const kSinStageDoing = <int, String>{
  1: '동의서 걷는 중',
  2: '동의율 달성 · 선정 대기',
  3: '선정 발표로 «오른» 구간',
  4: '기획 «수립» 중 — 저점(선정~확정 사이)',
  5: '기획 «완료» — 지정고시 대기',
  6: '지정고시 완료 · 동의서 준비',
  7: '조합 동의서 «징구» 중',
  8: '조합 운영',
  9: '사업시행 이후',
  10: '이주 · 착공',
  11: '입주',
};

/// 그 단계 «다음»에 오는 가격 상승 이벤트 (모아).
const kNextRise = <int, String>{
  3: '통합심의(관리계획 고시)',
  4: '통합심의(관리계획 고시)',
  6: '조합설립인가',
  7: '조합설립인가',
};

/// 신통 버전.
const kSinNextRise = <int, String>{
  3: '정비구역 지정고시',
  4: '정비구역 지정고시',
  5: '정비구역 지정고시',
  6: '조합설립인가',
  7: '조합설립인가',
};

// ══════════════════════════════════════════════════════════
// 권리산정기준일 대조 — 「사면 안 되는 물건」을 가른다
// ══════════════════════════════════════════════════════════

/// 권리산정기준일 판정 결과.
enum RightsCheck {
  /// 사용승인일이 기준일보다 «빠르다» — 입주권 나온다.
  ok,

  /// 사용승인일이 기준일보다 «늦다» — 현금청산 대상.
  cashOut,

  /// 사용승인일을 안 적었다. 건축물대장에서 보고 넣어야 한다.
  needBuildDate,

  /// 구역에 기준일이 없다(포털 미제공·구역 미매칭).
  unknown,
}

extension RightsCheckInfo on RightsCheck {
  String get label => switch (this) {
        RightsCheck.ok => '입주권 OK',
        RightsCheck.cashOut => '입주권 없음',
        RightsCheck.needBuildDate => '사용승인일 확인',
        RightsCheck.unknown => '기준일 미확인',
      };

  String get why => switch (this) {
        RightsCheck.ok =>
          '사용승인일이 권리산정기준일보다 «앞선다» — 입주권 대상이다.',
        RightsCheck.cashOut =>
          '사용승인일이 권리산정기준일보다 «늦다». 이 날 다음날부터 분할·신축된 '
              '물건은 입주권이 안 나오고 «현금청산»된다. 사면 안 된다.',
        RightsCheck.needBuildDate =>
          '«건축물대장»의 사용승인일을 넣어야 판정된다. 찾기 단계에서 어차피 보는 서류다.',
        RightsCheck.unknown => '구역의 권리산정기준일을 못 찾았다.',
      };

  Color get color => switch (this) {
        RightsCheck.ok => AppColors.primary,
        RightsCheck.cashOut => AppColors.rose,
        RightsCheck.needBuildDate => AppColors.gold,
        RightsCheck.unknown => AppColors.textFaint,
      };

  IconData get icon => switch (this) {
        RightsCheck.ok => Icons.verified_rounded,
        RightsCheck.cashOut => Icons.dangerous_rounded,
        RightsCheck.needBuildDate => Icons.help_outline_rounded,
        RightsCheck.unknown => Icons.help_outline_rounded,
      };

  /// 사면 안 되는 판정인가.
  bool get isBlocking => this == RightsCheck.cashOut;
}

/// 물건의 사용승인일과 구역의 권리산정기준일을 대조한다.
RightsCheck rightsCheck(AuctionProperty p, Zone? z) {
  final base = z?.rightsDate;
  if (base == null) return RightsCheck.unknown;
  final built = p.approvedOn;
  if (built == null) return RightsCheck.needBuildDate;
  // 기준일 «다음날»부터가 청산 대상이므로, 같은 날은 통과.
  return built.isAfter(base) ? RightsCheck.cashOut : RightsCheck.ok;
}

// ══════════════════════════════════════════════════════════
// 구역 해제 위험
// ══════════════════════════════════════════════════════════

/// 초기 단계 구역은 «해제»될 수 있다.
///
/// 교안 사례 — 자양2동 681번지:
///   2026.03.15 「모아타운 통과 (727세대)」
///   2026.07.16 「하루 아침에 수포로 — 대상지 해제」
/// 통과 «4개월» 만이다. 초기일수록 수익이 큰 대신 사업이 엎어질 수 있다.
/// 모아는 관리계획 수립(4)까지, 신통은 기획 완료(5)까지가 초기다.
bool hasDropRisk(Zone? z) =>
    z != null && z.stage > 0 && (z.isSin ? z.stage <= 5 : z.stage <= 4);

const kDropRiskNote =
    '초기 단계는 «해제»될 수 있다 — 자양2동 681은 통과 4개월 만에 대상지에서 '
    '빠졌다. 또 정비구역 «지정 전»까지 구역이 «축소·변경»될 수 있다 — '
    '특히 상가·교회·성당 «인접지»는 빠질 수 있으니, 이 물건이 존치·제외 대상은 아닌지 '
    '(예비)추진위·구청에 «전화로» 확인한다.';

// ══════════════════════════════════════════════════════════
// 다음에 채울 것 하나 — 판정기가 「입력 필요」만 뱉지 않게
// ══════════════════════════════════════════════════════════
//
// 물건 9건의 입력 상태를 세어보니 공시가 1/9 · 거래량 0/9 · 전세 1/9 였다.
// 게이트 6개를 한꺼번에 늘어놓으면 아무것도 안 채운다.
// 그래서 «비어 있는 것 중 첫 번째 하나»만 카드에 띄운다.
// 진행 탭의 pendingTasks().first 와 같은 생각이다.

enum FieldKind { money, count, date, zone }

/// 채워야 할 값 하나.
class MissingField {
  final String column; // DB 컬럼
  final String label;
  final String why; // 왜 필요한가 — 어느 게이트를 막고 있나
  final FieldKind kind;
  const MissingField(this.column, this.label, this.why, this.kind);
}

/// 판정 순서대로. 게이트 G1~G6 순서를 그대로 따른다.
const _order = <MissingField>[
  MissingField('current_price', '현재시세', 'G1 갭 판정 — 시세 없이는 갭이 안 나온다',
      FieldKind.money),
  MissingField('jeonse_price', '전세가', 'G1 갭 판정 — 플피의 생명줄. 임장에서 들은 값',
      FieldKind.money),
  MissingField('official_price', '공시가', 'G2 — 1억 이하면 법인 취득세 기본세율(1%)',
      FieldKind.money),
  MissingField('project_zone', '사업시행구역 해당 여부', 'G3 — 해당되면 이미 늦었다',
      FieldKind.zone),
  MissingField('approved_on', '사용승인일', 'G4 — 권리산정기준일과 대조해 입주권 판정',
      FieldKind.date),
  MissingField('recent_deals', '최근 실거래 건수', 'G5 환금성 — 안 팔리면 단타가 아니다',
      FieldKind.count),
  MissingField('expected_sale_price', '예상 매도가', 'G6 — 얼마에 팔 건지가 없으면 수익이 없다',
      FieldKind.money),
];

/// 이 물건에서 «다음에 채울 것» 하나. 다 채웠으면 null.
MissingField? nextMissing(AuctionProperty p) {
  bool empty(String col) => switch (col) {
        'current_price' => p.currentPrice <= 0,
        'jeonse_price' => p.jeonsePrice <= 0,
        'official_price' => p.officialPrice <= 0,
        'project_zone' => (p.projectZone ?? '').isEmpty ||
            p.projectZone == 'unknown',
        'approved_on' => p.approvedOn == null,
        'recent_deals' => p.recentDeals <= 0,
        'expected_sale_price' => p.expectedSalePrice <= 0,
        _ => false,
      };
  for (final f in _order) {
    if (empty(f.column)) return f;
  }
  return null;
}

/// 몇 개 중 몇 개를 채웠나.
(int, int) filledCount(AuctionProperty p) {
  var done = 0;
  for (final f in _order) {
    final was = nextMissing(p);
    if (was == null) return (_order.length, _order.length);
    if (f.column == was.column) break;
    done++;
  }
  return (done, _order.length);
}

// ══════════════════════════════════════════════════════════
// 재개발 vs 재건축 — 신통 목록에 섞여 온다
// ══════════════════════════════════════════════════════════
//
// 서울도시공간포털의 «신속통합기획(BZ101)» 232곳에는 재개발과 재건축이
// 같이 들어 있다. 포털에 구분 필드가 없다 — 재건축 코드(BZ104/105)와
// 대조해도 «정비구역으로 지정된» 것만 걸려 75곳밖에 안 맞는다.
//
// 우리가 노리는 건 빌라를 낙찰받아 입주권을 받는 «재개발»이다.
// 아파트 단지 재건축은 경매로 살 빌라가 아예 없다 — 영등포구 19곳 중
// 13곳이 여의도·목동·신길 아파트였다.
//
// 그래서 이름으로 가른다. 포털 코드로 라벨을 만든 75곳에 맞춰보면
// 72곳(96%)이 맞는다.
//   · 「N구역 · A구역 · N지구」  → 재개발 (구역 단위로 묶은 저층 주거지)
//   · 아파트 단지명·「N차」·「N단지」 → 재건축
//   · 「동 + 번지」               → 재개발
//   · 그 외                      → 재건축 (단지명일 가능성이 높다)

final _reGuyeok = RegExp(r'\d+\s*구역|[A-Z]\s*구역|\d+지구|재개발');

/// 「신풍역 일대」처럼 «숫자 없는 일대»가 있다. 저층 주거지를 묶은
/// 재개발 표기이므로 번지 규칙과 따로 잡는다 — 이걸 빼먹어서 영등포
/// 신풍역이 재건축으로 걸러졌었다.
final _reIldae = RegExp(r'일\s*대|일재');
final _reApt = RegExp(
    r'(단지|시영|주공|아파트|맨션|하이츠|타워|위브|자이|래미안|푸르지오|e편한|'
    r'미성|우성|현대|삼익|은하|목화|시범|한양|대교|삼부|광장|경남|쌍용|한신|'
    r'크로바|장미|진주|건영|코오롱|동아|극동|신동아|청구|무지개|개나리|삼환|'
    r'우방|벽산|풍림|두산|롯데|대우|삼성|성원|한강|리버|\d+차)');
final _reBunji = RegExp(r'\d+동\s|동\s*\d|\d+-\d+|\d+\s*번지|\d+\s*$');

/// 아파트 «재건축»인가. 맞으면 경매로 살 빌라가 없다.
bool isRebuild(String name) {
  if (_reGuyeok.hasMatch(name) || _reIldae.hasMatch(name)) return false;
  if (_reApt.hasMatch(name)) return true;
  if (_reBunji.hasMatch(name)) return false;
  return true;
}

// ══════════════════════════════════════════════════════════
// 「후계공통승」 — 모아타운 관리계획 지정 절차
// ══════════════════════════════════════════════════════════
//
//   후 보지 선정 → 계 획 수립 → 공 람(14일) → 통 합심의 → 승 인고시
//
// 앱의 단계 축(12칸)과 «칸 수가 다르다». 주민공람은 별도 칸이 아니라
// 관리계획 수립(4)과 통합심의(5) 사이에 끼는 14일짜리 절차다. 칸을 늘리면
// 이미 저장된 353개 구역의 단계가 통째로 밀리므로, 축은 그대로 두고
// «어느 칸이 어느 글자인지»만 얹는다.
class MoaStep {
  final String letter;
  final String label;

  /// 이 절차가 벌어지는 축의 칸. 공람은 4번 칸 «안»에서 일어난다.
  final int stage;
  const MoaStep(this.letter, this.label, this.stage);
}

const kMoaSteps = <MoaStep>[
  MoaStep('후', '후보지 선정', 3),
  MoaStep('계', '관리계획 수립', 4),
  MoaStep('공', '주민공람 14일', 4),
  MoaStep('통', '통합심의', 5),
  MoaStep('승', '관리계획 승인고시', 6),
];

/// 그 칸에 붙는 글자들. 4번 칸은 「계·공」 둘이다.
String moaLetters(int stage) =>
    kMoaSteps.where((s) => s.stage == stage).map((s) => s.letter).join('·');
