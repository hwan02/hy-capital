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
import '../dashboard/asset_editor.dart' show assetCategoriesOf;
import 'plan_period.dart';

/// 갈래별 색 — 칩·점·왼쪽 줄에 같이 쓴다.
const _trackColors = <String, Color>{
  '비전': AppColors.gold,
  '경공매': Color(0xFF14B8A6),
  '사업': AppColors.sky,
  '교육': Color(0xFFF97316),
  '인스타': Color(0xFFEC4899),
  '재무': AppColors.primary,
  '여행': AppColors.violet,
};

Color _trackColor(String t) => _trackColors[t] ?? AppColors.textSecondary;

/// 순자산은 «100억», 현금흐름은 «월 1000만».
String _goalText(String metric, double v) =>
    metric == '순자산' ? Won.compact(v) : '월 ${Won.compact(v)}';

Map<String, dynamic> _toMap(PlanItem p) => {
      'title': p.title,
      'horizon': p.horizon,
      'track': p.track,
      'metric': p.metric,
      'detail': p.detail,
      'due_date': p.dueDate?.toIso8601String().substring(0, 10),
      'period_start': p.periodStart?.toIso8601String().substring(0, 10),
      'note': p.note,
    };

Map<String, dynamic> _goalMap(PlanItem g) => {
      'horizon': g.horizon,
      'metric': g.metric,
      'target': g.target,
      'detail': g.detail,
      'due_date': g.dueDate?.toIso8601String().substring(0, 10),
      'period_start': g.periodStart?.toIso8601String().substring(0, 10),
    };

String _ymd(DateTime d) => d.toIso8601String().substring(0, 10);

/// 칸을 세기 시작하는 날 — 가장 먼저 적은 계획. 없으면 오늘.
DateTime _planStart(List<PlanItem> all) =>
    all.map((p) => p.createdAt).whereType<DateTime>().fold<DateTime?>(
        null, (a, b) => a == null || b.isBefore(a) ? b : a) ??
    DateTime.now();

/// 자산 카드(대시보드 _AssetsCard)와 같은 셈 — 부채 빼고 더한 것 − 부채.
double _netWorth(List<Asset> assets) {
  final byCat = <String, double>{};
  for (final a in assets) {
    byCat[a.category] = (byCat[a.category] ?? 0) + a.amount;
  }
  return byCat.entries.fold(
      0.0,
      (t, e) => e.key == '부채'
          ? t - e.value
          : t + (e.value > 0 ? e.value : 0));
}

/// 자산 카드 분류별 합 한 줄 — 순자산 목표 밑에 «지금 무엇으로 이뤄져 있나».
String? _assetLine(List<Asset>? assets) {
  if (assets == null || assets.isEmpty) return null;
  return [
    for (final c in assetCategoriesOf(assets))
      if (assets.any((a) => a.category == c))
        '$c ${c == '부채' ? '−' : ''}${Won.compact(assets.where((a) => a.category == c).fold(0.0, (t, a) => t + a.amount))}',
  ].join(' · ');
}

/// «지금» 숫자. null = 아직 불러오는 중.
///   순자산 — 자산 카드.
///   월 현금흐름 — 지난 3달(이번 달 빼고) 에비·배당·숏폼·토지 평균. 월급 제외.
Map<String, double?> _nowValues(WidgetRef ref) {
  final assets = ref.watch(assetsProvider).asData?.value;
  final byMonth = ref.watch(moduleIncomeByMonthProvider).asData?.value;
  double? personal;
  if (byMonth != null) {
    final now = DateTime.now();
    double month(int back) {
      final k = DateTime(now.year, now.month - back)
          .toIso8601String()
          .substring(0, 10);
      return (byMonth[k] ?? const {}).values.fold(0.0, (a, b) => a + b);
    }

    // 수익이 없던 달도 0으로 센다 — 있는 달만 평균 내면 부풀려진다.
    personal = (month(1) + month(2) + month(3)) / 3;
  }
  return {
    '순자산': assets == null ? null : _netWorth(assets),
    '월 현금흐름': personal,
  };
}

