import 'dart:math' as math;

/// 사용자 입력과 조사 근거만 사용하는 결정론적 분석. 감정가로 시세를 채우지 않는다.
const investmentVersion = 1;
const investmentGates = <String, String>{
  'identity': '법원·사건·물건번호와 최신 기일',
  'condition': '위반건축물·용도·현장 상태',
  'rights': '인수 권리·임차인·점유',
  'zone': '공식 필지·사업블록·인가 단계',
  'eligibility': '취득 및 재매도 시 지위 승계',
  'market': '유사 면적 실거래·임대·매수 수요',
  'tax': '취득세·법인 유형·과표·비용 처리',
  'funding': '잔금 재원·실행 조건·공투 약정',
};

class InvestmentEvidence {
  final String status, source, detail, kind;
  final DateTime? checkedOn;
  const InvestmentEvidence({
    this.status = 'unknown',
    this.source = '',
    this.detail = '',
    this.kind = '미확인',
    this.checkedOn,
  });

  factory InvestmentEvidence.fromMap(Map<String, dynamic> m) =>
      InvestmentEvidence(
        status: m['status'] as String? ?? 'unknown',
        source: m['source'] as String? ?? '',
        detail: m['detail'] as String? ?? '',
        kind: m['kind'] as String? ?? '미확인',
        checkedOn: DateTime.tryParse(m['checked_on'] as String? ?? ''),
      );
  Map<String, dynamic> toMap() => {
    'status': status,
    'source': source,
    'detail': detail,
    'kind': kind,
    'checked_on': checkedOn?.toIso8601String(),
  };

  /// 최근 근거가 있을 때만 통과. 오래된 부적합을 자동 해제하지 않는다.
  bool verified(DateTime now) {
    if (status != 'pass' ||
        source.trim().isEmpty ||
        detail.trim().isEmpty ||
        !const ['공식 원문', '사용자 제공', '현장 확인', '민간 자료'].contains(kind) ||
        checkedOn == null) {
      return false;
    }
    final day = DateTime(now.year, now.month, now.day);
    final checked = DateTime(checkedOn!.year, checkedOn!.month, checkedOn!.day);
    return !checked.isAfter(day) && day.difference(checked).inDays <= 30;
  }
}

class InvestmentInputs {
  final Map<String, dynamic> values;
  final Map<String, InvestmentEvidence> evidence;
  InvestmentInputs(
    Map<String, dynamic> values, [
    Map<String, InvestmentEvidence> evidence = const {},
  ]) : values = Map.unmodifiable(values),
       evidence = Map.unmodifiable(evidence);

  double n(String key) {
    final value = values[key];
    return value is num && value.isFinite ? value.toDouble() : 0;
  }

  bool b(String key) => values[key] == true;
  double get bid => n('bid');
  double get share => n('share') / 100;
  double get approvedMortgage => b('mortgage_confirmed') ? n('mortgage') : 0;
  double get approvedCredit => b('credit_confirmed') ? n('credit') : 0;
  double get approvedJoint => b('joint_confirmed') ? n('joint') : 0;
  double get funds =>
      n('cash') + approvedMortgage + approvedCredit + approvedJoint;
  double get target => n('target');

  List<String> get errors {
    final out = <String>[];
    for (final e in values.entries) {
      if (!const [
            'tax_note',
            'market_note',
            'target_scope',
            'credit_confirmed',
            'mortgage_confirmed',
            'joint_confirmed',
          ].contains(e.key) &&
          e.value != null &&
          e.value is! num) {
        out.add('${e.key}: 숫자 형식을 확인하세요');
      }
      if (e.value is num &&
          (!(e.value as num).isFinite || (e.value as num) < 0)) {
        out.add('${e.key}: 0 이상의 유한한 값을 입력하세요');
      }
    }
    for (final k in [
      'share',
      'acq_pct',
      'ordinary_pct',
      'additional_pct',
      'local_pct',
      'sale_fee_pct',
      'mortgage_rate',
      'credit_rate',
      'joint_rate',
    ]) {
      if (n(k) > 100) out.add('$k: 100%를 초과할 수 없어요');
    }
    if (share <= 0) out.add('본인 이익 배분율을 입력하세요');
    if (n('deposit') <= 0) out.add('원문에서 입찰보증금을 확인해 입력하세요');
    if (!const ['own', 'project'].contains(values['target_scope'])) {
      out.add('목표 적용 범위를 확인하세요');
    }
    if (target <= 0) out.add('목표 수익을 입력하세요');
    if (bid <= 0) out.add('검토 입찰가를 입력하세요');
    if (approvedMortgage > bid) out.add('승인 주담대가 입찰가를 초과해요');
    if (n('deposit') > bid) out.add('입찰보증금이 입찰가를 초과해요');
    for (final s in ['low', 'base', 'high']) {
      if (n('${s}_sale') <= 0) out.add('$s 매도가 가정을 입력하세요');
      if (n('${s}_months') <= 0 || n('${s}_months') > 120) {
        out.add('$s 보유기간은 0 초과 120개월 이하로 입력하세요');
      }
    }
    if (n('low_sale') > n('base_sale') || n('base_sale') > n('high_sale')) {
      out.add('매도가는 보수적 ≤ 기준 ≤ 공격적으로 입력하세요');
    }
    return out;
  }

