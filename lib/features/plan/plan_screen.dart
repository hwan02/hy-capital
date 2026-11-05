import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/data/data_providers.dart';
import '../../core/edit/builtin_crud.dart';
import '../../core/edit/builtin_specs.dart';
import '../../core/format/formatters.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/module_page.dart';
import '../../models/models.dart';
import 'plan_roadmap.dart';

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

Map<String, dynamic> _toMap(PlanItem p) => {
      'title': p.title,
      'horizon': p.horizon,
      'track': p.track,
      'detail': p.detail,
      'due_date': p.dueDate?.toIso8601String().substring(0, 10),
    };

/// 계획 — 맨 위 10년 비전, 그 아래 기간(10년~1주)을 골라 갈래별 할 일,
/// 맨 아래 재무 로드맵(Goals 에서 옮겨 왔다).
class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key});

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
  // 처음엔 «이번 주» — 들어와서 바로 할 일을 본다.
  String _horizon = '1주';

  void _add({String? track}) => editBuiltinRecord(context, ref, planItemSpec,
      initial: {'horizon': _horizon, 'track': track ?? '경공매'});

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
          data: (items) {
            if (items.isEmpty) {
              return const EmptyState(
                  icon: Icons.route_rounded, message: '아직 계획이 없습니다');
            }
            final visions = items.where((p) => p.track == '비전').toList();
            final rest = items.where((p) => p.track != '비전').toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (visions.isNotEmpty) ...[
                  _VisionCard(visions),
                  const Gap(24),
                ],
                const SectionHeader('기간별 계획',
                    subtitle: '10년 → 1주로 쪼갠 할 일 · 동그라미를 누르면 완료'),
                const Gap(12),
                _HorizonChips(
                  items: rest,
                  selected: _horizon,
                  onSelect: (h) => setState(() => _horizon = h),
                ),
                const Gap(14),
                _HorizonView(
                  horizon: _horizon,
                  items: rest.where((p) => p.horizon == _horizon).toList(),
                  onAdd: (t) => _add(track: t),
                ),
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

Future<void> _toggle(WidgetRef ref, PlanItem p) async {
  // 완료일은 여기서 — DB current_date 는 UTC 라 한국 아침엔 하루 전으로 찍혔다.
  final today = DateTime.now().toIso8601String().substring(0, 10);
  await ref.read(supabaseProvider).from('plan_items').update({
    'done': !p.done,
    'done_at': p.done ? null : today,
  }).eq('id', p.id);
  ref.invalidate(planItemsProvider);
}

void _edit(BuildContext c, WidgetRef ref, PlanItem p) =>
    editBuiltinRecord(c, ref, planItemSpec, initial: _toMap(p), id: p.id);

void _delete(BuildContext c, WidgetRef ref, PlanItem p) =>
    deleteBuiltinRecord(c, ref, planItemSpec, p.id, name: p.title);

/// 10년 비전 — 큰 목표 몇 개를 크게.
class _VisionCard extends ConsumerWidget {
  final List<PlanItem> visions;
  const _VisionCard(this.visions);

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

/// 기간 고르기 — 가로 스크롤 대신 Wrap. 칩마다 «완료/전체».
class _HorizonChips extends StatelessWidget {
  final List<PlanItem> items;
  final String selected;
  final ValueChanged<String> onSelect;
  const _HorizonChips(
      {required this.items, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final h in kPlanHorizons)
        Builder(builder: (_) {
          final mine = items.where((p) => p.horizon == h);
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

/// 고른 기간의 할 일 — 갈래별로 묶고, 기한과 진행률을 위에.
class _HorizonView extends ConsumerWidget {
  final String horizon;
  final List<PlanItem> items;
  final ValueChanged<String> onAdd;
  const _HorizonView(
      {required this.horizon, required this.items, required this.onAdd});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = items.where((p) => p.done).length;
    final due = items.map((p) => p.dueDate).whereType<DateTime>().fold<DateTime?>(
        null, (a, b) => a == null || b.isAfter(a) ? b : a);
    final tracks = [
      for (final t in kPlanTracks)
        if (items.any((p) => p.track == t)) t,
      // 목록에 없는 갈래로 적은 것도 버리지 않는다.
      ...{for (final p in items) if (!kPlanTracks.contains(p.track)) p.track},
    ];
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Text('$horizon 계획',
                style: const TextStyle(
                    fontSize: AppFont.title, fontWeight: FontWeight.w800)),
            const Gap(10),
            if (due != null)
              Text('${Dates.ymd(due)}까지 · ${Dates.dday(due)}',
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: AppFont.label)),
            const Spacer(),
            if (items.isNotEmpty)
              Text('$done / ${items.length}',
                  style: const TextStyle(
                      color: AppColors.gold, fontWeight: FontWeight.w800)),
          ]),
          if (items.isNotEmpty) ...[
            const Gap(10),
            ProgressBar(
                value: done / items.length, color: AppColors.gold, height: 6),
          ],
          if (items.isEmpty)
            const EmptyState(
                icon: Icons.event_note_rounded, message: '이 기간에 적힌 할 일이 없습니다'),
          for (final t in tracks) ...[
            const Gap(20),
            _TrackHeader(t, onAdd: () => onAdd(t)),
            const Gap(6),
            for (final p in items.where((p) => p.track == t))
              _PlanRow(
                item: p,
                color: _trackColor(t),
                onToggle: () => _toggle(ref, p),
                onEdit: () => _edit(context, ref, p),
                onDelete: () => _delete(context, ref, p),
              ),
          ],
        ],
      ),
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
      IconButton(
        onPressed: onAdd,
        tooltip: '$track 할 일 추가',
        visualDensity: VisualDensity.compact,
        icon: Icon(Icons.add_rounded, color: c, size: 20),
      ),
    ]);
  }
}

class _PlanRow extends StatelessWidget {
  final PlanItem item;
  final Color color;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _PlanRow({
    required this.item,
    required this.color,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final done = item.done;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        IconButton(
          onPressed: onToggle,
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
          child: Padding(
            padding: const EdgeInsets.only(top: 9),
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
                  if (item.dueDate != null || item.doneAt != null) ...[
                    const Gap(4),
                    Text(
                        [
                          if (item.dueDate != null)
                            '기한 ${Dates.md(item.dueDate!)}',
                          if (item.doneAt != null)
                            '${Dates.md(item.doneAt!)} 완료',
                        ].join(' · '),
                        style: TextStyle(
                            color: done ? color : AppColors.textFaint,
                            fontSize: AppFont.caption,
                            fontWeight: FontWeight.w600)),
                  ],
                ]),
          ),
        ),
        RecordMenu(onEdit: onEdit, onDelete: onDelete),
      ]),
    );
  }
}