/// 계획 — 맨 위 10년 비전(+ 숫자 목표 서브), 한눈에 보기 표,
/// 그 아래 기간(10년~1주)을 골라 숫자 목표별·갈래별 할 일.
/// 기간마다 칸이 이어진다 — 1주 계획은 1주차·2주차 …, 1개월 계획은 매달(plan_period.dart).
class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key});

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
  // 처음엔 «이번 주» — 들어와서 바로 할 일을 본다.
  String _horizon = '1주';
  final _viewKey = GlobalKey();

  /// 기간마다 보고 있는 칸 — 없으면 지금 칸(이번 주·이번 달).
  final _period = <String, int>{};
  PlanPeriods _periods = PlanPeriods(DateTime.now());
  List<PlanItem> _goalsAll = const [];

  int _idx(String h) => _period[h] ?? _periods.current(h);

  /// 새로 적는 건 지금 보는 칸에 — 기한은 그 칸의 마지막 날.
  Map<String, dynamic> get _here => {
        'horizon': _horizon,
        'period_start': _ymd(_periods.startOf(_horizon, _idx(_horizon))),
        'due_date': _ymd(_periods.endOf(_horizon, _idx(_horizon))),
      };

  void _add({String? track}) => editBuiltinRecord(context, ref, planItemSpec,
      initial: {..._here, 'track': track ?? '경공매'});

  void _addFor(String metric) => editBuiltinRecord(context, ref, planItemSpec,
      initial: {..._here, 'track': '재무', 'metric': metric});

  // 목표 금액은 앞 칸에 정해 둔 것을 미리 채운다 — 매주 처음부터 치지 않게.
  void _addGoal([String? metric]) {
    final before = metric == null
        ? null
        : _carried(_goalsAll, _periods, _horizon, metric, _idx(_horizon));
    editBuiltinRecord(context, ref, planGoalSpec,
        initial: {..._here, 'metric': ?metric, 'target': ?before?.target},
        fixed: kPlanGoalFixed);
  }

  /// 앞 칸에서 안 끝난 할 일과 숫자 목표를 이 칸으로 가져온다.
  Future<void> _copyIn(List<PlanItem> src) async {
    final sb = ref.read(supabaseProvider);
    final uid = sb.auth.currentUser?.id;
    if (uid == null || src.isEmpty) return;
    final i = _idx(_horizon);
    try {
      await sb.from('plan_items').insert([
        for (final p in src)
          {
            'user_id': uid,
            'horizon': p.horizon,
            'track': p.track,
            'title': p.title,
            'detail': p.detail,
            'metric': p.metric,
            'target': p.target,
            'sort_order': p.sortOrder,
            'period_start': _ymd(_periods.startOf(_horizon, i)),
            'due_date': _ymd(_periods.endOf(_horizon, i)),
          },
      ]);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('가져오기 실패: $e'), backgroundColor: AppColors.rose));
      return;
    }
    invalidateAll(ref);
  }

  // 표에서 고르면 아래 기간 카드까지 내려 준다 — 폰에선 표 밑이 안 보인다.
  void _jump(String h) {
    setState(() {
      _horizon = h;
      _period.remove(h); // 표는 «지금» 칸 기준이다
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = _viewKey.currentContext;
      if (c != null) {
        Scrollable.ensureVisible(c,
            duration: const Duration(milliseconds: 300), alignment: 0.05);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(planItemsProvider);
    return ModulePage(
      title: '계획',
      icon: Icons.route_rounded,
      color: AppColors.gold,
      action: AddButton(color: AppColors.gold, onTap: _add),
      fab: FloatingActionButton(
        onPressed: _add,
        backgroundColor: AppColors.gold,
        foregroundColor: Colors.black,
        tooltip: '할 일 추가',
        child: const Icon(Icons.add_rounded),
      ),
      children: [
        async.when(
          loading: AsyncStatus.loading,
          error: AsyncStatus.error,
          data: (all) {
            if (all.isEmpty) {
              return const EmptyState(
                  icon: Icons.route_rounded, message: '아직 계획이 없습니다');
            }
            final now = _nowValues(ref);
            final periods = _periods = PlanPeriods(_planStart(all));
            final visions = all.where((p) => p.track == '비전').toList();
            final goals = _goalsAll = all.where((p) => p.isGoal).toList();
            final todos =
                all.where((p) => p.track != '비전' && !p.isGoal).toList();
            final today = DateTime.now();
            List<PlanItem> at(List<PlanItem> src, String h, int i) => [
                  for (final p in src)
                    if (p.horizon == h &&
                        periods.indexOf(h, p.periodDay ?? today) == i)
                      p,
                ];
            final h = _horizon, i = _idx(h);
            final hereTodos = at(todos, h, i), hereGoals = at(goals, h, i);
            // 빈 칸이면 앞 칸에서 가져오기 — 안 끝난 할 일 + 숫자 목표.
            final carry = i == 0 || hereTodos.isNotEmpty || hereGoals.isNotEmpty
                ? const <PlanItem>[]
                : [
                    ...at(goals, h, i - 1),
                    ...at(todos, h, i - 1).where((p) => !p.done),
                  ];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (visions.isNotEmpty) ...[
                  _VisionCard(visions,
                      subs: goals.where((g) => g.horizon == '10년').toList(),
                      now: now),
                  const Gap(24),
                ],
                const SectionHeader('한눈에 보기',
                    subtitle: '줄을 누르면 그 기간 계획이 열려요'),
                const Gap(12),
                _OverviewTable(
                  goalOf: (h, m) =>
                      _carried(goals, periods, h, m, periods.current(h)),
                  todosOf: (h) => at(todos, h, periods.current(h)),
                  now: now,
                  selected: _horizon,
                  onSelect: _jump,
                ),
                const Gap(28),
                const SectionHeader('기간별 계획',
                    subtitle: '동그라미는 완료, 할 일을 누르면 적을 수 있어요'),
                const Gap(12),
                _HorizonChips(
                  itemsOf: (h) => at(todos, h, _idx(h)),
                  selected: _horizon,
                  onSelect: (h) => setState(() => _horizon = h),
                ),
                const Gap(14),
                _HorizonView(
                  key: _viewKey,
                  horizon: h,
                  goals: hereGoals,
                  items: hereTodos,
                  bar: _PeriodBar(
                    name: periods.name(h, i),
                    range: periods.range(h, i),
                    nowWord: PlanPeriods.nowWord(h),
                    isNow: i == periods.current(h),
                    onPrev: i > 0
                        ? () => setState(() => _period[h] = i - 1)
                        : null,
                    onNext: i < periods.count(h) - 1
                        ? () => setState(() => _period[h] = i + 1)
                        : null,
                    onNow: () => setState(() => _period.remove(h)),
                  ),
                  carry: carry,
                  onCarry: () => _copyIn(carry),
                  now: now,
                  assetLine:
                      _assetLine(ref.watch(assetsProvider).asData?.value),
                  onAdd: (t) => _add(track: t),
                  onAddFor: _addFor,
                  onAddGoal: _addGoal,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

Future<void> _toggle(WidgetRef ref, PlanItem p) async {
  // 완료일은 여기서 — DB current_date 는 UTC 라 한국 아침엔 하루 전으로 찍혔다.
  final today = DateTime.now().toIso8601String().substring(0, 10);
  await ref.read(supabaseProvider).from('plan_items').update({
    'done': !p.done,
    'done_at': p.done ? null : today,
  }).eq('id', p.id);
  ref.invalidate(planItemsProvider);
}

/// 숫자 목표는 칸마다 새로 안 정해도 이어진다 — [i] 칸까지 가장 최근에 정한 것.
PlanItem? _carried(
    List<PlanItem> goals, PlanPeriods periods, String h, String m, int i) {
  PlanItem? best;
  var bestIdx = -1;
  final today = DateTime.now();
  for (final g in goals) {
    if (g.horizon != h || g.metric != m) continue;
    final gi = periods.indexOf(h, g.periodDay ?? today);
    if (gi <= i && gi > bestIdx) {
      best = g;
      bestIdx = gi;
    }
  }
  return best;
}

void _edit(BuildContext c, WidgetRef ref, PlanItem p) =>
    editBuiltinRecord(c, ref, planItemSpec, initial: _toMap(p), id: p.id);

/// 할 일을 누르면 «적기» — 제목이 질문, 칸 하나.
void _note(BuildContext c, WidgetRef ref, PlanItem p) => editBuiltinRecord(
    c, ref, planNoteSpec(p.title),
    initial: {'note': p.note}, id: p.id);

void _delete(BuildContext c, WidgetRef ref, PlanItem p) =>
    deleteBuiltinRecord(c, ref, planItemSpec, p.id, name: p.title);

void _editGoal(BuildContext c, WidgetRef ref, PlanItem g) => editBuiltinRecord(
    c, ref, planGoalSpec,
    initial: _goalMap(g), id: g.id, fixed: kPlanGoalFixed);

void _deleteGoal(BuildContext c, WidgetRef ref, PlanItem g) =>
    deleteBuiltinRecord(c, ref, planGoalSpec, g.id,
        name: '${g.horizon} ${g.metric} 목표');

/// 10년 비전 — 큰 목표 몇 개를 크게. 숫자 목표가 묶인 비전 밑에는
/// 10년 숫자 목표(현금흐름)를 서브로.
class _VisionCard extends ConsumerWidget {
  final List<PlanItem> visions;
  final List<PlanItem> subs;
  final Map<String, double?> now;
  const _VisionCard(this.visions, {required this.subs, required this.now});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = visions.map((v) => v.dueDate).whereType<DateTime>().fold<DateTime?>(
        null, (a, b) => a == null || b.isAfter(a) ? b : a);
    return GlassCard(
      accent: AppColors.gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.auto_awesome_rounded,
                color: AppColors.gold, size: 22),
            const Gap(10),
            const Expanded(
              child: Text('10년 비전',
                  style: TextStyle(
                      fontSize: AppFont.title, fontWeight: FontWeight.w800)),
            ),
            if (due != null) Pill('${Dates.ymd(due)} · ${Dates.dday(due)}',
                color: AppColors.gold),
          ]),
          const Gap(14),
          for (var i = 0; i < visions.length; i++) ...[
            if (i > 0) const Divider(height: 22, color: AppColors.border),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${i + 1}',
                  style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: AppFont.display,
                      fontWeight: FontWeight.w900)),
              const Gap(14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(visions[i].title,
                          style: TextStyle(
                              fontSize: AppFont.section,
                              fontWeight: FontWeight.w800,
                              decoration: visions[i].done
                                  ? TextDecoration.lineThrough
                                  : null)),
                      if ((visions[i].detail ?? '').isNotEmpty) ...[
                        const Gap(4),
                        Text(visions[i].detail!,
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: AppFont.label,
                                height: 1.5)),
                      ],
                      if (visions[i].metric != null)
                        for (final g in subs
                            .where((g) => g.metric != visions[i].metric))
                          _VisionSub(g, now[g.metric]),
                    ]),
              ),
              RecordMenu(
                  onEdit: () => _edit(context, ref, visions[i]),
                  onDelete: () => _delete(context, ref, visions[i])),
            ]),
          ],
        ],
      ),
    );
  }
}

