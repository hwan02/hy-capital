// Shorts 달력 — 「오늘 뭘 올려야 하나」에 먼저 답한다.
//
// 편성표(shortsSlots)는 8/21~9/30 콘텐츠 계획이고, tasks(module='shorts')는
// 그때그때 추가하는 할 일이다. 둘 다 «날짜»를 갖고 있으므로 한 달력에 얹는다.
//
// 완료 표시는 tasks 에 남긴다 — 편성표를 위한 새 테이블을 만들지 않고,
// 체크하면 그 날짜의 할 일로 기록되어 대시보드에도 함께 잡힌다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/data/data_providers.dart';
import '../../core/edit/builtin_crud.dart';
import '../../core/edit/builtin_specs.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../models/models.dart';
import 'shorts_schedule.dart' show shortsCats;

const _rose = AppColors.rose;

DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);
bool _same(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class ShortsCalendar extends ConsumerStatefulWidget {
  const ShortsCalendar({super.key});

  @override
  ConsumerState<ShortsCalendar> createState() => _ShortsCalendarState();
}

class _ShortsCalendarState extends ConsumerState<ShortsCalendar> {
  late DateTime _month;
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selected = _dayOf(now);
    _month = DateTime(now.year, now.month);
  }

  Future<void> _toggleSlot(ShortsSlotRow s) async {
    try {
      await ref
          .read(supabaseProvider)
          .from('shorts_slots')
          .update({'done': !s.done}).eq('id', s.id);
      invalidateAll(ref);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('저장 실패: $e'), backgroundColor: AppColors.rose));
    }
  }

  Map<String, dynamic> _slotToMap(ShortsSlotRow s) => {
        'title': s.title,
        'slot_date': s.slotDate.toIso8601String().substring(0, 10),
        'cat': s.cat,
        'hook': s.hook,
        'src': s.src,
        'url': s.url,
        'prio': s.prio,
        'done': s.done,
        'memo': s.memo,
      };

  Future<void> _toggleTask(TodoTask t) async {
    try {
      await ref
          .read(supabaseProvider)
          .from('tasks')
          .update({'done': !t.done}).eq('id', t.id);
      invalidateAll(ref);
    } catch (_) {}
  }

  Future<void> _open(String url) async {
    if (url.isEmpty) return;
    await launchUrl(Uri.parse(url),
        mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(shortsSlotsProvider);
    return async.when(
      loading: AsyncStatus.loading,
      error: AsyncStatus.error,
      data: (slots) {
        final tasks = (ref.watch(tasksProvider).asData?.value ?? const <TodoTask>[])
            .where((t) => t.module == 'shorts' && t.dueDate != null)
            .toList();

        final slotsByDay = <DateTime, List<ShortsSlotRow>>{};
        for (final s in slots) {
          slotsByDay.putIfAbsent(_dayOf(s.slotDate), () => []).add(s);
        }
        final tasksByDay = <DateTime, List<TodoTask>>{};
        for (final t in tasks) {
          tasksByDay.putIfAbsent(_dayOf(t.dueDate!), () => []).add(t);
        }

        final today = _dayOf(DateTime.now());
        final todaySlots = slotsByDay[today] ?? const <ShortsSlotRow>[];
        final pickedSlots = slotsByDay[_selected] ?? const <ShortsSlotRow>[];
        final pickedTasks = tasksByDay[_selected] ?? const <TodoTask>[];
        final overdue = [
          for (final s in slots)
            if (!s.done && _dayOf(s.slotDate).isBefore(today)) s
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 오늘 — 달력보다 먼저 답한다
            GlassCard(
              accent: _rose,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    const Text('오늘 올릴 것',
                        style: TextStyle(
                            fontSize: AppFont.section,
                            fontWeight: FontWeight.w800)),
                    const Gap(8),
                    Text('${today.month}월 ${today.day}일',
                        style: const TextStyle(
                            color: AppColors.textFaint,
                            fontSize: AppFont.caption)),
                    const Spacer(),
                    if (overdue.isNotEmpty)
                      Pill('밀린 것 ${overdue.length}', color: AppColors.gold),
                  ]),
                  const Gap(10),
                  if (todaySlots.isEmpty)
                    const Text('오늘 편성이 없어요. 달력에서 날짜를 골라 확인하세요.',
                        style: TextStyle(
                            color: AppColors.textFaint,
                            fontSize: AppFont.label))
                  else
                    for (final s in todaySlots)
                      _SlotTile(
                        slot: s,
                        onToggle: () => _toggleSlot(s),
                        onOpen: () => _open(s.url ?? ''),
                        onEdit: () => editBuiltinRecord(
                            context, ref, shortsSlotSpec,
                            initial: _slotToMap(s), id: s.id),
                        onDelete: () => deleteBuiltinRecord(
                            context, ref, shortsSlotSpec, s.id,
                            name: s.title),
                      ),
                ],
              ),
            ),
            const Gap(14),

            // 달력
            GlassCard(
              child: Column(children: [
                Row(children: [
                  IconButton(
                    onPressed: () => setState(() =>
                        _month = DateTime(_month.year, _month.month - 1)),
                    icon: const Icon(Icons.chevron_left_rounded, size: 20),
                    visualDensity: VisualDensity.compact,
                  ),
                  Expanded(
                    child: Text('${_month.year}년 ${_month.month}월',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: AppFont.section,
                            fontWeight: FontWeight.w800)),
                  ),
                  IconButton(
                    onPressed: () => setState(() =>
                        _month = DateTime(_month.year, _month.month + 1)),
                    icon: const Icon(Icons.chevron_right_rounded, size: 20),
                    visualDensity: VisualDensity.compact,
                  ),
                ]),
                const Gap(6),
                _Grid(
                  month: _month,
                  selected: _selected,
                  today: today,
                  slotsByDay: slotsByDay,
                  tasksByDay: tasksByDay,
                  onPick: (d) => setState(() => _selected = d),
                ),
                const Gap(8),
                const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _Legend(color: _rose, label: '할 것'),
                  Gap(14),
                  _Legend(color: AppColors.primary, label: '완료'),
                  Gap(14),
                  _Legend(color: AppColors.gold, label: '추가한 할 일'),
                ]),
              ]),
            ),
            const Gap(14),

            // 고른 날
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Text(
                        _same(_selected, today)
                            ? '오늘'
                            : '${_selected.month}월 ${_selected.day}일',
                        style: const TextStyle(
                            fontSize: AppFont.section,
                            fontWeight: FontWeight.w800)),
                    const Gap(8),
                    Text('${pickedSlots.length + pickedTasks.length}건',
                        style: const TextStyle(
                            color: AppColors.textFaint,
                            fontSize: AppFont.caption)),
                    const Spacer(),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _rose,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 9),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: const TextStyle(
                            fontSize: AppFont.label,
                            fontWeight: FontWeight.w800),
                      ),
                      onPressed: () => editBuiltinRecord(
                          context, ref, shortsSlotSpec,
                          initial: {
                            'slot_date':
                                _selected.toIso8601String().substring(0, 10),
                            'cat': 'fire',
                            'prio': '4',
                          }),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('편성'),
                    ),
                  ]),
                  const Gap(10),
                  if (pickedSlots.isEmpty && pickedTasks.isEmpty)
                    const Text('이 날은 비어 있어요.',
                        style: TextStyle(
                            color: AppColors.textFaint,
                            fontSize: AppFont.label))
                  else ...[
                    for (final s in pickedSlots)
                      _SlotTile(
                        slot: s,
                        onToggle: () => _toggleSlot(s),
                        onOpen: () => _open(s.url ?? ''),
                        onEdit: () => editBuiltinRecord(
                            context, ref, shortsSlotSpec,
                            initial: _slotToMap(s), id: s.id),
                        onDelete: () => deleteBuiltinRecord(
                            context, ref, shortsSlotSpec, s.id,
                            name: s.title),
                      ),
                    for (final t in pickedTasks) _taskRow(t),
                  ],
                ],
              ),
            ),

            if (overdue.isNotEmpty) ...[
              const Gap(14),
              GlassCard(
                accent: AppColors.gold,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      const Icon(Icons.history_rounded,
                          size: 16, color: AppColors.gold),
                      const Gap(8),
                      const Text('밀린 것',
                          style: TextStyle(
                              fontSize: AppFont.section,
                              fontWeight: FontWeight.w800)),
                      const Gap(8),
                      Text('${overdue.length}건',
                          style: const TextStyle(
                              color: AppColors.textFaint,
                              fontSize: AppFont.caption)),
                    ]),
                    const Gap(8),
                    for (final s in overdue)
                      _SlotTile(
                        slot: s,
                        onToggle: () => _toggleSlot(s),
                        onOpen: () => _open(s.url ?? ''),
                        onEdit: () => editBuiltinRecord(
                            context, ref, shortsSlotSpec,
                            initial: _slotToMap(s), id: s.id),
                        onDelete: () => deleteBuiltinRecord(
                            context, ref, shortsSlotSpec, s.id,
                            name: s.title),
                        showDate: true,
                      ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _taskRow(TodoTask t, {bool showDate = false}) => InkWell(
        onTap: () => _toggleTask(t),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: t.done
                    ? AppColors.gold.withValues(alpha: 0.16)
                    : Colors.transparent,
                border: Border.all(
                    color: t.done ? AppColors.gold : AppColors.border,
                    width: 1.6),
                borderRadius: BorderRadius.circular(6),
              ),
              child: t.done
                  ? const Icon(Icons.check_rounded,
                      size: 13, color: AppColors.gold)
                  : null,
            ),
            const Gap(10),
            Expanded(
              child: Text(t.title,
                  style: TextStyle(
                      fontSize: AppFont.label,
                      height: 1.45,
                      color:
                          t.done ? AppColors.textFaint : AppColors.textPrimary,
                      decoration: t.done ? TextDecoration.lineThrough : null,
                      decorationColor: AppColors.textFaint)),
            ),
            if (showDate && t.dueDate != null) ...[
              const Gap(8),
              Text('${t.dueDate!.month}/${t.dueDate!.day}',
                  style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: AppFont.caption,
                      fontWeight: FontWeight.w800)),
            ],
          ]),
        ),
      );
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(3))),
          const Gap(5),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textFaint, fontSize: AppFont.micro)),
        ],
      );
}

