// 매수 구간 판정 — «언제 사야 하나»를 한 곳에서 정한다.
//
// 출처: 자료실 「가격이 뛰는 구간 — 모아·신통 단타 타이밍」(2026-08-31, 본인 정리)
//
//   가격은 단계마다 균등하게 오르지 않는다. «특정 이벤트»에서 크게 뛴다.
//   그 «직전»에 사서 그 «직후 ~ 다음 이벤트 직전»에 판다.
//
// 모아타운은 두 번 크게 오른다:
//   ① 관리계획 수립 → «통합심의(고시)»
//   ② 동의서 징구  → «조합설립인가»
//
// 그래서 살 자리도 둘 —
//   A. 수립 중(고시 전)      = 저점. 상승이 «두 번» 남았다. (은천 사례)
//   B. 고시 후 동의서 징구 중 = 상승이 «한 번» 남았다.
//
// 그리고 «조합설립인가가 나면 끝»이다.
// 조합원 지위 양도가 막혀 낙찰받아도 승계가 안 되고 현금청산 대상이 된다.
// (2026-09-01 화곡1동 354 구역 조합 확인 — 승계 불가)
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/models.dart';

enum BuyBand {
  /// 아직 «오르는 중». 발표로 튄 값이 안 빠졌다 — 기다린다.
  /// 신통의 「후보지 선정」이 여기다 (토허가 발효까지 더 오른다).
  rising,

  /// 저점. 상승 2번 남음. 모아=수립 중 · 신통=기획 완료.
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
        BuyBand.rising => '발표로 튄 값 · 아직 안 빠졌다',
        BuyBand.early => '저점 — 다음 상승 직전',
        BuyBand.late_ => '조합 동의서 징구 중',
        BuyBand.blocked => '조합설립인가 지남',
        BuyBand.unknown => '구역을 못 찾음',
      };

  /// 왜 이 판정인가 — 카드에서 한 줄로 보여준다.
  String get why => switch (this) {
        BuyBand.rising =>
          '선정 «발표»로 값이 튄 구간이다. 신통은 여기서 토지거래허가 발효까지 '
              '더 오르고, «기획 완료»에서 빠진다 — 그때가 매수 자리다.',
        BuyBand.early =>
          '«관리계획 수립» 중 — 다음 상승은 통합심의(고시). 그 뒤 조합설립인가까지 '
              '상승이 «두 번» 남았다. 은천 사례의 진입 자리.',
        BuyBand.late_ =>
          '«조합 동의서 징구» 중 — 다음 상승은 조합설립인가. 상승이 «한 번» 남았다. '
              '단, 인가가 나면 양도가 막히므로 «인가 전»에 팔아야 한다.',
        BuyBand.blocked =>
          '조합원 지위 «양도 제한». 낙찰받아도 승계가 안 되고 현금청산 대상이 될 수 있다.',
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

/// 모아타운 단계 → 매수 구간.
///   1 수립 중       → 매수 A (첫 골짜기)
///   2 고시 후 징구   → 매수 B (두 번째 골짜기)
///   3+ 조합설립      → 진입 불가
BuyBand bandOfStage(int stage) {
  if (stage >= 3) return BuyBand.blocked;
  if (stage == 2) return BuyBand.late_;
  if (stage == 1) return BuyBand.early;
  return BuyBand.unknown; // 0 = 미정
}

/// 신속통합기획 단계 → 매수 구간. 골짜기 위치가 모아와 «다르다».
///   1 후보지 선정        → 오르는 중 (토허가까지 더 오른다)
///   2 기획 완료          → 매수 A  ← 첫 골짜기
///   3 열람공고·지정 임박   → 오르는 중 (지정고시로 뛴다)
///   4 정비구역 지정고시    → 봉우리
///   5 조합 동의서 징구     → 매수 B  ← 두 번째 골짜기
///   6+ 조합설립인가       → 진입 불가
BuyBand bandOfSinStage(int stage) => switch (stage) {
      1 || 3 || 4 => BuyBand.rising,
      2 => BuyBand.early,
      5 => BuyBand.late_,
      >= 6 => BuyBand.blocked,
      _ => BuyBand.unknown,
    };

/// 구역 → 매수 구간. 종류에 따라 축이 다르다.
BuyBand bandOfZone(Zone? z) => z == null
    ? BuyBand.unknown
    : (z.isSin ? bandOfSinStage(z.stage) : bandOfStage(z.stage));

/// 이 구간에서 «다음에 팔 자리»는 어디인가.
String sellLineOf(BuyBand b) => switch (b) {
      BuyBand.early => '첫 상승(고시·지정) 직후, 또는 조합설립인가 직전',
      BuyBand.late_ => '조합설립인가 «직전» — 이 창을 놓치면 못 판다',
      BuyBand.rising => '지금은 살 자리가 아니다 — 다음 골짜기를 기다린다',
      _ => '—',
    };

/// 신통 단계에서 «지금 진행 중인 일».
const kSinStageDoing = <int, String>{
  1: '기획 «수립» 중',
  2: '정비구역 지정 준비',
  3: '열람공고 · 지정 임박',
  4: '조합 «동의서 징구» 준비',
  5: '조합 동의서 «징구» 중',
  6: '조합 운영',
  7: '사업시행 이후',
};

/// 그 단계에서 «지금 진행 중인 일». 단계 이름은 «끝난 일»만 말해줘서
/// 정작 지금 뭐가 돌아가는지가 안 보인다 — 매수 자리는 여기서 갈린다.
///
///   단계1 「대상지 선정」  → 지금은 «관리계획 수립» 중  → 다음 상승 통합심의
///   단계2 「관리계획 고시」 → 지금은 «조합 동의서 징구» 중 → 다음 상승 조합설립인가
const kStageDoing = <int, String>{
  1: '관리계획 «수립» 중',
  2: '조합 동의서 «징구» 중',
  3: '조합 운영 · 건축계획',
  4: '시공자 선정',
  5: '이주 준비',
  6: '이주 · 착공',
  7: '입주',
};

/// 그 단계 다음에 오는 «가격이 뛰는 이벤트». 없으면 null.
const kNextRise = <int, String>{
  1: '통합심의(관리계획 고시)',
  2: '조합설립인가',
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
bool hasDropRisk(Zone? z) =>
    z != null && (z.isSin ? z.stage <= 2 : z.stage <= 1);

const kDropRiskNote =
    '초기 단계는 «해제»될 수 있다 — 자양2동 681은 통과 4개월 만에 대상지에서 '
    '빠졌다. (예비)추진위·구청에 해제·취소 가능성을 «전화로» 확인한다.';

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
