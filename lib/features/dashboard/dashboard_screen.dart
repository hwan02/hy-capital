import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/data_providers.dart';
import '../../core/edit/builtin_crud.dart';
import '../../core/edit/builtin_specs.dart';
import '../../core/format/formatters.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/module_page.dart';
import '../../models/models.dart';
import '../ipo/ipo_alert.dart';
import '../plan/plan_roadmap.dart';

/// profiles 값을 편집 폼 초기값으로.
Map<String, dynamic> _profileToMap(Profile p) => {
      'display_name': p.displayName,
      'freedom_target': p.freedomTarget,
      'monthly_expenses': p.monthlyExpenses,
      'net_worth_goal': p.netWorthGoal,
    };

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  /// 목표·기준선(월 목표 현금흐름 등) 설정.
  Future<void> _editProfile(BuildContext context, WidgetRef ref) async {
    final p = ref.read(profileProvider).asData?.value;
    if (p == null) return;
    await editBuiltinRecord(context, ref, profileSpec,
        initial: _profileToMap(p), id: p.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(dashboardMetricsProvider);

    return ModulePage(
      title: '대시보드',
      icon: Icons.dashboard_rounded,
      color: AppColors.primary,
      children: [
        // 공모주 — 청약은 마감을 넘기면 끝이라 맨 위에 둔다.
        const IpoTodayBanner(),
        metricsAsync.when(
          loading: AsyncStatus.loading,
          error: AsyncStatus.error,
          data: (m) => _FreedomHero(m: m, onEdit: () => _editProfile(context, ref)),
        ),
        const Gap(14),
        metricsAsync.maybeWhen(
          data: (m) => _BusinessEngines(m: m),
          orElse: () => const SizedBox.shrink(),
        ),
        const Gap(14),
        const _MoneyFlowSummary(),
        const Gap(14),
        const _CapitalProgress(),
        const Gap(14),
        // 목표 섹션 = 재무 로드맵 + 개별 목표
        const PlanRoadmapCompact(),
        const Gap(14),
        const _NextGoalsCard(),
        const Gap(14),
        // 오늘 해야 할 일 (전체 폭)
        const _TodayTasks(),
      ],
    );
  }
}

// ── Freedom Score 히어로 (컴팩트 + 월별 현금흐름 내장) ──────────
class _FreedomHero extends ConsumerWidget {
  final DashboardMetrics m;
  final VoidCallback onEdit;
  const _FreedomHero({required this.m, required this.onEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flows = ref.watch(monthlyCashflowProvider).asData?.value ?? [];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Insets.radius),
        gradient: const LinearGradient(
          colors: [Color(0xFF12351F), Color(0xFF0E2233)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          LayoutBuilder(builder: (context, c) {
            final narrow = c.maxWidth < 760;
            final gauge = _FreedomGauge(m: m);
            final info = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bolt, color: AppColors.primary, size: 16),
                    Gap(5),
                    Text('FREEDOM SCORE',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: AppFont.label,
                            letterSpacing: 1.4)),
                  ],
                ),
                const Gap(14),
                Wrap(
                  spacing: 26,
                  runSpacing: 14,
                  children: [
                    _miniStat('월급 제외(평균)', '${Won.compact(m.nonSalaryCashflow)}원',
                        '${m.freedomScore.toStringAsFixed(0)}%'),
                    _miniStat('이번 달 기준', '${Won.compact(m.thisMonthCashflow)}원',
                        '${m.thisMonthScore.toStringAsFixed(0)}%'),
                    _miniStat('자유 기준선 (월 목표)', '${Won.compact(m.freedomTarget)}원', null),
                  ],
                ),
              ],
            );
            final hasMonthly = flows.any((f) => f.nonSalary > 0);
            final monthly = _MonthlyStrip(flows: flows);
            if (narrow) {
              // 좁은 화면: 게이지 → 정보 → 월별을 세로로 쌓아 가로 넘침 방지.
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  gauge,
                  const Gap(16),
                  info,
                  if (hasMonthly) ...[
                    const Gap(14),
                    const Divider(height: 1, color: Color(0x1AFFFFFF)),
                    const Gap(12),
                    monthly,
                  ],
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                gauge,
                const Gap(22),
                Expanded(child: info),
                if (hasMonthly) ...[
                  const Gap(24),
                  monthly,
                ],
              ],
            );
          }),
            ],
          ),
          // 목표 설정 — 카드 제일 오른쪽 위 작은 아이콘.
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              onPressed: onEdit,
              tooltip: '목표 설정',
              icon: const Icon(Icons.tune_rounded,
                  size: 16, color: AppColors.textFaint),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, String? delta) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: AppFont.label)),
        const Gap(4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: AppFont.display, fontWeight: FontWeight.w900)),
            if (delta != null) ...[
              const Gap(8),
              Text(delta,
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: AppFont.section,
                      fontWeight: FontWeight.w800)),
            ],
          ],
        ),
      ],
    );
  }
}

