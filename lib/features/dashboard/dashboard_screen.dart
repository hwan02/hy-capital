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
import '../goals/goals_screen.dart' show goalToMap;
import '../ipo/ipo_alert.dart';
import 'asset_editor.dart';

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
        // 2단 두 줄 — [목표 | 오늘 해야 할 일], [사업 엔진 | 메모].
        // 칸마다 높이를 정해 두고, 내용이 더 길면 칸 안에서 세로로 스크롤한다
        // (카드가 길어지면 아래 카드들이 밀려 내려갔다). 좁으면 위아래로 쌓는다.
        // 할 일은 체크하면 사라지고 「지난 완료」로 간다.
        const _TwoColumns(
          height: 440,
          left: _NextGoalsCard(),
          right: _TodayTasks(),
        ),
        const Gap(14),
        _TwoColumns(
          height: 300,
          left: metricsAsync.when(
            loading: () => GlassCard(child: AsyncStatus.loading()),
            error: (e, st) => GlassCard(child: AsyncStatus.error(e, st)),
            data: (m) => _BusinessEngines(m: m),
          ),
          right: const _Memos(),
        ),
        const Gap(14),
        const _CapitalProgress(),
        const Gap(14),
        // 자산 한눈에 — «지금 내 돈이 어디에 얼마». 맨 아래(11/03 요청).
        const _AssetsCard(),
      ],
    );
  }
}

/// 넓은 화면은 좌우 2단 — 두 칸 모두 [height] 로 높이를 맞추고, 카드 안
/// 목록은 [_ScrollBody] 로 칸 안에서 스크롤한다.
///
/// 좁은 화면(폰)은 위아래로 쌓고 높이를 «풀어» 내용만큼 늘린다. 폰에서
/// 칸마다 안쪽 스크롤이 있으면 손가락으로 끌 때 안쪽 목록만 움직이고
/// 페이지가 안 내려간다(Flutter 는 터치 스크롤을 바깥으로 넘기지 않는다).
class _TwoColumns extends StatelessWidget {
  final Widget left, right;
  final double height;
  const _TwoColumns(
      {required this.left, required this.right, required this.height});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 760) {
        return _PanelFixed(
          fixed: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [left, const Gap(14), right],
          ),
        );
      }
      return SizedBox(
        height: height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: left),
            const Gap(14),
            Expanded(child: right),
          ],
        ),
      );
    });
  }
}

