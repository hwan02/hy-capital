import 'package:flutter_test/flutter_test.dart';
import 'package:hy_capital/features/auction/investment_analysis.dart';

final now = DateTime(2026, 10, 30);
InvestmentInputs input({
  Map<String, dynamic> changes = const {},
  Map<String, InvestmentEvidence>? evidence,
}) => InvestmentInputs(
  {
    'bid': 100000000.0,
    'deposit': 10000000.0,
    'acq_pct': 12.4,
    'legal': 700000.0,
    'expenses': 6000000.0,
    'reserve': 1500000.0,
    'sale_fee_pct': .44,
    'ordinary_pct': 20.0,
    'additional_pct': 20.0,
    'local_pct': 10.0,
    'cash': 200000000.0,
    'share': 100.0,
    'target': 10000000.0,
    'target_scope': 'own',
    'low_sale': 140000000.0,
    'base_sale': 150000000.0,
    'high_sale': 160000000.0,
    'low_months': 12.0,
    'base_months': 12.0,
    'high_months': 3.0,
    ...changes,
  },
  evidence ??
      {
        for (final key in investmentGates.keys)
          key: InvestmentEvidence(
            status: 'pass',
            source: '해당 물건 공식 문서 p1',
            detail: '조건 확인',
            kind: '공식 원문',
            checkedOn: now,
          ),
      },
);

