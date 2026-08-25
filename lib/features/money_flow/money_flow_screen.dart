import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/data/data_providers.dart';
import '../../core/edit/builtin_crud.dart';
import '../../core/edit/field_spec.dart';
import '../../core/edit/record_form.dart';
import '../../core/format/formatters.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/module_page.dart';
import '../../models/models.dart';
import '../plan/plan_roadmap.dart';

/// 자금 흐름 — 날짜별 유입/지출 거래 장부 (에어비앤비 상세와 동일 구조).
/// 월 탭(전체+각 월) · 유입/지출/순흐름 · 월별 막대 · 거래 내역(추가/검색).
class MoneyFlowScreen extends ConsumerStatefulWidget {
  const MoneyFlowScreen({super.key});

  @override
  ConsumerState<MoneyFlowScreen> createState() => _MoneyFlowState();
}

class _MoneyFlowState extends ConsumerState<MoneyFlowScreen> {
  DateTime? _month; // null = 전체
  String _query = '';
  bool _unpaidOnly = false; // 아직 안 낸 지출만 보기

  static const _palette = [
    AppColors.primary, AppColors.sky, AppColors.gold, AppColors.rose,
    AppColors.violet, Color(0xFFB4844E), Color(0xFF34D399), Color(0xFFFB923C),
    Color(0xFFE879F9), Color(0xFF2DD4BF),
  ];

  static const _fields = [
    FieldSpec(key: 'entry_date', label: '날짜', type: FieldType.date, required: true),
    FieldSpec(key: 'direction', label: '유형', type: FieldType.select, required: true,
        options: ['들어오는 돈', '나가는 돈']),
    FieldSpec(key: 'label', label: '항목명 (월급·에어비앤비·연금저축 …)', type: FieldType.text, required: true),
    FieldSpec(key: 'amount', label: '금액', type: FieldType.money, required: true),
    FieldSpec(key: 'memo', label: '메모', type: FieldType.text),
  ];

  bool _inScope(FlowEntry e) =>
      _month == null || (e.date.year == _month!.year && e.date.month == _month!.month);

  Future<void> _addOrEdit({FlowEntry? entry}) async {
    final values = await showRecordForm(
      context,
      title: entry == null ? '거래 추가' : '거래 수정',
      fields: _fields,
      accent: AppColors.gold,
      initial: entry == null
          ? {
              'entry_date':
                  (_month ?? DateTime.now()).toIso8601String().substring(0, 10),
              'direction': '들어오는 돈',
            }
          : {
              'entry_date': entry.date.toIso8601String().substring(0, 10),
              'direction': entry.direction,
              'label': entry.label,
              'amount': entry.amount,
              'memo': entry.memo,
            },
    );
    if (values == null) return;
    final sb = ref.read(supabaseProvider);
    final clean = Map<String, dynamic>.from(values)
      ..removeWhere((k, v) => v == null);
    if (entry == null) {
      clean['user_id'] = sb.auth.currentUser!.id;
      await sb.from('flow_entries').insert(clean);
    } else {
      await sb.from('flow_entries').update(clean).eq('id', entry.id);
    }
    ref.invalidate(flowEntriesProvider);
  }