/// 카드 높이가 정해져 있나 — [_TwoColumns] 가 좁은 화면에서 false 로 내린다.
class _PanelFixed extends InheritedWidget {
  final bool fixed;
  const _PanelFixed({required this.fixed, required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_PanelFixed>()?.fixed ?? true;

  @override
  bool updateShouldNotify(_PanelFixed old) => old.fixed != fixed;
}

/// 높이가 정해진 카드의 «본문» — 남은 높이를 채우고 넘치면 세로 스크롤.
/// 높이가 풀린 카드(폰)에서는 그냥 내용만큼 늘어난다.
class _ScrollBody extends StatelessWidget {
  final Widget child;
  const _ScrollBody({required this.child});

  @override
  Widget build(BuildContext context) {
    if (!_PanelFixed.of(context)) return child;
    return Expanded(
      child: SingleChildScrollView(
        // 스크롤바가 글자를 덮지 않게 오른쪽을 조금 비운다.
        padding: const EdgeInsets.only(right: 10),
        child: child,
      ),
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
            // 원형 게이지만 — 같은 숫자를 글자로 한 번 더 쓰지 않는다.
            final info = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  mainAxisSize: MainAxisSize.min,
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
                _FreedomGauge(m: m),
              ],
            );
            final hasMonthly = flows.any((f) => f.nonSalary > 0);
            final monthly = _MonthlyBars(flows: flows);
            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  info,
                  if (hasMonthly) ...[
                    const Gap(16),
                    const Divider(height: 1, color: Color(0x1AFFFFFF)),
                    const Gap(14),
                    monthly,
                  ],
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                info,
                if (hasMonthly) ...[
                  const Gap(28),
                  Container(width: 1, height: 170, color: const Color(0x1AFFFFFF)),
                  const Gap(24),
                  Expanded(child: monthly),
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
}

/// 이번 달 실적 / 월 목표. 가운데 숫자와 %는 모두 «이번 달 실적» 기준 —
/// 전엔 %만 추정 평균(freedomScore)이라 옆 숫자와 달랐다(18% vs 20%).
class _FreedomGauge extends StatelessWidget {
  final DashboardMetrics m;
  const _FreedomGauge({required this.m});

  @override
  Widget build(BuildContext context) {
    final pct = (m.thisMonthScore / 100).clamp(0.0, 1.0);
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
              // 단위까지 붙여 «203만». 큰 금액(1,083만 등)은 링 안에 맞게 줄인다.
              SizedBox(
                width: 118,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(Won.compact(m.thisMonthCashflow),
                      style: const TextStyle(
                          fontSize: AppFont.hero, fontWeight: FontWeight.w900, height: 1)),
                ),
              ),
              const Gap(2),
              Text('/ $tgt만',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: AppFont.body)),
              const Gap(3),
              Text('${m.thisMonthScore.toStringAsFixed(0)}% 달성',
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

/// 프리덤 스코어 옆 월별 현금흐름(월급은 뺀 사업 수익) — 사업별로 쌓은 막대.
/// 카드의 남는 폭을 다 쓴다. 이번 달은 진하게, 지난달들은 옅게.
class _MonthlyBars extends StatelessWidget {
  final List<MonthlyCashflow> flows;
  const _MonthlyBars({required this.flows});

  static const _barArea = 128.0;
  static const _sources = [
    ('에비', AppColors.sky),
    ('배당', AppColors.primary),
    ('숏폼', AppColors.rose),
  ];

  List<double> _parts(MonthlyCashflow f) => [f.airbnb, f.dividend, f.shorts];

  @override
  Widget build(BuildContext context) {
    final rows = flows.where((f) => f.nonSalary > 0).toList();
    if (rows.isEmpty) return const SizedBox.shrink();
    final recent = rows.length > 6 ? rows.sublist(rows.length - 6) : rows;
    final maxV = recent.map((r) => r.nonSalary).reduce((a, b) => a > b ? a : b);
    final now = DateTime.now();
    bool isNow(DateTime d) => d.year == now.year && d.month == now.month;
    // 범례는 실제로 값이 있는 사업만.
    final used = [
      for (var i = 0; i < _sources.length; i++)
        if (recent.any((r) => _parts(r)[i] > 0)) i,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 28), // 우상단 설정 아이콘 자리
          child: Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('월별 현금흐름',
                  style: TextStyle(
                      fontSize: AppFont.label,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700)),
              for (final i in used)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        color: _sources[i].$2,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                  const Gap(4),
                  Text(_sources[i].$1,
                      style: const TextStyle(
                          color: AppColors.textFaint, fontSize: AppFont.caption)),
                ]),
            ],
          ),
        ),
        const Gap(14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final r in recent)
              Expanded(
                child: _bar(r, maxV, isNow(r.month)),
              ),
          ],
        ),
      ],
    );
  }

  Widget _bar(MonthlyCashflow r, double maxV, bool current) {
    final h = maxV <= 0 ? 0.0 : (r.nonSalary / maxV) * _barArea;
    final parts = _parts(r);
    final alpha = current ? 1.0 : 0.55;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('${Won.compact(r.nonSalary)}원',
                style: TextStyle(
                    color: current ? AppColors.primary : AppColors.textPrimary,
                    fontSize: current ? AppFont.section : AppFont.label,
                    fontWeight: FontWeight.w900)),
          ),
          const Gap(6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 44),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: h < 4 ? 4 : h,
                child: Column(
                  children: [
                    // 위에서부터 숏폼 → 배당 → 에어비앤비 (바닥이 가장 큰 사업).
                    for (var i = parts.length - 1; i >= 0; i--)
                      if (parts[i] > 0)
                        Expanded(
                          flex: (parts[i] / r.nonSalary * 1000).round().clamp(1, 1000),
                          child: Container(
                              color: _sources[i].$2.withValues(alpha: alpha)),
                        ),
                  ],
                ),
              ),
            ),
          ),
          const Gap(8),
          Text(Dates.ym(r.month),
              style: TextStyle(
                  color: current ? AppColors.textPrimary : AppColors.textFaint,
                  fontSize: AppFont.caption,
                  fontWeight: current ? FontWeight.w800 : FontWeight.w500)),
        ],
      ),
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
    // 달성한 목표는 빼고 Goals의 «달성한 목표»로 보관한다(10/20).
    final active = goals.where((g) => !g.achieved).toList()
      ..sort((a, b) => (a.targetDate ?? DateTime(2100))
          .compareTo(b.targetDate ?? DateTime(2100)));
    final achievedCount = goals.where((g) => g.achieved).length;

    // 목표 줄을 누르면 수정·삭제 — 목표 화면까지 들어가 고치기 번거로웠다(10/19).
    Future<void> menu(Goal g) async {
      final pick = await showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(
          backgroundColor: AppColors.surface,
          title: Text(g.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: AppFont.section)),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 'edit'),
              child: const Row(children: [
                Icon(Icons.edit_rounded, size: 18, color: AppColors.violet),
                Gap(10),
                Text('수정', style: TextStyle(fontSize: AppFont.body)),
              ]),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 'delete'),
              child: const Row(children: [
                Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.rose),
                Gap(10),
                Text('삭제',
                    style: TextStyle(fontSize: AppFont.body, color: AppColors.rose)),
              ]),
            ),
          ],
        ),
      );
      if (!context.mounted) return;
      if (pick == 'edit') {
        await editBuiltinRecord(context, ref, goalsSpec,
            initial: goalToMap(g), id: g.id);
      } else if (pick == 'delete') {
        await deleteBuiltinRecord(context, ref, goalsSpec, g.id, name: g.title);
      }
    }

    return GlassCard(
      accent: AppColors.violet,
      // 카드를 누르면 자금 흐름으로(10/19 요청). 목표 줄은 따로 눌러 수정·삭제.
      onTap: () => context.go('/money'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 목표 화면까지 안 가고 여기서 바로 추가한다(메모 카드와 같은 모양).
          SectionHeader('목표',
              trailing: TextButton.icon(
                onPressed: () => editBuiltinRecord(context, ref, goalsSpec),
                style: TextButton.styleFrom(foregroundColor: AppColors.violet),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('추가'),
              )),
          const Gap(14),
          _ScrollBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              if (active.isEmpty)
                EmptyState(
                    icon: Icons.flag,
                    message: achievedCount > 0
                        ? '진행 중인 목표를 모두 달성했어요 — 다음 목표를 추가해 보세요'
                        : '목표를 추가해 보세요')
              else
                for (final g in active) ...[
                  InkWell(
                    onTap: () => menu(g),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                          Expanded(
                            child: Text.rich(
                              TextSpan(children: [
                                TextSpan(text: _goalValue(g)),
                                // 건수 목표 — 목표일까지 하루에 몇 건(10/22).
                                if (g.dailyPace != null)
                                  TextSpan(
                                      text: '  ·  ${g.dailyPace}',
                                      style: const TextStyle(
                                          color: AppColors.gold,
                                          fontWeight: FontWeight.w800)),
                              ]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: AppFont.caption),
                            ),
                          ),
                          Text('${(g.progress * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(
                                  color: AppColors.violet,
                                  fontWeight: FontWeight.w800,
                                  fontSize: AppFont.label)),
                        ],
                      ),
                        ],
                      ),
                    ),
                  ),
                  const Gap(16),
                ],
              if (achievedCount > 0)
                InkWell(
                  onTap: () => context.go('/goals'),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      const Icon(Icons.emoji_events_rounded,
                          size: 16, color: AppColors.gold),
                      const Gap(6),
                      Text('달성한 목표 $achievedCount개',
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: AppFont.caption,
                              fontWeight: FontWeight.w700)),
                      const Spacer(),
                      const Icon(Icons.chevron_right_rounded,
                          size: 18, color: AppColors.textFaint),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


