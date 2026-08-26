// 「진행」 탭 — 물건을 순서대로 끌고 가는 화면.
//
// 매물 탭이 «무엇을 살까»라면, 여기는 «지금 무엇을 할까»다.
// 물건마다 지금 단계와 다음 할 일 하나를 보여주고, 기한을 지킨다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/data_providers.dart';
import '../../core/format/formatters.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../models/models.dart';
import 'progress.dart';

/// 기한 한 건 — 무엇이 언제까지인가.
class _Due {
  final AuctionProperty p;
  final String what;
  final DateTime when;
  final Color color;
  final int days; // 음수면 지났다
  _Due(this.p, this.what, this.when, this.color)
      : days = DateTime(when.year, when.month, when.day)
            .difference(DateTime(DateTime.now().year, DateTime.now().month,
                DateTime.now().day))
            .inDays;
}

/// 물건에서 «지켜야 할 날짜»를 뽑는다. 지난 단계의 날짜는 안 본다.
List<_Due> _duesOf(AuctionProperty p) {
  final out = <_Due>[];
  final idx = stageIndex(p.status);
  if (p.bidDate != null && idx <= stageIndex('bidding')) {
    out.add(_Due(p, '입찰', p.bidDate!, AppColors.gold));
  }
  if (p.balanceDue != null && idx <= stageIndex('won')) {
    out.add(_Due(p, '잔금', p.balanceDue!, AppColors.rose));
  }
  if (p.evictDue != null && idx <= stageIndex('evicting')) {
    out.add(_Due(p, '명도', p.evictDue!, AppColors.violet));
  }
  if (p.repairDue != null && idx <= stageIndex('repairing')) {
    out.add(_Due(p, '수리', p.repairDue!, const Color(0xFFF59E0B)));
  }
  if (p.exitDue != null && idx <= stageIndex('exiting')) {
    out.add(_Due(p, '출구', p.exitDue!, const Color(0xFF6366F1)));
  }
  return out;
}

class ProgressView extends ConsumerStatefulWidget {
  const ProgressView({super.key});

  @override
  ConsumerState<ProgressView> createState() => _ProgressViewState();
}

class _ProgressViewState extends ConsumerState<ProgressView> {
  String? _only; // 선택한 단계 status. null = 전체
  bool _guide = false; // 단계 안내 펼침

  Future<void> _setStatus(AuctionProperty p, String status) async {
    await ref
        .read(supabaseProvider)
        .from('auction_properties')
        .update({'status': status}).eq('id', p.id);
    ref.invalidate(auctionProvider);
  }

  Future<void> _toggleTask(
      AuctionProperty p, StageTask t, bool now) async {
    final next = Map<String, dynamic>.from(p.checklist)..[t.key] = now;
    try {
      await ref
          .read(supabaseProvider)
          .from('auction_properties')
          .update({'checklist': next}).eq('id', p.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('저장 실패 — $e')));
      return;
    }
    ref.invalidate(auctionProvider);
  }

  Future<void> _pickDate(AuctionProperty p, String col, DateTime? cur) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: cur ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );
    if (d == null) return;
    await ref
        .read(supabaseProvider)
        .from('auction_properties')
        .update({col: d.toIso8601String().substring(0, 10)}).eq('id', p.id);
    ref.invalidate(auctionProvider);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(auctionProvider);
    return async.when(
      loading: AsyncStatus.loading,
      error: AsyncStatus.error,
      data: (all) {
        // 제외·모의 물건은 진행 대상이 아니다. 실제로 끌고 가는 것만 본다.
        final live = all
            .where((p) => !p.excluded && !kDoneStatuses.contains(p.status))
            .toList();

        if (all.isEmpty) {
          return const EmptyState(
            icon: Icons.timeline_rounded,
            message: '등록된 물건이 없어요.\n「매물」 탭에서 물건을 먼저 추가하세요.',
          );
        }

        // 기한 — 가까운 순. 지난 것이 맨 위.
        final dues = [for (final p in live) ..._duesOf(p)]
          ..sort((a, b) => a.days.compareTo(b.days));
        final urgent = dues.where((d) => d.days <= 14).toList();

        final shown = _only == null
            ? live
            : live.where((p) => p.status == _only).toList();
        shown.sort((a, b) {
          // 급한 기한이 있는 물건을 위로, 그 다음은 단계 역순(끝에 가까운 것 먼저).
          final ad = _duesOf(a).map((d) => d.days).fold<int>(9999, (x, y) => y < x ? y : x);
          final bd = _duesOf(b).map((d) => d.days).fold<int>(9999, (x, y) => y < x ? y : x);
          if (ad != bd) return ad.compareTo(bd);
          return stageIndex(b.status).compareTo(stageIndex(a.status));
        });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 기한 ────────────────────────────────────────
            if (urgent.isNotEmpty) ...[
              _DueCard(
                dues: urgent,
                onTap: (p) => context.go('/auction/${p.id}'),
              ),
              const Gap(16),
            ],

            // ── 단계 막대 ───────────────────────────────────
            _StageBar(
              items: live,
              selected: _only,
              onTap: (s) => setState(() => _only = _only == s ? null : s),
            ),
            const Gap(10),

            // ── 순서 안내 ───────────────────────────────────
            _GuideCard(
              open: _guide,
              onToggle: () => setState(() => _guide = !_guide),
            ),
            const Gap(16),

            if (shown.isEmpty)
              EmptyState(
                icon: Icons.check_circle_outline_rounded,
                message: _only == null
                    ? '진행 중인 물건이 없어요.\n낙찰·매도가 끝났거나 전부 보류 상태입니다.'
                    : '이 단계에 있는 물건이 없어요.',
              )
            else
              for (final p in shown)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _ProgressCard(
                    p: p,
                    onOpen: () => context.go('/auction/${p.id}'),
                    onTask: (t, v) => _toggleTask(p, t, v),
                    onNext: (s) => _setStatus(p, s),
                    onDate: (col, cur) => _pickDate(p, col, cur),
                  ),
                ),
          ],
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════
// 기한
// ══════════════════════════════════════════════════════════