class _VisionSub extends StatelessWidget {
  final PlanItem goal;
  final double? now;
  const _VisionSub(this.goal, this.now);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(children: [
        const Icon(Icons.subdirectory_arrow_right_rounded,
            color: AppColors.textFaint, size: 16),
        const Gap(6),
        Expanded(
          child: Text(goal.metric!,
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: AppFont.label,
                  fontWeight: FontWeight.w700)),
        ),
        Text(_goalText(goal.metric!, goal.target!),
            style: const TextStyle(
                color: AppColors.gold,
                fontSize: AppFont.body,
                fontWeight: FontWeight.w800)),
        if (now != null) ...[
          const Gap(8),
          Text('지금 ${Won.compact(now!)}',
              style: const TextStyle(
                  color: AppColors.textFaint, fontSize: AppFont.caption)),
        ],
      ]),
    );
  }
}

/// 한눈에 보기 — 줄은 기간(10년 → 1주, 맨 아래 «지금»), 칸은 숫자 목표 셋과 할 일.
/// 가로 스크롤 없이 폰 폭에 들어가게 칸을 나눈다.
/// 숫자는 지금 칸(이번 주·이번 달 …) 기준 — 이번 칸에 목표를 안 정했으면 앞 칸 것.
class _OverviewTable extends StatelessWidget {
  final PlanItem? Function(String horizon, String metric) goalOf;
  final List<PlanItem> Function(String horizon) todosOf;
  final Map<String, double?> now;
  final String selected;
  final ValueChanged<String> onSelect;
  const _OverviewTable({
    required this.goalOf,
    required this.todosOf,
    required this.now,
    required this.selected,
    required this.onSelect,
  });

