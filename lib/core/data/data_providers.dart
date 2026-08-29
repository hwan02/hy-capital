import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../models/custom.dart';
import '../supabase/supabase_providers.dart';
import 'fx_provider.dart';

/// 각 테이블을 조회하는 FutureProvider 모음.
/// invalidate 로 새로고침 가능.

final profileProvider = FutureProvider<Profile?>((ref) async {
  final sb = ref.watch(supabaseProvider);
  final uid = sb.auth.currentUser?.id;
  if (uid == null) return null;
  final row =
      await sb.from('profiles').select().eq('id', uid).maybeSingle();
  return row == null ? null : Profile.fromMap(row);
});

final snapshotsProvider = FutureProvider<List<FinancialSnapshot>>((ref) async {
  final sb = ref.watch(supabaseProvider);
  final rows = await sb
      .from('financial_snapshots')
      .select()
      .order('as_of', ascending: true);
  return rows.map<FinancialSnapshot>(FinancialSnapshot.fromMap).toList();
});

final cashFlowsProvider = FutureProvider<List<CashFlow>>((ref) async {
  final sb = ref.watch(supabaseProvider);
  final rows = await sb
      .from('cash_flows')
      .select()
      .order('occurred_on', ascending: false);
  return rows.map<CashFlow>(CashFlow.fromMap).toList();
});

final airbnbProvider = FutureProvider<List<AirbnbUnit>>((ref) async {
  final sb = ref.watch(supabaseProvider);
  final rows =
      await sb.from('airbnb_units').select().order('sort_order');
  return rows.map<AirbnbUnit>(AirbnbUnit.fromMap).toList();
});

final shortsProvider = FutureProvider<List<ShortsChannel>>((ref) async {
  final sb = ref.watch(supabaseProvider);
  final rows = await sb.from('shorts_channels').select().order('revenue',
      ascending: false);
  return rows.map<ShortsChannel>(ShortsChannel.fromMap).toList();
});

final landProvider = FutureProvider<List<LandProject>>((ref) async {
  final sb = ref.watch(supabaseProvider);
  final rows = await sb.from('land_projects').select().order('created_at');
  return rows.map<LandProject>(LandProject.fromMap).toList();
});

/// 경매 물건. 테이블(0015)이 아직 없으면 빈 목록으로 안전하게 처리.
final auctionProvider = FutureProvider<List<AuctionProperty>>((ref) async {
  final sb = ref.watch(supabaseProvider);
  try {
    final rows =
        await sb.from('auction_properties').select().order('created_at');
    return rows.map<AuctionProperty>(AuctionProperty.fromMap).toList();
  } catch (_) {
    return const <AuctionProperty>[]; // 테이블 미생성 시
  }
});

/// 부동산 지식 자료실 — 강의 Q&A·칼럼·메모. 테이블(0018) 미생성이면 빈 목록.
final knowledgeProvider = FutureProvider<List<KnowledgeNote>>((ref) async {
  final sb = ref.watch(supabaseProvider);
  try {
    final rows = await sb
        .from('knowledge_notes')
        .select()
        .order('source_date', ascending: false);
    return rows.map<KnowledgeNote>(KnowledgeNote.fromMap).toList();
  } catch (_) {
    return const <KnowledgeNote>[];
  }
});

/// 롤모델 계정. 테이블(0020) 미생성이면 빈 목록.
final referenceAccountsProvider =
    FutureProvider<List<ReferenceAccount>>((ref) async {
  final sb = ref.watch(supabaseProvider);
  try {
    final rows = await sb
        .from('reference_accounts')
        .select()
        .order('created_at', ascending: false);
    return rows.map<ReferenceAccount>(ReferenceAccount.fromMap).toList();
  } catch (_) {
    return const <ReferenceAccount>[];
  }
});

final dividendProvider = FutureProvider<List<DividendHolding>>((ref) async {
  final sb = ref.watch(supabaseProvider);
  final rows = await sb
      .from('dividend_holdings')
      .select()
      .order('market_value', ascending: false);
  return rows.map<DividendHolding>(DividendHolding.fromMap).toList();
});

