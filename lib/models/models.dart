// HY CAPITAL 도메인 모델. Supabase row(Map)로부터 파싱.

double _d(dynamic v) => v == null ? 0 : (v as num).toDouble();
int _i(dynamic v) => v == null ? 0 : (v as num).toInt();
DateTime? _date(dynamic v) => v == null ? null : DateTime.parse(v as String);

class Profile {
  final String id;
  final String? displayName;
  final double monthlyExpenses;
  final double netWorthGoal;
  final double freedomTarget; // 월 목표 현금흐름 (Freedom Score 기준선)
  final String poolBusinessLabel;
  final String poolSalaryLabel;

  /// 경매에 쓸 수 있는 돈. 전체 현금과 분리해서 관리한다(0 이면 미설정).
  final double auctionBudget;

  Profile({
    required this.id,
    this.displayName,
    required this.monthlyExpenses,
    required this.netWorthGoal,
    required this.freedomTarget,
    required this.poolBusinessLabel,
    required this.poolSalaryLabel,
    this.auctionBudget = 0,
  });

  factory Profile.fromMap(Map<String, dynamic> m) => Profile(
        id: m['id'],
        displayName: m['display_name'],
        monthlyExpenses: _d(m['monthly_expenses']),
        netWorthGoal: _d(m['net_worth_goal']),
        freedomTarget:
            m['freedom_target'] == null ? 10000000 : _d(m['freedom_target']),
        poolBusinessLabel: m['pool_business_label'] ?? '사업자금',
        poolSalaryLabel: m['pool_salary_label'] ?? '월급·개인자금',
        auctionBudget: _d(m['auction_budget']),
      );
}

class FinancialSnapshot {
  final String id;
  final DateTime asOf;
  final double netWorth;
  final double cash;
  final double nonSalaryCashflow;
  final double salaryCashflow;

  FinancialSnapshot({
    required this.id,
    required this.asOf,
    required this.netWorth,
    required this.cash,
    required this.nonSalaryCashflow,
    required this.salaryCashflow,
  });

  factory FinancialSnapshot.fromMap(Map<String, dynamic> m) => FinancialSnapshot(
        id: m['id'],
        asOf: DateTime.parse(m['as_of']),
        netWorth: _d(m['net_worth']),
        cash: _d(m['cash']),
        nonSalaryCashflow: _d(m['non_salary_cashflow']),
        salaryCashflow: _d(m['salary_cashflow']),
      );
}

class CashFlow {
  final String id;
  final DateTime occurredOn;
  final String source;
  final String target;
  final double amount;
  final bool isSalary;
  final String? memo;

  CashFlow({
    required this.id,
    required this.occurredOn,
    required this.source,
    required this.target,
    required this.amount,
    required this.isSalary,
    this.memo,
  });

  factory CashFlow.fromMap(Map<String, dynamic> m) => CashFlow(
        id: m['id'],
        occurredOn: DateTime.parse(m['occurred_on']),
        source: m['source'],
        target: m['target'],
        amount: _d(m['amount']),
        isSalary: m['is_salary'] ?? false,
        memo: m['memo'],
      );
}

class AirbnbUnit {
  final String id;
  final String name;
  final String status; // planning|preparing|open
  final double reserveFund;
  final double targetFund;
  final DateTime? expectedOpen;
  final double monthlyProfit;
  final double monthlyTarget;
  final double roi;
  final double occupancy;

  AirbnbUnit({
    required this.id,
    required this.name,
    required this.status,
    required this.reserveFund,
    required this.targetFund,
    required this.expectedOpen,
    required this.monthlyProfit,
    required this.monthlyTarget,
    required this.roi,
    required this.occupancy,
  });

  double get progress =>
      targetFund <= 0 ? 0 : (reserveFund / targetFund).clamp(0, 1).toDouble();

  factory AirbnbUnit.fromMap(Map<String, dynamic> m) => AirbnbUnit(
        id: m['id'],
        name: m['name'],
        status: m['status'],
        reserveFund: _d(m['reserve_fund']),
        targetFund: _d(m['target_fund']),
        expectedOpen: _date(m['expected_open']),
        monthlyProfit: _d(m['monthly_profit']),
        monthlyTarget: _d(m['monthly_target']),
        roi: _d(m['roi']),
        occupancy: _d(m['occupancy']),
      );
}

class ShortsChannel {
  final String id;
  final String name;
  final String platform;
  final String? link;
  final int uploads;
  final int views;
  final double rpm;
  final double revenue;
  final double netProfit;
  final double roi;
  final double reinvestRatio;
  final double monthlyTarget;

  ShortsChannel({
    required this.id,
    required this.name,
    required this.platform,
    this.link,
    required this.uploads,
    required this.views,
    required this.rpm,
    required this.revenue,
    required this.netProfit,
    required this.roi,
    required this.reinvestRatio,
    required this.monthlyTarget,
  });

  factory ShortsChannel.fromMap(Map<String, dynamic> m) => ShortsChannel(
        id: m['id'],
        name: m['name'],
        platform: m['platform'],
        link: m['link'],
        uploads: _i(m['uploads']),
        views: _i(m['views']),
        rpm: _d(m['rpm']),
        revenue: _d(m['revenue']),
        netProfit: _d(m['net_profit']),
        roi: _d(m['roi']),
        reinvestRatio: _d(m['reinvest_ratio']),
        monthlyTarget: _d(m['monthly_target']),
      );
}

class LandProject {
  final String id;
  final String name;
  final String? analysis;
  final String? catalyst;
  final double principal;
  final double targetPrice;
  final String? expertOpinion;
  final String status; // reviewing|holding|sold
  final double reserveFund; // 사업자금 적립
  final double targetFund;  // 사업자금 목표

  LandProject({
    required this.id,
    required this.name,
    this.analysis,
    this.catalyst,
    required this.principal,
    required this.targetPrice,
    this.expertOpinion,
    required this.status,
    required this.reserveFund,
    required this.targetFund,
  });

  double get expectedReturnPct =>
      principal <= 0 ? 0 : ((targetPrice - principal) / principal) * 100;

  double get fundProgress =>
      targetFund <= 0 ? 0 : (reserveFund / targetFund).clamp(0, 1).toDouble();