// ── 사업 엔진 ───────────────────────────────────────────────
// 이번 달에 «실제로 기록된» 수익만 보여준다. 0원인 엔진은 카드를 안 만든다.
// 전엔 「평균 / 이번 달」 두 숫자를 같이 띄웠는데, 평균은 추정치라 헷갈렸다.
// 토지는 월 수익이 아니라 «프로젝트 건수»라 이 줄에서 뺐다(토지 메뉴에서 본다).
class _BusinessEngines extends StatelessWidget {
  final DashboardMetrics m;
  const _BusinessEngines({required this.m});

  @override
  Widget build(BuildContext context) {
    final engines = [
      _Engine('에비', Icons.house_rounded, AppColors.sky,
          m.airbnbThisMonth, '/airbnb'),
      _Engine('배당', Icons.savings_rounded, AppColors.primary,
          m.dividendThisMonth, '/dividend'),
      _Engine('숏폼', Icons.play_circle_fill_rounded, AppColors.rose,
          m.shortsThisMonth, '/shorts'),
    ].where((e) => e.amount > 0).toList();

    // 칸은 늘 «4개(2×2)»로 나눠 두고 엔진을 앞에서부터 채운다 — 하나뿐일 때
    // 칸 전체를 쓰면 너무 컸다(10/31). 빈 칸은 자리만 보인다.
    // 5개를 넘으면 3열로 늘린다.
    final cols = engines.length <= 4 ? 2 : 3;
    final slots = engines.length <= 4
        ? 4
        : (engines.length / cols).ceil() * cols;
    final rows = <List<_Engine?>>[
      for (var i = 0; i < slots; i += cols)
        [for (var j = i; j < i + cols; j++) j < engines.length ? engines[j] : null],
    ];

    final grid = Column(
      children: [
        for (var r = 0; r < rows.length; r++) ...[
          if (r > 0) const Gap(10),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var c = 0; c < cols; c++) ...[
                  if (c > 0) const Gap(10),
                  Expanded(
                    child: rows[r][c] == null
                        ? const _EmptySlot()
                        : _EngineTile(e: rows[r][c]!),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader('사업 엔진'),
          const Gap(12),
          // 높이가 풀린 카드(폰)에서도 칸을 나누려면 높이가 있어야 한다.
          if (_PanelFixed.of(context))
            Expanded(child: grid)
          else
            SizedBox(height: 220, child: grid),
        ],
      ),
    );
  }
}

/// 아직 엔진이 없는 칸 — 테두리만.
class _EmptySlot extends StatelessWidget {
  const _EmptySlot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
    );
  }
}

