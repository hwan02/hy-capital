import 'package:flutter_test/flutter_test.dart';
import 'package:hy_capital/features/auction/auction_paste.dart';

void main() {
  test('감정일보다 라벨 있는 매각기일 우선, 분까지 보존', () {
    final p = parseAuctionText(
      '감정일 2025.01.01\n매각기일 2026.11.19 (목) (10:30)\n'
      '서울중앙지방법원 2025타경102723\n최저가 232,960,000원',
    );
    expect(p.bidDate, DateTime(2026, 11, 19, 10, 30));
    expect(p.minPrice, 232960000);
    expect(p.caseNo, '2025타경102723');
  });
  test('입찰보증금과 임차보증금을 혼동하지 않음', () {
    final p = parseAuctionText('임차보증금 305,000,000원\n최저가 154,880,000원');
    expect(p.deposit, 0);
    final special = parseAuctionText(
      '임차보증금 300,000,000원\n입찰보증금 (20%) 48,320,000원',
    );
    expect(special.deposit, 48320000);
  });
  test('전용면적은 라벨 값만, 대지권 최솟값으로 추정하지 않음', () {
    expect(parseAuctionText('대지권 12.5㎡\n건물면적 19.03㎡').exclusiveArea, 0);
    expect(parseAuctionText('대지권 12.5㎡\n전용면적: 19.03㎡').exclusiveArea, 19.03);
  });
  test('위반 없음 뒤 다른 문장의 실제 무단증축을 누락하지 않음', () {
    expect(parseAuctionText('위반건축물 없음').violationDetected, false);
    expect(parseAuctionText('누수 없음\n위반건축물 등재').violationDetected, true);
    expect(parseAuctionText('위반건축물 없음, 무단증축 12.15㎡').violationDetected, true);
  });
  test('HUG 키워드와 포기조건은 별개, 재매각을 유찰로 환산하지 않음', () {
    expect(parseAuctionText('대항력 포기').hugDetected, false);
    expect(parseAuctionText('주택도시보증공사').hugDetected, true);
    expect(parseAuctionText('대금 미납 재매각').failedBids, 0);
  });
  test('존재하지 않는 날짜는 보정하지 않고 미확인 유지', () {
    expect(parseAuctionText('매각기일 2026.02.30').bidDate, isNull);
    expect(parseAuctionText('감정일 2025.01.01\n전입일 2022.01.01').bidDate, isNull);
  });
}