  /// 나가는 돈 — 실제로 냈는지 표시. 적어둔 것과 나간 것은 다르다.
  Future<void> _togglePaid(FlowEntry e) async {
    final now = !e.paid;
    try {
      await ref.read(supabaseProvider).from('flow_entries').update({
        'paid': now,
        'paid_at': now ? DateTime.now().toIso8601String() : null,
      }).eq('id', e.id);
    } catch (err) {
      // 체크가 조용히 안 먹으면 원인을 알 길이 없다 — 반드시 알린다.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패 — $err')),
      );
      return;
    }
    ref.invalidate(flowEntriesProvider);
  }

  Future<void> _delete(FlowEntry e) async {
    if (!await confirmDelete(context, name: '${e.label} ${Won.compact(e.amount)}원')) {
      return;
    }
    await ref.read(supabaseProvider).from('flow_entries').delete().eq('id', e.id);
    ref.invalidate(flowEntriesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(flowEntriesProvider);

    return ModulePage(
      title: '자금 흐름',
      icon: Icons.swap_horiz_rounded,
      color: AppColors.gold,
      children: [
        async.when(
          loading: AsyncStatus.loading,
          error: AsyncStatus.error,
          data: (all) {
            // 월 목록
            final monthSet = <String>{
              for (final e in all)
                DateTime(e.date.year, e.date.month).toIso8601String().substring(0, 10)
            };
            final months = monthSet.map(DateTime.parse).toList()..sort();

            final scope = all.where(_inScope).toList();
            // 자동 연동 라벨의 수동 입력은 숨김(자동값으로 대체) → 중복 방지.
            final manualIncome = scope
                .where((e) => e.isIn && !kAutoIncomeLabels.contains(e.label))
                .toList();
            final expense = scope.where((e) => !e.isIn).toList();

            // 들어오는 돈 = 수동(비모듈) + 자동(이번 달 모듈 수익, 0 제외).
            final autoIncome =
                ref.watch(moduleIncomeThisMonthProvider).value ?? const {};
            final incomeBy = <String, double>{};
            for (final e in manualIncome) {
              incomeBy[e.label] = (incomeBy[e.label] ?? 0) + e.amount;
            }
            autoIncome.forEach((k, v) {
              if (v > 0) incomeBy[k] = (incomeBy[k] ?? 0) + v;
            });
            final totalIn = incomeBy.values.fold(0.0, (s, v) => s + v);
            final totalOut = expense.fold(0.0, (s, e) => s + e.amount);

            List<_Slice> colorize(Map<String, double> by) {
              final out = <_Slice>[
                for (final entry in by.entries)
                  _Slice(entry.key, entry.value, Colors.white)
              ]..sort((a, b) => b.value.compareTo(a.value));
              for (var i = 0; i < out.length; i++) {
                out[i] =
                    _Slice(out[i].label, out[i].value, _palette[i % _palette.length]);
              }
              return out;
            }

            List<_Slice> slices(List<FlowEntry> list) {
              final by = <String, double>{};
              for (final e in list) {
                by[e.label] = (by[e.label] ?? 0) + e.amount;
              }
              return colorize(by);
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 월 탭
                if (months.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                        _MonthChip(
                          label: '전체',
                          selected: _month == null,
                          onTap: () => setState(() => _month = null),
                        ),
                        for (final m in months.reversed)
                          _MonthChip(
                            label: Dates.ym(m),
                            selected: _month != null &&
                                _month!.year == m.year &&
                                _month!.month == m.month,
                            onTap: () => setState(() => _month = m),
                          ),
                    ],
                  ),
                const Gap(16),
                // 도넛 2개 (크기 동일 · 순흐름은 제목 옆에)
                LayoutBuilder(builder: (context, c) {
                  final narrow = c.maxWidth < 720;
                  _DonutCard inD(bool st) => _DonutCard(
                      title: '들어오는 돈',
                      slices: colorize(incomeBy),
                      total: totalIn,
                      color: AppColors.gold,
                      emptyMsg: '유입 없음',
                      stacked: st);
                  _DonutCard outD(bool st) => _DonutCard(
                      title: '나가는 돈',
                      slices: slices(expense),
                      total: totalOut,
                      color: AppColors.sky,
                      emptyMsg: '지출 없음',
                      stacked: st);
                  if (narrow) {
                    // 좁은 화면: 카드 세로로 쌓기 (도넛 위·범례 아래).
                    return Column(children: [inD(true), const Gap(16), outD(true)]);
                  }
                  // 넓은 화면: 두 카드를 같은 높이(더 큰 쪽)로 맞춘다.
                  // 카드 안엔 LayoutBuilder 가 없으므로 IntrinsicHeight 안전.
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: inD(false)),
                        const Gap(16),
                        Expanded(child: outD(false)),
                      ],
                    ),
                  );
                }),
                // 아직 안 낸 지출 — 있을 때만.
                Builder(builder: (context) {
                  final unpaid = expense.where((e) => !e.paid).toList();
                  // 필터가 켜져 있으면 0건이어도 남긴다 — 끌 곳이 없어진다.
                  if (unpaid.isEmpty && !_unpaidOnly) return const Gap(16);
                  final sum = unpaid.fold(0.0, (s, e) => s + e.amount);
                  return Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _UnpaidBar(
                      count: unpaid.length,
                      amount: sum,
                      only: _unpaidOnly,
                      onToggle: () => setState(() => _unpaidOnly = !_unpaidOnly),
                    ),
                  );
                }),
                const Gap(16),
                // 나가는 돈 — 현재 단계 기본세팅(계획) vs 이번 달 실제
                const PhasePlanVsActual(),
                const Gap(16),
                // 월별 순흐름 막대 (전체일 때 · 클릭 가능)
                if (months.length > 1 && _month == null) ...[
                  _MonthlyFlowBars(
                    entries: all,
                    onTap: (m) => setState(() => _month = m),
                  ),
                  const Gap(16),
                ],
                // 거래 내역
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader('거래 내역',
                          subtitle: '${[...manualIncome, ...expense].length}건',
                          trailing: FilledButton.icon(
                            style: FilledButton.styleFrom(
                                backgroundColor: AppColors.gold,
                                foregroundColor: const Color(0xFF1B1400),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10)),
                            onPressed: () => _addOrEdit(),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('거래 추가'),
                          )),
                      const Gap(12),
                      TextField(
                        onChanged: (v) => setState(() => _query = v),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: '항목·메모로 검색 (예: 월급, 연금)',
                          prefixIcon: const Icon(Icons.search_rounded, size: 20),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 18),
                                  onPressed: () => setState(() => _query = ''),
                                ),
                        ),
                      ),
                      const Gap(4),
                      Builder(builder: (context) {
                        final q = _query.trim().toLowerCase();
                        // 날짜만으로 정렬하면 같은 날 항목끼리 순서가 매번
                        // 달라진다(Dart sort 는 안정 정렬이 아니다).
                        // 금액·id 까지 내려가 순서를 못박는다.
                        var ledger = [...manualIncome, ...expense]
                          ..sort((a, b) {
                            final d = b.date.compareTo(a.date);
                            if (d != 0) return d;
                            final m = b.amount.compareTo(a.amount);
                            return m != 0 ? m : a.id.compareTo(b.id);
                          });
                        if (_unpaidOnly) {
                          ledger = ledger.where((e) => e.unpaid).toList();
                        }
                        final shown = q.isEmpty
                            ? ledger
                            : ledger
                                .where((e) =>
                                    e.label.toLowerCase().contains(q) ||
                                    (e.memo ?? '').toLowerCase().contains(q))
                                .toList();
                        if (shown.isEmpty) {
                          return EmptyState(
                              icon: Icons.receipt_long_rounded,
                              message: _unpaidOnly
                                  ? '안 낸 지출이 없습니다'
                                  : _query.isEmpty
                                      ? '거래를 추가하세요'
                                      : "'$_query' 검색 결과 없음");
                        }
                        return Column(
                          children: [
                            for (final e in shown)
                              _EntryRow(
                                entry: e,
                                onEdit: () => _addOrEdit(entry: e),
                                onDelete: () => _delete(e),
                                onTogglePaid: () => _togglePaid(e),
                              ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Slice {
  final String label;
  final double value;
  final Color color;
  _Slice(this.label, this.value, this.color);
}

class _MonthChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _MonthChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? AppColors.gold : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(label,
                style: TextStyle(
                    color: selected ? const Color(0xFF1B1400) : AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: AppFont.label)),
          ),
        ),
      ),
    );
  }
}

