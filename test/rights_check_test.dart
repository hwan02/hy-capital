// 권리산정기준일 판정 — 사업 방식별로 «보는 날짜가 다르다».
// (자료실 교안 — 「사업 방식 별로 권리산정기준일의 해석이 다르므로 주의하자」)
import 'package:flutter_test/flutter_test.dart';
import 'package:hy_capital/features/auction/buy_band.dart';
import 'package:hy_capital/models/models.dart';

DateTime d(String s) => DateTime.parse(s);

Zone zone({required String kind, String? rights}) => Zone(
      id: 'z',
      name: '테스트 구역',
      kind: kind,
      rightsDate: rights == null ? null : d(rights),
    );

/// [g1to3] 를 주면 G1~G3 게이트를 미리 채운 상태가 된다 — G4 만 보고 싶을 때.
AuctionProperty prop({
  String? approved,
  String? permit,
  String? start,
  String? regist,
  bool g1to3 = false,
}) =>
    AuctionProperty(
      id: 'p',
      title: '테스트 빌라',
      status: '검토',
      currentPrice: g1to3 ? 240000000 : 0,
      jeonsePrice: g1to3 ? 180000000 : 0,
      officialPrice: g1to3 ? 90000000 : 0,
      projectZone: g1to3 ? 'out' : null,
      recentDeals: g1to3 ? 4 : 0,
      expectedSalePrice: g1to3 ? 295000000 : 0,
      minPrice: 0,
      bidPrice: 0,
      loanAmount: 0,
      acquisitionCost: 0,
      repairCost: 0,
      evictionCost: 0,
      otherCost: 0,
      saleCost: 0,
      financeCost: 0,
      targetProfit: 0,
      score: 0,
      verdict: '',
      approvedOn: approved == null ? null : d(approved),
      permitOn: permit == null ? null : d(permit),
      startOn: start == null ? null : d(start),
      registOn: regist == null ? null : d(regist),
    );

void main() {
  const base = '2022-01-20'; // 권리산정기준일

  group('모아타운(빈집법) — 기준일«까지» 건축허가 + 착공신고', () {
    final z = zone(kind: '모아타운', rights: base);

    test('허가·착공 모두 기준일 안 → 분양대상', () {
      expect(rightsCheck(prop(permit: '2021-05-01', start: '2021-09-30'), z),
          RightsCheck.ok);
    });

    test('착공신고가 기준일을 넘김 → 현금청산', () {
      expect(rightsCheck(prop(permit: '2021-05-01', start: '2022-03-02'), z),
          RightsCheck.cashOut);
    });

    test('건축허가부터 기준일을 넘김 → 현금청산', () {
      expect(rightsCheck(prop(permit: '2022-02-01', start: '2022-03-02'), z),
          RightsCheck.cashOut);
    });

    test('기준일 당일 착공신고는 통과 — «까지»이므로', () {
      expect(rightsCheck(prop(permit: '2021-05-01', start: base), z),
          RightsCheck.ok);
    });

    test('사용승인일이 기준일 안이면 착공은 더 앞 → 그것만으로 OK', () {
      expect(rightsCheck(prop(approved: '2021-11-30'), z), RightsCheck.ok);
    });

    test('★ 사용승인일이 기준일보다 늦어도 «청산이 아니다» — 허가·착공을 봐야 한다', () {
      // 예전 로직은 여기서 cashOut 을 뱉어 살 수 있는 물건을 버렸다.
      expect(rightsCheck(prop(approved: '2022-08-15'), z),
          RightsCheck.needBuildDate);
    });

    test('사용승인은 늦었지만 허가·착공이 기준일 안 → 분양대상', () {
      expect(
          rightsCheck(
              prop(approved: '2022-08-15', permit: '2021-06-01', start: '2021-12-20'),
              z),
          RightsCheck.ok);
    });
  });

  group('신통기획(도정법) — 기준일 «다음 날»까지 소유권 보존등기 접수', () {
    final z = zone(kind: '신통기획', rights: base);

    test('보존등기가 기준일 다음 날 접수 → 통과', () {
      expect(rightsCheck(prop(regist: '2022-01-21'), z), RightsCheck.ok);
    });

    test('보존등기가 그 이틀 뒤 → 현금청산', () {
      expect(rightsCheck(prop(regist: '2022-01-22'), z), RightsCheck.cashOut);
    });

    test('★ 사용승인일이 기준일 안이어도 OK 가 아니다 — 보존등기를 봐야 한다', () {
      expect(rightsCheck(prop(approved: '2021-12-01'), z),
          RightsCheck.needBuildDate);
    });

    test('사용승인일이 이미 기준일+1 을 넘었으면 보존등기는 더 뒤 → 청산', () {
      expect(rightsCheck(prop(approved: '2022-05-01'), z), RightsCheck.cashOut);
    });
  });

  group('구역·날짜가 없을 때', () {
    test('구역에 기준일이 없으면 판정 불가', () {
      expect(rightsCheck(prop(approved: '2020-01-01'), zone(kind: '모아타운')),
          RightsCheck.unknown);
      expect(rightsCheck(prop(), null), RightsCheck.unknown);
    });

    test('아무 날짜도 없으면 «판정일 확인»', () {
      expect(rightsCheck(prop(), zone(kind: '모아타운', rights: base)),
          RightsCheck.needBuildDate);
    });
  });

  group('다음에 물어볼 서류 — 사용승인일이 «먼저»다', () {
    test('사용승인일이 비면 그것부터', () {
      final z = zone(kind: '모아타운', rights: base);
      expect(nextMissing(prop(g1to3: true), z)?.column, 'approved_on');
    });

    test('모아 — 사용승인일이 늦으면 허가일로 넘어간다', () {
      final z = zone(kind: '모아타운', rights: base);
      expect(nextMissing(prop(approved: '2022-08-15', g1to3: true), z)?.column,
          'permit_on');
      expect(
          nextMissing(
                  prop(approved: '2022-08-15', permit: '2021-06-01', g1to3: true),
                  z)
              ?.column,
          'start_on');
    });

    test('신통 — 사용승인일 다음은 보존등기 접수일', () {
      final z = zone(kind: '신통기획', rights: base);
      expect(nextMissing(prop(approved: '2021-12-01', g1to3: true), z)?.column,
          'regist_on');
    });
  });
}
