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
import '../../models/models.dart';

String _won(double? v) => v == null ? '' : '${Won.compact(v)}원';

/// 배분 한 줄을 사람이 읽는 문자열로.
String allocText(PlanAllocation a) {
  switch (a.kind) {
    case 'monthly':
      return '${_won(a.amount)} / 월';
    case 'percent':
      return '${(a.percent ?? 0).toStringAsFixed(0)}%';
    case 'target':
      return '목표 ${_won(a.amount)}';
    default:
      return a.note ?? '—';
  }
}

// ── 편집 CRUD 헬퍼 ────────────────────────────────────────────
Future<void> _setCurrentPhase(WidgetRef ref, PlanPhase p) async {
  final sb = ref.read(supabaseProvider);
  final uid = sb.auth.currentUser!.id;
  await sb.from('plan_phases').update({'is_current': false}).eq('user_id', uid);
  await sb.from('plan_phases').update({'is_current': true}).eq('id', p.id);
  ref.invalidate(planPhasesProvider);
  ref.invalidate(currentPhaseProvider);
}

Future<void> _toggleCond(WidgetRef ref, PlanCondition c) async {
  final sb = ref.read(supabaseProvider);
  final done = !c.done;
  await sb.from('plan_conditions').update({
    'done': done,
    'achieved_date':
        done ? DateTime.now().toIso8601String().substring(0, 10) : null,
  }).eq('id', c.id);
  ref.invalidate(planConditionsProvider);
}

Future<void> _editPhase(BuildContext c, WidgetRef ref, PlanPhase p) async {
  final v = await showRecordForm(c,
      title: 'Phase ${p.phaseNo} 수정',
      accent: AppColors.gold,
      fields: const [
        FieldSpec(key: 'title', label: '제목', type: FieldType.text, required: true),
        FieldSpec(key: 'summary', label: '설명', type: FieldType.longtext),
        FieldSpec(key: 'target_date', label: '목표일', type: FieldType.date),
        FieldSpec(key: 'achieved_date', label: '달성일', type: FieldType.date),
      ],
      initial: {
        'title': p.title,
        'summary': p.summary,
        'target_date': p.targetDate?.toIso8601String().substring(0, 10),
        'achieved_date': p.achievedDate?.toIso8601String().substring(0, 10),
      });
  if (v == null) return;
  await ref.read(supabaseProvider).from('plan_phases').update({
    'title': v['title'],
    'summary': v['summary'],
    'target_date': v['target_date'],
    'achieved_date': v['achieved_date'],
  }).eq('id', p.id);
  ref.invalidate(planPhasesProvider);
  ref.invalidate(currentPhaseProvider);
}

const _allocFields = [
  FieldSpec(key: 'category', label: '항목명', type: FieldType.text, required: true),
  FieldSpec(
      key: 'kind',
      label: '종류 (monthly=월정기·percent=비중·target=누적목표·rule=규칙)',
      type: FieldType.select,
      options: ['monthly', 'percent', 'target', 'rule'],
      required: true),
  FieldSpec(
      key: 'amount',
      label: '금액 (target=누적목표 · monthly=월정기)',
      type: FieldType.money),
  FieldSpec(
      key: 'monthly_amount',
      label: '월 계획 (target 항목: 매달 넣을 금액)',
      type: FieldType.money),
  FieldSpec(
      key: 'held_amount',
      label: '이미 가진 돈 (target 항목: 현재 보유액)',
      type: FieldType.money),
  FieldSpec(key: 'percent', label: '비중 % (percent)', type: FieldType.number),
  FieldSpec(key: 'note', label: '메모 (rule 설명 등)', type: FieldType.text),
];