final goalsProvider = FutureProvider<List<Goal>>((ref) async {
  final sb = ref.watch(supabaseProvider);
  final rows = await sb.from('goals').select().order('sort_order');
  return rows.map<Goal>(Goal.fromMap).toList();
});

final tasksProvider = FutureProvider<List<TodoTask>>((ref) async {
  final sb = ref.watch(supabaseProvider);
  final rows = await sb
      .from('tasks')
      .select()
      .order('done')
      .order('due_date', ascending: true);
  return rows.map<TodoTask>(TodoTask.fromMap).toList();
});

final weeklyReviewsProvider = FutureProvider<List<WeeklyReview>>((ref) async {
  final sb = ref.watch(supabaseProvider);
  final rows = await sb
      .from('weekly_reviews')
      .select()
      .order('week_start', ascending: false);
  return rows.map<WeeklyReview>(WeeklyReview.fromMap).toList();
});

final aiReportsProvider = FutureProvider<List<AiReport>>((ref) async {
  final sb = ref.watch(supabaseProvider);
  final rows = await sb
      .from('ai_reports')
      .select()
      .order('report_date', ascending: false);
  return rows.map<AiReport>(AiReport.fromMap).toList();
});

// ── 자금 흐름: 거래 장부 ─────────────────────────────────────
final flowEntriesProvider = FutureProvider<List<FlowEntry>>((ref) async {
  final sb = ref.watch(supabaseProvider);
  if (sb.auth.currentUser == null) return [];
  // 같은 날짜가 많다. id 까지 정렬해야 매번 같은 순서로 온다 —
  // 그러지 않으면 체크 한 번에 목록이 뒤섞인다.
  final rows = await sb
      .from('flow_entries')
      .select()
      .order('entry_date', ascending: false)
      .order('id');
  return rows.map<FlowEntry>(FlowEntry.fromMap).toList();
});

// ── 자금 흐름: 들어오는 돈(수입원) ───────────────────────────
final incomeSourcesProvider = FutureProvider<List<IncomeSource>>((ref) async {
  final sb = ref.watch(supabaseProvider);
  if (sb.auth.currentUser == null) return [];
  final rows = await sb.from('income_sources').select().order('sort_order');
  return rows.map<IncomeSource>(IncomeSource.fromMap).toList();
});

// ── 월별 추적 / 자금 분배 ────────────────────────────────────
final allocationsProvider = FutureProvider<List<Allocation>>((ref) async {
  final sb = ref.watch(supabaseProvider);
  final rows = await sb
      .from('allocations')
      .select()
      .order('pool')
      .order('sort_order');
  return rows.map<Allocation>(Allocation.fromMap).toList();
});

final airbnbMonthlyProvider =
    FutureProvider.family<List<AirbnbMonthly>, String>((ref, unitId) async {
  final sb = ref.watch(supabaseProvider);
  final rows = await sb
      .from('airbnb_monthly')
      .select()
      .eq('unit_id', unitId)
      .order('month', ascending: true);
  return rows.map<AirbnbMonthly>(AirbnbMonthly.fromMap).toList();
});

/// 에어비앤비 전체(전 호점) 거래장부 기반 실적 요약.
class AirbnbSummary {
  final double totalNet; // 누적 순이익
  final double totalRevenue; // 누적 매출
  final double avgMonthlyNet; // 월평균 순이익(거래 있는 달 기준)
  final double currentMonthNet; // 이번 달 순이익
  final DateTime? latestMonth; // 거래가 있는 가장 최근 달
  final double latestMonthNet; // 그 달 순이익
  final int monthsCount; // 거래가 있는 달 수
  final int openCount; // 운영중 호점 수

  AirbnbSummary({
    required this.totalNet,
    required this.totalRevenue,
    required this.avgMonthlyNet,
    required this.currentMonthNet,
    required this.latestMonth,
    required this.latestMonthNet,
    required this.monthsCount,
    required this.openCount,
  });
}