/// 프리덤 스코어 옆 월별 현금흐름 — 최근 3개월, 날짜+금액만.
class _MonthlyStrip extends StatelessWidget {
  final List<MonthlyCashflow> flows;
  const _MonthlyStrip({required this.flows});

  @override
  Widget build(BuildContext context) {
    final rows = flows.where((f) => f.nonSalary > 0).toList();
    if (rows.isEmpty) return const SizedBox.shrink();
    final recent = rows.length > 4 ? rows.sublist(rows.length - 4) : rows;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('월별 현금흐름 · 월급 제외',
            style: TextStyle(
                fontSize: AppFont.label,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700)),
        const Gap(12),
        for (final r in recent)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 52,
                  child: Text(Dates.ym(r.month),
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: AppFont.label)),
                ),
                const Gap(14),
                Text('${Won.compact(r.nonSalary)}원',
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: AppFont.display,
                        fontWeight: FontWeight.w900)),
              ],
            ),
          ),
      ],
    );
  }
}

class _FreedomGauge extends StatelessWidget {
  final DashboardMetrics m;
  const _FreedomGauge({required this.m});

  @override
  Widget build(BuildContext context) {
    final pct = (m.freedomScore / 100).clamp(0.0, 1.0);
    final cur = (m.nonSalaryCashflow / 10000).round();
    final tgt = (m.freedomTarget / 10000).round();
    return SizedBox(
      height: 156,
      width: 156,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            height: 156,
            width: 156,
            child: CircularProgressIndicator(
              value: pct,
              strokeWidth: 13,
              backgroundColor: AppColors.surfaceAlt,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$cur',
                  style: const TextStyle(
                      fontSize: AppFont.hero, fontWeight: FontWeight.w900, height: 1)),
              const Gap(2),
              Text('/ $tgt만',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: AppFont.body)),
              const Gap(3),
              Text('${m.freedomScore.toStringAsFixed(0)}% 달성',
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: AppFont.body,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── 자금 흐름 요약 (들어오는 돈 / 나가는 돈 도넛 2개) ──────────
class _MoneyFlowSummary extends ConsumerWidget {
  const _MoneyFlowSummary();

  static const _palette = [
    AppColors.primary, AppColors.sky, AppColors.gold, AppColors.rose,
    AppColors.violet, Color(0xFFB4844E), Color(0xFF34D399), Color(0xFFFB923C),
    Color(0xFFE879F9), Color(0xFF2DD4BF),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(flowEntriesProvider).asData?.value ?? [];

    // 가장 최근 데이터가 있는 달을 이번 달로 본다.
    DateTime? latest;
    for (final e in entries) {
      final m = DateTime(e.date.year, e.date.month);
      if (latest == null || m.isAfter(latest)) latest = m;
    }
    final lm = latest;
    final scope = lm == null
        ? <FlowEntry>[]
        : entries
            .where((e) => e.date.year == lm.year && e.date.month == lm.month)
            .toList();

    List<_MiniSlice> colorize(Map<String, double> by) {
      final list = by.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      return [
        for (var i = 0; i < list.length; i++)
          _MiniSlice(list[i].key, list[i].value, _palette[i % _palette.length]),
      ];
    }

    // 들어오는 돈 = 수동 기록(비모듈 라벨) + 자동(이번 달 모듈 수익).
    // 자금 흐름 페이지와 동일한 moduleIncomeThisMonthProvider 사용 → 값 일치.
    final incomeBy = <String, double>{};
    for (final e in scope
        .where((e) => e.isIn && !kAutoIncomeLabels.contains(e.label))) {
      incomeBy[e.label] = (incomeBy[e.label] ?? 0) + e.amount;
    }
    final autoIncome = ref.watch(moduleIncomeThisMonthProvider).value ?? const {};
    autoIncome.forEach((k, v) {
      if (v > 0) incomeBy[k] = (incomeBy[k] ?? 0) + v;
    });
    final outBy = <String, double>{};
    for (final e in scope.where((e) => !e.isIn)) {
      outBy[e.label] = (outBy[e.label] ?? 0) + e.amount;
    }
    final inSlices = colorize(incomeBy);
    final outSlices = colorize(outBy);
    final totalIn = inSlices.fold(0.0, (s, a) => s + a.value);
    final totalOut = outSlices.fold(0.0, (s, a) => s + a.value);

    return GlassCard(
      accent: AppColors.gold,
      onTap: () => context.go('/money'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: SectionHeader('자금 흐름')),
              Text(lm == null ? '' : Dates.ym(lm),
                  style: const TextStyle(
                      color: AppColors.textFaint, fontSize: AppFont.label)),
              const Gap(6),
              const Icon(Icons.chevron_right, color: AppColors.textFaint, size: 18),
            ],
          ),
          const Gap(18),
          LayoutBuilder(builder: (context, c) {
            final inD = _MiniDonut(
                title: '들어오는 돈', slices: inSlices, total: totalIn,
                color: AppColors.gold, emptyMsg: '유입 없음');
            final outD = _MiniDonut(
                title: '나가는 돈', slices: outSlices, total: totalOut,
                color: AppColors.sky, emptyMsg: '지출 없음');
            if (c.maxWidth < 620) {
              return Column(children: [inD, const Gap(20), outD]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: inD),
                const Gap(28),
                Expanded(child: outD),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _MiniSlice {
  final String label;
  final double value;
  final Color color;
  _MiniSlice(this.label, this.value, this.color);
}

class _MiniDonut extends StatelessWidget {
  final String title;
  final List<_MiniSlice> slices;
  final double total;
  final Color color;
  final String emptyMsg;
  const _MiniDonut({
    required this.title,
    required this.slices,
    required this.total,
    required this.color,
    required this.emptyMsg,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: AppFont.section, fontWeight: FontWeight.w800)),
        const Gap(16),
        if (total <= 0)
          SizedBox(
            height: 150,
            child: EmptyState(icon: Icons.donut_large_rounded, message: emptyMsg),
          )
        else
          Row(
            children: [
              SizedBox(
                height: 150,
                width: 150,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 44,
                      sections: [
                        for (final s in slices)
                          PieChartSectionData(
                            value: s.value,
                            color: s.color,
                            radius: 30,
                            showTitle: false,
                          ),
                      ],
                    )),
                    Text('${Won.compact(total)}원',
                        style: TextStyle(
                            fontSize: AppFont.section, fontWeight: FontWeight.w900, color: color)),
                  ],
                ),
              ),
              const Gap(16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final s in slices.take(6))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 10, height: 10,
                              decoration: BoxDecoration(
                                  color: s.color,
                                  borderRadius: BorderRadius.circular(3)),
                            ),
                            const Gap(9),
                            Flexible(
                              child: Text(s.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: AppFont.label, fontWeight: FontWeight.w600)),
                            ),
                            const Gap(8),
                            Text('${(s.value / total * 100).toStringAsFixed(0)}%',
                                style: TextStyle(
                                    color: color,
                                    fontSize: AppFont.label,
                                    fontWeight: FontWeight.w800)),
                            const Gap(8),
                            Text('${Won.compact(s.value)}원',
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: AppFont.label,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }
}

// ── 사업자금 모으기 (에비/토지 준비금 진행률) ──────────────────
class _CapitalProgress extends ConsumerWidget {
  const _CapitalProgress();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final airbnb = ref.watch(airbnbProvider).asData?.value ?? [];
    final land = ref.watch(landProvider).asData?.value ?? [];

    final items = <_CapItem>[
      for (final u in airbnb.where((a) => a.status != 'open' && a.targetFund > 0))
        _CapItem('${u.name} 준비금', u.reserveFund, u.targetFund, AppColors.sky),
      for (final l in land.where((l) => l.targetFund > 0))
        _CapItem('${l.name} 사업자금', l.reserveFund, l.targetFund,
            const Color(0xFFB4844E)),
    ];
    if (items.isEmpty) return const SizedBox.shrink();

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader('사업자금 모으기'),
          const Gap(16),
          for (final it in items) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(it.label,
                    style: const TextStyle(
                        fontSize: AppFont.body, fontWeight: FontWeight.w600)),
                Text('${(it.progress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(color: it.color, fontWeight: FontWeight.w800)),
              ],
            ),
            const Gap(6),
            ProgressBar(value: it.progress, color: it.color),
            const Gap(4),
            Text('${Won.compact(it.reserve)} / ${Won.compact(it.target)}원',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: AppFont.caption)),
            const Gap(16),
          ],
        ],
      ),
    );
  }
}