/// 편성 한 칸 — 제목·훅·출처. 누르면 수정, 체크하면 «올림».
class _SlotTile extends StatelessWidget {
  final ShortsSlotRow slot;
  final VoidCallback onToggle;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool showDate;
  const _SlotTile({
    required this.slot,
    required this.onToggle,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    this.showDate = false,
  });

  @override
  Widget build(BuildContext context) {
    final cat = shortsCats[slot.cat];
    final c = cat?.color ?? AppColors.textFaint;
    final done = slot.done;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: done
                  ? AppColors.primary.withValues(alpha: 0.16)
                  : Colors.transparent,
              border: Border.all(
                  color: done ? AppColors.primary : AppColors.border,
                  width: 1.6),
              borderRadius: BorderRadius.circular(6),
            ),
            child: done
                ? const Icon(Icons.check_rounded,
                    size: 14, color: AppColors.primary)
                : null,
          ),
        ),
        const Gap(10),
        Expanded(
          child: InkWell(
            onTap: onEdit,
            borderRadius: BorderRadius.circular(8),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    if (cat != null) ...[
                      Text(cat.emoji,
                          style: const TextStyle(fontSize: AppFont.caption)),
                      const Gap(5),
                      Text(cat.label,
                          style: TextStyle(
                              color: c,
                              fontSize: AppFont.micro,
                              fontWeight: FontWeight.w800)),
                      const Gap(8),
                    ],
                    if (slot.isTop) const Pill('우선', color: AppColors.rose),
                    if (showDate) ...[
                      const Gap(6),
                      Text('${slot.slotDate.month}/${slot.slotDate.day}',
                          style: const TextStyle(
                              color: AppColors.gold,
                              fontSize: AppFont.micro,
                              fontWeight: FontWeight.w800)),
                    ],
                  ]),
                  const Gap(4),
                  Text(slot.title,
                      style: TextStyle(
                          fontSize: AppFont.label,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                          color:
                              done ? AppColors.textFaint : AppColors.textPrimary,
                          decoration:
                              done ? TextDecoration.lineThrough : null,
                          decorationColor: AppColors.textFaint)),
                  if ((slot.hook ?? '').isNotEmpty) ...[
                    const Gap(3),
                    Text(slot.hook!,
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: AppFont.caption,
                            height: 1.45)),
                  ],
                  if ((slot.src ?? '').isNotEmpty) ...[
                    const Gap(4),
                    InkWell(
                      onTap: slot.hasUrl ? onOpen : null,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(
                            slot.hasUrl
                                ? Icons.open_in_new_rounded
                                : Icons.description_rounded,
                            size: 12,
                            color: slot.hasUrl
                                ? AppColors.sky
                                : AppColors.textFaint),
                        const Gap(5),
                        Flexible(
                          child: Text(slot.src!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: slot.hasUrl
                                      ? AppColors.sky
                                      : AppColors.textFaint,
                                  fontSize: AppFont.micro)),
                        ),
                      ]),
                    ),
                  ],
                ]),
          ),
        ),
        RecordMenu(onEdit: onEdit, onDelete: onDelete),
      ]),
    );
  }
}