class _DonutCard extends StatelessWidget {
  final String title;
  final List<_Slice> slices;
  final double total;
  final Color color;
  final String emptyMsg;
  final bool stacked; // 좁은 화면: 도넛 위·범례 아래

  const _DonutCard({
    required this.title,
    required this.slices,
    required this.total,
    required this.color,
    this.emptyMsg = '데이터 없음',
    this.stacked = false,
  });

  @override
  Widget build(BuildContext context) {
    final donut = SizedBox(
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
                  radius: 32,
                  showTitle: false,
                ),
            ],
          )),
          Text('${Won.compact(total)}원',
              style: const TextStyle(fontSize: AppFont.section, fontWeight: FontWeight.w900)),
        ],
      ),
    );
    final legend = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final s in slices)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                      color: s.color, borderRadius: BorderRadius.circular(3)),
                ),
                const Gap(10),
                Flexible(
                  child: Text(s.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: AppFont.body, fontWeight: FontWeight.w600)),
                ),
                const Gap(10),
                Text('${(s.value / total * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                        color: color, fontSize: AppFont.body, fontWeight: FontWeight.w800)),
                const Gap(10),
                Text('${Won.compact(s.value)}원',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: AppFont.body)),
              ],
            ),
          ),
      ],
    );

    Widget body;
    if (total <= 0) {
      body = SizedBox(
        height: 160,
        child: EmptyState(icon: Icons.donut_large_rounded, message: emptyMsg),
      );
    } else if (stacked) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [Center(child: donut), const Gap(16), legend],
      );
    } else {
      body = Row(children: [donut, const Gap(18), Expanded(child: legend)]);
    }

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title,
                  style: const TextStyle(fontSize: AppFont.section, fontWeight: FontWeight.w800)),
              const Spacer(),
              Text('${Won.compact(total)}원',
                  style: TextStyle(
                      fontSize: AppFont.section, fontWeight: FontWeight.w900, color: color)),
            ],
          ),
          const Gap(18),
          // 넓은 화면: 카드가 더 큰 쪽 높이로 늘어나므로, 남는 공간에서 도넛/범례를 세로 가운데로.
          // 모바일(stacked): 카드 높이가 내용에 맞으므로 Expanded 없이 그대로.
          if (stacked) body else Expanded(child: Center(child: body)),
        ],
      ),
    );
  }
}