  static const _head = TextStyle(
      color: AppColors.textFaint,
      fontSize: AppFont.caption,
      fontWeight: FontWeight.w700);
  static const _faint =
      TextStyle(color: AppColors.textFaint, fontSize: AppFont.label);

  Widget _line(Widget h, List<Widget> cells, Widget todo) => Row(children: [
        SizedBox(width: 50, child: h),
        for (final c in cells) Expanded(child: c),
        SizedBox(width: 48, child: todo),
      ]);

  Widget _right(String t, TextStyle s) =>
      Align(alignment: Alignment.centerRight, child: Text(t, style: s));

  Widget _goalCell(PlanItem? g, double? cur) {
    if (g == null) return _right('—', _faint);
    final pct = cur == null || g.target! <= 0 ? null : cur / g.target!;
    final hit = pct != null && pct >= 1;
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(Won.compact(g.target!),
          style: TextStyle(
              color: hit ? AppColors.primary : AppColors.textPrimary,
              fontSize: AppFont.label,
              fontWeight: FontWeight.w800)),
      if (pct != null)
        Text(hit ? '달성' : '${(pct * 100).floor()}%',
            style: TextStyle(
                color: hit ? AppColors.primary : AppColors.textFaint,
                fontSize: AppFont.micro,
                fontWeight: FontWeight.w600)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _line(
              const Text('기간', style: _head),
              [for (final m in kPlanMetrics) _right(m, _head)],
              _right('할 일', _head),
            ),
          ),
          const Gap(6),
          for (final h in kPlanHorizons)
            Builder(builder: (_) {
              final mine = todosOf(h);
              final done = mine.where((p) => p.done).length;
              final on = h == selected;
              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onSelect(h),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 40),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: on ? AppColors.gold.withValues(alpha: 0.12) : null,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _line(
                    Text(h,
                        style: TextStyle(
                            color: on ? AppColors.gold : AppColors.textPrimary,
                            fontSize: AppFont.body,
                            fontWeight: FontWeight.w800)),
                    [
                      for (final m in kPlanMetrics)
                        _goalCell(goalOf(h, m), now[m])
                    ],
                    _right(
                        mine.isEmpty ? '—' : '$done/${mine.length}',
                        TextStyle(
                            color: mine.isNotEmpty && done == mine.length
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            fontSize: AppFont.label,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              );
            }),
          const Divider(height: 14, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _line(
              const Text('지금',
                  style: TextStyle(
                      color: AppColors.gold,
                      fontSize: AppFont.body,
                      fontWeight: FontWeight.w800)),
              [
                for (final m in kPlanMetrics)
                  _right(
                      now[m] == null ? '…' : Won.compact(now[m]!),
                      const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: AppFont.label,
                          fontWeight: FontWeight.w700)),
              ],
              const SizedBox(),
            ),
          ),
        ],
      ),
    );
  }
}