class _Grid extends StatelessWidget {
  final DateTime month;
  final DateTime selected;
  final DateTime today;
  final Map<DateTime, List<ShortsSlotRow>> slotsByDay;
  final Map<DateTime, List<TodoTask>> tasksByDay;
  final ValueChanged<DateTime> onPick;
  const _Grid({
    required this.month,
    required this.selected,
    required this.today,
    required this.slotsByDay,
    required this.tasksByDay,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final firstWeekday = month.weekday % 7; // 일=0
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final cells = <DateTime?>[
      for (var i = 0; i < firstWeekday; i++) null,
      for (var d = 1; d <= daysInMonth; d++)
        DateTime(month.year, month.month, d),
    ];

    return Column(children: [
      Row(children: [
        for (final (i, w) in ['일', '월', '화', '수', '목', '금', '토'].indexed)
          Expanded(
            child: Text(w,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: AppFont.caption,
                    fontWeight: FontWeight.w700,
                    color: i == 0
                        ? _rose.withValues(alpha: 0.8)
                        : AppColors.textFaint)),
          ),
      ]),
      const Gap(6),
      for (var r = 0; r * 7 < cells.length; r++)
        Row(children: [
          for (var c = 0; c < 7; c++)
            Expanded(
              child: (r * 7 + c < cells.length && cells[r * 7 + c] != null)
                  ? _cell(cells[r * 7 + c]!)
                  : const SizedBox(height: 46),
            ),
        ]),
    ]);
  }

