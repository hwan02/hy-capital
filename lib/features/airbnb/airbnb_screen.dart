import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/data_providers.dart';
import '../../core/edit/builtin_crud.dart';
import '../../core/edit/builtin_specs.dart';
import '../../core/format/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/module_page.dart';
import '../../models/models.dart';

Map<String, dynamic> _unitToMap(AirbnbUnit u) => {
      'name': u.name,
      'status': u.status,
      'reserve_fund': u.reserveFund,
      'target_fund': u.targetFund,
      'expected_open': u.expectedOpen?.toIso8601String().substring(0, 10),
      'monthly_profit': u.monthlyProfit,
      'monthly_target': u.monthlyTarget,
    };

class AirbnbScreen extends ConsumerWidget {
  const AirbnbScreen({super.key});

  static const _statusLabel = {
    'open': '운영중',
    'preparing': '준비중',
    'planning': '계획',
  };
  static const _statusColor = {
    'open': AppColors.primary,
    'preparing': AppColors.gold,
    'planning': AppColors.textFaint,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(airbnbProvider);
    return ModulePage(
      title: 'Airbnb',
      icon: Icons.house_rounded,
      color: AppColors.sky,
      action: AddButton(
        color: AppColors.sky,
        onTap: () => editBuiltinRecord(context, ref, airbnbSpec),
      ),
      children: [
        async.when(
          loading: AsyncStatus.loading,
          error: AsyncStatus.error,
          data: (units) {
            if (units.isEmpty) {
              return const EmptyState(icon: Icons.house, message: '등록된 호점이 없습니다');
            }
            final summary = ref.watch(airbnbSummaryProvider).value;
            String won(double? v) => v == null ? '—' : '${Won.compact(v)}원';
            final latestLabel = summary?.latestMonth == null
                ? '최근 순이익'
                : '최근 순이익 (${summary!.latestMonth!.month}월)';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ResponsiveGrid(
                  minTileWidth: 160,
                  ratio: 1.5,
                  children: [
                    StatTile(
                      label: '누적 순이익',
                      value: won(summary?.totalNet),
                      icon: Icons.savings_rounded,
                      color: (summary?.totalNet ?? 0) >= 0
                          ? AppColors.primary
                          : AppColors.rose,
                    ),
                    StatTile(
                      label: '월평균 순이익',
                      value: won(summary?.avgMonthlyNet),
                      icon: Icons.trending_up_rounded,
                      color: AppColors.gold,
                    ),
                    StatTile(
                      label: latestLabel,
                      value: won(summary?.latestMonthNet),
                      icon: Icons.event_available_rounded,
                      color: AppColors.sky,
                    ),
                    StatTile(
                      label: '누적 매출',
                      value: won(summary?.totalRevenue),
                      icon: Icons.payments_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
                const Gap(20),
                for (final u in units) ...[
                  _UnitCard(
                    unit: u,
                    statusLabel: _statusLabel[u.status] ?? u.status,
                    statusColor: _statusColor[u.status] ?? AppColors.textFaint,
                    onEdit: () => editBuiltinRecord(context, ref, airbnbSpec,
                        initial: _unitToMap(u), id: u.id),
                    onOpen: () => context.go('/airbnb/${u.id}'),
                    onDelete: () => deleteBuiltinRecord(
                        context, ref, airbnbSpec, u.id,
                        name: u.name),
                  ),
                  const Gap(14),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _UnitCard extends StatelessWidget {
  final AirbnbUnit unit;
  final String statusLabel;
  final Color statusColor;
  final VoidCallback onEdit;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  const _UnitCard({
    required this.unit,
    required this.statusLabel,
    required this.statusColor,
    required this.onEdit,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      accent: statusColor,
      onTap: unit.status == 'open' ? onOpen : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(unit.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: AppFont.section, fontWeight: FontWeight.w700)),
              ),
              const Gap(10),
              Pill(statusLabel, color: statusColor),
              const Spacer(),
              if (unit.expectedOpen != null)
                Text('오픈 ${Dates.ymd(unit.expectedOpen!)}',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: AppFont.label)),
              RecordMenu(onEdit: onEdit, onDelete: onDelete),
            ],
          ),
          const Gap(16),
          if (unit.status != 'open') ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('준비금 ${Won.compact(unit.reserveFund)} / 목표 ${Won.compact(unit.targetFund)}원',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: AppFont.label)),
                Text('${(unit.progress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                        color: AppColors.sky, fontWeight: FontWeight.w800)),
              ],
            ),
            const Gap(8),
            ProgressBar(value: unit.progress, color: AppColors.sky),
          ] else ...[
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.sky.withValues(alpha: 0.16),
                  foregroundColor: AppColors.sky,
                  elevation: 0,
                ),
                onPressed: onOpen,
                icon: const Icon(Icons.receipt_long_rounded, size: 16),
                label: const Text('거래 장부·상세'),
              ),
            ),
            const Gap(4),
            _UnitMonthly(unitId: unit.id),
          ],
        ],
      ),
    );
  }
}

/// 오픈 호점의 월별 손익 (거래 장부 집계).
class _UnitMonthly extends ConsumerWidget {
  final String unitId;
  const _UnitMonthly({required this.unitId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(airbnbMonthlyProvider(unitId));
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (months) {
        if (months.isEmpty) return const SizedBox.shrink();
        final recent = months.length > 6 ? months.sublist(months.length - 6) : months;
        final maxAbs = recent
            .map((m) => m.netProfit.abs())
            .fold(1.0, (a, b) => a > b ? a : b);
        // "이번 달" 은 실제 현재 달 기준 (내역 없으면 0).
        final now = DateTime.now();
        AirbnbMonthly? cur;
        for (final m in months) {
          if (m.month.year == now.year && m.month.month == now.month) cur = m;
        }
        final curRev = cur?.revenue ?? 0;
        final curCost = cur?.totalCost ?? 0;
        final curNet = cur?.netProfit ?? 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _m('이번 달 매출', Won.compact(curRev), AppColors.gold),
                _m('이번 달 비용', Won.compact(curCost), AppColors.rose),
                _m('이번 달 순이익', Won.compact(curNet),
                    curNet >= 0 ? AppColors.primary : AppColors.rose),
              ],
            ),
            if (cur == null) ...[
              const Gap(8),
              Text('${now.month}월 거래 내역이 아직 없어요',
                  style: const TextStyle(
                      color: AppColors.textFaint, fontSize: AppFont.label)),
            ],
            const Gap(16),
            const Divider(color: AppColors.border, height: 1),
            const Gap(14),
            const Text('월별 순이익',
                style: TextStyle(fontSize: AppFont.body, fontWeight: FontWeight.w700)),
            const Gap(14),
            SizedBox(
              height: 116,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final m in recent)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${Won.compact(m.netProfit)}원',
                                style: TextStyle(
                                    color: m.netProfit >= 0
                                        ? AppColors.primary
                                        : AppColors.rose,
                                    fontSize: AppFont.label,
                                    fontWeight: FontWeight.w800)),
                            const Gap(6),
                            Container(
                              height: (m.netProfit.abs() / maxAbs * 66)
                                  .clamp(6, 66),
                              decoration: BoxDecoration(
                                color: m.netProfit >= 0
                                    ? AppColors.primary
                                    : AppColors.rose,
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                            const Gap(7),
                            Text(Dates.ym(m.month),
                                style: const TextStyle(
                                    color: AppColors.textFaint,
                                    fontSize: AppFont.caption)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _m(String label, String won, Color color) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: AppFont.caption)),
            const Gap(3),
            Text('$won원',
                style: TextStyle(
                    fontSize: AppFont.section, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
      );
}