/// 기간 고르기 — 가로 스크롤 대신 Wrap. 칩마다 «완료/전체».
class _HorizonChips extends StatelessWidget {
  /// 그 기간에서 지금 보고 있는 칸의 할 일.
  final List<PlanItem> Function(String horizon) itemsOf;
  final String selected;
  final ValueChanged<String> onSelect;
  const _HorizonChips(
      {required this.itemsOf, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final h in kPlanHorizons)
        Builder(builder: (_) {
          final mine = itemsOf(h);
          final done = mine.where((p) => p.done).length;
          final on = h == selected;
          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => onSelect(h),
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: on ? AppColors.gold : AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: on ? AppColors.gold : AppColors.border),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(h,
                    style: TextStyle(
                        color: on ? Colors.black : AppColors.textPrimary,
                        fontSize: AppFont.body,
                        fontWeight: FontWeight.w800)),
                if (mine.isNotEmpty) ...[
                  const Gap(6),
                  Text('$done/${mine.length}',
                      style: TextStyle(
                          color: on ? Colors.black54 : AppColors.textFaint,
                          fontSize: AppFont.caption,
                          fontWeight: FontWeight.w700)),
                ],
              ]),
            ),
          );
        }),
    ]);
  }
}

/// 고른 기간 — 위에 숫자 목표마다 «그걸 위한 할 일», 아래에 나머지 할 일을 갈래별로.
class _HorizonView extends ConsumerWidget {
  final String horizon;
  final List<PlanItem> goals;
  final List<PlanItem> items;