Future<void> _editAllocation(BuildContext c, WidgetRef ref,
    {PlanAllocation? alloc, int? phaseNo, String side = 'out'}) async {
  final v = await showRecordForm(c,
      title: alloc == null ? '항목 추가' : '항목 수정',
      accent: AppColors.sky,
      fields: _allocFields,
      initial: alloc == null
          ? {}
          : {
              'category': alloc.category,
              'kind': alloc.kind,
              'amount': alloc.amount,
              'monthly_amount': alloc.monthlyAmount,
              'held_amount': alloc.heldAmount,
              'percent': alloc.percent,
              'note': alloc.note,
            });
  if (v == null) return;
  final sb = ref.read(supabaseProvider);
  final data = <String, dynamic>{
    'category': v['category'],
    'kind': v['kind'],
    'amount': v['amount'],
    'percent': v['percent'],
    'note': v['note'],
  };
  // 월 계획·보유액은 값이 있을 때만 전송 (컬럼 미추가 환경에서 저장이 깨지지 않도록).
  if (v['monthly_amount'] != null) data['monthly_amount'] = v['monthly_amount'];
  if (v['held_amount'] != null) data['held_amount'] = v['held_amount'];
  if (alloc == null) {
    data['user_id'] = sb.auth.currentUser!.id;
    data['phase_no'] = phaseNo;
    data['side'] = side;
    await sb.from('plan_allocations').insert(data);
  } else {
    await sb.from('plan_allocations').update(data).eq('id', alloc.id);
  }
  ref.invalidate(planAllocationsProvider);
}

Future<void> _deleteAllocation(
    BuildContext c, WidgetRef ref, PlanAllocation a) async {
  if (!await confirmDelete(c, name: a.category)) return;
  await ref.read(supabaseProvider).from('plan_allocations').delete().eq('id', a.id);
  ref.invalidate(planAllocationsProvider);
}

const _condFields = [
  FieldSpec(key: 'label', label: '조건', type: FieldType.text, required: true),
  FieldSpec(
      key: 'kind',
      label: '종류 (manual=수동체크·cashflow=현금흐름 자동)',
      type: FieldType.select,
      options: ['manual', 'cashflow'],
      required: true),
  FieldSpec(
      key: 'target_value',
      label: '목표 현금흐름액 (cashflow)',
      type: FieldType.money),
  FieldSpec(key: 'target_date', label: '목표일', type: FieldType.date),
];

Future<void> _editConditionRec(BuildContext c, WidgetRef ref,
    {PlanCondition? cond, int? phaseNo}) async {
  final v = await showRecordForm(c,
      title: cond == null ? '조건 추가' : '조건 수정',
      accent: AppColors.violet,
      fields: _condFields,
      initial: cond == null
          ? {}
          : {
              'label': cond.label,
              'kind': cond.kind,
              'target_value': cond.targetValue,
              'target_date': cond.targetDate?.toIso8601String().substring(0, 10),
            });
  if (v == null) return;
  final sb = ref.read(supabaseProvider);
  final data = <String, dynamic>{
    'label': v['label'],
    'kind': v['kind'],
    'target_value': v['target_value'],
    'target_date': v['target_date'],
  };
  if (cond == null) {
    data['user_id'] = sb.auth.currentUser!.id;
    data['phase_no'] = phaseNo;
    await sb.from('plan_conditions').insert(data);
  } else {
    await sb.from('plan_conditions').update(data).eq('id', cond.id);
  }
  ref.invalidate(planConditionsProvider);
}

Future<void> _deleteConditionRec(
    BuildContext c, WidgetRef ref, PlanCondition cond) async {
  if (!await confirmDelete(c, name: cond.label)) return;
  await ref.read(supabaseProvider).from('plan_conditions').delete().eq('id', cond.id);
  ref.invalidate(planConditionsProvider);
}

/// 서브 섹션 헤더 + 추가 버튼.
class _EditSubHeader extends StatelessWidget {
  final String title;
  final VoidCallback onAdd;
  const _EditSubHeader({required this.title, required this.onAdd});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title,
            style: const TextStyle(
                color: AppColors.textFaint,
                fontSize: AppFont.caption,
                fontWeight: FontWeight.w700)),
        const Spacer(),
        InkWell(
          onTap: onAdd,
          borderRadius: BorderRadius.circular(6),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(children: [
              Icon(Icons.add_rounded, size: 15, color: AppColors.sky),
              Gap(2),
              Text('추가',
                  style: TextStyle(color: AppColors.sky, fontSize: AppFont.label)),
            ]),
          ),
        ),
      ],
    );
  }
}

