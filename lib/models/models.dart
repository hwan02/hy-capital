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
  });

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

  FlowEntry({
    required this.id,
    required this.date,
    required this.direction,
    required this.label,
    required this.amount,
    this.memo,
  });

  bool get isIn => direction == '들어오는 돈';
  double get signed => isIn ? amount : -amount;

  factory FlowEntry.fromMap(Map<String, dynamic> m) => FlowEntry(
        id: m['id'],
        date: DateTime.parse(m['entry_date']),
        direction: m['direction'] ?? '들어오는 돈',
        label: m['label'] ?? '',
        amount: _d(m['amount']),
        memo: m['memo'],
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