  /// 몇 주차·몇 개월차 — 앞뒤로 넘긴다.
  final Widget bar;

  /// 빈 칸일 때 앞 칸에서 가져올 것(안 끝난 할 일 + 숫자 목표).
  final List<PlanItem> carry;
  final VoidCallback onCarry;
  final Map<String, double?> now;
  final String? assetLine;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onAddFor;
  final ValueChanged<String?> onAddGoal;
  const _HorizonView({
    super.key,
    required this.horizon,
    required this.goals,
    required this.items,
    required this.bar,
    required this.carry,
    required this.onCarry,
    required this.now,
    this.assetLine,
    required this.onAdd,
    required this.onAddFor,
    required this.onAddGoal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = items.where((p) => p.done).length;
    final linked = items.where((p) => p.metric != null).toList();
    final loose = items.where((p) => p.metric == null).toList();
    final metrics = [
      for (final m in kPlanMetrics)
        if (goals.any((g) => g.metric == m) || linked.any((p) => p.metric == m))
          m,
    ];
    final tracks = [
      for (final t in kPlanTracks)
        if (loose.any((p) => p.track == t)) t,
      // 목록에 없는 갈래로 적은 것도 버리지 않는다.
      ...{for (final p in loose) if (!kPlanTracks.contains(p.track)) p.track},
    ];
    Widget row(PlanItem p, {bool tagged = false}) => _PlanRow(
          item: p,
          color: _trackColor(p.track),
          tag: tagged ? p.track : null,
          onToggle: () => _toggle(ref, p),
          onEdit: () => _edit(context, ref, p),
          onNote: () => _note(context, ref, p),
          onDelete: () => _delete(context, ref, p),
        );
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          bar,
          if (items.isNotEmpty) ...[
            const Gap(10),
            Row(children: [
              Expanded(
                child: ProgressBar(
                    value: done / items.length,
                    color: AppColors.gold,
                    height: 6),
              ),
              const Gap(10),
              Text('$done / ${items.length}',
                  style: const TextStyle(
                      color: AppColors.gold, fontWeight: FontWeight.w800)),
            ]),
          ],
          if (items.isEmpty && goals.isEmpty) ...[
            const EmptyState(
                icon: Icons.event_note_rounded,
                message: '이 칸에 적힌 계획이 없습니다'),
            if (carry.isNotEmpty)
              Center(
                child: FilledButton.tonalIcon(
                  onPressed: onCarry,
                  icon: const Icon(Icons.redo_rounded, size: 18),
                  label: Text(
                      '앞 칸에서 가져오기 — ${[
                        if (carry.any((p) => !p.isGoal))
                          '안 끝난 일 ${carry.where((p) => !p.isGoal).length}개',
                        if (carry.any((p) => p.isGoal))
                          '목표 ${carry.where((p) => p.isGoal).length}개',
                      ].join(' · ')}'),
                ),
              ),
          ],
          for (final m in metrics) ...[
            const Gap(20),
            _GoalHeader(
              metric: m,
              goal: goals.where((g) => g.metric == m).firstOrNull,
              now: now[m],
              note: m == '순자산' ? assetLine : null,
              onAdd: () => onAddFor(m),
              onSetGoal: () => onAddGoal(m),
            ),
            const Gap(4),
            for (final p in linked.where((p) => p.metric == m))
              row(p, tagged: true),
          ],
          if (metrics.length < kPlanMetrics.length)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => onAddGoal(null),
                icon: const Icon(Icons.flag_rounded, size: 18),
                label: const Text('숫자 목표 정하기'),
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary),
              ),
            ),
          for (final t in tracks) ...[
            const Gap(20),
            _TrackHeader(t, onAdd: () => onAdd(t)),
            const Gap(6),
            for (final p in loose.where((p) => p.track == t)) row(p),
          ],
        ],
      ),
    );
  }
}

