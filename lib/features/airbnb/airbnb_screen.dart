import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import 'airbnb_month_chart.dart';
import '../../core/data/data_providers.dart';
import '../../core/edit/builtin_crud.dart';
import '../../core/edit/builtin_specs.dart';
import '../../core/format/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/module_page.dart';
import '../knowledge/knowledge_screen.dart';
import '../../models/models.dart';

Map<String, dynamic> _unitToMap(AirbnbUnit u) => {
      'name': u.name,
      'status': u.status,
      'reserve_fund': u.reserveFund,
      'target_fund': u.targetFund,
      'expected_open': u.expectedOpen?.toIso8601String().substring(0, 10),
      'monthly_profit': u.monthlyProfit,
      'monthly_target': u.monthlyTarget,
      'monthly_rent': u.monthlyRent,
    };

class AirbnbScreen extends ConsumerStatefulWidget {
  const AirbnbScreen({super.key});

  @override
  ConsumerState<AirbnbScreen> createState() => _AirbnbScreenState();
}

class _AirbnbScreenState extends ConsumerState<AirbnbScreen> {
  int _tab = 0; // 0=호점 · 1=자료실

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
  Widget build(BuildContext context) {
    final async = ref.watch(airbnbProvider);
    const amber = Color(0xFFF59E0B);
    return ModulePage(
      title: '에비',
      icon: Icons.house_rounded,
      color: _tab == 0 ? AppColors.sky : amber,
      action: _tab == 0
          ? AddButton(
              color: AppColors.sky,
              onTap: () => editBuiltinRecord(context, ref, airbnbSpec),
            )
          : const KnowledgeActions(defaultTag: '에어비앤비'),
      children: [
        // 호점 / 자료실 전환
        Wrap(spacing: 8, runSpacing: 8, children: [
          ModuleTab(
              label: '호점',
              icon: Icons.house_rounded,
              color: AppColors.sky,
              selected: _tab == 0,
              onTap: () => setState(() => _tab = 0)),
          ModuleTab(
              label: '자료실',
              icon: Icons.menu_book_rounded,
              color: amber,
              selected: _tab == 1,
              onTap: () => setState(() => _tab = 1)),
        ]),
        const Gap(18),
        if (_tab == 1) const KnowledgeView(onlyTag: '에어비앤비'),
        if (_tab == 0)
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

  /// 「157.4만」 — 이번 달 세 숫자는 소수 첫째 자리까지. Won.compact 는 100만
  /// 이상을 정수로 반올림해서 비용 157.4만·순이익 156.5만이 둘 다 「157만」으로
  /// 보여 «고장 난 것처럼» 보였다(10/19).
  static String _man(double v) => AirbnbMonthChart.man(v);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(airbnbMonthlyProvider(unitId));
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (months) {
        if (months.isEmpty) return const SizedBox.shrink();
        final recent = months.length > 6 ? months.sublist(months.length - 6) : months;
        // "이번 달" 은 실제 현재 달 기준 (내역 없으면 0).
        final now = DateTime.now();
        AirbnbMonthly? cur;
        for (final m in months) {
          if (m.month.year == now.year && m.month.month == now.month) cur = m;
        }
        final curRev = cur?.revenue ?? 0;
        final curCost = cur?.totalCost ?? 0;
        final curNet = cur?.netProfit ?? 0;
        final margin = curRev > 0 ? curNet / curRev * 100 : 0.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _m('이번 달 매출', _man(curRev), AppColors.gold,
                    cur == null ? null : '${cur.bookings}건 · ${cur.nights.toStringAsFixed(0)}박'),
                _m('이번 달 비용', _man(curCost), AppColors.rose,
                    curRev > 0 ? '매출의 ${(curCost / curRev * 100).toStringAsFixed(0)}%' : null),
                _m('이번 달 순이익', _man(curNet),
                    curNet >= 0 ? AppColors.primary : AppColors.rose,
                    curRev > 0 ? '순이익률 ${margin.toStringAsFixed(0)}%' : null),
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
            Row(children: [
              const Text('월별 손익',
                  style: TextStyle(fontSize: AppFont.body, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('월평균 순이익 ${_man(recent.fold(0.0, (s, m) => s + m.netProfit) / recent.length)}원',
                  style: const TextStyle(
                      fontSize: AppFont.caption, color: AppColors.textFaint)),
            ]),
            const Gap(10),
            AirbnbMonthChart(months: recent, highlight: now),
          ],
        );
      },
    );
  }

  Widget _m(String label, String won, Color color, String? sub) => Expanded(
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
            if (sub != null) ...[
              const Gap(2),
              Text(sub,
                  style: const TextStyle(
                      color: AppColors.textFaint, fontSize: AppFont.micro)),
            ],
          ],
        ),
      );
}