/// 월별 순흐름 막대 (클릭 → 해당 월).
class _MonthlyFlowBars extends StatelessWidget {
  final List<FlowEntry> entries;
  final void Function(DateTime) onTap;
  const _MonthlyFlowBars({required this.entries, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final byMonth = <String, double>{};
    for (final e in entries) {
      final k = DateTime(e.date.year, e.date.month).toIso8601String().substring(0, 10);
      byMonth[k] = (byMonth[k] ?? 0) + e.signed;
    }
    final keys = byMonth.keys.toList()..sort();
    final recent = keys.length > 10 ? keys.sublist(keys.length - 10) : keys;
    final maxAbs =
        recent.map((k) => byMonth[k]!.abs()).fold(1.0, (a, b) => a > b ? a : b);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader('월별 순흐름', subtitle: '월을 눌러 상세 보기'),
          const Gap(18),
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final k in recent)
                  Expanded(
                    child: InkWell(
                      onTap: () => onTap(DateTime.parse(k)),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${byMonth[k]! >= 0 ? '+' : ''}${Won.compact(byMonth[k]!)}',
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: AppFont.caption,
                                    fontWeight: FontWeight.w700)),
                            const Gap(6),
                            Container(
                              height: (byMonth[k]!.abs() / maxAbs * 96).clamp(8, 96),
                              decoration: BoxDecoration(
                                color: byMonth[k]! >= 0
                                    ? AppColors.primary
                                    : AppColors.rose,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const Gap(8),
                            Text(Dates.ym(DateTime.parse(k)),
                                style: const TextStyle(
                                    color: AppColors.textFaint, fontSize: AppFont.caption)),
                          ],
                        ),
                      ),
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

/// 아직 안 낸 지출 요약. 「미납만 보기」로 목록을 좁힌다.
class _UnpaidBar extends StatelessWidget {
  final int count;
  final double amount;
  final bool only;
  final VoidCallback onToggle;
  const _UnpaidBar({
    required this.count,
    required this.amount,
    required this.only,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      accent: AppColors.rose,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.rose.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.schedule_send_rounded,
                size: 17, color: AppColors.rose),
          ),
          const Gap(11),
          const Expanded(
            child: Text('아직 안 낸 지출',
                style: TextStyle(
                    fontSize: AppFont.body,
                    fontWeight: FontWeight.w800,
                    color: AppColors.rose)),
          ),
          Text('$count건 · ${Won.compact(amount)}원',
              style: const TextStyle(
                  fontSize: AppFont.body, fontWeight: FontWeight.w900)),
          const Gap(10),
          TextButton(
            onPressed: onToggle,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: only ? AppColors.rose : AppColors.textSecondary,
            ),
            child: Text(only ? '전체 보기' : '미납만',
                style: const TextStyle(
                    fontSize: AppFont.label, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  final FlowEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// 나가는 돈에만 쓴다 — 입금 완료 토글.
  final VoidCallback onTogglePaid;

  const _EntryRow({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePaid,
  });

  @override
  Widget build(BuildContext context) {
    final isIn = entry.isIn;
    final color = isIn ? AppColors.gold : AppColors.sky;
    // 낸 것은 한 톤 죽인다 — 남은 것(미납)이 눈에 먼저 들어와야 한다.
    final done = !isIn && entry.paid;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(Dates.md(entry.date),
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: AppFont.label)),
          ),
          const Gap(8),
          if (isIn) ...[
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const Gap(10),
          ] else
            // 나가는 돈 — 실제로 냈는지 체크
            Tooltip(
              message: entry.paid ? '입금 완료 (눌러서 취소)' : '입금했으면 체크',
              child: SizedBox(
                width: 34,
                height: 34,
                child: Checkbox(
                  value: entry.paid,
                  onChanged: (_) => onTogglePaid(),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  activeColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.border, width: 1.6),
                ),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: AppFont.body,
                        color: done
                            ? AppColors.textSecondary
                            : AppColors.textPrimary)),
                if (entry.memo?.isNotEmpty == true) ...[
                  const Gap(2),
                  Text(entry.memo!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textFaint, fontSize: AppFont.caption)),
                ],
              ],
            ),
          ),
          if (entry.unpaid) ...[
            const Pill('미납', color: AppColors.rose),
            const Gap(8),
          ],
          Text('${isIn ? '+' : '-'}${Won.compact(entry.amount)}원',
              style: TextStyle(
                  color: isIn
                      ? AppColors.primary
                      : (done ? AppColors.textFaint : AppColors.rose),
                  fontWeight: FontWeight.w800,
                  fontSize: AppFont.body)),
          RecordMenu(onEdit: onEdit, onDelete: onDelete),
        ],
      ),
    );
  }
}