/// 배분 한 줄 (수정/삭제 메뉴 포함).
class _AllocRow extends StatelessWidget {
  final PlanAllocation a;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _AllocRow(
      {required this.a, required this.onEdit, required this.onDelete});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration:
                const BoxDecoration(color: AppColors.sky, shape: BoxShape.circle),
          ),
          const Gap(8),
          Expanded(child: Text(a.category, style: const TextStyle(fontSize: AppFont.label))),
          Text(allocText(a),
              style: TextStyle(
                  fontSize: AppFont.label,
                  fontWeight: FontWeight.w700,
                  color: a.kind == 'rule'
                      ? AppColors.textSecondary
                      : AppColors.textPrimary)),
          RecordMenu(onEdit: onEdit, onDelete: onDelete),
        ],
      ),
    );
  }
}

/// ══════════════════════════════════════════════════════════
/// 재무 로드맵 (Goals) — 7단계 타임라인 + 조건 + 배분 (편집 가능)
/// ══════════════════════════════════════════════════════════
class PlanRoadmap extends ConsumerWidget {
  const PlanRoadmap({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phases = ref.watch(planPhasesProvider).value ?? [];
    if (phases.isEmpty) return const SizedBox.shrink();
    final conds = ref.watch(planConditionsProvider).value ?? [];
    final allocs = ref.watch(planAllocationsProvider).value ?? [];
    final cashflow = ref.watch(nonSalaryCashflowThisMonthProvider).value ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('재무 로드맵',
            subtitle: '연필로 단계·조건·배분 수정 · + 로 추가 · 조건 체크로 달성 기록'),
        const Gap(14),
        for (var i = 0; i < phases.length; i++)
          _PhaseTile(
            phase: phases[i],
            isLast: i == phases.length - 1,
            conditions:
                conds.where((c) => c.phaseNo == phases[i].phaseNo).toList(),
            allocations:
                allocs.where((a) => a.phaseNo == phases[i].phaseNo).toList(),
            cashflow: cashflow,
          ),
      ],
    );
  }
}

class _PhaseTile extends ConsumerWidget {
  final PlanPhase phase;
  final bool isLast;
  final List<PlanCondition> conditions;
  final List<PlanAllocation> allocations;
  final double cashflow;

  const _PhaseTile({
    required this.phase,
    required this.isLast,
    required this.conditions,
    required this.allocations,
    required this.cashflow,
  });