final airbnbSummaryProvider = FutureProvider<AirbnbSummary>((ref) async {
  final sb = ref.watch(supabaseProvider);
  final unitsF = ref.watch(airbnbProvider.future);
  final rows = await sb.from('airbnb_monthly').select('month,revenue,net_profit');
  final units = await unitsF;

  final netByMonth = <String, double>{};
  double totalNet = 0, totalRev = 0;
  for (final r in rows) {
    final mk = (r['month'] as String).substring(0, 7); // yyyy-MM
    final net = (r['net_profit'] as num?)?.toDouble() ?? 0;
    totalNet += net;
    totalRev += (r['revenue'] as num?)?.toDouble() ?? 0;
    netByMonth[mk] = (netByMonth[mk] ?? 0) + net;
  }
  final months = netByMonth.keys.toList()..sort();
  final now = DateTime.now();
  final curKey =
      '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
  final latestKey = months.isNotEmpty ? months.last : null;
  return AirbnbSummary(
    totalNet: totalNet,
    totalRevenue: totalRev,
    avgMonthlyNet: months.isEmpty ? 0 : totalNet / months.length,
    currentMonthNet: netByMonth[curKey] ?? 0,
    latestMonth: latestKey == null ? null : DateTime.parse('$latestKey-01'),
    latestMonthNet: latestKey == null ? 0 : netByMonth[latestKey]!,
    monthsCount: months.length,
    openCount: units.where((u) => u.status == 'open').length,
  );
});

/// 에어비앤비 호점의 거래 장부.
final airbnbTransactionsProvider =
    FutureProvider.family<List<AirbnbTransaction>, String>((ref, unitId) async {
  final sb = ref.watch(supabaseProvider);
  final rows = await sb
      .from('airbnb_transactions')
      .select()
      .eq('unit_id', unitId)
      .order('txn_date', ascending: false);
  return rows.map<AirbnbTransaction>(AirbnbTransaction.fromMap).toList();
});

/// 월별 현금흐름 추이 (에비+배당+숏폼+월급, 최근 순).
final monthlyCashflowProvider =
    FutureProvider<List<MonthlyCashflow>>((ref) async {
  final sb = ref.watch(supabaseProvider);
  // 의존 조회 + 두 테이블 조회를 동시에 시작 후 대기 → 순차 왕복 제거.
  final rateF = ref.watch(usdKrwProvider.future);
  final dividendsF = ref.watch(dividendProvider.future);
  final snapsF = ref.watch(snapshotsProvider.future);
  final amF = sb.from('airbnb_monthly').select('month,net_profit');
  final entF = sb
      .from('monthly_entries')
      .select('category,ref_id,month,amount')
      .inFilter('category', ['dividend', 'shorts']);

  final rate = await rateF;
  final dividends = await dividendsF;
  final snaps = await snapsF;
  final divById = {for (final d in dividends) d.id: d};

  String key(DateTime d) => DateTime(d.year, d.month).toIso8601String().substring(0, 10);
  final airbnbBy = <String, double>{};
  final divBy = <String, double>{};
  final shortsBy = <String, double>{};
  final salaryBy = <String, double>{};

  final am = await amF;
  for (final r in am) {
    final k = key(DateTime.parse(r['month']));
    airbnbBy[k] = (airbnbBy[k] ?? 0) + ((r['net_profit'] as num?)?.toDouble() ?? 0);
  }
  final ent = await entF;
  for (final r in ent) {
    final k = key(DateTime.parse(r['month']));
    final amt = (r['amount'] as num?)?.toDouble() ?? 0;
    if (r['category'] == 'shorts') {
      shortsBy[k] = (shortsBy[k] ?? 0) + amt;
    } else {
      final d = divById[r['ref_id']];
      if (d != null) divBy[k] = (divBy[k] ?? 0) + d.krw(amt * d.shares, rate);
    }
  }
  for (final s in snaps) {
    salaryBy[key(s.asOf)] = s.salaryCashflow;
  }

  final keys = <String>{...airbnbBy.keys, ...divBy.keys, ...shortsBy.keys, ...salaryBy.keys}
      .toList()
    ..sort();
  return [
    for (final k in keys)
      MonthlyCashflow(
        month: DateTime.parse(k),
        salary: salaryBy[k] ?? 0,
        airbnb: airbnbBy[k] ?? 0,
        dividend: divBy[k] ?? 0,
        shorts: shortsBy[k] ?? 0,
      ),
  ];
});

