// 매물이 «단지»에서 시세를 상속받는다.
//
// 시세조사는 단지에 붙어 있다. 매물마다 시세를 다시 입력하면
// 같은 값을 두 번 넣게 되고, 조사를 갱신해도 매물에 반영되지 않는다.
// 그래서 «단지 조사값이 있으면 그것을 쓴다»가 기본이다.
import '../../models/models.dart';

/// 어디서 온 시세인가 — 화면에 출처를 보여주기 위해.
enum PriceOrigin { complex, manual, none }

class EffectivePrice {
  /// 매매 시세 (현재시세로 쓴다).
  final double sale;

  /// 전세 시세 — 플피 계산의 핵심.
  final double jeonse;
  final PriceOrigin origin;

  /// 단지 조사가 며칠 전인지. origin == complex 일 때만 의미 있다.
  final int ageDays;

  const EffectivePrice({
    this.sale = 0,
    this.jeonse = 0,
    this.origin = PriceOrigin.none,
    this.ageDays = 0,
  });

  bool get fromComplex => origin == PriceOrigin.complex;
  bool get stale => fromComplex && ageDays > 60;

  String get label => switch (origin) {
        PriceOrigin.complex => '단지 시세조사',
        PriceOrigin.manual => '직접 입력',
        PriceOrigin.none => '시세 없음',
      };
}

/// 매물의 실효 시세. 단지 조사가 «값을 가지고 있으면» 그것을 쓰고,
/// 없으면 매물에 직접 입력된 값으로 떨어진다.
EffectivePrice effectivePrice(
  AuctionProperty p,
  Map<String, PriceSurvey> surveys,
) {
  final s = p.complexId == null ? null : surveys[p.complexId];
  if (s != null && (s.saleAvg > 0 || s.jeonseAvg > 0)) {
    return EffectivePrice(
      sale: s.saleAvg > 0 ? s.saleAvg : p.currentPrice,
      jeonse: s.jeonseAvg > 0 ? s.jeonseAvg : p.jeonsePrice,
      origin: PriceOrigin.complex,
      ageDays: s.ageDays,
    );
  }
  if (p.currentPrice > 0 || p.jeonsePrice > 0) {
    return EffectivePrice(
      sale: p.currentPrice,
      jeonse: p.jeonsePrice,
      origin: PriceOrigin.manual,
    );
  }
  return const EffectivePrice();
}
