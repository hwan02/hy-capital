// 경매 물건 3-시나리오 자동 분석.
//
// 물건을 등록하면 보수적·기준·공격적 3가지 매도가 가정으로
// 세전/세후 수익, 필요현금, 세후3천 상한 입찰가를 한 번에 계산한다.
// 순수 함수 — UI·DB 의존 없음.

/// 하나의 시나리오 결과.
class ScenarioResult {
  final String label; // 보수적 / 기준 / 공격적
  final double salePrice; // 매도가 가정
  final double bidPrice; // 입찰가
  final double acqTaxRate; // 취득세율 (%)
  final double acqTax; // 취득세
  final double totalCost; // 총원가 (입찰가+취득세+등기+수리+명도+기타)
  final double preTaxProfit; // 세전 수익
  final double taxRate; // 법인세+추가과세 실효세율 (%)
  final double tax; // 세금
  final double afterTaxProfit; // 세후 수익
  final double cashNeeded; // 필요현금 (대출 차감 후)

  const ScenarioResult({
    required this.label,
    required this.salePrice,
    required this.bidPrice,
    required this.acqTaxRate,
    required this.acqTax,
    required this.totalCost,
    required this.preTaxProfit,
    required this.taxRate,
    required this.tax,
    required this.afterTaxProfit,
    required this.cashNeeded,
  });

  /// 세후 목표(기본 3천만) 충족 여부.
  bool meetsTarget([double target = 30000000]) => afterTaxProfit >= target;
}

/// 3-시나리오 분석 결과 묶음.
class ScenarioAnalysis {
  final ScenarioResult conservative; // 보수적 (매도가 -10%)
  final ScenarioResult standard; // 기준 (매도가 그대로)
  final ScenarioResult aggressive; // 공격적 (매도가 +10%)
  final double maxBidForTarget; // 세후3천 상한 입찰가 (기준 매도가 기준)
  final double maxBidPct; // 상한이 최저가의 몇 % 인지
  final double competitionBidProfit; // 경쟁(116%) 입찰 시 기준 매도가 세후 수익

  const ScenarioAnalysis({
    required this.conservative,
    required this.standard,
    required this.aggressive,
    required this.maxBidForTarget,
    required this.maxBidPct,
    required this.competitionBidProfit,
  });

  /// 전체 판정: 보수적에서도 목표 충족이면 GO, 기준만 충족이면 HOLD, 기준도 미달이면 PASS.
  String get autoVerdict {
    if (conservative.meetsTarget()) return 'GO';
    if (standard.meetsTarget()) return 'HOLD';
    return 'PASS';
  }
}

/// 시나리오 분석 실행.
///
/// [salePrice] 기준 매도가 (실거래가 또는 감정가).
/// [bidPrice] 입찰 예정가 (통상 최저가).
/// [acqTaxPct] 취득세율 % (공시가 1억↓ 모아타운 조합설립 전 = 1.1, 그 외 = 13.4).
/// [legalFee] 등기비용 (원). 미입력이면 200만 가정.
/// [repairCost] 수리비 (원).
/// [evictionCost] 명도비 (원).
/// [otherCost] 기타/예비비 (원).
/// [saleCostPct] 매도 중개보수 % (기본 0.5).
/// [corpTaxPct] 법인세+추가과세 실효세율 % (기본 40).
/// [loanPct] 경락잔금대출 비율 % (기본 0 — 확인 전 적용하지 않음).
/// [targetProfit] 세후 목표 수익 (원, 기본 3천만).
/// [competitionPct] 경쟁 입찰 비율 % (기본 116 — 601호 낙찰 기준).
ScenarioAnalysis runScenarios({
  required double salePrice,
  required double bidPrice,
  double acqTaxPct = 13.4,
  double legalFee = 2000000,
  double repairCost = 0,
  double evictionCost = 0,
  double otherCost = 0,
  double saleCostPct = 0.5,
  double corpTaxPct = 40,
  double loanPct = 0,
  double targetProfit = 30000000,
  double competitionPct = 116,
}) {
  ScenarioResult calc(String label, double sale, double bid) {
    final acqTax = bid * acqTaxPct / 100;
    final upfront = acqTax + legalFee + repairCost + evictionCost + otherCost;
    final totalCost = bid + upfront;
    final saleCost = sale * saleCostPct / 100;
    final preTax = sale - totalCost - saleCost;
    final tax = preTax > 0 ? preTax * corpTaxPct / 100 : 0.0;
    final afterTax = preTax - tax;
    final loan = bid * loanPct / 100;
    final cash = bid - loan + upfront;
    return ScenarioResult(
      label: label,
      salePrice: sale,
      bidPrice: bid,
      acqTaxRate: acqTaxPct,
      acqTax: acqTax,
      totalCost: totalCost,
      preTaxProfit: preTax,
      taxRate: corpTaxPct,
      tax: tax,
      afterTaxProfit: afterTax,
      cashNeeded: cash,
    );
  }

  final conservative = calc('보수적', salePrice * 0.9, bidPrice);
  final standard = calc('기준', salePrice, bidPrice);
  final aggressive = calc('공격적', salePrice * 1.1, bidPrice);

  // 세후3천 상한: 기준 매도가에서 세후 targetProfit을 남기는 최대 입찰가.
  // afterTax = (sale - bid*(1+acq%) - legal - repair - evict - other - saleCost) * (1 - tax%)
  // targetProfit = afterTax 이므로:
  // targetProfit / (1-tax%) = sale - bid*(1+acq%) - fixed - saleCost
  // bid = (sale - fixed - saleCost - targetProfit/(1-tax%)) / (1+acq%)
  final taxKeep = 1 - corpTaxPct / 100;
  final fixed = legalFee + repairCost + evictionCost + otherCost;
  final saleCostAmt = salePrice * saleCostPct / 100;
  final requiredPreTax = taxKeep > 0 ? targetProfit / taxKeep : targetProfit;
  final maxBid =
      (salePrice - fixed - saleCostAmt - requiredPreTax) / (1 + acqTaxPct / 100);

  final maxBidPct = bidPrice > 0 ? (maxBid / bidPrice) * 100 : 0;

  // 경쟁 시나리오 (116% 입찰 시 기준 매도가)
  final compBid = bidPrice * competitionPct / 100;
  final compResult = calc('경쟁', salePrice, compBid);

  return ScenarioAnalysis(
    conservative: conservative,
    standard: standard,
    aggressive: aggressive,
    maxBidForTarget: maxBid,
    maxBidPct: maxBidPct.toDouble(),
    competitionBidProfit: compResult.afterTaxProfit,
  );
}

/// 물건에서 자동 시나리오를 돌릴 때 사용할 기준 매도가를 정한다.
/// 우선순위: ① 사용자가 입력한 expectedSalePrice ② 감정가 ③ 현재시세.
double pickSalePrice({
  double expectedSalePrice = 0,
  double appraisalPrice = 0,
  double currentPrice = 0,
}) {
  if (expectedSalePrice > 0) return expectedSalePrice;
  if (appraisalPrice > 0) return appraisalPrice;
  return currentPrice;
}