  factory LandProject.fromMap(Map<String, dynamic> m) => LandProject(
        id: m['id'],
        name: m['name'],
        analysis: m['analysis'],
        catalyst: m['catalyst'],
        principal: _d(m['principal']),
        targetPrice: _d(m['target_price']),
        expertOpinion: m['expert_opinion'],
        status: m['status'],
        reserveFund: _d(m['reserve_fund']),
        targetFund: _d(m['target_fund']),
      );
}

/// 부동산 경매 투자 판단 물건. 돈 관련 값은 원(₩) 단위.
/// 필요현금·순수익·ROI·최대입찰가는 저장하지 않고 계산으로 파생한다.
class AuctionProperty {
  final String id;
  final String title;
  final String? address;
  final String? caseNo;
  final String status; // interest|researching|visited|bidding|won|sold|pass
  final double currentPrice; // 현재시세
  final double expectedSalePrice; // 예상매도가
  final double minPrice; // 최저가
  final double bidPrice; // 예상입찰가
  final double loanAmount; // 경락잔금대출
  final double acquisitionCost; // 취득·등기비
  final double repairCost; // 수리/인테리어
  final double evictionCost; // 명도비
  final double otherCost; // 기타/예비비/미납관리비
  final double saleCost; // 매도비용
  final double financeCost; // 대출이자/금융비용
  final double targetProfit; // 목표수익
  final double score; // 투자점수 0~100
  final String verdict; // GO|HOLD|PASS
  final String? memo;
  final Map<String, dynamic> checklist; // 입찰 전 체크리스트(온라인·오프라인·권리·최종점검)
  final List<String> images; // 스크린샷 base64 data URL 목록
  final DateTime? bidDate; // 매각기일
  final String? court; // 입찰법원·계
  final double appraisalPrice; // 감정가
  final double deposit; // 입찰보증금 (통상 최저가 10%, 재매각은 20~30%)
  final String? propertyKind; // 아파트|빌라|다세대|오피스텔|기타
  final String strategy; // flip=아파트 차익 · plus=모아·신속 빌라 플피
  final double jeonsePrice; // 전세 시세 (플피 판정의 핵심)
  final String? districtType; // 모아타운|신통기획|없음
  final String? complexId; // 소속 단지 — 시세를 여기서 상속받는다
  final String acquisition; // auction=경매 · quick_sale=급매
  final String mode; // sim=모의 · real=실제 (모의투자 트레이닝)
  final double actualPrice; // 실제 낙찰가 (결과 회고용)
  final String? reason; // 입찰 판단 근거 — 왜 이 물건/이 가격
  final String? review; // 원인분석(회고) — 내 입찰가 vs 낙찰가
  final bool alertEnabled; // 매각기일 알림 받기 (D-3·2·1)
  final bool excluded; // 목록에서 제외(삭제 아님)

  // ── 진행 일정 ──────────────────────────────────────────
  final DateTime? wonDate; // 낙찰일
  final DateTime? balanceDue; // 잔금 납부 기한 — 넘기면 보증금 몰수
  final DateTime? evictDue; // 명도 목표일 / 합의 이사일
  final DateTime? repairDue; // 수리 완료 목표일
  final DateTime? exitDue; // 매도·전세 세팅 목표일
  final DateTime? soldDate; // 매도·전세 세팅 완료일

  AuctionProperty({
    required this.id,
    required this.title,
    this.address,
    this.caseNo,
    required this.status,
    required this.currentPrice,
    required this.expectedSalePrice,
    required this.minPrice,
    required this.bidPrice,
    required this.loanAmount,
    required this.acquisitionCost,
    required this.repairCost,
    required this.evictionCost,
    required this.otherCost,
    required this.saleCost,
    required this.financeCost,
    required this.targetProfit,
    required this.score,
    required this.verdict,
    this.memo,
    this.checklist = const {},
    this.images = const [],
    this.bidDate,
    this.court,
    this.appraisalPrice = 0,
    this.deposit = 0,
    this.propertyKind,
    this.strategy = 'flip',
    this.jeonsePrice = 0,
    this.districtType,
    this.complexId,
    this.acquisition = 'auction',
    this.mode = 'sim',
    this.actualPrice = 0,
    this.reason,
    this.review,
    this.alertEnabled = false,
    this.excluded = false,
    this.wonDate,
    this.balanceDue,
    this.evictDue,
    this.repairDue,
    this.exitDue,
    this.soldDate,
  });

  /// 급매(일반 매매)인가. 경매와 계산 틀은 같고 이름만 다르다 —
  /// 최저가→호가, 입찰보증금→계약금, 예상입찰가→협상가.
  bool get isQuickSale => acquisition == 'quick_sale';
  String get priceLabel => isQuickSale ? '호가' : '최저가';
  String get bidLabel => isQuickSale ? '협상가' : '예상입찰가';
  String get depositLabel => isQuickSale ? '계약금' : '입찰보증금';

  /// 모아·신속 선정지 빌라 플피 전략인가.
  bool get isPlus => strategy == 'plus';

  /// 선투입 부대비용 — 매도 시점 비용(매도비용·금융비용)은 제외한다.
  double get _upfrontCosts =>
      acquisitionCost + repairCost + evictionCost + otherCost;

  /// 실투자금 (플피형) = 낙찰가 + 선투입비용 − 전세보증금.
  /// 음수면 돈이 남는다(플피). 전세를 놓으면 경락잔금대출은 통상 못 쓰므로
  /// 대출은 빼지 않는다.
  double get ownCash => bidPrice + _upfrontCosts - jeonsePrice;

  /// 플피 금액 — 실투자금이 음수일 때 남는 돈.
  double get plusPi => ownCash < 0 ? -ownCash : 0;
  bool get isPlusPiSet => jeonsePrice > 0 && ownCash <= 0;

  /// 전세가 ≥ 낙찰가 — 플피 전략의 성립 조건.
  bool get jeonseCoversBid => jeonsePrice > 0 && jeonsePrice >= bidPrice;

  /// 전략에 맞는 '내 돈' — 카드·계산기가 이 값을 보여준다.
  double get moneyIn => isPlus ? ownCash : cashNeeded;

