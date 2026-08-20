import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../data/data_providers.dart';
import '../edit/field_spec.dart';
import '../edit/record_form.dart';
import '../format/formatters.dart';
import '../supabase/supabase_providers.dart';
import '../theme/app_theme.dart';
import '../../models/models.dart';
import 'common.dart';

/// 카테고리(shorts 등)의 월별 실적 추적 카드.
/// 전체(누적)·월별 탭 + 원하는 달 직접 입력.
class MonthlyTracker extends ConsumerStatefulWidget {
  final String category;
  final String title;
  final double target;
  final Color accent;

  const MonthlyTracker({
    super.key,
    required this.category,
    required this.title,
    required this.target,
    required this.accent,
  });

  @override
  ConsumerState<MonthlyTracker> createState() => _MonthlyTrackerState();
}

class _MonthlyTrackerState extends ConsumerState<MonthlyTracker> {
  DateTime? _month; // null = 전체

  /// 연도를 고르면 1~12월을 한 폼에서 한 번에 입력.
  Future<void> _inputYear() async {
    final entries =
        ref.read(monthlyEntriesProvider(widget.category)).asData?.value ?? [];
    final year = await pickYear(context, initial: _month?.year);
    if (year == null || !mounted) return;

    String mk(int m) => '$year-${m.toString().padLeft(2, '0')}';
    final fields = [
      for (var m = 1; m <= 12; m++)
        FieldSpec(key: mk(m), label: '$m월', type: FieldType.money),
    ];
    final initial = <String, dynamic>{};
    for (final e in entries) {
      if (e.month.year == year) initial[mk(e.month.month)] = e.amount;
    }
    final values = await showRecordForm(
      context,
      title: '${widget.title} · $year년 월별 (한 번에 입력)',
      accent: widget.accent,
      fields: fields,
      initial: initial,
    );
    if (values == null) return;

    final sb = ref.read(supabaseProvider);
    final uid = sb.auth.currentUser!.id;
    // 그 해 기존 항목(ref_id 없음) 삭제 후 채워진 달만 삽입.
    await sb
        .from('monthly_entries')
        .delete()
        .eq('category', widget.category)
        .isFilter('ref_id', null)
        .gte('month', '$year-01-01')
        .lte('month', '$year-12-01');
    final rows = <Map<String, dynamic>>[];
    for (var m = 1; m <= 12; m++) {
      final v = values[mk(m)];
      if (v == null) continue;
      rows.add({
        'user_id': uid,
        'category': widget.category,
        'month': '${mk(m)}-01',
        'amount': v,
      });
    }
    if (rows.isNotEmpty) await sb.from('monthly_entries').insert(rows);
    ref.invalidate(monthlyEntriesProvider(widget.category));
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    final async = ref.watch(monthlyEntriesProvider(widget.category));
    return GlassCard(
      accent: accent,
      child: async.when(
        loading: () => const SizedBox(
            height: 80, child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Text('불러오기 실패: $e'),
        data: (entries) {
          final months = [for (final e in entries) e.month]
            ..sort((a, b) => a.compareTo(b));
          final total = entries.fold(0.0, (s, e) => s + e.amount);
          MonthlyEntry? selected;
          if (_month != null) {
            for (final e in entries) {
              if (e.month.year == _month!.year &&
                  e.month.month == _month!.month) {
                selected = e;
              }
            }
          }
          final selectedAmount = selected?.amount ?? 0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: SectionHeader('${widget.title} 월별 추적')),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accent,
                      side: BorderSide(color: accent.withValues(alpha: 0.5)),
                    ),
                    onPressed: _inputYear,
                    icon: const Icon(Icons.edit_calendar_rounded, size: 16),
                    label: const Text('월별 입력'),
                  ),
                ],
              ),
              const Gap(14),
              // 전체 / 월별 탭
              if (months.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                      _Chip(
                        label: '전체',
                        color: accent,
                        selected: _month == null,
                        onTap: () => setState(() => _month = null),
                      ),
                      for (final m in months.reversed)
                        _Chip(
                          label: Dates.ym(m),
                          color: accent,
                          selected: _month != null &&
                              _month!.year == m.year &&
                              _month!.month == m.month,
                          onTap: () => setState(() => _month = m),
                        ),
                  ],
                ),
              const Gap(16),
              if (entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('“월 입력”으로 원하는 달의 순이익을 기록하세요',
                      style: TextStyle(color: AppColors.textFaint)),
                )
              else if (_month == null)
                _AllView(entries: entries, total: total, accent: accent,
                    onTapMonth: (m) => setState(() => _month = m))
              else
                _MonthView(month: _month!, amount: selectedAmount, accent: accent),
            ],
          );
        },
      ),
    );
  }
}

/// 전체(누적) 뷰 — 누적 총액 + 월별 막대(클릭).
class _AllView extends StatelessWidget {
  final List<MonthlyEntry> entries;
  final double total;
  final Color accent;
  final void Function(DateTime) onTapMonth;
  const _AllView(
      {required this.entries,
      required this.total,
      required this.accent,
      required this.onTapMonth});

  @override
  Widget build(BuildContext context) {
    final recent =
        entries.length > 10 ? entries.sublist(entries.length - 10) : entries;
    final maxV = recent.map((e) => e.amount).fold(1.0, (a, b) => a > b ? a : b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${Won.compact(total)}원',
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w900, color: accent)),
            const Gap(8),
            const Padding(
              padding: EdgeInsets.only(bottom: 3),
              child: Text('누적 순이익',
                  style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
            ),
          ],
        ),
        const Gap(16),
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final e in recent)
                Expanded(
                  child: InkWell(
                    onTap: () => onTapMonth(e.month),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${Won.compact(e.amount)}원',
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                          const Gap(5),
                          Container(
                            height: (e.amount / maxV * 74).clamp(4, 74),
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          const Gap(6),
                          Text(Dates.ym(e.month),
                              style: const TextStyle(
                                  color: AppColors.textFaint, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 특정 월 뷰 — 그 달 순이익 크게.
class _MonthView extends StatelessWidget {
  final DateTime month;
  final double amount;
  final Color accent;
  const _MonthView(
      {required this.month, required this.amount, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(Insets.radius),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${Dates.ym(month)} 순이익',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
          const Gap(6),
          Text('${Won.compact(amount)}원',
              style: TextStyle(
                  fontSize: 32, fontWeight: FontWeight.w900, color: accent)),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _Chip(
      {required this.label,
      required this.color,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? color : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(label,
                style: TextStyle(
                    color: selected ? Colors.white : AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ),
        ),
      ),
    );
  }
}