  Widget _cell(DateTime day) {
    final slots = slotsByDay[day] ?? const <ShortsSlotRow>[];
    final tasks = tasksByDay[day] ?? const <TodoTask>[];
    final slotDone = slots.where((s) => s.done).length;
    final slotLeft = slots.length - slotDone;
    final extra = tasks.length;

    final isToday = _same(day, today);
    final isSel = _same(day, selected);

    return InkWell(
      onTap: () => onPick(day),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 46,
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: isSel
              ? _rose.withValues(alpha: 0.18)
              : (isToday ? AppColors.surfaceAlt : Colors.transparent),
          border: Border.all(
              color: isSel
                  ? _rose
                  : (isToday ? AppColors.border : Colors.transparent),
              width: isSel ? 1.4 : 1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('${day.day}',
              style: TextStyle(
                  fontSize: AppFont.label,
                  fontWeight:
                      isToday || isSel ? FontWeight.w900 : FontWeight.w600,
                  color: isSel
                      ? _rose
                      : (day.weekday == DateTime.sunday
                          ? _rose.withValues(alpha: 0.75)
                          : AppColors.textPrimary))),
          const Gap(3),
          SizedBox(
            height: 5,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < slotLeft.clamp(0, 3); i++) _dot(_rose),
              for (var i = 0; i < slotDone.clamp(0, 3); i++)
                _dot(AppColors.primary),
              for (var i = 0; i < extra.clamp(0, 2); i++) _dot(AppColors.gold),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _dot(Color c) => Container(
        width: 4,
        height: 4,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration:
            BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)),
      );
}