/// 칸 넘기기 — «‹ 2주차 · 11/9 ~ 11/15 ›». 지금 칸이 아니면 «이번 주로».
class _PeriodBar extends StatelessWidget {
  final String name;
  final String range;
  final String nowWord;
  final bool isNow;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback onNow;
  const _PeriodBar({
    required this.name,
    required this.range,
    required this.nowWord,
    required this.isNow,
    required this.onPrev,
    required this.onNext,
    required this.onNow,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      IconButton(
        onPressed: onPrev,
        tooltip: '앞 칸',
        icon: const Icon(Icons.chevron_left_rounded),
      ),
      Expanded(
        child: Column(children: [
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text(name,
                  style: const TextStyle(
                      fontSize: AppFont.title, fontWeight: FontWeight.w800)),
              if (isNow)
                Pill(nowWord, color: AppColors.gold)
              else
                InkWell(
                  onTap: onNow,
                  borderRadius: BorderRadius.circular(20),
                  child: Pill('$nowWord로', color: AppColors.textSecondary),
                ),
            ],
          ),
          const Gap(2),
          Text(range,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: AppFont.label)),
        ]),
      ),
      IconButton(
        onPressed: onNext,
        tooltip: '다음 칸',
        icon: const Icon(Icons.chevron_right_rounded),
      ),
    ]);
  }
}

/// 숫자 목표 한 칸의 머리 — 목표 금액, 지금, 진행 막대. 아래에 그걸 위한 할 일이 붙는다.
class _GoalHeader extends ConsumerWidget {
  final String metric;
  final PlanItem? goal;
  final double? now;

  /// 지금 숫자 밑에 한 줄 더 — 순자산이면 자산 카드 분류별 합.
  final String? note;
  final VoidCallback onAdd;
  final VoidCallback onSetGoal;
  const _GoalHeader({
    required this.metric,
    required this.goal,
    required this.now,
    this.note,
    required this.onAdd,
    required this.onSetGoal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const c = AppColors.primary;
    final g = goal;
    final pct = g == null || now == null || g.target! <= 0
        ? null
        : now! / g.target!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                  color: c, borderRadius: BorderRadius.circular(2))),
          const Gap(8),
          Expanded(
            child: Text(metric,
                style: const TextStyle(
                    color: c,
                    fontSize: AppFont.section,
                    fontWeight: FontWeight.w800)),
          ),
          if (g != null)
            Text(_goalText(metric, g.target!),
                style: const TextStyle(
                    fontSize: AppFont.section, fontWeight: FontWeight.w900))
          else
            TextButton(
              onPressed: onSetGoal,
              style: TextButton.styleFrom(
                  foregroundColor: c, visualDensity: VisualDensity.compact),
              child: const Text('목표 정하기'),
            ),
          IconButton(
            onPressed: onAdd,
            tooltip: '$metric 할 일 추가',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add_rounded, color: c, size: 20),
          ),
          if (g != null)
            RecordMenu(
                onEdit: () => _editGoal(context, ref, g),
                onDelete: () => _deleteGoal(context, ref, g)),
        ]),
        if (pct != null)
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 8),
            child: Row(children: [
              Text(
                  '지금 ${Won.compact(now!)}'
                  '${pct >= 1 ? ' · 달성' : ' · ${(pct * 100).floor()}%'}',
                  style: TextStyle(
                      color: pct >= 1 ? c : AppColors.textSecondary,
                      fontSize: AppFont.caption,
                      fontWeight: FontWeight.w700)),
              const Gap(10),
              Expanded(child: ProgressBar(value: pct, color: c, height: 4)),
            ]),
          )
        // 목표가 없거나 0이어도 «지금»은 보인다 — 비어 보이면 없는 줄 안다.
        else if (now != null)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text('지금 ${Won.compact(now!)}',
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: AppFont.caption,
                    fontWeight: FontWeight.w700)),
          ),
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 3, right: 8),
            child: Text(note!,
                style: const TextStyle(
                    color: AppColors.textFaint,
                    fontSize: AppFont.caption,
                    height: 1.5)),
          ),
        if ((g?.detail ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 6, right: 8),
            child: Text(g!.detail!,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: AppFont.label,
                    height: 1.5)),
          ),
      ],
    );
  }
}

