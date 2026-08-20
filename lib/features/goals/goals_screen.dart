import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/data/data_providers.dart';
import '../../core/edit/builtin_crud.dart';
import '../../core/edit/builtin_specs.dart';
import '../../core/format/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/module_page.dart';
import '../../models/models.dart';
import '../plan/plan_roadmap.dart';

Map<String, dynamic> _goalToMap(Goal g) => {
      'title': g.title,
      'unit': g.unit,
      'target_value': g.targetValue,
      'current_value': g.currentValue,
      'target_date': g.targetDate?.toIso8601String().substring(0, 10),
      'status': g.status,
    };

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(goalsProvider);
    void add() => editBuiltinRecord(context, ref, goalsSpec);
    return ModulePage(
      title: 'Goals',
      icon: Icons.flag_rounded,
      color: AppColors.violet,
      action: AddButton(color: AppColors.violet, onTap: add),
      // 로드맵이 길어서 맨 위까지 올라가지 않아도 목표를 추가할 수 있게.
      fab: FloatingActionButton(
        onPressed: add,
        backgroundColor: AppColors.violet,
        foregroundColor: Colors.white,
        tooltip: '개별 목표 추가',
        child: const Icon(Icons.add_rounded),
      ),
      children: [
        const PlanRoadmap(),
        const Gap(28),
        SectionHeader(
          '개별 목표',
          trailing: TextButton.icon(
            onPressed: add,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.violet,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('목표 추가',
                style: TextStyle(
                    fontSize: AppFont.label, fontWeight: FontWeight.w700)),
          ),
        ),
        const Gap(14),
        async.when(
          loading: AsyncStatus.loading,
          error: AsyncStatus.error,
          data: (goals) {
            if (goals.isEmpty) {
              return const EmptyState(icon: Icons.flag, message: '등록된 목표가 없습니다');
            }
            final done = goals.where((g) => g.progress >= 1).length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GlassCard(
                  accent: AppColors.violet,
                  child: Row(
                    children: [
                      const Icon(Icons.emoji_events_rounded,
                          color: AppColors.violet, size: 28),
                      const Gap(14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$done / ${goals.length} 목표 달성',
                                style: const TextStyle(
                                    fontSize: AppFont.section,
                                    fontWeight: FontWeight.w800)),
                            const Gap(4),
                            const Text('경제적 자유까지의 마일스톤',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: AppFont.label)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Gap(16),
                for (final g in goals) ...[
                  _GoalCard(
                    goal: g,
                    onEdit: () => editBuiltinRecord(context, ref, goalsSpec,
                        initial: _goalToMap(g), id: g.id),
                    onDelete: () => deleteBuiltinRecord(
                        context, ref, goalsSpec, g.id,
                        name: g.title),
                  ),
                  const Gap(12),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _GoalCard extends StatelessWidget {
  final Goal goal;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _GoalCard(
      {required this.goal, required this.onEdit, required this.onDelete});

  String get _value {
    if (goal.unit == 'KRW') {
      return '${Won.compact(goal.currentValue)} / ${Won.compact(goal.targetValue)}원';
    }
    if (goal.unit == 'count') {
      return '${goal.currentValue.toStringAsFixed(0)} / ${goal.targetValue.toStringAsFixed(0)}건';
    }
    return '${goal.currentValue.toStringAsFixed(0)} / ${goal.targetValue.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final complete = goal.progress >= 1;
    final color = complete ? AppColors.primary : AppColors.violet;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(complete ? Icons.check_circle_rounded : Icons.flag_rounded,
                  color: color, size: 20),
              const Gap(10),
              Expanded(
                child: Text(goal.title,
                    style: const TextStyle(
                        fontSize: AppFont.section, fontWeight: FontWeight.w700)),
              ),
              if (goal.targetDate != null)
                Pill(Dates.dday(goal.targetDate!),
                    color: complete ? AppColors.primary : AppColors.textFaint),
              RecordMenu(onEdit: onEdit, onDelete: onDelete),
            ],
          ),
          const Gap(14),
          ProgressBar(value: goal.progress, color: color),
          const Gap(8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_value,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: AppFont.label)),
              Text('${(goal.progress * 100).toStringAsFixed(0)}%',
                  style:
                      TextStyle(color: color, fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }
}