  Map<String, dynamic> toMap() => {
    'version': investmentVersion,
    'values': values,
    'evidence': evidence.map((k, v) => MapEntry(k, v.toMap())),
  };

  factory InvestmentInputs.fromMap(Map<String, dynamic> m) {
    if (m['version'] != investmentVersion) {
      throw const FormatException('지원하지 않는 분석 버전이에요');
    }
    final values = Map<String, dynamic>.from(m['values'] as Map);
    final evidence = <String, InvestmentEvidence>{};
    for (final e in (m['evidence'] as Map? ?? {}).entries) {
      if (investmentGates.containsKey(e.key)) {
        evidence[e.key as String] = InvestmentEvidence.fromMap(
          Map<String, dynamic>.from(e.value as Map),
        );
      }
    }
    return InvestmentInputs(values, evidence);
  }
}

/// AI 제안은 초안이다. 자금 약정·기존 제외를 바꾸거나, 다른 숫자에
/// 예전 확인을 재사용하지 못하도록 UI와 독립된 경계에서 병합한다.
InvestmentInputs mergeAnalyzedInvestment(
  InvestmentInputs current,
  InvestmentInputs proposed,
) {
  final values = {...current.values, ...proposed.values};
  for (final key in [
    'cash',
    'credit',
    'credit_confirmed',
    'credit_rate',
    'mortgage',
    'mortgage_confirmed',
    'mortgage_rate',
    'joint',
    'joint_confirmed',
    'joint_rate',
    'share',
    'target',
    'target_scope',
    'distribution_cost',
  ]) {
    values[key] = current.values[key];
  }
  final changed = values.keys.any((k) => values[k] != current.values[k]);
  final evidence = <String, InvestmentEvidence>{};
  for (final key in investmentGates.keys) {
    final old = current.evidence[key];
    final next = proposed.evidence[key] ?? const InvestmentEvidence();
    if (old?.status == 'fail') {
      evidence[key] = old!;
      continue;
    }
    final selected = next.status == 'pass' && old?.status == 'pass'
        ? old!
        : next;
    if (selected.status == 'pass' && (changed || old?.status != 'pass')) {
      evidence[key] = InvestmentEvidence(
        status: 'unknown',
        kind: selected.kind,
        source: selected.source,
        checkedOn: selected.checkedOn,
        detail: 'AI 제안 또는 가정 변경 후 확인 대기. ${selected.detail}',
      );
    } else {
      evidence[key] = selected;
    }
  }
  return InvestmentInputs(values, evidence);
}

class InvestmentScenario {
  final double sale,
      months,
      costBasis,
      ordinaryTax,
      additionalTax,
      corporateInterest,
      personalInterest,
      jointPreferredProfit,
      projectProfit,
      ownProfit,
      peakCash,
      fundingGap,
      depositGap;
  const InvestmentScenario({
    required this.sale,
    required this.months,
    required this.costBasis,
    required this.ordinaryTax,
    required this.additionalTax,
    required this.corporateInterest,
    required this.personalInterest,
    required this.jointPreferredProfit,
    required this.projectProfit,
    required this.ownProfit,
    required this.peakCash,
    required this.fundingGap,
    required this.depositGap,
  });
}

