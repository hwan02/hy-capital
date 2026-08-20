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

/// 에어비앤비 호점 상세 — 거래 장부 + 통계(비용 세분화) + 월 선택.
class AirbnbDetailScreen extends ConsumerStatefulWidget {
  final String unitId;
  const AirbnbDetailScreen({super.key, required this.unitId});

  @override
  ConsumerState<AirbnbDetailScreen> createState() => _AirbnbDetailState();
}

class _AirbnbDetailState extends ConsumerState<AirbnbDetailScreen> {
  DateTime? _month; // null = 전체
  String _query = ''; // 거래 검색어

  static const _txnFields = [
    FieldSpec(key: 'txn_date', label: '날짜', type: FieldType.date, required: true),
    FieldSpec(key: 'nights', label: '박(숙박일)', type: FieldType.number),
    FieldSpec(key: 'payout', label: '정산금 (수익)', type: FieldType.money),
    FieldSpec(key: 'extra_income', label: '추가 지급', type: FieldType.money),
    FieldSpec(key: 'cleaning_cost', label: '청소비', type: FieldType.money),
    FieldSpec(key: 'variable_cost', label: '변동비 (비품·소모품)', type: FieldType.money),
    FieldSpec(key: 'fixed_cost', label: '고정비 (월세·공과금)', type: FieldType.money),
    FieldSpec(key: 'memo', label: '메모', type: FieldType.text),
  ];

  bool _inScope(AirbnbTransaction t) =>
      _month == null || (t.date.year == _month!.year && t.date.month == _month!.month);

  Future<void> _addOrEdit({AirbnbTransaction? txn}) async {
    final values = await showRecordForm(
      context,
      title: txn == null ? '거래 추가' : '거래 수정',
      fields: _txnFields,
      accent: AppColors.sky,
      initial: txn == null
          ? {
              'txn_date': (_month ?? DateTime.now())
                  .toIso8601String()
                  .substring(0, 10)
            }
          : {
              'txn_date': txn.date.toIso8601String().substring(0, 10),
              'nights': txn.nights,
              'payout': txn.payout,
              'extra_income': txn.extraIncome,
              'cleaning_cost': txn.cleaningCost,
              'variable_cost': txn.variableCost,
              'fixed_cost': txn.fixedCost,
              'memo': txn.memo,
            },
    );
    if (values == null) return;
    final sb = ref.read(supabaseProvider);
    final clean = Map<String, dynamic>.from(values)
      ..removeWhere((k, v) => v == null);
    if (txn == null) {
      clean['user_id'] = sb.auth.currentUser!.id;
      clean['unit_id'] = widget.unitId;
      await sb.from('airbnb_transactions').insert(clean);
    } else {
      await sb.from('airbnb_transactions').update(clean).eq('id', txn.id);
    }
    ref.invalidate(airbnbTransactionsProvider(widget.unitId));
    ref.invalidate(airbnbMonthlyProvider(widget.unitId));
  }

  Future<void> _delete(AirbnbTransaction t) async {
    if (!await confirmDelete(context, name: '${Dates.md(t.date)} 거래')) return;
    await ref.read(supabaseProvider).from('airbnb_transactions').delete().eq('id', t.id);
    ref.invalidate(airbnbTransactionsProvider(widget.unitId));
    ref.invalidate(airbnbMonthlyProvider(widget.unitId));
  }