void main() {
  test('공투 우선배분은 일반 과표 손금이 아니며 세후 이익 한도', () {
    final base = calculateInvestment(input(), 'base');
    final joint = calculateInvestment(
      input(
        changes: {
          'joint': 50000000.0,
          'joint_confirmed': true,
          'joint_rate': 10.0,
          'share': 50.0,
        },
      ),
      'base',
    );
    expect(joint.ordinaryTax, base.ordinaryTax);
    expect(joint.jointPreferredProfit, 5000000);
    expect(joint.projectProfit, base.projectProfit);
    expect(
      joint.ownProfit,
      closeTo((base.projectProfit - 5000000) / 2 - 750000, .01),
    );
    final loss = calculateInvestment(
      input(
        changes: {
          'expenses': 50000000.0,
          'joint': 50000000.0,
          'joint_confirmed': true,
          'joint_rate': 10.0,
        },
      ),
      'base',
    );
    expect(loss.jointPreferredProfit, 0);
  });
  test('기준 현금은 충분해도 보유 지연 자금이 부족하면 보류', () {
    final i = input(
      changes: {
        'cash': 75000000.0,
        'mortgage': 50000000.0,
        'mortgage_confirmed': true,
        'mortgage_rate': 12.0,
        'base_months': 3.0,
      },
    );
    expect(calculateInvestment(i, 'base').fundingGap, 0);
    expect(calculateInvestment(i, 'low').fundingGap, greaterThan(0));
    expect(analyzeInvestment(i, now).verdict, '보류');
  });
  test('일반/추가 과표를 분리하고 개인 이자를 배분 후 전액 차감', () {
    final r = calculateInvestment(
      input(
        changes: {
          'share': 50.0,
          'credit': 90000000.0,
          'credit_confirmed': true,
          'credit_rate': 8.0,
        },
      ),
      'base',
    );
    // 원가113.1m, 일반과표30.24m, 추가과표36.9m.
    expect(r.costBasis, closeTo(113100000, .01));
    expect(r.ordinaryTax, closeTo(6652800, .01));
    expect(r.additionalTax, closeTo(8118000, .01));
    expect(r.projectProfit, closeTo(15469200, .01));
    expect(r.ownProfit, closeTo(-215400, .01));
  });
  test('대출·공투 미승인은 자금과 이자에 넣지 않음', () {
    final i = input(
      changes: {
        'cash': 10000000.0,
        'credit': 90000000.0,
        'credit_rate': 8.0,
        'mortgage': 80000000.0,
        'joint': 90000000.0,
      },
    );
    final r = calculateInvestment(i, 'base');
    expect(i.funds, 10000000);
    expect(r.personalInterest, 0);
    expect(r.fundingGap, closeTo(110600000, .01));
    expect(analyzeInvestment(i, now).verdict, '보류');
  });
  test('주담대는 입찰일 보증금 현금으로 계산하지 않음', () {
    final i = input(
      changes: {
        'cash': 0.0,
        'mortgage': 100000000.0,
        'mortgage_confirmed': true,
      },
    );
    expect(calculateInvestment(i, 'base').depositGap, 10000000);
    expect(analyzeInvestment(i, now).verdict, '보류');
  });
  test('수익 충분해도 미확인/오래된/미래 근거는 통과하지 않음', () {
    for (final e in [
      const InvestmentEvidence(),
      InvestmentEvidence(
        status: 'pass',
        source: 's',
        detail: 'd',
        kind: '공식 원문',
        checkedOn: DateTime(2026, 9, 1),
      ),
      InvestmentEvidence(
        status: 'pass',
        source: 's',
        detail: 'd',
        kind: '공식 원문',
        checkedOn: now.add(const Duration(days: 1)),
      ),
      InvestmentEvidence(
        status: 'pass',
        source: 's',
        detail: 'd',
        kind: '계산 가정',
        checkedOn: now,
      ),
    ]) {
      final good = input();
      final i = input(evidence: {...good.evidence, 'rights': e});
      expect(analyzeInvestment(i, now).verdict, '보류');
    }
  });
  test('위반 등 제외 사유가 있으면 수익/입력보다 우선', () {
    final i = input(
      changes: {'bid': 0.0},
      evidence: {
        'condition': const InvestmentEvidence(status: 'fail', detail: '위반 표기'),
      },
    );
    final r = analyzeInvestment(i, now);
    expect(r.verdict, '제외');
    expect(r.limit, isNull);
  });
  test('손실 시 일반세액0, 추가과표에는 매도중개비를 공제하지 않음', () {
    final r = calculateInvestment(
      input(changes: {'expenses': 40000000.0}),
      'base',
    );
    expect(r.ordinaryTax, 0);
    expect(r.additionalTax, closeTo(8118000, .01));
    expect(r.projectProfit, lessThan(0));
  });
  test('목표 상한은 실제 함수로 역산하고 자금상한 중 낮은 값', () {
    final i = input();
    final d = analyzeInvestment(i, now);
    final limitResult = calculateInvestment(
      i,
      'base',
      bidOverride: d.profitLimit,
    );
    expect(limitResult.ownProfit, closeTo(i.target, 1));
    expect(d.limit, lessThanOrEqualTo(d.cashLimit!));
    expect(
      calculateInvestment(i, 'base', bidOverride: d.limit! + 10000).ownProfit,
      lessThan(i.target),
    );
  });
  test('모든 근거와 자금/수익이 충족될 때만 입찰 검토', () {
    expect(analyzeInvestment(input(), now).verdict, '입찰 검토');
  });
  test('가정 버전과 근거를 JSON 왕복 보존, 잘못된 버전 거부', () {
    final i = input();
    final loaded = InvestmentInputs.fromMap(i.toMap());
    expect(loaded.bid, i.bid);
    expect(loaded.evidence['rights']!.source, i.evidence['rights']!.source);
    expect(
      () => InvestmentInputs.fromMap({'version': 99}),
      throwsFormatException,
    );
  });
  test('무한대·음수·순서가 뒤바뀐 매도 가정을 차단', () {
    for (final bad in [
      {'bid': double.infinity},
      {'share': -1.0},
      {'low_sale': 170000000.0},
      {'base_months': 0.0},
    ]) {
      final d = analyzeInvestment(input(changes: bad), now);
      expect(d.verdict, '입력 필요');
      expect(d.limit, isNull);
    }
  });
}