class _CapItem {
  final String label;
  final double reserve, target;
  final Color color;
  _CapItem(this.label, this.reserve, this.target, this.color);
  double get progress => target <= 0 ? 0 : (reserve / target).clamp(0, 1).toDouble();
}

// ── 다음 목표들 (리스트) ─────────────────────────────────────
class _NextGoalsCard extends ConsumerWidget {
  const _NextGoalsCard();

  String _goalValue(Goal g) {
    if (g.unit == 'KRW') {
      return '${Won.compact(g.currentValue)} / ${Won.compact(g.targetValue)}원';
    }
    return '${g.currentValue.toStringAsFixed(0)} / ${g.targetValue.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider).asData?.value ?? [];
    final active = goals.where((g) => g.status == 'active').toList()
      ..sort((a, b) => (a.targetDate ?? DateTime(2100))
          .compareTo(b.targetDate ?? DateTime(2100)));

    return GlassCard(
      accent: AppColors.violet,
      onTap: () => context.go('/goals'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader('목표'),
          const Gap(14),
          if (active.isEmpty)
            const EmptyState(icon: Icons.flag, message: '목표를 추가해 보세요')
          else
            for (final g in active) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(g.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: AppFont.body, fontWeight: FontWeight.w700)),
                  ),
                  if (g.targetDate != null)
                    Text(Dates.dday(g.targetDate!),
                        style: const TextStyle(
                            color: AppColors.textFaint, fontSize: AppFont.caption)),
                ],
              ),
              const Gap(7),
              ProgressBar(value: g.progress, color: AppColors.violet),
              const Gap(5),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_goalValue(g),
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: AppFont.caption)),
                  Text('${(g.progress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                          color: AppColors.violet,
                          fontWeight: FontWeight.w800,
                          fontSize: AppFont.label)),
                ],
              ),
              const Gap(16),
            ],
        ],
      ),
    );
  }
}


