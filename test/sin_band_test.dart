import 'package:flutter_test/flutter_test.dart';
import 'package:hy_capital/features/auction/buy_band.dart';

// «건조개관» — 재건축은 조합설립인가(8)부터, 재개발은 관리처분인가(10)부터 막힌다.
void main() {
  test('신통 재건축: 조합설립인가(8)부터 진입 불가', () {
    expect(bandOfSinStage(7), BuyBand.late_);
    expect(bandOfSinStage(8), BuyBand.blocked);
    expect(bandOfSinStage(9), BuyBand.blocked);
    expect(bandOfSinStage(10), BuyBand.blocked);
  });

  test('신통 재개발: 조합설립·사업시행은 승계 가능, 관리처분인가(10)부터 진입 불가', () {
    expect(bandOfSinStage(7, redev: true), BuyBand.late_);
    expect(bandOfSinStage(8, redev: true), BuyBand.rising);
    expect(bandOfSinStage(9, redev: true), BuyBand.rising);
    expect(bandOfSinStage(10, redev: true), BuyBand.blocked);
    expect(bandOfSinStage(12, redev: true), BuyBand.blocked);
  });

  test('모아타운은 그대로: 조합설립인가(9)부터 진입 불가', () {
    expect(bandOfStage(8), BuyBand.late_);
    expect(bandOfStage(9), BuyBand.blocked);
  });
}