  @override
  Widget build(BuildContext context) {
    final units = ref.watch(airbnbProvider).asData?.value ?? [];
    final unit = units
        .where((u) => u.id == widget.unitId)
        .cast<AirbnbUnit?>()
        .firstWhere((u) => true, orElse: () => null);
    final txnsAsync = ref.watch(airbnbTransactionsProvider(widget.unitId));
    final monthsAsync = ref.watch(airbnbMonthlyProvider(widget.unitId));
    final months = monthsAsync.asData?.value ?? [];

    return ModulePage(
      title: unit?.name ?? '호점 상세',
      icon: Icons.house_rounded,
      color: AppColors.sky,
      children: [
        // ── 월 선택 (전체 + 각 월) ──
        if (months.isNotEmpty)
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _MonthChip(
                  label: '전체',
                  selected: _month == null,
                  onTap: () => setState(() => _month = null),
                ),
                for (final m in months.reversed)
                  _MonthChip(
                    label: Dates.ym(m.month),
                    selected: _month != null &&
                        _month!.year == m.month.year &&
                        _month!.month == m.month.month,
                    onTap: () => setState(() => _month = m.month),
                  ),
              ],
            ),
          ),
        const Gap(16),
        txnsAsync.when(
          loading: AsyncStatus.loading,
          error: AsyncStatus.error,
          data: (all) {
            final txns = all.where(_inScope).toList();
            final revenue = txns.fold(0.0, (s, t) => s + t.revenue);
            final cleaning = txns.fold(0.0, (s, t) => s + t.cleaningCost);
            final variable = txns.fold(0.0, (s, t) => s + t.variableCost);
            final fixed = txns.fold(0.0, (s, t) => s + t.fixedCost);
            final cost = cleaning + variable + fixed;
            final net = revenue - cost;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ResponsiveGrid(
                  minTileWidth: 165,
                  ratio: 1.5,
                  children: [
                    StatTile(label: _month == null ? '누적 순이익' : '순이익',
                        value: '${Won.compact(net)}원',
                        icon: Icons.trending_up_rounded,
                        color: net >= 0 ? AppColors.primary : AppColors.rose),
                    StatTile(label: '매출',
                        value: '${Won.compact(revenue)}원',
                        icon: Icons.payments_rounded, color: AppColors.gold),
                    StatTile(label: '비용',
                        value: '${Won.compact(cost)}원',
                        icon: Icons.trending_down_rounded, color: AppColors.rose),
                  ],
                ),
                const Gap(16),
                // ── 비용 세분화 ──
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader('비용 세분화'),
                      const Gap(14),
                      _costRow('청소비', cleaning, cost, AppColors.sky),
                      _costRow('변동비 (비품·소모품)', variable, cost, AppColors.gold),
                      _costRow('고정비 (월세·공과금)', fixed, cost, AppColors.rose),
                    ],
                  ),
                ),
                const Gap(16),
                // ── 월별 순이익 (클릭 가능) ──
                if (months.isNotEmpty && _month == null)
                  _MonthlyBars(
                    months: months,
                    onTap: (m) => setState(() => _month = m),
                  ),
                if (months.isNotEmpty && _month == null) const Gap(16),
                // ── 거래 내역 (추가 버튼 내장) ──
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader('거래 내역',
                          subtitle: '${txns.length}건',
                          trailing: FilledButton.icon(
                            style: FilledButton.styleFrom(
                                backgroundColor: AppColors.sky,
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
                          hintText: '메모로 검색 (예: 청소, 에어컨)',
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
                        final shown = _query.trim().isEmpty
                            ? txns
                            : txns
                                .where((t) => (t.memo ?? '')
                                    .toLowerCase()
                                    .contains(_query.trim().toLowerCase()))
                                .toList();
                        if (shown.isEmpty) {
                          return EmptyState(
                              icon: Icons.receipt_long_rounded,
                              message: _query.isEmpty
                                  ? '거래를 추가하세요'
                                  : "'$_query' 검색 결과 없음");
                        }
                        return Column(
                          children: [
                            for (final t in shown)
                              _TxnRow(
                                txn: t,
                                onEdit: () => _addOrEdit(txn: t),
                                onDelete: () => _delete(t),
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

  Widget _costRow(String label, double val, double total, Color color) {
    final pct = total <= 0 ? 0.0 : val / total;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: AppFont.body)),
          ),
          Expanded(child: ProgressBar(value: pct, color: color)),
          const Gap(12),
          SizedBox(
            width: 90,
            child: Text('${Won.compact(val)}원',
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: AppFont.body)),
          ),
          SizedBox(
            width: 44,
            child: Text('${(pct * 100).toStringAsFixed(0)}%',
                textAlign: TextAlign.right,
                style: const TextStyle(
                    color: AppColors.textFaint, fontSize: AppFont.label)),
          ),
        ],
      ),
    );
  }
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
        color: selected ? AppColors.sky : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(label,
                style: TextStyle(
                    color: selected ? const Color(0xFF04130A) : AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: AppFont.label)),
          ),
        ),
      ),
    );
  }
}

class _MonthlyBars extends StatelessWidget {
  final List<AirbnbMonthly> months;
  final void Function(DateTime) onTap;
  const _MonthlyBars({required this.months, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final recent = months.length > 10 ? months.sublist(months.length - 10) : months;
    final maxAbs =
        recent.map((m) => m.netProfit.abs()).fold(1.0, (a, b) => a > b ? a : b);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader('월별 순이익', subtitle: '월을 눌러 상세 보기'),
          const Gap(16),
          SizedBox(
            height: 138,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final m in recent)
                  Expanded(
                    child: InkWell(
                      onTap: () => onTap(m.month),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('${Won.compact(m.netProfit)}원',
                                  style: TextStyle(
                                      color: m.netProfit >= 0
                                          ? AppColors.primary
                                          : AppColors.rose,
                                      fontSize: AppFont.label,
                                      fontWeight: FontWeight.w800)),
                            ),
                            const Gap(6),
                            Container(
                              height: (m.netProfit.abs() / maxAbs * 66).clamp(4, 66),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: m.netProfit >= 0
                                      ? const [AppColors.primary, Color(0xFF15803D)]
                                      : const [AppColors.rose, Color(0xFF9F1239)],
                                ),
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                            const Gap(7),
                            Text(Dates.ym(m.month),
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: AppFont.caption,
                                    fontWeight: FontWeight.w600)),
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

class _TxnRow extends StatelessWidget {
  final AirbnbTransaction txn;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _TxnRow({required this.txn, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final pos = txn.net >= 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(Dates.md(txn.date),
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: AppFont.label)),
          ),
          const Gap(8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  txn.memo?.isNotEmpty == true
                      ? txn.memo!
                      : (txn.nights > 0 ? '${txn.nights.toStringAsFixed(0)}박 예약' : '지출'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: AppFont.body),
                ),
                const Gap(2),
                Text(
                    '수익 ${Won.compact(txn.revenue)} · 청소 ${Won.compact(txn.cleaningCost)} · 변동 ${Won.compact(txn.variableCost)} · 고정 ${Won.compact(txn.fixedCost)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.textFaint, fontSize: AppFont.caption)),
              ],
            ),
          ),
          Text('${pos ? '+' : ''}${Won.compact(txn.net)}원',
              style: TextStyle(
                  color: pos ? AppColors.primary : AppColors.rose,
                  fontWeight: FontWeight.w800,
                  fontSize: AppFont.body)),
          RecordMenu(onEdit: onEdit, onDelete: onDelete),
        ],
      ),
    );
  }
}
