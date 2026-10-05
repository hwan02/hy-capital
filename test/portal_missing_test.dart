// 포털 «대상지 목록»에 없는 구역은 매수 판정을 멈춘다.
//
// 자양2동 681 은 2026.07.16 대상지 해제됐는데 서울시 표(2026-09-08)에는
// 두 달 뒤까지 「관리계획 수립 중」으로 남아 있었다. 표만 믿고 매수 A 후보로
// 올렸던 사고를 코드로 막는다.
import 'package:flutter_test/flutter_test.dart';
import 'package:hy_capital/features/auction/buy_band.dart';
import 'package:hy_capital/models/models.dart';

Zone zone({required int stage, bool? portalListed, String kind = '모아타운'}) =>
    Zone(id: 'z', name: '자양2동 681번지 일대', kind: kind, stage: stage,
        portalListed: portalListed);

void main() {
  test('★ 포털에 없으면 단계가 저점(4)이어도 «매수 A» 가 아니다', () {
    final z = zone(stage: 4, portalListed: false);
    expect(z.portalMissing, isTrue);
    expect(bandOfZone(z), BuyBand.unknown);
    expect(bandOfZone(z).canBuy, isFalse);
  });

  test('포털에 있으면 평소대로 판정한다', () {
    expect(bandOfZone(zone(stage: 4, portalListed: true)), BuyBand.early);
    expect(bandOfZone(zone(stage: 7, portalListed: true)), BuyBand.late_);
  });

  test('아직 대조 전(null)이면 막지 않는다 — 모르는 것과 없는 것은 다르다', () {
    expect(zone(stage: 4, portalListed: null).portalMissing, isFalse);
    expect(bandOfZone(zone(stage: 4, portalListed: null)), BuyBand.early);
  });

  test('신통기획도 같은 규칙 (신통 저점은 3·4단계다)', () {
    final z = zone(stage: 4, portalListed: false, kind: '신통기획');
    expect(bandOfZone(z), BuyBand.unknown);
    expect(bandOfZone(zone(stage: 4, portalListed: true, kind: '신통기획')),
        BuyBand.early);
  });

  test('진입 불가 구역은 포털에 있든 없든 사지 않는다', () {
    expect(bandOfZone(zone(stage: 9, portalListed: true)).canBuy, isFalse);
    expect(bandOfZone(zone(stage: 9, portalListed: false)).canBuy, isFalse);
  });
}