  bool get _done => phase.achievedDate != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Color color = _done
        ? AppColors.primary
        : phase.isCurrent
            ? AppColors.gold
            : AppColors.textFaint;
    final String status =
        _done ? '완료' : (phase.isCurrent ? '현재' : '예정');
    final outAllocs = allocations.where((a) => a.side == 'out').toList();
    final inAllocs = allocations.where((a) => a.side == 'in').toList();

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 타임라인 레일
          Column(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                alignment: Alignment.center,
                child: _done
                    ? const Icon(Icons.check_rounded,
                        size: 16, color: AppColors.primary)
                    : Text('${phase.phaseNo}',
                        style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w800,
                            fontSize: AppFont.label)),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: AppColors.border),
                ),
            ],
          ),
          const Gap(12),
          // 내용
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: GlassCard(
                accent: phase.isCurrent ? AppColors.gold : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(phase.title,
                              style: const TextStyle(
                                  fontSize: AppFont.section,
                                  fontWeight: FontWeight.w800)),
                        ),
                        Pill(status, color: color),
                        IconButton(
                          onPressed: () => _editPhase(context, ref, phase),
                          icon: const Icon(Icons.edit_rounded,
                              size: 16, color: AppColors.textFaint),
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(6),
                        ),
                      ],
                    ),
                    if (phase.summary != null) ...[
                      const Gap(6),
                      Text(phase.summary!,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: AppFont.label)),
                    ],
                    const Gap(10),
                    // 날짜
                    InkWell(
                      onTap: () => _editPhase(context, ref, phase),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.event_rounded,
                                size: 14, color: AppColors.textFaint),
                            const Gap(6),
                            Text(
                              phase.targetDate == null
                                  ? '목표일 설정'
                                  : '목표 ${Dates.ymd(phase.targetDate!)} · ${Dates.dday(phase.targetDate!)}',
                              style: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: AppFont.label),
                            ),
                            if (phase.achievedDate != null) ...[
                              const Gap(10),
                              Text('달성 ${Dates.ymd(phase.achievedDate!)}',
                                  style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: AppFont.label,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ],
                        ),
                      ),
                    ),
                    // 조건 체크리스트
                    const Gap(10),
                    _EditSubHeader(
                        title: '전환 조건',
                        onAdd: () => _editConditionRec(context, ref,
                            phaseNo: phase.phaseNo)),
                    for (final c in conditions)
                      _ConditionRow(
                        cond: c,
                        cashflow: cashflow,
                        onTap: () => _toggleCond(ref, c),
                        onEdit: () => _editConditionRec(context, ref, cond: c),
                        onDelete: () => _deleteConditionRec(context, ref, c),
                      ),
                    if (conditions.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Text('조건 없음',
                            style: TextStyle(
                                color: AppColors.textFaint, fontSize: AppFont.label)),
                      ),
                    // 배분 (나가는 돈 기본세팅 / 현금흐름 구성 목표)
                    const Gap(12),
                    const Divider(color: AppColors.border, height: 1),
                    const Gap(10),
                    _EditSubHeader(
                        title: '나가는 돈 기본세팅',
                        onAdd: () => _editAllocation(context, ref,
                            phaseNo: phase.phaseNo, side: 'out')),
                    for (final a in outAllocs)
                      _AllocRow(
                        a: a,
                        onEdit: () => _editAllocation(context, ref, alloc: a),
                        onDelete: () => _deleteAllocation(context, ref, a),
                      ),
                    const Gap(10),
                    _EditSubHeader(
                        title: '목표 현금흐름 구성',
                        onAdd: () => _editAllocation(context, ref,
                            phaseNo: phase.phaseNo, side: 'in')),
                    for (final a in inAllocs)
                      _AllocRow(
                        a: a,
                        onEdit: () => _editAllocation(context, ref, alloc: a),
                        onDelete: () => _deleteAllocation(context, ref, a),
                      ),
                    // 현재 단계 지정 버튼
                    if (!phase.isCurrent) ...[
                      const Gap(12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => _setCurrentPhase(ref, phase),
                          icon: const Icon(Icons.my_location_rounded, size: 16),
                          label: const Text('현재 단계로'),
                          style: TextButton.styleFrom(
                              foregroundColor: AppColors.gold),
                        ),
                      ),
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
}

class _ConditionRow extends StatelessWidget {
  final PlanCondition cond;
  final double cashflow;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  const _ConditionRow(
      {required this.cond,
      required this.cashflow,
      required this.onTap,
      this.onEdit,
      this.onDelete});