// ── 사업 엔진 현황 ───────────────────────────────────────────
class _BusinessEngines extends StatelessWidget {
  final DashboardMetrics m;
  const _BusinessEngines({required this.m});

  @override
  Widget build(BuildContext context) {
    final engines = [
      _Engine('에어비앤비', Icons.house_rounded, AppColors.sky,
          m.airbnbMonthly, m.airbnbThisMonth, '/airbnb'),
      _Engine('배당', Icons.savings_rounded, AppColors.primary,
          m.monthlyDividend, m.dividendThisMonth, '/dividend'),
      _Engine('숏폼', Icons.play_circle_fill_rounded, AppColors.rose,
          m.shortsProfit, m.shortsThisMonth, '/shorts'),
      _Engine('토지', Icons.terrain_rounded, const Color(0xFFB4844E),
          m.landCount.toDouble(), -1, '/land'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12, left: 2),
          child: Text('사업 엔진 · 평균 / 이번 달',
              style: TextStyle(fontSize: AppFont.section, fontWeight: FontWeight.w700)),
        ),
        ResponsiveGrid(
          minTileWidth: 180,
          ratio: 1.1,
          children: [
            for (final e in engines)
              GlassCard(
                accent: e.color,
                padding: const EdgeInsets.all(16),
                onTap: () => context.go(e.route),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(e.icon, color: e.color, size: 18),
                        const Gap(8),
                        Text(e.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: AppFont.body)),
                        const Spacer(),
                        const Icon(Icons.chevron_right,
                            color: AppColors.textFaint, size: 16),
                      ],
                    ),
                    const Gap(10),
                    if (e.name == '토지') ...[
                      Text('${e.avg.toStringAsFixed(0)}건',
                          style: TextStyle(
                              fontSize: AppFont.title,
                              fontWeight: FontWeight.w800,
                              color: e.color)),
                      const Text('프로젝트',
                          style: TextStyle(
                              color: AppColors.textFaint, fontSize: AppFont.micro)),
                      const Gap(5),
                      Text(e.avg > 0 ? '진행 중' : '없음',
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: AppFont.label,
                              fontWeight: FontWeight.w600)),
                    ] else ...[
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text('${Won.compact(e.avg)}원',
                            maxLines: 1,
                            style: TextStyle(
                                fontSize: AppFont.title,
                                fontWeight: FontWeight.w800,
                                color: e.color)),
                      ),
                      const Text('평균(월)',
                          style: TextStyle(
                              color: AppColors.textFaint, fontSize: AppFont.micro)),
                      const Gap(5),
                      Text('이번 달 ${Won.compact(e.thisMonth)}원',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: AppFont.label,
                              fontWeight: FontWeight.w600)),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Engine {
  final String name;
  final IconData icon;
  final Color color;
  final double avg;
  final double thisMonth;
  final String route;
  _Engine(this.name, this.icon, this.color, this.avg, this.thisMonth, this.route);
}