  /// 입찰보증금. 저장값이 없으면 최저가의 10% 로 본다(통상 기준).
  double get depositDue => deposit > 0 ? deposit : minPrice * 0.1;

  /// 최저가 / 감정가 — 몇 회 유찰됐는지 가늠하는 값.
  double get minToAppraisal =>
      appraisalPrice <= 0 ? 0 : (minPrice / appraisalPrice) * 100;

  /// 입찰일까지 남은 날. 지났으면 음수.
  int? get daysToBid {
    if (bidDate == null) return null;
    final now = DateTime.now();
    return DateTime(bidDate!.year, bidDate!.month, bidDate!.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
  }

  bool get bidPassed => (daysToBid ?? 1) < 0;

  /// 자금 게이트 — 가용현금으로 입찰보증금이 되는가.
  /// 안 되면 조사할 이유가 없다(입찰 자체가 불가).
  /// cash 가 0(미입력)이면 판정하지 않는다.
  bool cashShort(double cash) => cash > 0 && depositDue > cash;
  double shortfall(double cash) => (depositDue - cash).clamp(0, double.infinity);

  // 모든 부대비용 합(입찰가 제외).
  double get _costs =>
      acquisitionCost +
      repairCost +
      evictionCost +
      otherCost +
      saleCost +
      financeCost;

  double get discountAmount => currentPrice - bidPrice; // 시세 대비 할인액
  double get discountRate =>
      currentPrice <= 0 ? 0 : (discountAmount / currentPrice) * 100;

  // 필요현금 = 낙찰가 - 대출 + 취득·등기비 + 수리비 + 명도비 + 기타선투입.
  double get cashNeeded =>
      bidPrice - loanAmount + acquisitionCost + repairCost + evictionCost + otherCost;

  // 예상순수익 = 예상매도가 - 낙찰가 - 모든 비용.
  double get netProfit => expectedSalePrice - bidPrice - _costs;

  double get roi => cashNeeded <= 0 ? 0 : (netProfit / cashNeeded) * 100;

  // 최대입찰가 = 예상매도가 - 모든 비용 - 목표수익.
  double get maxBid => expectedSalePrice - _costs - targetProfit;

  // 최대입찰가 초과 → 입찰 비추천.
  bool get overMaxBid => maxBid > 0 && bidPrice > maxBid;
  // 목표수익 미달.
  bool get belowTarget => targetProfit > 0 && netProfit < targetProfit;

  factory AuctionProperty.fromMap(Map<String, dynamic> m) => AuctionProperty(
        id: m['id'],
        title: m['title'] ?? '',
        address: m['address'],
        caseNo: m['case_no'],
        status: m['status'] ?? 'interest',
        currentPrice: _d(m['current_price']),
        expectedSalePrice: _d(m['expected_sale_price']),
        minPrice: _d(m['min_price']),
        bidPrice: _d(m['bid_price']),
        loanAmount: _d(m['loan_amount']),
        acquisitionCost: _d(m['acquisition_cost']),
        repairCost: _d(m['repair_cost']),
        evictionCost: _d(m['eviction_cost']),
        otherCost: _d(m['other_cost']),
        saleCost: _d(m['sale_cost']),
        financeCost: _d(m['finance_cost']),
        targetProfit: _d(m['target_profit']),
        score: _d(m['score']),
        verdict: m['verdict'] ?? 'HOLD',
        memo: m['memo'],
        checklist: (m['checklist'] as Map?)?.cast<String, dynamic>() ??
            const {},
        images: (m['images'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
        bidDate: m['bid_date'] == null
            ? null
            : DateTime.tryParse(m['bid_date'].toString())?.toLocal(),
        court: m['court'],
        appraisalPrice: _d(m['appraisal_price']),
        deposit: _d(m['deposit']),
        propertyKind: m['property_kind'],
        strategy: m['strategy'] ?? 'flip',
        jeonsePrice: _d(m['jeonse_price']),
        districtType: m['district_type'],
        complexId: m['complex_id'],
        acquisition: m['acquisition'] ?? 'auction',
        mode: m['mode'] ?? 'sim',
        actualPrice: _d(m['actual_price']),
        reason: m['reason'],
        review: m['review'],
        alertEnabled: m['alert_enabled'] == true,
        excluded: m['excluded'] == true,
        wonDate: _date(m['won_date']),
        balanceDue: _date(m['balance_due']),
        evictDue: _date(m['evict_due']),
        repairDue: _date(m['repair_due']),
        exitDue: _date(m['exit_due']),
        soldDate: _date(m['sold_date']),
      );

  /// 모의투자인가 (기본값 모의).
  bool get isSim => mode != 'real';

  /// 실제 낙찰가가 있고, 내 입찰가로 이겼을지.
  bool get wouldWin => actualPrice > 0 && bidPrice >= actualPrice;

  /// 내 입찰가 − 실제 낙찰가 (양수면 더 썼다).
  double get bidGap => actualPrice > 0 ? bidPrice - actualPrice : 0;
}

/// 경매 계산기 이력 — 입력값 전체를 inputs(jsonb)로 저장.
class CalcRecord {
  final String id;
  final String label;
  final Map<String, dynamic> inputs;
  final DateTime createdAt;
  CalcRecord({
    required this.id,
    required this.label,
    required this.inputs,
    required this.createdAt,
  });
  double num_(String k) => (inputs[k] as num?)?.toDouble() ?? 0;
  factory CalcRecord.fromMap(Map<String, dynamic> m) => CalcRecord(
        id: m['id'],
        label: m['label'] ?? '',
        inputs: (m['inputs'] as Map?)?.cast<String, dynamic>() ?? const {},
        createdAt: DateTime.parse(m['created_at']),
      );
}

/// 부동산 세제·규제 타임라인 이벤트.
class TaxEvent {
  final String id;
  final DateTime date;
  final String title;
  final String? description;
  final String kind; // 세제 | 정비
  final bool pending; // 국회 통과 전(확정 아님)
  final String? source;
  TaxEvent({
    required this.id,
    required this.date,
    required this.title,
    this.description,
    this.kind = '세제',
    this.pending = false,
    this.source,
  });
  factory TaxEvent.fromMap(Map<String, dynamic> m) => TaxEvent(
        id: m['id'],
        date: DateTime.parse(m['event_date']),
        title: m['title'] ?? '',
        description: m['description'],
        kind: m['kind'] ?? '세제',
        pending: m['pending'] == true,
        source: m['source'],
      );
}

class DividendHolding {
  final String id;
  final String ticker;
  final String market; // 국장 | 미장
  final double purchasePrice; // 매입액 (주당, 국장=KRW·미장=USD)
  final double price; // 평가액 (주당)
  final double shares; // 수량
  final double annualYield; // 연배당률 %
  final String? symbol; // 티커/코드 (국장=6자리, 미장=심볼) — 실시간 시세용

  DividendHolding({
    required this.id,
    required this.ticker,
    required this.market,
    required this.purchasePrice,
    required this.price,
    required this.shares,
    required this.annualYield,
    this.symbol,
  });

  bool get isUsd => market == '미장';

  // ── 원(native) 통화 기준 총액: 주당 값 × 수량 ──
  double get marketValue => price * shares; // 총 평가금액
  double get purchaseValue => purchasePrice * shares; // 총 매입금액
  double get annualDividend => marketValue * annualYield / 100; // 연배당
  double get monthlyDividend => annualDividend / 12; // 월배당
  double get yieldPct => annualYield;
  double get returnPct => purchaseValue <= 0
      ? 0
      : (marketValue - purchaseValue) / purchaseValue * 100;

  /// 환율 적용 KRW 값 (미장이면 ×rate).
  double krw(double v, double rate) => isUsd ? v * rate : v;

  factory DividendHolding.fromMap(Map<String, dynamic> m) => DividendHolding(
        id: m['id'],
        ticker: m['ticker'],
        market: m['market'] ?? '미장',
        purchasePrice: _d(m['purchase_amount']),
        price: _d(m['market_value']),
        shares: _d(m['shares']),
        annualYield: _d(m['annual_yield']),
        symbol: m['symbol'],
      );
}

class Goal {
  final String id;
  final String title;
  final double targetValue;
  final double currentValue;
  final String unit; // KRW|count|percent
  final DateTime? targetDate;
  final String status;

  Goal({
    required this.id,
    required this.title,
    required this.targetValue,
    required this.currentValue,
    required this.unit,
    required this.targetDate,
    required this.status,
  });

  double get progress =>
      targetValue <= 0 ? 0 : (currentValue / targetValue).clamp(0, 1).toDouble();

  factory Goal.fromMap(Map<String, dynamic> m) => Goal(
        id: m['id'],
        title: m['title'],
        targetValue: _d(m['target_value']),
        currentValue: _d(m['current_value']),
        unit: m['unit'],
        targetDate: _date(m['target_date']),
        status: m['status'],
      );
}

class TodoTask {
  final String id;
  final String title;
  final String? module;
  final DateTime? dueDate;
  final bool done;

  TodoTask({
    required this.id,
    required this.title,
    this.module,
    this.dueDate,
    required this.done,
  });

  factory TodoTask.fromMap(Map<String, dynamic> m) => TodoTask(
        id: m['id'],
        title: m['title'],
        module: m['module'],
        dueDate: _date(m['due_date']),
        done: m['done'] ?? false,
      );
}

class WeeklyReview {
  final String id;
  final DateTime weekStart;
  final String? wins;
  final String? misses;
  final String? nextActions;
  final double? freedomScore;

  WeeklyReview({
    required this.id,
    required this.weekStart,
    this.wins,
    this.misses,
    this.nextActions,
    this.freedomScore,
  });

  factory WeeklyReview.fromMap(Map<String, dynamic> m) => WeeklyReview(
        id: m['id'],
        weekStart: DateTime.parse(m['week_start']),
        wins: m['wins'],
        misses: m['misses'],
        nextActions: m['next_actions'],
        freedomScore: m['freedom_score'] == null ? null : _d(m['freedom_score']),
      );
}

class AirbnbTransaction {
  final String id;
  final DateTime date;
  final double nights;
  final double guestPayment; // 게스트결제금액
  final double payout; // 에어비앤비 정산금
  final double extraIncome; // 추가지급
  final double cleaningCost; // 청소비
  final double variableCost; // 변동비
  final double fixedCost; // 고정비
  final String? memo;

  AirbnbTransaction({
    required this.id,
    required this.date,
    required this.nights,
    required this.guestPayment,
    required this.payout,
    required this.extraIncome,
    required this.cleaningCost,
    required this.variableCost,
    required this.fixedCost,
    this.memo,
  });

  double get revenue => payout + extraIncome;
  double get cost => cleaningCost + variableCost + fixedCost;
  double get net => revenue - cost;

  factory AirbnbTransaction.fromMap(Map<String, dynamic> m) => AirbnbTransaction(
        id: m['id'],
        date: DateTime.parse(m['txn_date']),
        nights: _d(m['nights']),
        guestPayment: _d(m['guest_payment']),
        payout: _d(m['payout']),
        extraIncome: _d(m['extra_income']),
        cleaningCost: _d(m['cleaning_cost']),
        variableCost: _d(m['variable_cost']),
        fixedCost: _d(m['fixed_cost']),
        memo: m['memo'],
      );
}

class AirbnbMonthly {
  final DateTime month;
  final double revenue;
  final double totalCost;
  final double netProfit;
  final int bookings;
  final double nights;

  AirbnbMonthly({
    required this.month,
    required this.revenue,
    required this.totalCost,
    required this.netProfit,
    required this.bookings,
    required this.nights,
  });

  factory AirbnbMonthly.fromMap(Map<String, dynamic> m) => AirbnbMonthly(
        month: DateTime.parse(m['month']),
        revenue: _d(m['revenue']),
        totalCost: _d(m['total_cost']),
        netProfit: _d(m['net_profit']),
        bookings: _i(m['bookings']),
        nights: _d(m['nights']),
      );
}

class MonthlyEntry {
  final String id;
  final String category;
  final String? refId;
  final String? refName;
  final DateTime month;
  final double amount;

  MonthlyEntry({
    required this.id,
    required this.category,
    this.refId,
    this.refName,
    required this.month,
    required this.amount,
  });

  factory MonthlyEntry.fromMap(Map<String, dynamic> m) => MonthlyEntry(
        id: m['id'],
        category: m['category'],
        refId: m['ref_id'],
        refName: m['ref_name'],
        month: DateTime.parse(m['month']),
        amount: _d(m['amount']),
      );
}

class MonthlyCashflow {
  final DateTime month;
  final double salary;
  final double airbnb;
  final double dividend;
  final double shorts;
  MonthlyCashflow({
    required this.month,
    required this.salary,
    required this.airbnb,
    required this.dividend,
    required this.shorts,
  });
  double get nonSalary => airbnb + dividend + shorts;
  double get total => nonSalary + salary;
}

class Allocation {
  final String id;
  final String pool; // salary | business
  final String label;
  final double monthlyAmount;

  Allocation({
    required this.id,
    required this.pool,
    required this.label,
    required this.monthlyAmount,
  });

  factory Allocation.fromMap(Map<String, dynamic> m) => Allocation(
        id: m['id'],
        pool: m['pool'],
        label: m['label'],
        monthlyAmount: _d(m['monthly_amount']),
      );
}

/// 자금 흐름 거래 장부 항목 (날짜별 유입/지출).
class FlowEntry {
  final String id;
  final DateTime date;
  final String direction; // 들어오는 돈 | 나가는 돈
  final String label;
  final double amount;
  final String? memo;

  /// 나가는 돈만 쓴다 — 실제로 입금(이체)했는지.
  final bool paid;
  final DateTime? paidAt;

  FlowEntry({
    required this.id,
    required this.date,
    required this.direction,
    required this.label,
    required this.amount,
    this.memo,
    this.paid = false,
    this.paidAt,
  });

  bool get isIn => direction == '들어오는 돈';
  double get signed => isIn ? amount : -amount;

  /// 아직 안 낸 지출. 들어오는 돈은 해당 없다.
  bool get unpaid => !isIn && !paid;

  factory FlowEntry.fromMap(Map<String, dynamic> m) => FlowEntry(
        id: m['id'],
        date: DateTime.parse(m['entry_date']),
        direction: m['direction'] ?? '들어오는 돈',
        label: m['label'] ?? '',
        amount: _d(m['amount']),
        memo: m['memo'],
        paid: m['paid'] == true,
        paidAt: m['paid_at'] == null ? null : DateTime.parse(m['paid_at']),
      );
}

/// 들어오는 돈(수입원) — 자금 흐름에서 직접 추가/수정.
class IncomeSource {
  final String id;
  final String label;
  final double monthlyAmount;

  IncomeSource({
    required this.id,
    required this.label,
    required this.monthlyAmount,
  });

  factory IncomeSource.fromMap(Map<String, dynamic> m) => IncomeSource(
        id: m['id'],
        label: m['label'],
        monthlyAmount: _d(m['monthly_amount']),
      );
}

class AiReport {
  final String id;
  final DateTime reportDate;
  final String? summary;
  final Map<String, dynamic> payload;

  AiReport({
    required this.id,
    required this.reportDate,
    this.summary,
    required this.payload,
  });

  factory AiReport.fromMap(Map<String, dynamic> m) => AiReport(
        id: m['id'],
        reportDate: DateTime.parse(m['report_date']),
        summary: m['summary'],
        payload: Map<String, dynamic>.from(m['payload'] ?? {}),
      );
}

// ── 재무 로드맵(Phase) ─────────────────────────────────────────
class PlanPhase {
  final String id;
  final int phaseNo;
  final String title;
  final String? summary;
  final DateTime? targetDate;
  final DateTime? achievedDate;
  final bool isCurrent;
  final int sortOrder;

  PlanPhase({
    required this.id,
    required this.phaseNo,
    required this.title,
    this.summary,
    this.targetDate,
    this.achievedDate,
    required this.isCurrent,
    required this.sortOrder,
  });

  factory PlanPhase.fromMap(Map<String, dynamic> m) => PlanPhase(
        id: m['id'],
        phaseNo: _i(m['phase_no']),
        title: m['title'],
        summary: m['summary'],
        targetDate: _date(m['target_date']),
        achievedDate: _date(m['achieved_date']),
        isCurrent: m['is_current'] == true,
        sortOrder: _i(m['sort_order']),
      );
}

class PlanAllocation {
  final String id;
  final int phaseNo;
  final String side; // 'out' | 'in'
  final String category;
  final String kind; // 'monthly' | 'percent' | 'target' | 'rule'
  final double? amount; // target: 누적 목표 · monthly: 월 계획
  final double? monthlyAmount; // target 항목의 '매달 넣을 계획' (선택)
  final double? heldAmount; // target 항목의 '이미 가진 돈(현재 보유액)' (선택)
  final double? percent;
  final String? note;
  final int sortOrder;

  PlanAllocation({
    required this.id,
    required this.phaseNo,
    required this.side,
    required this.category,
    required this.kind,
    this.amount,
    this.monthlyAmount,
    this.heldAmount,
    this.percent,
    this.note,
    required this.sortOrder,
  });

  bool get isIn => side == 'in';

  factory PlanAllocation.fromMap(Map<String, dynamic> m) => PlanAllocation(
        id: m['id'],
        phaseNo: _i(m['phase_no']),
        side: m['side'] ?? 'out',
        category: m['category'],
        kind: m['kind'],
        amount: m['amount'] == null ? null : _d(m['amount']),
        monthlyAmount:
            m['monthly_amount'] == null ? null : _d(m['monthly_amount']),
        heldAmount:
            m['held_amount'] == null ? null : _d(m['held_amount']),
        percent: m['percent'] == null ? null : _d(m['percent']),
        note: m['note'],
        sortOrder: _i(m['sort_order']),
      );
}

class PlanCondition {
  final String id;
  final int phaseNo;
  final String label;
  final String kind; // 'cashflow' | 'manual'
  final double? targetValue;
  final DateTime? targetDate;
  final DateTime? achievedDate;
  final bool done;
  final int sortOrder;

  PlanCondition({
    required this.id,
    required this.phaseNo,
    required this.label,
    required this.kind,
    this.targetValue,
    this.targetDate,
    this.achievedDate,
    required this.done,
    required this.sortOrder,
  });

  factory PlanCondition.fromMap(Map<String, dynamic> m) => PlanCondition(
        id: m['id'],
        phaseNo: _i(m['phase_no']),
        label: m['label'],
        kind: m['kind'] ?? 'manual',
        targetValue: m['target_value'] == null ? null : _d(m['target_value']),
        targetDate: _date(m['target_date']),
        achievedDate: _date(m['achieved_date']),
        done: m['done'] == true,
        sortOrder: _i(m['sort_order']),
      );
}

/// 부동산 지식 자료실 항목 (강의 Q&A · 칼럼 · 메모).
/// 자료실 항목에 첨부된 파일 하나. 본체는 Storage 'knowledge' 버킷에 있고
/// 여기에는 경로만 담는다. 열 때 서명 URL 을 만든다.
class KnowledgeFile {
  final String name;
  final String path;
  final int size;

  const KnowledgeFile(
      {required this.name, required this.path, this.size = 0});

  factory KnowledgeFile.fromMap(Map<String, dynamic> m) => KnowledgeFile(
        name: (m['name'] ?? '파일').toString(),
        path: (m['path'] ?? '').toString(),
        size: (m['size'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() =>
      {'name': name, 'path': path, 'size': size};

  /// 3.2MB · 940KB 형태.
  String get sizeLabel {
    if (size <= 0) return '';
    if (size >= 1 << 20) return '${(size / (1 << 20)).toStringAsFixed(1)}MB';
    return '${(size / 1024).round()}KB';
  }

  bool get isPdf => name.toLowerCase().endsWith('.pdf');
}

class KnowledgeNote {
  final String id;
  final String kind; // qa|article|note|video
  final String title;
  final String? body;
  final List<String> tags;
  final String? source;
  final String? author;
  final String? asker;
  final String? url; // 원문 링크
  final DateTime? sourceDate;
  final bool starred;
  final List<KnowledgeFile> files; // 첨부 PDF 등

  KnowledgeNote({
    required this.id,
    required this.kind,
    required this.title,
    this.body,
    this.tags = const [],
    this.source,
    this.author,
    this.asker,
    this.url,
    this.sourceDate,
    this.starred = false,
    this.files = const [],
  });

  /// 검색 대상 문자열 (제목+본문+태그+출처).
  String get haystack =>
      '$title ${body ?? ''} ${tags.join(' ')} ${source ?? ''} ${author ?? ''}'
          .toLowerCase();

  factory KnowledgeNote.fromMap(Map<String, dynamic> m) => KnowledgeNote(
        id: m['id'],
        kind: m['kind'] ?? 'note',
        title: m['title'] ?? '',
        body: m['body'],
        tags: (m['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        source: m['source'],
        author: m['author'],
        asker: m['asker'],
        url: m['url'],
        sourceDate: m['source_date'] == null
            ? null
            : DateTime.tryParse(m['source_date'].toString()),
        starred: m['starred'] == true,
        files: (m['files'] as List?)
                ?.map((e) =>
                    KnowledgeFile.fromMap(Map<String, dynamic>.from(e as Map)))
                .where((f) => f.path.isNotEmpty)
                .toList() ??
            const [],
      );
}

/// 롤모델 계정 — 벤치마킹할 인스타/유튜브/틱톡.
class ReferenceAccount {
  final String id;
  final String platform;
  final String name;
  final String? url;
  final String? category;
  final double followers;
  final String? memo;
  final bool starred;

  ReferenceAccount({
    required this.id,
    required this.platform,
    required this.name,
    this.url,
    this.category,
    this.followers = 0,
    this.memo,
    this.starred = false,
  });

  factory ReferenceAccount.fromMap(Map<String, dynamic> m) => ReferenceAccount(
        id: m['id'],
        platform: m['platform'] ?? 'Instagram',
        name: m['name'] ?? '',
        url: m['url'],
        category: m['category'],
        followers: _d(m['followers']),
        memo: m['memo'],
        starred: m['starred'] == true,
      );
}

/// 강의 질문 하나에 대한 내 기록 — 물어봤는지 + 받은 답.
class LectureAnswer {
  final String id;
  final String qkey;

  /// 질문 원문. 내가 추가한 질문(qkey 가 'custom-')은 이 값이 곧 질문이다.
  final String question;
  final bool asked;
  final String answer;

  const LectureAnswer({
    required this.id,
    required this.qkey,
    this.question = '',
    this.asked = false,
    this.answer = '',
  });

  bool get isCustom => qkey.startsWith('custom-');

  bool get hasAnswer => answer.trim().isNotEmpty;

  factory LectureAnswer.fromMap(Map<String, dynamic> m) => LectureAnswer(
        id: m['id'],
        qkey: (m['qkey'] ?? '').toString(),
        question: (m['question'] ?? '').toString(),
        asked: m['asked'] == true,
        answer: (m['answer'] ?? '').toString(),
      );
}

/// 공모주 청약 한 건. 수익금·수익률은 저장하지 않고 계산한다.
class IpoSubscription {
  final String id;
  final String? broker;        // 증권사
  final String name;           // 종목
  final double offerPrice;     // 공모가 (주당)
  final double invested;       // 청약금(증거금)
  final double competitionRate; // 경쟁률
  final int shares;            // 배정 수량
  final DateTime? listingDate; // 상장일
  final double sellPrice;      // 매도가 (0 = 미매도)
  final DateTime? subStart;    // 청약 시작
  final DateTime? subEnd;      // 청약 마감 — 놓치면 끝
  final DateTime? refundDate;  // 환불일
  final double bandLow;        // 희망공모가 하단
  final double bandHigh;       // 희망공모가 상단
  final String? source;        // 어디서 찾았나
  final String? memo;

  IpoSubscription({
    required this.id,
    this.broker,
    required this.name,
    this.offerPrice = 0,
    this.invested = 0,
    this.competitionRate = 0,
    this.shares = 0,
    this.listingDate,
    this.sellPrice = 0,
    this.subStart,
    this.subEnd,
    this.refundDate,
    this.bandLow = 0,
    this.bandHigh = 0,
    this.source,
    this.memo,
  });

  /// 아직 청약하지 않은 «예정» 건인가 (배치가 넣어둔 것).
  bool get upcoming => shares == 0 && !sold && subEnd != null;

  /// 오늘 기준 상태. 날짜로 계산한다 — 저장하지 않는다.
  String get phase {
    final t = DateTime.now();
    final today = DateTime(t.year, t.month, t.day);
    bool before(DateTime? d) => d != null && today.isBefore(d);
    bool after(DateTime? d) => d != null && today.isAfter(d);
    if (before(subStart)) return '예정';
    if (subStart != null && subEnd != null && !before(subStart) && !after(subEnd)) {
      return '청약중';
    }
    if (after(subEnd) && before(listingDate)) return '배정·환불';
    if (listingDate != null && !before(listingDate)) return sold ? '매도' : '상장';
    return sold ? '매도' : '기록';
  }

  /// 청약 마감까지 남은 날. 지났으면 음수.
  int? get daysToSubEnd {
    if (subEnd == null) return null;
    final t = DateTime.now();
    return DateTime(subEnd!.year, subEnd!.month, subEnd!.day)
        .difference(DateTime(t.year, t.month, t.day))
        .inDays;
  }

  /// 희망공모가 밴드 표기.
  String get bandLabel => (bandLow <= 0 && bandHigh <= 0)
      ? ''
      : '${bandLow.round()}~${bandHigh.round()}원';

  /// 매도가가 없으면 아직 안 팔았다 — 손익 집계에서 뺀다.
  bool get sold => sellPrice > 0;

  /// 수익금 = (매도가 − 공모가) × 수량
  double get profit => sold ? (sellPrice - offerPrice) * shares : 0;

  /// 수익률 = (매도가 − 공모가) ÷ 공모가 (주당 기준)
  double get profitRate =>
      (!sold || offerPrice <= 0) ? 0 : (sellPrice - offerPrice) / offerPrice * 100;

  bool get isWin => sold && profit > 0;

  /// 배정 금액 = 공모가 × 배정수량 (실제로 받은 주식의 취득가)
  double get allocated => offerPrice * shares;

  factory IpoSubscription.fromMap(Map<String, dynamic> m) => IpoSubscription(
        id: m['id'],
        broker: m['broker'],
        name: m['name'] ?? '',
        offerPrice: _d(m['offer_price']),
        invested: _d(m['invested']),
        competitionRate: _d(m['competition_rate']),
        shares: _i(m['shares']),
        listingDate: _date(m['listing_date']),
        sellPrice: _d(m['sell_price']),
        subStart: _date(m['sub_start']),
        subEnd: _date(m['sub_end']),
        refundDate: _date(m['refund_date']),
        bandLow: _d(m['band_low']),
        bandHigh: _d(m['band_high']),
        source: m['source'],
        memo: m['memo'],
      );
}

// ── 부동산 작업대 ────────────────────────────────────────────
// 조사·임장은 «단지»에 붙는다. 매물(경매·급매)은 단지에서 시세를 상속받는다.

/// 구역 — 모아타운·신통기획 선정지.
class Zone {
  final String id;
  final String name;
  final String kind; // 모아타운|신통기획|일반
  final String? district;
  final double consentRate; // 조합설립 동의율 %
  final DateTime? unionExpected;
  final String? memo;
  final bool starred;
  final int stage; // 0=미정, 1~7
  final String? stageSource; // 단계 근거·출처
  final DateTime? stageCheckedAt; // 단계 확인 시각
  final List<String> aliases; // 구역에 포함된 다른 번지들(대표번지 외)

  Zone({
    required this.id,
    required this.name,
    this.kind = '모아타운',
    this.district,
    this.consentRate = 0,
    this.unionExpected,
    this.memo,
    this.starred = false,
    this.stage = 0,
    this.stageSource,
    this.stageCheckedAt,
    this.aliases = const [],
  });

  /// 조합설립 임박 여부 — 물건 고르는 기준 ②.
  /// 동의율 70% 이상이면 임박으로 본다(자료실 사례 기준 72~78%에서 거래 활발).
  bool get imminent => consentRate >= 70;

  /// 모아타운 7단계 라벨.
  static const stageLabels = <int, String>{
    0: '미정',
    1: '대상지 선정',
    2: '관리계획 고시',
    3: '조합설립',
    4: '건축심의·시공자선정',
    5: '사업시행인가',
    6: '이주·착공',
    7: '준공',
  };
  String get stageLabel => stageLabels[stage] ?? '미정';

  factory Zone.fromMap(Map<String, dynamic> m) => Zone(
        id: m['id'],
        name: m['name'] ?? '',
        kind: m['kind'] ?? '모아타운',
        district: m['district'],
        consentRate: _d(m['consent_rate']),
        unionExpected: _date(m['union_expected']),
        memo: m['memo'],
        starred: m['starred'] == true,
        stage: (m['stage'] as num?)?.toInt() ?? 0,
        stageSource: m['stage_source'],
        stageCheckedAt: _date(m['stage_checked_at']),
        aliases: (m['aliases'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
      );
}

/// 단지 — 조사·임장이 붙는 단위. 구역 밖이어도 된다(zoneId == null).
class Complex {
  final String id;
  final String? zoneId;
  final String name;
  final String? address;
  final String kind; // 빌라|다세대|연립|아파트|기타
  final String? district; // 자치구 — 구역이 없어도 지역을 안다
  final String? memo;

  Complex({
    required this.id,
    this.zoneId,
    required this.name,
    this.address,
    this.kind = '빌라',
    this.district,
    this.memo,
  });

  factory Complex.fromMap(Map<String, dynamic> m) => Complex(
        id: m['id'],
        zoneId: m['zone_id'],
        name: m['name'] ?? '',
        address: m['address'],
        kind: m['kind'] ?? '빌라',
        district: m['district'],
        memo: m['memo'],
      );
}

/// 시세조사의 한 출처. at: desk(책상 — 네이버·실거래·KB) | field(현장 — 부동산)
class PriceSource {
  final String label;
  final double sale;   // 매매
  final double jeonse; // 전세
  final String at;     // desk | field

  const PriceSource(
      {required this.label, this.sale = 0, this.jeonse = 0, this.at = 'desk'});

  bool get isField => at == 'field';
  bool get hasAny => sale > 0 || jeonse > 0;

  factory PriceSource.fromMap(Map<String, dynamic> m) => PriceSource(
        label: (m['label'] ?? '').toString(),
        sale: _d(m['sale']),
        jeonse: _d(m['jeonse']),
        at: (m['at'] ?? 'desk').toString(),
      );

  Map<String, dynamic> toMap() =>
      {'label': label, 'sale': sale, 'jeonse': jeonse, 'at': at};
}

/// 시세조사 — 단지당 여러 시점. 평균·전세비율은 계산으로 낸다.
/// 빈 칸은 평균에서 제외된다 → 다 못 채워도 결론이 나온다.
class PriceSurvey {
  final String id;
  final String complexId;
  final DateTime surveyedOn;
  final List<PriceSource> sources;
  final String? memo;

  PriceSurvey({
    required this.id,
    required this.complexId,
    required this.surveyedOn,
    this.sources = const [],
    this.memo,
  });

  static double _avg(Iterable<double> xs) {
    final v = xs.where((e) => e > 0).toList();
    return v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;
  }

  double get saleAvg => _avg(sources.map((s) => s.sale));
  double get jeonseAvg => _avg(sources.map((s) => s.jeonse));

  /// 전세/매매 — 플피 판단의 핵심 지표.
  double get jeonseRatio => saleAvg <= 0 ? 0 : jeonseAvg / saleAvg * 100;

  int get deskFilled => sources.where((s) => !s.isField && s.hasAny).length;
  int get fieldFilled => sources.where((s) => s.isField && s.hasAny).length;

  /// 며칠 전 조사인가. 오래되면 갱신을 권한다.
  int get ageDays {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day)
        .difference(DateTime(surveyedOn.year, surveyedOn.month, surveyedOn.day))
        .inDays;
  }

  bool get stale => ageDays > 60;

  factory PriceSurvey.fromMap(Map<String, dynamic> m) => PriceSurvey(
        id: m['id'],
        complexId: m['complex_id'],
        surveyedOn: DateTime.parse(m['surveyed_on']),
        sources: (m['sources'] as List?)
                ?.map((e) =>
                    PriceSource.fromMap(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            const [],
        memo: m['memo'],
      );
}

/// 임장에서 들은 시세 (부동산 한 곳).
class HeardPrice {
  final String who;
  final double sale;
  final double jeonse;
  const HeardPrice({required this.who, this.sale = 0, this.jeonse = 0});

  factory HeardPrice.fromMap(Map<String, dynamic> m) => HeardPrice(
        who: (m['who'] ?? '').toString(),
        sale: _d(m['sale']),
        jeonse: _d(m['jeonse']),
      );
  Map<String, dynamic> toMap() => {'who': who, 'sale': sale, 'jeonse': jeonse};
}

/// 임장 한 줄 메모 — 현장에서 길게 쓰지 않는다.
class VisitMemo {
  final String at;   // 14:26
  final String text;
  const VisitMemo({required this.at, required this.text});

  factory VisitMemo.fromMap(Map<String, dynamic> m) => VisitMemo(
        at: (m['at'] ?? '').toString(),
        text: (m['text'] ?? '').toString(),
      );
  Map<String, dynamic> toMap() => {'at': at, 'text': text};
}

/// 임장 사진 — Storage 'knowledge' 버킷의 <uid>/visits/... 경로.
class VisitPhoto {
  final String path;
  final String name;
  final String tag; // 어느 체크 항목의 사진인가
  const VisitPhoto({required this.path, this.name = '', this.tag = ''});

  factory VisitPhoto.fromMap(Map<String, dynamic> m) => VisitPhoto(
        path: (m['path'] ?? '').toString(),
        name: (m['name'] ?? '').toString(),
        tag: (m['tag'] ?? '').toString(),
      );
  Map<String, dynamic> toMap() => {'path': path, 'name': name, 'tag': tag};
}

/// 임장 — 단지에 붙는다. 매물이 없어도 간다(급매를 만날 수 있으니).
class Visit {
  final String id;
  final String complexId;
  final DateTime visitedAt;
  final Map<String, dynamic> checks;
  final List<VisitPhoto> photos;
  final List<VisitMemo> memos;
  final List<HeardPrice> heard;
  final bool done;
  final String? memo;

  Visit({
    required this.id,
    required this.complexId,
    required this.visitedAt,
    this.checks = const {},
    this.photos = const [],
    this.memos = const [],
    this.heard = const [],
    this.done = false,
    this.memo,
  });

  int get checkedCount => checks.values.where((v) => v == true).length;

  factory Visit.fromMap(Map<String, dynamic> m) => Visit(
        id: m['id'],
        complexId: m['complex_id'],
        visitedAt: DateTime.parse(m['visited_at']).toLocal(),
        checks: (m['checks'] as Map?)?.cast<String, dynamic>() ?? const {},
        photos: (m['photos'] as List?)
                ?.map((e) =>
                    VisitPhoto.fromMap(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            const [],
        memos: (m['memos'] as List?)
                ?.map((e) =>
                    VisitMemo.fromMap(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            const [],
        heard: (m['heard'] as List?)
                ?.map((e) =>
                    HeardPrice.fromMap(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            const [],
        done: m['done'] == true,
        memo: m['memo'],
      );
}

/// 숏폼 편성 한 칸. 예전에는 Dart 코드에 박혀 있어 고칠 수 없었다.
class ShortsSlotRow {
  final String id;
  final DateTime slotDate;
  final String cat; // fire|film|mind|data|trophy|swap
  final String title;
  final String? hook;
  final String? src;
  final String? url;
  final String prio;
  final bool done;
  final String? memo;

  ShortsSlotRow({
    required this.id,
    required this.slotDate,
    this.cat = 'fire',
    required this.title,
    this.hook,
    this.src,
    this.url,
    this.prio = '4',
    this.done = false,
    this.memo,
  });

  bool get isTop => prio == '5';
  bool get hasUrl => (url ?? '').isNotEmpty;

  factory ShortsSlotRow.fromMap(Map<String, dynamic> m) => ShortsSlotRow(
        id: m['id'],
        slotDate: DateTime.parse(m['slot_date']),
        cat: m['cat'] ?? 'fire',
        title: m['title'] ?? '',
        hook: m['hook'],
        src: m['src'],
        url: m['url'],
        prio: (m['prio'] ?? '4').toString(),
        done: m['done'] == true,
        memo: m['memo'],
      );
}