  @override
  Widget build(BuildContext context) {
    // cashflow 조건은 실데이터로 자동 진행률.
    double? progress;
    String? sub;
    if (cond.kind == 'cashflow' && (cond.targetValue ?? 0) > 0) {
      progress = (cashflow / cond.targetValue!).clamp(0, 1).toDouble();
      sub =
          '현재 ${Won.compact(cashflow)} / ${Won.compact(cond.targetValue!)}원 (${(progress * 100).toStringAsFixed(0)}%)';
    }
    final auto = progress != null && progress >= 1;
    final done = cond.done || auto;
    final color = done ? AppColors.primary : AppColors.textSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  done
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 18,
                  color: done ? AppColors.primary : AppColors.textFaint,
                ),
                const Gap(8),
                Expanded(
                  child: Text(cond.label,
                      style: TextStyle(
                          fontSize: AppFont.label,
                          color: color,
                          fontWeight: FontWeight.w600,
                          decoration:
                              done ? TextDecoration.lineThrough : null)),
                ),
                if (cond.achievedDate != null)
                  Text(Dates.ymd(cond.achievedDate!),
                      style: const TextStyle(
                          color: AppColors.primary, fontSize: AppFont.caption)),
                if (onEdit != null && onDelete != null)
                  RecordMenu(onEdit: onEdit!, onDelete: onDelete!),
              ],
            ),
            if (sub != null) ...[
              const Gap(6),
              Padding(
                padding: const EdgeInsets.only(left: 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProgressBar(
                        value: progress!,
                        color: auto ? AppColors.primary : AppColors.gold,
                        height: 5),
                    const Gap(4),
                    Text(sub,
                        style: const TextStyle(
                            color: AppColors.textFaint, fontSize: AppFont.caption)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// ══════════════════════════════════════════════════════════
/// 자금 흐름 '나가는 돈' — 현재 단계 기본세팅(계획) vs 이번 달 실제
/// ══════════════════════════════════════════════════════════
bool _matchLabel(String category, String label) {
  final cat = category.toLowerCase();
  final lab = label.toLowerCase();
  final sep = RegExp(r'[\s/·]+');
  for (final t in category.split(sep)) {
    if (t.length >= 2 && lab.contains(t.toLowerCase())) return true;
  }
  for (final t in label.split(sep)) {
    if (t.length >= 2 && cat.contains(t.toLowerCase())) return true;
  }
  return false;
}

class PhasePlanVsActual extends ConsumerStatefulWidget {
  const PhasePlanVsActual({super.key});

  @override
  ConsumerState<PhasePlanVsActual> createState() => _PhasePlanVsActualState();
}

class _PhasePlanVsActualState extends ConsumerState<PhasePlanVsActual> {
  int? _selPhaseNo; // 보고 있는 Phase (null → 현재 단계)

  @override
  Widget build(BuildContext context) {
    final phases = ref.watch(planPhasesProvider).value ?? [];
    final current = ref.watch(currentPhaseProvider).value;
    final allocs = ref.watch(planAllocationsProvider).value ?? [];
    final entries = ref.watch(flowEntriesProvider).value ?? [];
    if (phases.isEmpty) return const SizedBox.shrink();
    final selNo = _selPhaseNo ?? current?.phaseNo ?? phases.first.phaseNo;
    final phase = phases
        .firstWhere((p) => p.phaseNo == selNo, orElse: () => phases.first);
    final outAllocs = allocs
        .where((a) => a.phaseNo == phase.phaseNo && a.side == 'out')
        .toList();

    // 이번 달 실제 지출 (거래 장부의 '나가는 돈').
    final now = DateTime.now();
    final expenseThisMonth = entries
        .where((e) =>
            !e.isIn && e.date.year == now.year && e.date.month == now.month)
        .toList();
    // 자동 수입 카테고리(에어비앤비·배당·숏폼·토지)는 모듈 실적을 쓴다.
    final autoIncome =
        ref.watch(moduleIncomeThisMonthProvider).value ?? const <String, double>{};
    double? autoFor(String category) {
      for (final entry in autoIncome.entries) {
        // 실적이 0보다 클 때만 자동 대체(0이면 거래 장부 값을 그대로).
        if (entry.value > 0 &&
            (_matchLabel(category, entry.key) || _matchLabel(entry.key, category))) {
          return entry.value;
        }
      }
      return null;
    }

    // isIncome=true(들어오는 돈): 모듈 수입 실적 + 거래 장부 '들어온 돈'.
    // isIncome=false(나가는 돈): 거래 장부 '나간 돈'(실제 매입/지출)만.
    //   ── 배당을 '나가는 돈'(매달 얼마 매입)으로 잡으면, 배당금 수령액이 아니라
    //      실제로 산 금액(나간 돈)을 보여줘야 하므로 모듈 수입을 쓰지 않는다.
    double actualOf(String category, {required bool isIncome}) {
      if (isIncome) {
        final auto = autoFor(category);
        if (auto != null) return auto; // 배당·에비·숏폼 등 모듈 수입 실적
        double s = 0;
        for (final e in entries) {
          if (e.isIn &&
              e.date.year == now.year &&
              e.date.month == now.month &&
              _matchLabel(category, e.label)) {
            s += e.amount;
          }
        }
        return s;
      }
      double s = 0;
      for (final e in expenseThisMonth) {
        if (_matchLabel(category, e.label)) s += e.amount;
      }
      return s;
    }

    // 누적(전 기간) 모은/나간 금액 — 누적 목표 진행률용.
    double allTimeOf(String category, {required bool isIncome}) {
      if (isIncome) {
        final auto = autoFor(category);
        if (auto != null) return auto; // 모듈 수입은 이번 달 실적으로 근사
        double s = 0;
        for (final e in entries) {
          if (e.isIn && _matchLabel(category, e.label)) s += e.amount;
        }
        return s;
      }
      double s = 0;
      for (final e in entries) {
        if (!e.isIn && _matchLabel(category, e.label)) s += e.amount;
      }
      return s;
    }

    // 이번 달 실제 나간 돈 총액 (거래 장부).
    double actualTotal = 0;
    for (final e in expenseThisMonth) {
      actualTotal += e.amount;
    }
    // 기본세팅 월 정기 계획 합계 (월정기 항목만 — 누적목표/규칙 제외).
    double planMonthly = 0;
    for (final a in outAllocs) {
      if (a.kind == 'monthly' && a.amount != null) planMonthly += a.amount!;
    }

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.rule_folder_rounded,
                  color: AppColors.gold, size: 18),
              const Gap(8),
              const Expanded(
                child: Text('기본세팅',
                    style: TextStyle(
                        fontSize: AppFont.section, fontWeight: FontWeight.w800)),
              ),
              const Text('이번 달',
                  style:
                      TextStyle(color: AppColors.textFaint, fontSize: AppFont.label)),
            ],
          ),
          const Gap(10),
          // Phase 전환 칩 — 어느 단계의 기본세팅을 보고/편집할지 선택.
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final p in phases)
                _PhaseChip(
                  label: 'P${p.phaseNo}',
                  selected: p.phaseNo == phase.phaseNo,
                  isCurrent: current?.phaseNo == p.phaseNo,
                  onTap: () => setState(() => _selPhaseNo = p.phaseNo),
                ),
            ],
          ),
          const Gap(8),
          Text('Phase ${phase.phaseNo} · ${phase.title}',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: AppFont.label)),
          const Gap(14),
          // 이번 달 실제 나간 돈 총액 (거래내역 기준)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.sky.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Text('이번 달 실제 나간 돈',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: AppFont.label)),
                const Spacer(),
                Text('${Won.compact(actualTotal)}원',
                    style: const TextStyle(
                        color: AppColors.sky,
                        fontSize: AppFont.title,
                        fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          const Gap(6),
          Text(
              planMonthly > 0
                  ? '기본세팅 월 정기 계획 ${Won.compact(planMonthly)}원 · 아래는 항목별 계획/실제'
                  : '아래는 기본세팅(계획) 대비 이번 달 실제',
              style: const TextStyle(color: AppColors.textFaint, fontSize: AppFont.caption)),
          const Gap(12),
          const Divider(color: AppColors.border, height: 1),
          const Gap(6),
          _EditSubHeader(
              title: '나가는 돈 · 계획 / 실제 (누르면 수정)',
              onAdd: () => _editAllocation(context, ref,
                  phaseNo: phase.phaseNo, side: 'out')),
          for (final a in outAllocs)
            _PlanActualRow(
              alloc: a,
              thisMonth: actualOf(a.category, isIncome: false),
              // 현재(누적) = 이미 가진 돈(보유액) + 지금까지 쌓인 거래 합계.
              accumulated: (a.heldAmount ?? 0) +
                  allTimeOf(a.category, isIncome: false),
              onEdit: () => _editAllocation(context, ref, alloc: a),
              onDelete: () => _deleteAllocation(context, ref, a),
            ),
        ],
      ),
    );
  }
}