InvestmentScenario calculateInvestment(
  InvestmentInputs i,
  String scenario, {
  double? bidOverride,
}) {
  final bid = bidOverride ?? i.bid;
  final sale = i.n('${scenario}_sale'), months = i.n('${scenario}_months');
  final basis =
      bid * (1 + i.n('acq_pct') / 100) +
      i.n('legal') +
      i.n('capitalized') +
      i.n('takeover');
  final expenses = i.n('expenses');
  final corporateInterest =
      i.approvedMortgage * i.n('mortgage_rate') / 100 * months / 12;
  final personalInterest =
      i.approvedCredit * i.n('credit_rate') / 100 * months / 12;
  final saleFee = sale * i.n('sale_fee_pct') / 100;
  final ordinaryBase = math.max(
    0,
    sale - basis - expenses - corporateInterest - saleFee,
  );
  final additionalBase = math.max(0, sale - basis);
  final local = 1 + i.n('local_pct') / 100;
  final ordinaryTax = ordinaryBase * i.n('ordinary_pct') / 100 * local;
  final additionalTax = additionalBase * i.n('additional_pct') / 100 * local;
  final projectProfit =
      sale -
      basis -
      expenses -
      corporateInterest -
      saleFee -
      ordinaryTax -
      additionalTax;
  // 공투 출자금의 우선배분은 이익 한도 내에서 세후 배분한다.
  // 법인 차입이자가 아니므로 일반 손금이나 보유기간 현금유출에 넣지 않는다.
  final jointPreferredProfit = math.min(
    math.max(0.0, projectProfit),
    i.approvedJoint * i.n('joint_rate') / 100 * months / 12,
  );
  final ownProfit =
      (projectProfit - jointPreferredProfit) * i.share -
      personalInterest -
      i.n('distribution_cost') -
      i.n('reserve') * i.share;
  final peakCash =
      basis + expenses + corporateInterest + personalInterest + i.n('reserve');
  return InvestmentScenario(
    sale: sale,
    months: months,
    costBasis: basis,
    ordinaryTax: ordinaryTax,
    additionalTax: additionalTax,
    corporateInterest: corporateInterest,
    personalInterest: personalInterest,
    jointPreferredProfit: jointPreferredProfit,
    projectProfit: projectProfit,
    ownProfit: ownProfit,
    peakCash: peakCash,
    fundingGap: math.max(0, peakCash - i.funds),
    // 승인 잔금대출도 입찰보증금 시점의 현금으로 취급하지 않는다.
    depositGap: math.max(0, i.n('deposit') - i.n('cash')),
  );
}

class InvestmentDecision {
  final String verdict;
  final List<String> actions;

  /// 가정상 수익/자금 상한. 확인 미완료이면 실행 상한으로 사용하지 않는다.
  final double? profitLimit, cashLimit;
  const InvestmentDecision(
    this.verdict,
    this.actions,
    this.profitLimit,
    this.cashLimit,
  );
  double? get limit => profitLimit == null || cashLimit == null
      ? null
      : math.min(profitLimit!, cashLimit!);
}

InvestmentDecision analyzeInvestment(InvestmentInputs i, DateTime now) {
  final failures = investmentGates.entries.where(
    (e) => i.evidence[e.key]?.status == 'fail',
  );
  final actions = <String>[
    for (final e in failures) '${e.value}: 부적합 사유 해결 또는 제외',
    for (final e in investmentGates.entries)
      if (i.evidence[e.key]?.status != 'fail' &&
          !(i.evidence[e.key]?.verified(now) ?? false))
        '${e.value}: 출처·확인일·확인 내용을 보완하세요 (30일 이내)',
    ...i.errors,
  ];
  if (failures.isNotEmpty) return InvestmentDecision('제외', actions, null, null);
  if (i.errors.isNotEmpty) {
    return InvestmentDecision('입력 필요', actions, null, null);
  }
  final base = calculateInvestment(i, 'base');
  final low = calculateInvestment(i, 'low');
  final selected = i.values['target_scope'] == 'project'
      ? base.projectProfit
      : base.ownProfit;
  if (base.fundingGap > 0) actions.add('잔금·보유 재원이 부족해요. 승인 자금 또는 입찰가를 조정하세요');
  if (low.fundingGap > 0) actions.add('매도 지연 시 보수적 시나리오의 현금이 부족해요');
  if (base.depositGap > 0) actions.add('입찰일 보증금 현금을 확보하세요');
  if (selected < i.target) actions.add('기준 시나리오 목표 미달: 입찰가 또는 매도 근거를 재검토하세요');
  if (low.ownProfit < 0) actions.add('보수적 시나리오 본인 손실: 손실 한도·매도 지연을 검토하세요');
  final maxBid = math.max(i.n('base_sale'), i.funds) * 2 + 1;
  double bound(bool Function(double) allowed) {
    if (!allowed(0)) return 0;
    var lo = 0.0, hi = maxBid;
    for (var n = 0; n < 80; n++) {
      final mid = (lo + hi) / 2;
      if (allowed(mid)) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  final profitLimit = bound((b) {
    final r = calculateInvestment(i, 'base', bidOverride: b);
    return (i.values['target_scope'] == 'project'
            ? r.projectProfit
            : r.ownProfit) >=
        i.target;
  });
  final cashLimit = bound(
    (b) =>
        calculateInvestment(i, 'base', bidOverride: b).fundingGap == 0 &&
        calculateInvestment(i, 'low', bidOverride: b).fundingGap == 0,
  );
  return InvestmentDecision(
    actions.isEmpty ? '입찰 검토' : '보류',
    actions,
    profitLimit,
    cashLimit,
  );
}
