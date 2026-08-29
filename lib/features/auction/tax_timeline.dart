import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/data/data_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../models/models.dart';

/// 부동산 세제·규제 일자별 타임라인 — DB(tax_events)에서 읽는다.
const _teal = Color(0xFF14B8A6);
Color _kindColor(String k) => k == '정비' ? _teal : AppColors.violet;

class TaxTimeline extends ConsumerStatefulWidget {
  const TaxTimeline({super.key});

  @override
  ConsumerState<TaxTimeline> createState() => _TaxTimelineState();
}

class _TaxTimelineState extends ConsumerState<TaxTimeline> {
  String _filter = 'all'; // all | 세제 | 정비

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(taxEventsProvider);
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('부동산 세제·규제 타임라인',
            style:
                TextStyle(fontSize: AppFont.title, fontWeight: FontWeight.w800)),
        const Gap(2),
        const Text('시행일 기준 · 2026 세제개편은 8.3 발표안(국회 통과 전 → 변동 가능)',
            style:
                TextStyle(fontSize: AppFont.caption, color: AppColors.textFaint)),
        const Gap(14),
        async.when(
          loading: AsyncStatus.loading,
          error: AsyncStatus.error,
          data: (list) {
            if (list.isEmpty) {
              return const EmptyState(
                  icon: Icons.receipt_long_rounded,
                  message: '등록된 세제 항목이 없어요.\n(마이그레이션 0038 실행 필요)');
            }
            final taxN = list.where((e) => e.kind != '정비').length;
            final fixN = list.where((e) => e.kind == '정비').length;
            final filtered = [
              for (final e in list)
                if (_filter == 'all' ||
                    (_filter == '정비' ? e.kind == '정비' : e.kind != '정비'))
                  e
            ]..sort((a, b) => a.date.compareTo(b.date));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _filterBar(list.length, taxN, fixN),
                const Gap(14),
                if (filtered.isEmpty)
                  const EmptyState(
                      icon: Icons.filter_alt_off_rounded, message: '해당 항목이 없어요.')
                else
                  for (var i = 0; i < filtered.length; i++)
                    _row(filtered[i], now,
                        first: i == 0, last: i == filtered.length - 1),
              ],
            );
          },
        ),
        const Gap(10),
        _legend(),
        const Gap(8),
        const Text(
          '※ 확정 아님(개편안)은 원문(기재부 보도자료)·세무사로 재확인. 규제지역 지정/해제·대출 규제는 자료실 참조.',
          style: TextStyle(
              fontSize: AppFont.caption, color: AppColors.textFaint, height: 1.5),
        ),
      ],
    );
  }

  Widget _filterBar(int all, int taxN, int fixN) => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          _tab('all', '전체 $all', AppColors.gold),
          _tab('세제', '세제 $taxN', AppColors.violet),
          _tab('정비', '정비 $fixN', _teal),
        ],
      );

  Widget _tab(String key, String label, Color c) {
    final selected = _filter == key;
    return InkWell(
      onTap: () => setState(() => _filter = key),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.18) : Colors.transparent,
          border: Border.all(
              color: selected ? c : AppColors.border, width: selected ? 1.4 : 1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? c : AppColors.textSecondary,
                fontSize: AppFont.label,
                fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _row(TaxEvent it, DateTime now,
      {required bool first, required bool last}) {
    final future = it.date.isAfter(now);
    final dday =
        it.date.difference(DateTime(now.year, now.month, now.day)).inDays;
    final c = _kindColor(it.kind);
    final nodeColor = future ? c : AppColors.textFaint;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            child: Column(
              children: [
                Container(
                    width: 2,
                    height: 6,
                    color: first ? Colors.transparent : AppColors.border),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: future ? c : AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: nodeColor, width: 2),
                  ),
                ),
                Expanded(
                  child: Container(
                      width: 2,
                      color: last ? Colors.transparent : AppColors.border),
                ),
              ],
            ),
          ),
          const Gap(12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(
                accent: future ? c : null,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(
                          '${it.date.year}.${it.date.month.toString().padLeft(2, '0')}.${it.date.day.toString().padLeft(2, '0')}',
                          style: TextStyle(
                              fontSize: AppFont.label,
                              fontWeight: FontWeight.w800,
                              color: future ? c : AppColors.textSecondary)),
                      const Gap(8),
                      Pill(it.kind, color: c),
                      if (it.pending) ...[
                        const Gap(6),
                        const Pill('개편안', color: AppColors.gold),
                      ],
                      const Spacer(),
                      Text(
                          future ? (dday == 0 ? '오늘' : 'D-$dday') : '시행',
                          style: TextStyle(
                              fontSize: AppFont.caption,
                              fontWeight: FontWeight.w700,
                              color: future
                                  ? (dday <= 60 ? AppColors.rose : c)
                                  : AppColors.textFaint)),
                    ]),
                    const Gap(6),
                    Text(it.title,
                        style: const TextStyle(
                            fontSize: AppFont.section,
                            fontWeight: FontWeight.w800,
                            height: 1.35)),
                    if ((it.description ?? '').isNotEmpty) ...[
                      const Gap(4),
                      Text(it.description!,
                          style: const TextStyle(
                              fontSize: AppFont.body,
                              color: AppColors.textSecondary,
                              height: 1.5)),
                    ],
                    if ((it.source ?? '').isNotEmpty) ...[
                      const Gap(6),
                      Text('출처: ${it.source}',
                          style: const TextStyle(
                              fontSize: AppFont.caption,
                              color: AppColors.textFaint)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend() => Wrap(spacing: 14, runSpacing: 6, children: [
        _dot(_teal, '정비(모아타운·규제완화)'),
        _dot(AppColors.violet, '세제'),
        _dot(AppColors.gold, '개편안(국회 전)'),
      ]);

  Widget _dot(Color c, String label) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const Gap(6),
        Text(label,
            style: const TextStyle(
                fontSize: AppFont.caption, color: AppColors.textFaint)),
      ]);
}