// ── 오늘 해야 할 일 ─────────────────────────────────────────
class _TodayTasks extends ConsumerWidget {
  const _TodayTasks();

  Future<void> _toggle(WidgetRef ref, TodoTask t) async {
    await ref
        .read(supabaseProvider)
        .from('tasks')
        .update({'done': !t.done}).eq('id', t.id);
    ref.invalidate(tasksProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksProvider);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader('오늘 해야 할 일',
              trailing: TextButton.icon(
                onPressed: () => editBuiltinRecord(context, ref, taskSpec),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('추가'),
              )),
          const Gap(6),
          tasksAsync.when(
            loading: AsyncStatus.loading,
            error: AsyncStatus.error,
            data: (tasks) {
              if (tasks.isEmpty) {
                return const EmptyState(
                    icon: Icons.checklist_rounded, message: '할 일이 없습니다');
              }
              return Column(
                children: [
                  for (final t in tasks)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Checkbox(
                            value: t.done,
                            onChanged: (_) => _toggle(ref, t),
                            activeColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6)),
                          ),
                          // 태그를 맨 앞에.
                          if (t.module != null) ...[
                            Pill(t.module!,
                                color: AppColors.module[t.module] ??
                                    AppColors.textFaint),
                            const Gap(10),
                          ],
                          Expanded(
                            child: Text(
                              t.title,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: AppFont.body,
                                decoration: t.done
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: t.done
                                    ? AppColors.textFaint
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ),
                          RecordMenu(
                            onEdit: () => editBuiltinRecord(
                                context, ref, taskSpec,
                                initial: {
                                  'title': t.title,
                                  'module': t.module,
                                  'due_date': t.dueDate
                                      ?.toIso8601String()
                                      .substring(0, 10),
                                  'done': t.done,
                                },
                                id: t.id),
                            onDelete: () => deleteBuiltinRecord(
                                context, ref, taskSpec, t.id,
                                name: t.title),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