class _DueCard extends StatelessWidget {
  final List<_Due> dues;
  final void Function(AuctionProperty) onTap;
  const _DueCard({required this.dues, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final late = dues.where((d) => d.days < 0).length;
    return GlassCard(
      accent: late > 0 ? AppColors.rose : AppColors.gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader('지켜야 할 날짜',
              subtitle: late > 0 ? '기한이 지난 것 $late건' : '2주 안'),
          const Gap(10),
          for (final d in dues.take(6))
            InkWell(
              onTap: () => onTap(d.p),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(children: [
                  SizedBox(
                    width: 42,
                    child: Pill(d.what, color: d.color),
                  ),
                  const Gap(12),
                  Expanded(
                    child: Text(d.p.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: AppFont.body,
                            fontWeight: FontWeight.w600)),
                  ),
                  const Gap(8),
                  Text(Dates.md(d.when),
                      style: const TextStyle(
                          color: AppColors.textFaint,
                          fontSize: AppFont.caption)),
                  const Gap(10),
                  Text(
                    d.days < 0
                        ? '${-d.days}일 지남'
                        : d.days == 0
                            ? '오늘'
                            : 'D-${d.days}',
                    style: TextStyle(
                        color: d.days < 0
                            ? AppColors.rose
                            : d.days <= 3
                                ? AppColors.gold
                                : AppColors.textSecondary,
                        fontSize: AppFont.label,
                        fontWeight: FontWeight.w900),
                  ),
                ]),
              ),
            ),
          if (dues.length > 6) ...[
            const Gap(6),
            Text('그 외 ${dues.length - 6}건',
                style: const TextStyle(
                    color: AppColors.textFaint, fontSize: AppFont.caption)),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 단계 막대
// ══════════════════════════════════════════════════════════

class _StageBar extends StatelessWidget {
  final List<AuctionProperty> items;
  final String? selected;
  final void Function(String) onTap;
  const _StageBar(
      {required this.items, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < kStages.length; i++)
          Builder(builder: (context) {
            final s = kStages[i];
            final n = items.where((p) => p.status == s.status).length;
            final on = selected == s.status;
            return Material(
              color: on ? s.color.withValues(alpha: 0.18) : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onTap(s.status),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: on ? s.color : Colors.transparent, width: 1.2),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('${i + 1}',
                        style: TextStyle(
                            color: s.color,
                            fontSize: AppFont.caption,
                            fontWeight: FontWeight.w900)),
                    const Gap(7),
                    Icon(s.icon, size: 15, color: s.color),
                    const Gap(6),
                    Text(s.label,
                        style: TextStyle(
                            fontSize: AppFont.label,
                            fontWeight: FontWeight.w700,
                            color: on ? s.color : AppColors.textSecondary)),
                    if (n > 0) ...[
                      const Gap(7),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: s.color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('$n',
                            style: TextStyle(
                                color: s.color,
                                fontSize: AppFont.micro,
                                fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ]),
                ),
              ),
            );
          }),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════
// 순서 안내 — 이 앱을 처음 쓰거나 순서를 잊었을 때
// ══════════════════════════════════════════════════════════

class _GuideCard extends StatelessWidget {
  final bool open;
  final VoidCallback onToggle;
  const _GuideCard({required this.open, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onTap: onToggle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.menu_book_rounded,
                size: 16, color: AppColors.textFaint),
            const Gap(9),
            const Expanded(
              child: Text('경매는 이 순서로 간다',
                  style: TextStyle(
                      fontSize: AppFont.label,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary)),
            ),
            Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                size: 18, color: AppColors.textFaint),
          ]),
          if (open) ...[
            const Gap(12),
            for (var i = 0; i < kStages.length; i++) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: kStages[i].color.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('${i + 1}',
                        style: TextStyle(
                            color: kStages[i].color,
                            fontSize: AppFont.micro,
                            fontWeight: FontWeight.w900)),
                  ),
                  const Gap(10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(kStages[i].label,
                            style: TextStyle(
                                fontSize: AppFont.label,
                                fontWeight: FontWeight.w800,
                                color: kStages[i].color)),
                        const Gap(2),
                        Text(kStages[i].goal,
                            style: const TextStyle(
                                fontSize: AppFont.caption,
                                color: AppColors.textSecondary,
                                height: 1.45)),
                      ],
                    ),
                  ),
                ]),
              ),
            ],
            const Gap(8),
            const Text(
                '각 단계의 할 일은 물건 카드에서 체크한다. 다 체크하면 다음 단계로 넘어간다.',
                style: TextStyle(
                    fontSize: AppFont.caption,
                    color: AppColors.textFaint,
                    height: 1.5)),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 물건 카드