class _PlanActualRow extends StatelessWidget {
  final PlanAllocation alloc;
  final double thisMonth; // 이번 달 실제
  final double accumulated; // 누적(전 기간)
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _PlanActualRow({
    required this.alloc,
    required this.thisMonth,
    required this.accumulated,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // 이번 달 실제 = 초록(있을 때) / 흐림(0).
    final Color actualColor =
        thisMonth > 0 ? AppColors.primary : AppColors.textFaint;
    final String actualText =
        thisMonth > 0 ? '이번 달 ${Won.compact(thisMonth)}원' : '이번 달 —';

    // 오른쪽: '월 목표 X  /  이번 달 Y' — 두 부분 폰트 크기 동일(색만 구분).
    RichText planActual(String planLabel) => RichText(
          textAlign: TextAlign.end,
          text: TextSpan(children: [
            TextSpan(
                text: '$planLabel  /  ',
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: AppFont.body,
                    fontWeight: FontWeight.w600)),
            TextSpan(
                text: actualText,
                style: TextStyle(
                    color: actualColor,
                    fontSize: AppFont.body,
                    fontWeight: FontWeight.w800)),
          ]),
        );

    // 항목명은 왼쪽, '월 목표/이번 달'은 오른쪽 끝 ··· 바로 왼쪽에 딱 붙임.
    Widget headRow(String planLabel) => Row(
          children: [
            Expanded(
              child: Text(alloc.category,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: AppFont.body, fontWeight: FontWeight.w700)),
            ),
            planActual(planLabel),
            const Gap(4),
            RecordMenu(onEdit: onEdit, onDelete: onDelete),
          ],
        );