/// 사업 엔진 칸 하나. 누르면 그 메뉴로 간다.
class _EngineTile extends StatelessWidget {
  final _Engine e;
  const _EngineTile({required this.e});

  @override
  Widget build(BuildContext context) {
    final month = DateTime.now().month;
    return Material(
      color: e.color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go(e.route),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: e.color.withValues(alpha: 0.30)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(e.icon, color: e.color, size: 18),
                  const Gap(8),
                  Expanded(
                    child: Text(e.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: AppFont.body)),
                  ),
                  const Icon(Icons.chevron_right,
                      color: AppColors.textFaint, size: 16),
                ],
              ),
              const Spacer(),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text('${Won.compact(e.amount)}원',
                    maxLines: 1,
                    style: TextStyle(
                        fontSize: AppFont.title,
                        fontWeight: FontWeight.w800,
                        color: e.color)),
              ),
              Text('$month월 실적',
                  style: const TextStyle(
                      color: AppColors.textFaint, fontSize: AppFont.caption)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Engine {
  final String name;
  final IconData icon;
  final Color color;
  final double amount; // 이번 달 실적
  final String route;
  _Engine(this.name, this.icon, this.color, this.amount, this.route);
}

// ── 오늘 해야 할 일 ─────────────────────────────────────────
//
// 체크하면 «목록에서 사라진다». 남은 것만 보이는 게 오늘 할 일의 목적이고,
// 끝낸 줄이 줄줄이 남아 있으면 남은 게 몇 개인지 한눈에 안 들어온다.
// 사라진 것은 헤더의 시계 아이콘 →「지난 완료」에서 날짜별로 본다.
// 잘못 눌렀을 때를 위해 체크 직후 스낵바에 되돌리기를 띄운다.
// 왼쪽 손잡이(⋮⋮)를 끌어 순서를 바꾼다 — tasks.sort_order(0072).
class _TodayTasks extends ConsumerStatefulWidget {
  const _TodayTasks();

  @override
  ConsumerState<_TodayTasks> createState() => _TodayTasksState();
}

class _TodayTasksState extends ConsumerState<_TodayTasks> {
  /// 끌어 놓은 직후 보여 줄 순서 — 다시 불러오기 전에 제자리로 튀지 않게.
  List<String>? _order;

  List<TodoTask> _sorted(List<TodoTask> tasks) {
    final o = _order;
    if (o == null) return tasks;
    final byId = {for (final t in tasks) t.id: t};
    return [
      for (final id in o)
        if (byId[id] != null) byId[id]!,
      ...tasks.where((t) => !o.contains(t.id)),
    ];
  }

  Future<void> _move(List<TodoTask> shown, int from, int to) async {
    final ids = [for (final t in shown) t.id];
    if (to > from) to -= 1; // ReorderableListView 는 «끼울 자리»를 준다
    ids.insert(to, ids.removeAt(from));
    setState(() => _order = ids);
    final sb = ref.read(supabaseProvider);
    try {
      await Future.wait([
        for (var i = 0; i < ids.length; i++)
          sb.from('tasks').update({'sort_order': i}).eq('id', ids[i]),
      ]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('순서 저장 실패 — $e'),
            backgroundColor: AppColors.rose));
      }
      return;
    }
    ref.invalidate(tasksProvider);
  }

  /// 체크 → done + done_at. 해제 → 둘 다 되돌린다.
  Future<void> _setDone(WidgetRef ref, TodoTask t, bool done) async {
    await ref.read(supabaseProvider).from('tasks').update({
      'done': done,
      'done_at': done ? DateTime.now().toUtc().toIso8601String() : null,
    }).eq('id', t.id);
    ref.invalidate(tasksProvider);
    ref.invalidate(doneTasksProvider);
  }

  Future<void> _check(BuildContext context, WidgetRef ref, TodoTask t) async {
    await _setDone(ref, t, true);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('완료 — ${t.title}'),
        backgroundColor: AppColors.surfaceAlt,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: '되돌리기',
          textColor: AppColors.primary,
          onPressed: () => _setDone(ref, t, false),
        ),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksProvider);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader('오늘 해야 할 일',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => showDoneTasksSheet(context),
                    icon: const Icon(Icons.history_rounded, size: 20),
                    color: AppColors.textFaint,
                    tooltip: '지난 완료',
                    visualDensity: VisualDensity.compact,
                  ),
                  TextButton.icon(
                    onPressed: () => editBuiltinRecord(context, ref, taskSpec),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('추가'),
                  ),
                ],
              )),
          const Gap(6),
          _ScrollBody(
            child: tasksAsync.when(
                loading: AsyncStatus.loading,
                error: AsyncStatus.error,
                data: (all) {
                  // 체크한 것은 여기 남지 않는다 —「지난 완료」로 간다.
                  final tasks = _sorted(all.where((t) => !t.done).toList());
                  if (tasks.isEmpty) {
                    return const EmptyState(
                        icon: Icons.task_alt_rounded, message: '오늘 할 일을 다 끝냈습니다');
                  }
                  return ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    onReorder: (from, to) => _move(tasks, from, to),
                    // 끄는 동안 줄이 카드 색으로 떠 보이게.
                    proxyDecorator: (child, _, _) => Material(
                      color: AppColors.surfaceAlt,
                      elevation: 6,
                      borderRadius: BorderRadius.circular(10),
                      child: child,
                    ),
                    children: [
                      for (var i = 0; i < tasks.length; i++)
                        Padding(
                          key: ValueKey(tasks[i].id),
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Builder(builder: (context) {
                            final t = tasks[i];
                            return Row(
                            children: [
                              ReorderableDragStartListener(
                                index: i,
                                child: const MouseRegion(
                                  cursor: SystemMouseCursors.grab,
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 2, vertical: 8),
                                    child: Icon(Icons.drag_indicator_rounded,
                                        size: 18, color: AppColors.textFaint),
                                  ),
                                ),
                              ),
                              Checkbox(
                                value: false,
                                onChanged: (_) => _check(context, ref, t),
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
                                  style: const TextStyle(
                                    fontSize: AppFont.body,
                                    color: AppColors.textPrimary,
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
                          );
                          }),
                        ),
                    ],
                  );
                },
              ),
          ),
        ],
      ),
    );
  }
}