// ══════════════════════════════════════════════════════════

class _ProgressCard extends StatefulWidget {
  final AuctionProperty p;
  final VoidCallback onOpen;
  final void Function(StageTask, bool) onTask;
  final void Function(String) onNext;
  final void Function(String col, DateTime? cur) onDate;

  const _ProgressCard({
    required this.p,
    required this.onOpen,
    required this.onTask,
    required this.onNext,
    required this.onDate,
  });

  @override
  State<_ProgressCard> createState() => _ProgressCardState();
}

class _ProgressCardState extends State<_ProgressCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final stage = stageOf(p.status);
    if (stage == null) return const SizedBox.shrink();

    final pending = pendingTasks(stage, p.checklist, p.strategy);
    final all = tasksFor(stage, p.strategy);
    final done = all.length - pending.length;
    final ratio = stageProgress(stage, p.checklist, p.strategy);
    final idx = stageIndex(p.status);
    final next = idx + 1 < kStages.length ? kStages[idx + 1] : null;
    final dues = _duesOf(p);

    return GlassCard(
      accent: stage.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 제목 줄
          Row(children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: stage.color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(stage.icon, size: 17, color: stage.color),
            ),
            const Gap(11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: AppFont.section,
                          fontWeight: FontWeight.w800)),
                  const Gap(2),
                  Text('${idx + 1}. ${stage.label} · $done/${stage.tasks.length}',
                      style: TextStyle(
                          fontSize: AppFont.caption, color: stage.color)),
                ],
              ),
            ),
            if (p.isSim) const Pill('모의', color: AppColors.textFaint),
            const Gap(6),
            IconButton(
              tooltip: '상세',
              onPressed: widget.onOpen,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.open_in_new_rounded,
                  size: 17, color: AppColors.textFaint),
            ),
          ]),
          const Gap(12),

          // 진행 막대 — 이 단계 안에서 얼마나 왔나
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: AppColors.surfaceAlt,
              valueColor: AlwaysStoppedAnimation(stage.color),
            ),
          ),
          const Gap(12),

          // 기한
          if (dues.isNotEmpty) ...[
            Wrap(spacing: 8, runSpacing: 6, children: [
              for (final d in dues)
                _DueChip(
                  what: d.what,
                  when: d.when,
                  days: d.days,
                  color: d.color,
                ),
            ]),
            const Gap(12),
          ],

          // 다음 할 일 — 하나만 보여준다. 목록을 보면 아무것도 안 한다.
          if (pending.isEmpty)
            Row(children: [
              const Icon(Icons.check_circle_rounded,
                  size: 17, color: AppColors.primary),
              const Gap(8),
              Expanded(
                child: Text('${stage.label} 끝. ${next == null ? '매도만 남았다' : '다음은 ${next.label}'}',
                    style: const TextStyle(
                        fontSize: AppFont.body,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
              ),
              if (next != null)
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: next.color,
                    foregroundColor: const Color(0xFF0B0F1A),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 9),
                  ),
                  onPressed: () => widget.onNext(next.status),
                  child: Text('${next.label}로',
                      style: const TextStyle(
                          fontSize: AppFont.label,
                          fontWeight: FontWeight.w800)),
                )
              else
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: const Color(0xFF06210F),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 9),
                  ),
                  onPressed: () => widget.onNext('sold'),
                  child: const Text('물건 종료',
                      style: TextStyle(
                          fontSize: AppFont.label,
                          fontWeight: FontWeight.w800)),
                ),
            ])
          else
            _TaskRow(
              task: pending.first,
              onCheck: () => widget.onTask(pending.first, true),
              color: stage.color,
              lead: '다음 할 일',
            ),

          // 나머지 할 일 펼치기
          if (pending.length > 1) ...[
            const Gap(6),
            InkWell(
              onTap: () => setState(() => _open = !_open),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Icon(
                      _open
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 17,
                      color: AppColors.textFaint),
                  const Gap(6),
                  Text('남은 ${pending.length - 1}개',
                      style: const TextStyle(
                          fontSize: AppFont.label,
                          color: AppColors.textFaint)),
                ]),
              ),
            ),
            if (_open)
              for (final t in pending.skip(1))
                _TaskRow(
                  task: t,
                  onCheck: () => widget.onTask(t, true),
                  color: stage.color,
                ),
          ],

          // 날짜 채우기 — 단계에 맞는 것만 노출한다
          if (const {'won', 'evicting', 'repairing', 'exiting', 'settling'}
              .contains(p.status)) ...[
            const Gap(10),
            const Divider(height: 1, color: AppColors.border),
            const Gap(10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (p.status == 'won') ...[
                _DateButton(
                    label: '낙찰일',
                    value: p.wonDate,
                    onTap: () => widget.onDate('won_date', p.wonDate)),
                _DateButton(
                    label: '잔금 기한',
                    value: p.balanceDue,
                    urgent: true,
                    onTap: () => widget.onDate('balance_due', p.balanceDue)),
              ],
              if (p.status == 'evicting')
                _DateButton(
                    label: '명도 목표일',
                    value: p.evictDue,
                    onTap: () => widget.onDate('evict_due', p.evictDue)),
              if (p.status == 'repairing')
                _DateButton(
                    label: '수리 완료 목표',
                    value: p.repairDue,
                    onTap: () => widget.onDate('repair_due', p.repairDue)),
              if (p.status == 'exiting')
                _DateButton(
                    label: '출구 목표일',
                    value: p.exitDue,
                    urgent: true,
                    onTap: () => widget.onDate('exit_due', p.exitDue)),
              if (p.status == 'settling')
                _DateButton(
                    label: '매도·세팅 완료일',
                    value: p.soldDate,
                    onTap: () => widget.onDate('sold_date', p.soldDate)),
            ]),
          ],
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  final StageTask task;
  final VoidCallback onCheck;
  final Color color;
  final String? lead;
  const _TaskRow(
      {required this.task,
      required this.onCheck,
      required this.color,
      this.lead});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 30,
          height: 30,
          child: Checkbox(
            value: false,
            onChanged: (_) => onCheck(),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            activeColor: AppColors.primary,
            side: const BorderSide(color: AppColors.border, width: 1.6),
          ),
        ),
        const Gap(4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (lead != null) ...[
                Text(lead!,
                    style: TextStyle(
                        fontSize: AppFont.micro,
                        fontWeight: FontWeight.w800,
                        color: color)),
                const Gap(2),
              ],
              Text(task.label,
                  style: const TextStyle(
                      fontSize: AppFont.body,
                      fontWeight: FontWeight.w600,
                      height: 1.35)),
              if (task.hint != null) ...[
                const Gap(3),
                Text(task.hint!,
                    style: const TextStyle(
                        fontSize: AppFont.caption,
                        color: AppColors.textFaint,
                        height: 1.5)),
              ],
            ],
          ),
        ),
      ]),
    );
  }
}