/// 카테고리별(shorts/dividend) 월별 실적.
final monthlyEntriesProvider =
    FutureProvider.family<List<MonthlyEntry>, String>((ref, category) async {
  final sb = ref.watch(supabaseProvider);
  final rows = await sb
      .from('monthly_entries')
      .select()
      .eq('category', category)
      .order('month', ascending: true);
  return rows.map<MonthlyEntry>(MonthlyEntry.fromMap).toList();
});

// ── 사용자 정의 모듈 ─────────────────────────────────────────
final customModulesProvider = FutureProvider<List<CustomModule>>((ref) async {
  final sb = ref.watch(supabaseProvider);
  if (sb.auth.currentUser == null) return [];
  final rows = await sb.from('custom_modules').select().order('sort_order');
  return rows.map<CustomModule>(CustomModule.fromMap).toList();
});

final customRecordsProvider =
    FutureProvider.family<List<CustomRecord>, String>((ref, moduleId) async {
  final sb = ref.watch(supabaseProvider);
  final rows = await sb
      .from('custom_records')
      .select()
      .eq('module_id', moduleId)
      .order('sort_order')
      .order('created_at');
  return rows.map<CustomRecord>(CustomRecord.fromMap).toList();
});

/// 대시보드 파생 지표.
class DashboardMetrics {
  final FinancialSnapshot? latest;
  final FinancialSnapshot? prev;
  final double freedomTarget; // 월 목표 현금흐름(기준선)
  final int openAirbnb;
  final double airbnbMonthly; // 평균(추정) 오픈 호점 월 순이익 합
  final double shortsProfit;
  final double monthlyDividend; // 평균(추정) 월 배당
  final int landCount;
  // 이번 달 실제
  final double airbnbThisMonth;
  final double dividendThisMonth;
  final double shortsThisMonth;

  DashboardMetrics({
    required this.latest,
    required this.prev,
    required this.freedomTarget,
    required this.openAirbnb,
    required this.airbnbMonthly,
    required this.shortsProfit,
    required this.monthlyDividend,
    required this.landCount,
    required this.airbnbThisMonth,
    required this.dividendThisMonth,
    required this.shortsThisMonth,
  });

  double get cash => latest?.cash ?? 0;

  /// 월급 제외 현금흐름(평균/추정) = 각 사업 엔진 월 실적의 합.
  double get nonSalaryCashflow => airbnbMonthly + shortsProfit + monthlyDividend;

  /// 이번 달 실제 현금흐름.
  double get thisMonthCashflow =>
      airbnbThisMonth + dividendThisMonth + shortsThisMonth;

  /// Freedom Score = 월급 제외 현금흐름(평균) / 월 목표 × 100.
  double get freedomScore =>
      freedomTarget <= 0 ? 0 : (nonSalaryCashflow / freedomTarget) * 100;

  /// 이번 달 기준 Freedom Score.
  double get thisMonthScore =>
      freedomTarget <= 0 ? 0 : (thisMonthCashflow / freedomTarget) * 100;
}