    // 누적 목표(target + 금액): 한 줄(항목/월목표/이번달) + 축적·총목표 진행률.
    if (alloc.kind == 'target' && (alloc.amount ?? 0) > 0) {
      final target = alloc.amount!;
      final pct = (accumulated / target).clamp(0, 1).toDouble();
      final monthly = alloc.monthlyAmount ?? 0;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            headRow(monthly > 0 ? '월 목표 ${Won.compact(monthly)}원' : '월 목표 —'),
            const Gap(8),
            ProgressBar(value: pct, color: AppColors.gold, height: 7),
            const Gap(6),
            Text(
                '현재 ${Won.compact(accumulated)}원 / 총 목표 ${Won.compact(target)}원 (${(pct * 100).toStringAsFixed(0)}%)',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: AppFont.label)),
          ],
        ),
      );
    }

    // 월정기/비중 등: 항목명 + '월 목표 X / 이번 달 Y' 한 줄로 끝.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: headRow('월 목표 ${allocText(alloc)}'),
    );
  }
}

/// Phase 전환 칩 — 기본세팅 카드 상단.
class _PhaseChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isCurrent;
  final VoidCallback onTap;
  const _PhaseChip({
    required this.label,
    required this.selected,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color base = isCurrent ? AppColors.gold : AppColors.sky;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? base.withValues(alpha: 0.18) : Colors.transparent,
          border: Border.all(
              color: selected ? base : AppColors.border,
              width: selected ? 1.4 : 1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    color: selected ? base : AppColors.textSecondary,
                    fontSize: AppFont.label,
                    fontWeight: FontWeight.w800)),
            if (isCurrent) ...[
              const Gap(4),
              const Icon(Icons.star_rounded,
                  size: 12, color: AppColors.gold),
            ],
          ],
        ),
      ),
    );
  }
}