class _TrackHeader extends StatelessWidget {
  final String track;
  final VoidCallback onAdd;
  const _TrackHeader(this.track, {required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final c = _trackColor(track);
    return Row(children: [
      Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
              color: c, borderRadius: BorderRadius.circular(2))),
      const Gap(8),
      Text(track,
          style: TextStyle(
              color: c, fontSize: AppFont.section, fontWeight: FontWeight.w800)),
      const Spacer(),
      // 여행은 가고 싶은 곳을 «여행» 메뉴(지도)에 적는다.
      if (track == '여행')
        TextButton.icon(
          onPressed: () => context.go('/travel'),
          icon: const Icon(Icons.map_rounded, size: 18),
          label: const Text('가고 싶은 곳 지도'),
          style: TextButton.styleFrom(
              foregroundColor: c, visualDensity: VisualDensity.compact),
        ),
      IconButton(
        onPressed: onAdd,
        tooltip: '$track 할 일 추가',
        visualDensity: VisualDensity.compact,
        icon: Icon(Icons.add_rounded, color: c, size: 20),
      ),
    ]);
  }
}

class _PlanRow extends StatefulWidget {
  final PlanItem item;
  final Color color;

  /// 숫자 목표 밑에 붙을 때 — 어느 갈래 일인지 앞에 적는다.
  final String? tag;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onNote;
  final VoidCallback onDelete;
  const _PlanRow({
    required this.item,
    required this.color,
    this.tag,
    required this.onToggle,
    required this.onEdit,
    required this.onNote,
    required this.onDelete,
  });

  @override
  State<_PlanRow> createState() => _PlanRowState();
}

class _PlanRowState extends State<_PlanRow> {
  // 누르자마자 바꿔 보여 준다 — 다시 불러오기까지 1~2초 비어 보였다.
  bool? _pending;

  @override
  void didUpdateWidget(_PlanRow old) {
    super.didUpdateWidget(old);
    if (old.item.done != widget.item.done) _pending = null;
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item, color = widget.color, tag = widget.tag;
    final done = _pending ?? item.done;
    final meta = [
      if (item.dueDate != null) '기한 ${Dates.md(item.dueDate!)}',
      if (item.doneAt != null) '${Dates.md(item.doneAt!)} 완료',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        IconButton(
          onPressed: () {
            setState(() => _pending = !done);
            widget.onToggle();
          },
          tooltip: done ? '완료 취소' : '완료',
          visualDensity: VisualDensity.compact,
          icon: Icon(
              done
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: done ? color : AppColors.textFaint,
              size: 22),
        ),
        const Gap(4),
        Expanded(
          // 글자를 누르면 «적기» — 적으라는 할 일에 답을 단다.
          child: InkWell(
            onTap: widget.onNote,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
            padding: const EdgeInsets.only(top: 9, bottom: 4),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      style: TextStyle(
                          fontSize: AppFont.body,
                          fontWeight: FontWeight.w700,
                          color: done
                              ? AppColors.textFaint
                              : AppColors.textPrimary,
                          decoration:
                              done ? TextDecoration.lineThrough : null)),
                  if ((item.detail ?? '').isNotEmpty) ...[
                    const Gap(3),
                    Text(item.detail!,
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: AppFont.label,
                            height: 1.5)),
                  ],
                  // 내가 적은 것 — 있으면 보이고, 없으면 «적기» 한 줄.
                  const Gap(6),
                  if ((item.note ?? '').trim().isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border(left: BorderSide(color: color, width: 3)),
                      ),
                      child: Text(item.note!.trim(),
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: AppFont.label,
                              height: 1.5)),
                    )
                  else if (!done)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.edit_rounded, size: 13, color: color.withValues(alpha: 0.8)),
                      const Gap(4),
                      Text('적기',
                          style: TextStyle(
                              color: color.withValues(alpha: 0.9),
                              fontSize: AppFont.caption,
                              fontWeight: FontWeight.w700)),
                    ]),
                  if (tag != null || meta.isNotEmpty) ...[
                    const Gap(4),
                    Text.rich(
                        TextSpan(children: [
                          if (tag != null)
                            TextSpan(
                                text: tag,
                                style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.w800)),
                          if (tag != null && meta.isNotEmpty)
                            const TextSpan(text: ' · '),
                          TextSpan(text: meta),
                        ]),
                        style: TextStyle(
                            color: done ? color : AppColors.textFaint,
                            fontSize: AppFont.caption,
                            fontWeight: FontWeight.w600)),
                  ],
                ]),
          ),
          ),
        ),
        RecordMenu(onEdit: widget.onEdit, onDelete: widget.onDelete),
      ]),
    );
  }
}
