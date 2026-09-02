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
  /// 단계 1 — 수립 중. 저점. 상승 2번 남음.
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
        BuyBand.early => '매수 A',
        BuyBand.late_ => '매수 B',
        BuyBand.blocked => '진입 불가',
        BuyBand.unknown => '구역 미확인',
      };

  /// 칩에 쓰는 짧은 설명 — «지금 뭐가 진행 중인가».
  String get short => switch (this) {
        BuyBand.early => '관리계획 수립 중 · 저점',
        BuyBand.late_ => '조합 동의서 징구 중',
        BuyBand.blocked => '조합설립인가 지남',
        BuyBand.unknown => '구역을 못 찾음',
      };

  /// 왜 이 판정인가 — 카드에서 한 줄로 보여준다.
  String get why => switch (this) {
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
        BuyBand.early => AppColors.primary,
        BuyBand.late_ => AppColors.gold,
        BuyBand.blocked => AppColors.rose,
        BuyBand.unknown => AppColors.textFaint,
      };

  IconData get icon => switch (this) {
        BuyBand.early => Icons.trending_up_rounded,
        BuyBand.late_ => Icons.timelapse_rounded,
        BuyBand.blocked => Icons.block_rounded,
        BuyBand.unknown => Icons.help_outline_rounded,
      };

  /// 사도 되는 구간인가.
  bool get canBuy => this == BuyBand.early || this == BuyBand.late_;
}

/// 구역 단계 → 매수 구간.
BuyBand bandOfStage(int stage) {
  if (stage >= 3) return BuyBand.blocked;
  if (stage == 2) return BuyBand.late_;
  if (stage == 1) return BuyBand.early;
  return BuyBand.unknown; // 0 = 미정
}

/// 구역 → 매수 구간.
BuyBand bandOfZone(Zone? z) =>
    z == null ? BuyBand.unknown : bandOfStage(z.stage);

/// 이 구간에서 «다음에 팔 자리»는 어디인가.
String sellLineOf(BuyBand b) => switch (b) {
      BuyBand.early => '통합심의(고시) 직후, 또는 조합설립인가 직전',
      BuyBand.late_ => '조합설립인가 «직전» — 이 창을 놓치면 못 판다',
      _ => '—',
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