// ── 지난 완료 ───────────────────────────────────────────────
/// 체크해서 사라진 할 일을 «날짜별»로 본다. 여기서 체크를 풀면
/// 다시 오늘 할 일로 돌아간다.
Future<void> showDoneTasksSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => const _DoneTasksSheet(),
  );
}

class _DoneTasksSheet extends ConsumerWidget {
  const _DoneTasksSheet();

  /// 「오늘」·「어제」는 날짜보다 그 말이 빠르게 읽힌다.
  String _dayLabel(DateTime? d) {
    if (d == null) return '날짜 기록 없음';
    final now = DateTime.now();
    final day = DateTime(d.year, d.month, d.day);
    final diff = DateTime(now.year, now.month, now.day).difference(day).inDays;
    if (diff == 0) return '오늘';
    if (diff == 1) return '어제';
    return Dates.md(d);
  }

  Future<void> _undo(WidgetRef ref, TodoTask t) async {
    await ref
        .read(supabaseProvider)
        .from('tasks')
        .update({'done': false, 'done_at': null}).eq('id', t.id);
    ref.invalidate(tasksProvider);
    ref.invalidate(doneTasksProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(doneTasksProvider);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader('지난 완료', subtitle: '체크한 날짜별로 묶여 있습니다'),
              const Gap(8),
              Flexible(
                child: async.when(
                  loading: AsyncStatus.loading,
                  error: AsyncStatus.error,
                  data: (tasks) {
                    if (tasks.isEmpty) {
                      return const EmptyState(
                          icon: Icons.history_rounded,
                          message: '아직 완료한 할 일이 없습니다');
                    }
                    // 날짜별로 묶는다. 목록이 이미 최신순이라 순서는 유지된다.
                    final groups = <String, List<TodoTask>>{};
                    for (final t in tasks) {
                      groups.putIfAbsent(_dayLabel(t.doneAt), () => []).add(t);
                    }
                    return ListView(
                      shrinkWrap: true,
                      children: [
                        for (final e in groups.entries) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(2, 12, 2, 6),
                            child: Row(
                              children: [
                                Text(e.key,
                                    style: const TextStyle(
                                        fontSize: AppFont.label,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary)),
                                const Gap(8),
                                Text('${e.value.length}',
                                    style: const TextStyle(
                                        fontSize: AppFont.caption,
                                        color: AppColors.textFaint)),
                              ],
                            ),
                          ),
                          for (final t in e.value)
                            Row(
                              children: [
                                Checkbox(
                                  value: true,
                                  onChanged: (_) => _undo(ref, t),
                                  activeColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6)),
                                ),
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
                                    style: const TextStyle(
                                      fontSize: AppFont.body,
                                      color: AppColors.textFaint,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 메모 ────────────────────────────────────────────────────
//
// 자료실은 «정리된 자료»고 여기는 그 전 단계 — 통화하다 들은 숫자,
// 아직 할 일인지도 모르는 한 줄. 제목 없이 본문만 받는다.
class _Memos extends ConsumerWidget {
  const _Memos();

  Future<void> _togglePin(WidgetRef ref, Memo m) async {
    await ref
        .read(supabaseProvider)
        .from('memos')
        .update({'pinned': !m.pinned}).eq('id', m.id);
    ref.invalidate(memosProvider);
  }

  /// 메모 전체 — 카드에서 잘린 것을 여기서 끝까지 읽는다. 글자 선택(복사) 가능.
  Future<void> _showMemo(BuildContext context, WidgetRef ref, Memo m) async {
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        titlePadding: const EdgeInsets.fromLTRB(22, 18, 10, 0),
        title: Row(children: [
          Icon(m.pinned ? Icons.push_pin_rounded : Icons.sticky_note_2_rounded,
              size: 18, color: AppColors.gold),
          const Gap(8),
          Text('메모 · ${Dates.md(m.createdAt)}',
              style: const TextStyle(fontSize: AppFont.section)),
          const Spacer(),
          IconButton(
            tooltip: '닫기',
            onPressed: () => Navigator.pop(ctx),
            icon: const Icon(Icons.close_rounded, size: 20),
          ),
        ]),
        content: ConstrainedBox(
          // 폰(375px)에서 넘치지 않게 — 다이얼로그 여백을 빼고 잡는다.
          constraints: BoxConstraints(
            minWidth: (MediaQuery.of(ctx).size.width - 140).clamp(0.0, 360.0),
            maxWidth: 560,
            maxHeight: MediaQuery.of(ctx).size.height * 0.6,
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              m.body.trim(),
              style: const TextStyle(
                  fontSize: AppFont.body,
                  height: 1.65,
                  color: AppColors.textPrimary),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'delete'),
            style: TextButton.styleFrom(foregroundColor: AppColors.rose),
            child: const Text('삭제'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'edit'),
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: const Color(0xFF1B1400)),
            child: const Text('수정'),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    if (action == 'edit') {
      await editBuiltinRecord(context, ref, memoSpec,
          initial: {'body': m.body, 'pinned': m.pinned}, id: m.id);
    } else if (action == 'delete') {
      await deleteBuiltinRecord(context, ref, memoSpec, m.id,
          name: m.firstLine);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(memosProvider);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader('메모',
              trailing: TextButton.icon(
                onPressed: () => editBuiltinRecord(context, ref, memoSpec),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('추가'),
              )),
          const Gap(6),
          _ScrollBody(
            child: async.when(
                loading: AsyncStatus.loading,
                error: AsyncStatus.error,
                data: (memos) {
                  if (memos.isEmpty) {
                    return const EmptyState(
                        icon: Icons.sticky_note_2_rounded,
                        message: '메모가 없습니다');
                  }
                  return Column(
                    children: [
                      for (final m in memos)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              IconButton(
                                onPressed: () => _togglePin(ref, m),
                                icon: Icon(
                                  m.pinned
                                      ? Icons.push_pin_rounded
                                      : Icons.push_pin_outlined,
                                  size: 16,
                                ),
                                color: m.pinned
                                    ? AppColors.gold
                                    : AppColors.textFaint,
                                tooltip: m.pinned ? '고정 해제' : '위에 고정',
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.only(top: 2),
                                constraints: const BoxConstraints(),
                              ),
                              const Gap(10),
                              // 카드에는 6줄까지(전엔 3줄이라 너무 짧았다). 넘치면
                              // «…»로 접고, 누르면 전체를 팝업으로 연다 — 다 펼치면
                              // 긴 메모 하나가 대시보드를 밀어낸다.
                              Expanded(
                                child: InkWell(
                                  onTap: () => _showMemo(context, ref, m),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        m.body.trim(),
                                        maxLines: 6,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: AppFont.body,
                                            height: 1.5,
                                            color: AppColors.textPrimary),
                                      ),
                                      const Gap(2),
                                      Text(Dates.md(m.createdAt),
                                          style: const TextStyle(
                                              fontSize: AppFont.caption,
                                              color: AppColors.textFaint)),
                                    ],
                                  ),
                                ),
                              ),
                              RecordMenu(
                                onEdit: () => editBuiltinRecord(
                                    context, ref, memoSpec,
                                    initial: {'body': m.body, 'pinned': m.pinned},
                                    id: m.id),
                                onDelete: () => deleteBuiltinRecord(
                                    context, ref, memoSpec, m.id,
                                    name: m.firstLine),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
          ),
        ],
      ),
    );
  }
}


// ── 자산 한눈에 ─────────────────────────────────────────────
// 계좌·사업별 잔액을 분류로 묶는다. 순자산 = 부채 빼고 다 더한 것 − 부채.
// 잔액은 손으로 고친다 — 그래서 «언제 고쳤는지»를 같이 보여 준다(30일 넘으면 노랗게).
// 줄을 누르면 편집 창(asset_editor.dart) 하나로 수정·삭제까지 끝난다.

class _AssetsCard extends ConsumerWidget {
  const _AssetsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assets = ref.watch(assetsProvider).asData?.value ?? const <Asset>[];
    final cats = assetCategoriesOf(assets).where((c) => assets.any((a) => a.category == c));
    final byCat = {for (final c in cats) c: assets.where((a) => a.category == c).toList()};
    double sum(String c) => (byCat[c] ?? []).fold(0.0, (t, a) => t + a.amount);
    final plusCats = byCat.keys.where((c) => c != '부채' && sum(c) > 0).toList();
    final gross = plusCats.fold(0.0, (t, c) => t + sum(c));
    final debt = sum('부채');
    final net = gross - debt;
    final last = assets.isEmpty
        ? null
        : assets.map((a) => a.updatedAt).reduce((x, y) => x.isAfter(y) ? x : y);

    // ── 위: 순자산 + 비중 막대 ──
    final top = LayoutBuilder(builder: (context, c) {
      final head = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('순자산',
              style: TextStyle(color: AppColors.textSecondary, fontSize: AppFont.label)),
          const Gap(2),
          Text('${Won.compact(net)}원',
              style: const TextStyle(
                  fontSize: AppFont.hero, fontWeight: FontWeight.w900, height: 1.15)),
          const Gap(4),
          Text.rich(TextSpan(children: [
            TextSpan(text: '자산 ${Won.compact(gross)}'),
            const TextSpan(text: '   '),
            TextSpan(
                text: '부채 ${Won.compact(debt)}',
                style: const TextStyle(color: AppColors.rose)),
          ]), style: const TextStyle(color: AppColors.textSecondary, fontSize: AppFont.label)),
        ],
      );
      final bar = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 18,
              child: Row(children: [
                for (final k in plusCats)
                  Expanded(
                    flex: (sum(k) / gross * 1000).round().clamp(1, 1000),
                    child: Container(
                      margin: const EdgeInsets.only(right: 2),
                      color: assetColor(k),
                    ),
                  ),
              ]),
            ),
          ),
          const Gap(10),
          Wrap(spacing: 14, runSpacing: 6, children: [
            for (final k in plusCats)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: assetColor(k), borderRadius: BorderRadius.circular(3))),
                const Gap(6),
                Text(k,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: AppFont.label)),
                const Gap(4),
                Text('${(sum(k) / gross * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                        fontSize: AppFont.label, fontWeight: FontWeight.w800)),
              ]),
          ]),
        ],
      );
      if (gross <= 0) return head;
      if (c.maxWidth < 640) {
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [head, const Gap(16), bar]);
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        SizedBox(width: 260, child: head),
        const Gap(24),
        Expanded(child: bar),
      ]);
    });

    // ── 아래: 분류별 칸 ──
    final tiles = [
      for (final k in byCat.keys)
        _AssetTile(
          category: k,
          items: byCat[k]!,
          total: sum(k),
          share: k == '부채' || gross <= 0 ? null : sum(k) / gross,
        ),
    ];
    final grid = LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 1100
          ? 4
          : c.maxWidth >= 760
              ? 3
              : c.maxWidth >= 460
                  ? 2
                  : 1;
      final rows = <Widget>[];
      for (var i = 0; i < tiles.length; i += cols) {
        if (i > 0) rows.add(const Gap(12));
        rows.add(IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var j = i; j < i + cols; j++) ...[
              if (j > i) const Gap(12),
              Expanded(child: j < tiles.length ? tiles[j] : const SizedBox()),
            ],
          ]),
        ));
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
    });

    return GlassCard(
      accent: AppColors.gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader('자산',
              subtitle: last == null ? null : '${Dates.md(last)} 수정',
              trailing: TextButton.icon(
                onPressed: () => showAssetEditor(context),
                style: TextButton.styleFrom(foregroundColor: AppColors.gold),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('추가'),
              )),
          const Gap(14),
          if (assets.isEmpty)
            const EmptyState(
                icon: Icons.account_balance_wallet_outlined,
                message: '계좌·사업별 잔액을 추가해 보세요')
          else ...[
            top,
            const Gap(20),
            grid,
          ],
        ],
      ),
    );
  }
}

