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

/// 목표 → 수정 창 초기값. 대시보드 목표 카드도 같이 쓴다.
Map<String, dynamic> goalToMap(Goal g) => {
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
      // 개별 목표가 먼저, 재무 로드맵은 맨 아래(10/22).
      children: [
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
            // 달성한 목표는 아래 «달성한 목표»로 따로 보관한다(10/20) —
            // 대시보드에서도 빠진다.
            final active = goals.where((g) => !g.achieved).toList();
            final achieved = goals.where((g) => g.achieved).toList()
              ..sort((a, b) => (b.achievedAt ?? DateTime(1900))
                  .compareTo(a.achievedAt ?? DateTime(1900)));
            final done = achieved.length;
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
                if (active.isEmpty)
                  const EmptyState(
                      icon: Icons.flag,
                      message: '진행 중인 목표를 모두 달성했어요 — 다음 목표를 추가해 보세요'),
                for (final g in active) ...[
                  _GoalCard(
                    goal: g,
                    onEdit: () => editBuiltinRecord(context, ref, goalsSpec,
                        initial: goalToMap(g), id: g.id),
                    onDelete: () => deleteBuiltinRecord(
                        context, ref, goalsSpec, g.id,
                        name: g.title),
                  ),
                  const Gap(12),
                ],
                if (achieved.isNotEmpty) ...[
                  const Gap(20),
                  SectionHeader('달성한 목표',
                      subtitle: '${achieved.length}개 · 최근 달성 순'),
                  const Gap(12),
                  GlassCard(
                    accent: AppColors.gold,
                    child: Column(children: [
                      for (var i = 0; i < achieved.length; i++) ...[
                        if (i > 0)
                          const Divider(height: 20, color: AppColors.border),
                        _AchievedRow(
                          goal: achieved[i],
                          onEdit: () => editBuiltinRecord(
                              context, ref, goalsSpec,
                              initial: goalToMap(achieved[i]),
                              id: achieved[i].id),
                          onDelete: () => deleteBuiltinRecord(
                              context, ref, goalsSpec, achieved[i].id,
                              name: achieved[i].title),
                        ),
                      ],
                    ]),
                  ),
                ],
              ],
            );
          },
        ),
        const Gap(28),
        const PlanRoadmap(),
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
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: _value),
                    // 건수 목표 — 목표일까지 하루에 몇 건(10/22).
                    if (goal.dailyPace != null)
                      TextSpan(
                          text: '  ·  ${goal.dailyPace}',
                          style: const TextStyle(
                              color: AppColors.gold,
                              fontWeight: FontWeight.w800)),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: AppFont.label),
                ),
              ),
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

/// 달성한 목표 한 줄 — 진행바 없이 «무엇을, 언제, 기한보다 얼마나 빨리».
class _AchievedRow extends StatelessWidget {
  final Goal goal;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _AchievedRow(
      {required this.goal, required this.onEdit, required this.onDelete});

  String get _value {
    if (goal.unit == 'KRW') return '${Won.compact(goal.currentValue)}원';
    if (goal.unit == 'count') return '${goal.currentValue.toStringAsFixed(0)}건';
    if (goal.unit == 'percent') return '${goal.currentValue.toStringAsFixed(0)}%';
    return goal.currentValue.toStringAsFixed(0);
  }

  /// 「기한보다 42일 먼저」 / 「기한 3일 넘김」 — 달성일·목표일이 다 있을 때만.
  String? get _pace {
    final a = goal.achievedAt, t = goal.targetDate;
    if (a == null || t == null) return null;
    final d = t.difference(a).inDays;
    if (d > 0) return '기한보다 $d일 먼저';
    if (d < 0) return '기한 ${-d}일 넘김';
    return '기한 당일';
  }

  @override
  Widget build(BuildContext context) {
    final a = goal.achievedAt;
    final meta = [
      _value,
      if (a != null) '${Dates.ymd(a)} 달성',
      ?_pace,
    ].join(' · ');
    return Row(children: [
      const Icon(Icons.emoji_events_rounded, color: AppColors.gold, size: 22),
      const Gap(12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(goal.title,
              style: const TextStyle(
                  fontSize: AppFont.body, fontWeight: FontWeight.w700)),
          const Gap(3),
          Text(meta,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: AppFont.caption)),
        ]),
      ),
      RecordMenu(onEdit: onEdit, onDelete: onDelete),
    ]);
  }
}