final dashboardMetricsProvider = FutureProvider<DashboardMetrics>((ref) async {
  // 의존 프로바이더 조회를 동시에 시작(병렬) 후 한꺼번에 대기 → 순차 왕복 제거.
  final snapsF = ref.watch(snapshotsProvider.future);
  final profileF = ref.watch(profileProvider.future);
  final airbnbF = ref.watch(airbnbProvider.future);
  final shortsF = ref.watch(shortsProvider.future);
  final dividendsF = ref.watch(dividendProvider.future);
  final landF = ref.watch(landProvider.future);
  final rateF = ref.watch(usdKrwProvider.future);

  // 이번 달 실제 실적 (airbnb_monthly + monthly_entries) 도 동시에 조회.
  final sb = ref.read(supabaseProvider);
  final now = DateTime.now();
  final m0 = DateTime(now.year, now.month).toIso8601String().substring(0, 10);
  final amF = sb.from('airbnb_monthly').select('net_profit').eq('month', m0);
  final entF = sb.from('monthly_entries').select('category,ref_id,amount').eq('month', m0);

  final snaps = await snapsF;
  final profile = await profileF;
  final airbnb = await airbnbF;
  final shorts = await shortsF;
  final dividends = await dividendsF;
  final land = await landF;
  final rate = await rateF;

  double airbnbThisMonth = 0, dividendThisMonth = 0, shortsThisMonth = 0;
  try {
    final am = await amF;
    airbnbThisMonth =
        am.fold(0.0, (s, r) => s + ((r['net_profit'] as num?)?.toDouble() ?? 0));
    final ent = await entF;
    for (final r in ent) {
      final cat = r['category'];
      final amt = (r['amount'] as num?)?.toDouble() ?? 0;
      if (cat == 'shorts') {
        shortsThisMonth += amt;
      } else if (cat == 'dividend') {
        final d = dividends.where((x) => x.id == r['ref_id']);
        if (d.isNotEmpty) {
          dividendThisMonth += d.first.krw(amt * d.first.shares, rate);
        }
      }
    }
  } catch (_) {}

  return DashboardMetrics(
    latest: snaps.isNotEmpty ? snaps.last : null,
    prev: snaps.length >= 2 ? snaps[snaps.length - 2] : null,
    freedomTarget: profile?.freedomTarget ?? 10000000,
    openAirbnb: airbnb.where((a) => a.status == 'open').length,
    airbnbMonthly: airbnb
        .where((a) => a.status == 'open')
        .fold(0.0, (s, a) => s + a.monthlyProfit),
    shortsProfit: shorts.fold(0.0, (s, c) => s + c.netProfit),
    monthlyDividend:
        dividends.fold(0.0, (s, d) => s + d.krw(d.monthlyDividend, rate)),
    landCount: land.length,
    airbnbThisMonth: airbnbThisMonth,
    dividendThisMonth: dividendThisMonth,
    shortsThisMonth: shortsThisMonth,
  );
});

/// 자금 흐름 '들어오는 돈' 자동 연동 — 이번 달 각 사업 엔진 수익.
/// 항상 현재 달 기준(고정). 라벨 → 금액.
final moduleIncomeThisMonthProvider =
    FutureProvider<Map<String, double>>((ref) async {
  final sb = ref.watch(supabaseProvider);
  final now = DateTime.now();
  final m0 = DateTime(now.year, now.month).toIso8601String().substring(0, 10);

  // 필요한 것만 병렬 조회 (대시보드 지표 체인에 의존하지 않음).
  final rateF = ref.watch(usdKrwProvider.future);
  final dividendsF = ref.watch(dividendProvider.future);
  final amF = sb.from('airbnb_monthly').select('net_profit').eq('month', m0);
  final entF = sb
      .from('monthly_entries')
      .select('category,ref_id,amount')
      .eq('month', m0);

  final rate = await rateF;
  final dividends = await dividendsF;
  final divById = {for (final d in dividends) d.id: d};

  double airbnb = 0, shorts = 0, dividend = 0, land = 0;
  final am = await amF;
  airbnb = am.fold(0.0, (s, r) => s + ((r['net_profit'] as num?)?.toDouble() ?? 0));
  final ent = await entF;
  for (final r in ent) {
    final amt = (r['amount'] as num?)?.toDouble() ?? 0;
    switch (r['category']) {
      case 'shorts':
        shorts += amt;
      case 'dividend':
        final d = divById[r['ref_id']];
        if (d != null) dividend += d.krw(amt * d.shares, rate);
      case 'land':
        land += amt;
    }
  }
  return {'에어비앤비': airbnb, '배당': dividend, '숏폼': shorts, '토지': land};
});