/// 분류 한 칸 — 색 띠 · 합계 크게 · 항목 목록 · 「+」.
class _AssetTile extends StatelessWidget {
  final String category;
  final List<Asset> items;
  final double total;
  final double? share;
  const _AssetTile(
      {required this.category, required this.items, required this.total, this.share});

  @override
  Widget build(BuildContext context) {
    final color = assetColor(category);
    final debt = category == '부채';
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 4, color: color),
          // 머리 — 누르면 분류 이름 바꾸기·삭제
          InkWell(
            onTap: () => showCategoryEditor(context, category, items.length),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(category,
                        style: TextStyle(
                            color: color,
                            fontSize: AppFont.label,
                            fontWeight: FontWeight.w800)),
                    const Spacer(),
                    if (share != null)
                      Text('${(share! * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: AppFont.caption,
                              fontWeight: FontWeight.w700)),
                  ]),
                  const Gap(4),
                  Text('${debt ? '−' : ''}${Won.compact(total)}원',
                      style: TextStyle(
                          fontSize: AppFont.title,
                          fontWeight: FontWeight.w900,
                          color: debt ? AppColors.rose : AppColors.textPrimary)),
                ],
              ),
            ),
          ),
          Container(height: 1, color: color.withValues(alpha: 0.18)),
          const Gap(4),
          for (final a in items) _AssetRow(a: a, onTap: () => showAssetEditor(context, asset: a)),
          const Spacer(),
          InkWell(
            onTap: () => showAssetEditor(context, category: category),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
              child: Row(children: [
                Icon(Icons.add_rounded, size: 15, color: color.withValues(alpha: 0.8)),
                const Gap(4),
                Text('추가',
                    style: TextStyle(
                        color: color.withValues(alpha: 0.8),
                        fontSize: AppFont.caption,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssetRow extends StatelessWidget {
  final Asset a;
  final VoidCallback onTap;
  const _AssetRow({required this.a, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final days = DateTime.now().difference(a.updatedAt).inDays;
    final empty = a.amount == 0;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(children: [
          Expanded(
            child: Text(a.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: AppFont.label)),
          ),
          // 30일 넘게 안 고친 잔액 — 지금 숫자가 아닐 수 있다.
          if (!empty && days > 30) ...[
            Text('$days일 전',
                style: const TextStyle(color: AppColors.gold, fontSize: AppFont.micro)),
            const Gap(6),
          ],
          Text(empty ? '—' : Won.compact(a.amount),
              style: TextStyle(
                  fontSize: AppFont.label,
                  fontWeight: FontWeight.w700,
                  color: empty ? AppColors.textFaint : AppColors.textPrimary)),
        ]),
      ),
    );
  }
}