class _DueChip extends StatelessWidget {
  final String what;
  final DateTime when;
  final int days;
  final Color color;
  const _DueChip(
      {required this.what,
      required this.when,
      required this.days,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final late = days < 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: late ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(what,
            style: TextStyle(
                color: color,
                fontSize: AppFont.caption,
                fontWeight: FontWeight.w800)),
        const Gap(7),
        Text(Dates.md(when),
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: AppFont.caption)),
        const Gap(7),
        Text(late ? '${-days}일 지남' : (days == 0 ? '오늘' : 'D-$days'),
            style: TextStyle(
                color: late ? AppColors.rose : AppColors.textPrimary,
                fontSize: AppFont.caption,
                fontWeight: FontWeight.w900)),
      ]),
    );
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final DateTime? value;
  final bool urgent;
  final VoidCallback onTap;
  const _DateButton(
      {required this.label,
      required this.value,
      required this.onTap,
      this.urgent = false});

  @override
  Widget build(BuildContext context) {
    final empty = value == null;
    final c = empty && urgent ? AppColors.rose : AppColors.textSecondary;
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: c,
        side: BorderSide(color: empty && urgent ? c : AppColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      ),
      icon: const Icon(Icons.event_rounded, size: 15),
      label: Text(empty ? '$label 입력' : '$label ${Dates.md(value!)}',
          style: const TextStyle(
              fontSize: AppFont.label, fontWeight: FontWeight.w700)),
    );
  }
}