/// 자금 흐름 자동 연동 라벨(이 라벨의 수동 입력은 자동값으로 대체).
const kAutoIncomeLabels = {'에어비앤비', '배당', '숏폼', '토지'};

/// 월급 제외 현금흐름(이번 달) = 각 사업 엔진 이번 달 수익 합.
final nonSalaryCashflowThisMonthProvider = FutureProvider<double>((ref) async {
  final Map<String, double> m =
      await ref.watch(moduleIncomeThisMonthProvider.future);
  double total = 0;
  for (final v in m.values) {
    total += v;
  }
  return total;
});

// ── 재무 로드맵(Phase) ─────────────────────────────────────────
final planPhasesProvider = FutureProvider<List<PlanPhase>>((ref) async {
  final sb = ref.watch(supabaseProvider);
  if (sb.auth.currentUser == null) return [];
  final rows = await sb.from('plan_phases').select().order('phase_no', ascending: true);
  return rows.map<PlanPhase>(PlanPhase.fromMap).toList();
});

final planAllocationsProvider = FutureProvider<List<PlanAllocation>>((ref) async {
  final sb = ref.watch(supabaseProvider);
  if (sb.auth.currentUser == null) return [];
  final rows = await sb
      .from('plan_allocations')
      .select()
      .order('phase_no', ascending: true)
      .order('sort_order', ascending: true);
  return rows.map<PlanAllocation>(PlanAllocation.fromMap).toList();
});

final planConditionsProvider = FutureProvider<List<PlanCondition>>((ref) async {
  final sb = ref.watch(supabaseProvider);
  if (sb.auth.currentUser == null) return [];
  final rows = await sb
      .from('plan_conditions')
      .select()
      .order('phase_no', ascending: true)
      .order('sort_order', ascending: true);
  return rows.map<PlanCondition>(PlanCondition.fromMap).toList();
});

/// 현재 단계 (is_current). 없으면 첫 단계.
final currentPhaseProvider = FutureProvider<PlanPhase?>((ref) async {
  final phases = await ref.watch(planPhasesProvider.future);
  if (phases.isEmpty) return null;
  return phases.firstWhere((p) => p.isCurrent, orElse: () => phases.first);
});

/// 모든 데이터 새로고침.
void invalidateAll(WidgetRef ref) {
  ref.invalidate(profileProvider);
  ref.invalidate(snapshotsProvider);
  ref.invalidate(cashFlowsProvider);
  ref.invalidate(airbnbProvider);
  ref.invalidate(shortsProvider);
  ref.invalidate(landProvider);
  ref.invalidate(auctionProvider);
  ref.invalidate(knowledgeProvider);
  ref.invalidate(referenceAccountsProvider);
  ref.invalidate(dividendProvider);
  ref.invalidate(goalsProvider);
  ref.invalidate(tasksProvider);
  ref.invalidate(weeklyReviewsProvider);
  ref.invalidate(aiReportsProvider);
  ref.invalidate(dashboardMetricsProvider);
  ref.invalidate(customModulesProvider);
  ref.invalidate(ipoProvider);
  ref.invalidate(shortsSlotsProvider);
  ref.invalidate(zonesProvider);
  ref.invalidate(complexesProvider);
  ref.invalidate(latestSurveysProvider);
  ref.invalidate(visitsProvider);
  ref.invalidate(customRecordsProvider);
  ref.invalidate(allocationsProvider);
  ref.invalidate(incomeSourcesProvider);
  ref.invalidate(flowEntriesProvider);
  ref.invalidate(airbnbMonthlyProvider);
  ref.invalidate(airbnbTransactionsProvider);
  ref.invalidate(monthlyEntriesProvider);
  ref.invalidate(moduleIncomeThisMonthProvider);
  ref.invalidate(nonSalaryCashflowThisMonthProvider);
  ref.invalidate(planPhasesProvider);
  ref.invalidate(planAllocationsProvider);
  ref.invalidate(planConditionsProvider);
  ref.invalidate(currentPhaseProvider);
}