/// ══════════════════════════════════════════════════════════
/// 대시보드용 컴팩트 로드맵 — 현재 단계 + 7단계 스텝퍼 + 다음 목표
/// ══════════════════════════════════════════════════════════
class PlanRoadmapCompact extends ConsumerStatefulWidget {
  const PlanRoadmapCompact({super.key});

  @override
  ConsumerState<PlanRoadmapCompact> createState() =>
      _PlanRoadmapCompactState();
}

class _PlanRoadmapCompactState extends ConsumerState<PlanRoadmapCompact> {
  int? _selected; // 선택된 phase_no (null → 현재 단계)

  Future<void> _toggleCondition(PlanCondition c) async {
    final sb = ref.read(supabaseProvider);
    final now = DateTime.now();
    final done = !c.done;
    await sb.from('plan_conditions').update({
      'done': done,
      'achieved_date': done ? now.toIso8601String().substring(0, 10) : null,
    }).eq('id', c.id);
    ref.invalidate(planConditionsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final phases = ref.watch(planPhasesProvider).value ?? [];
    if (phases.isEmpty) return const SizedBox.shrink();
    final conds = ref.watch(planConditionsProvider).value ?? [];
    final cashflow = ref.watch(nonSalaryCashflowThisMonthProvider).value ?? 0;
    final current =
        phases.firstWhere((p) => p.isCurrent, orElse: () => phases.first);
    final selNo = _selected ?? current.phaseNo;
    final sel =
        phases.firstWhere((p) => p.phaseNo == selNo, orElse: () => current);
    final selConds = conds.where((c) => c.phaseNo == selNo).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return GlassCard(
      accent: AppColors.gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.route_rounded, color: AppColors.gold, size: 18),
              const Gap(8),
              const Text('재무 로드맵',
                  style: TextStyle(fontSize: AppFont.section, fontWeight: FontWeight.w800)),
              const Spacer(),
              Pill('현재 Phase ${current.phaseNo}', color: AppColors.gold),
            ],
          ),
          const Gap(16),
          // 클릭형 7단계 스텝퍼 (단계를 눌러 조건 보기)
          Row(
            children: [
              for (var i = 0; i < phases.length; i++) ...[
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _selected = phases[i].phaseNo),
                  child: _StepDot(
                      phase: phases[i], selected: phases[i].phaseNo == selNo),
                ),
                if (i != phases.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: phases[i].achievedDate != null
                          ? AppColors.primary
                          : AppColors.border,
                    ),
                  ),
              ],
            ],
          ),
          const Gap(18),
          // 선택된 단계 상세
          Row(
            children: [
              Pill('Phase ${sel.phaseNo}',
                  color: sel.isCurrent ? AppColors.gold : AppColors.sky),
              const Gap(8),
              Expanded(
                child: Text(sel.title,
                    style: const TextStyle(
                        fontSize: AppFont.body, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          if (sel.summary != null) ...[
            const Gap(6),
            Text(sel.summary!,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: AppFont.label)),
          ],
          const Gap(10),
          if (selConds.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text('이 단계는 별도 전환 조건이 없습니다',
                  style: TextStyle(color: AppColors.textFaint, fontSize: AppFont.label)),
            )
          else
            for (final c in selConds)
              _ConditionRow(
                  cond: c,
                  cashflow: cashflow,
                  onTap: () => _toggleCondition(c)),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final PlanPhase phase;
  final bool selected;
  const _StepDot({required this.phase, this.selected = false});

  @override
  Widget build(BuildContext context) {
    final done = phase.achievedDate != null;
    final color = done
        ? AppColors.primary
        : phase.isCurrent
            ? AppColors.gold
            : AppColors.textFaint;
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.22) : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: selected ? 3 : 2),
      ),
      alignment: Alignment.center,
      child: done
          ? const Icon(Icons.check_rounded, size: 14, color: AppColors.primary)
          : Text('${phase.phaseNo}',
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w800, fontSize: AppFont.label)),
    );
  }
}