/// 강의 질문 기록 — qkey 로 바로 찾을 수 있게 Map 으로 준다.
final lectureAnswersProvider =
    FutureProvider<Map<String, LectureAnswer>>((ref) async {
  final sb = ref.watch(supabaseProvider);
  final rows = await sb.from('lecture_answers').select();
  final list = rows.map<LectureAnswer>(LectureAnswer.fromMap);
  return {for (final a in list) a.qkey: a};
});


/// 공모주 청약 기록 — 상장일 최신순.
final ipoProvider = FutureProvider<List<IpoSubscription>>((ref) async {
  final sb = ref.watch(supabaseProvider);
  final rows = await sb
      .from('ipo_subscriptions')
      .select()
      .order('listing_date', ascending: false);
  return rows.map<IpoSubscription>(IpoSubscription.fromMap).toList();
});

// ── 부동산 작업대 ────────────────────────────────────────────

/// 구역 — 동의율 높은 순(조합설립 임박한 곳부터).
final zonesProvider = FutureProvider<List<Zone>>((ref) async {
  final sb = ref.watch(supabaseProvider);
  final rows =
      await sb.from('zones').select().order('consent_rate', ascending: false);
  return rows.map<Zone>(Zone.fromMap).toList();
});

final calcRecordsProvider = FutureProvider<List<CalcRecord>>((ref) async {
  final sb = ref.watch(supabaseProvider);
  final rows =
      await sb.from('calc_records').select().order('created_at', ascending: false);
  return rows.map<CalcRecord>(CalcRecord.fromMap).toList();
});

final taxEventsProvider = FutureProvider<List<TaxEvent>>((ref) async {
  final sb = ref.watch(supabaseProvider);
  final rows = await sb.from('tax_events').select().order('event_date');
  return rows.map<TaxEvent>(TaxEvent.fromMap).toList();
});

/// 단지.
final complexesProvider = FutureProvider<List<Complex>>((ref) async {
  final sb = ref.watch(supabaseProvider);
  final rows = await sb.from('complexes').select().order('name');
  return rows.map<Complex>(Complex.fromMap).toList();
});

/// 단지별 «최신» 시세조사. 추이는 남기지만 화면은 최신 것만 본다.
final latestSurveysProvider =
    FutureProvider<Map<String, PriceSurvey>>((ref) async {
  final sb = ref.watch(supabaseProvider);
  final rows = await sb
      .from('price_surveys')
      .select()
      .order('surveyed_on', ascending: false);
  final out = <String, PriceSurvey>{};
  for (final r in rows) {
    final s = PriceSurvey.fromMap(r);
    out.putIfAbsent(s.complexId, () => s); // 내림차순이라 첫 개가 최신
  }
  return out;
});

/// 단지별 임장 목록 (최신순).
final visitsProvider = FutureProvider<Map<String, List<Visit>>>((ref) async {
  final sb = ref.watch(supabaseProvider);
  final rows =
      await sb.from('visits').select().order('visited_at', ascending: false);
  final out = <String, List<Visit>>{};
  for (final r in rows) {
    final v = Visit.fromMap(r);
    out.putIfAbsent(v.complexId, () => []).add(v);
  }
  return out;
});

/// 숏폼 편성표 — 날짜순.
final shortsSlotsProvider = FutureProvider<List<ShortsSlotRow>>((ref) async {
  final sb = ref.watch(supabaseProvider);
  final rows = await sb.from('shorts_slots').select().order('slot_date');
  return rows.map<ShortsSlotRow>(ShortsSlotRow.fromMap).toList();
});
