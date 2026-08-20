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

Map<String, dynamic> _landToMap(LandProject p) => {
      'name': p.name,
      'status': p.status,
      'principal': p.principal,
      'target_price': p.targetPrice,
      'reserve_fund': p.reserveFund,
      'target_fund': p.targetFund,
      'catalyst': p.catalyst,
      'analysis': p.analysis,
      'expert_opinion': p.expertOpinion,
    };

class LandScreen extends ConsumerWidget {
  const LandScreen({super.key});

  static const _statusLabel = {
    'reviewing': '검토중',
    'holding': '보유중',
    'sold': '매도완료',
  };
  static const _statusColor = {
    'reviewing': AppColors.gold,
    'holding': AppColors.primary,
    'sold': AppColors.textFaint,
  };
  static const _land = Color(0xFFB4844E);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(landProvider);
    return ModulePage(
      title: '토지',
      icon: Icons.terrain_rounded,
      color: _land,
      action: AddButton(
        color: _land,
        onTap: () => editBuiltinRecord(context, ref, landSpec),
      ),
      children: [
        async.when(
          loading: AsyncStatus.loading,
          error: AsyncStatus.error,
          data: (projects) {
            if (projects.isEmpty) {
              return const EmptyState(
                  icon: Icons.terrain, message: '등록된 토지 프로젝트가 없습니다');
            }
            final principal = projects.fold(0.0, (s, p) => s + p.principal);
            final target = projects.fold(0.0, (s, p) => s + p.targetPrice);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ResponsiveGrid(
                  minTileWidth: 160,
                  ratio: 1.5,
                  children: [
                    StatTile(
                      label: '투자 원금',
                      value: '${Won.compact(principal)}원',
                      icon: Icons.account_balance_wallet_rounded,
                      color: _land,
                    ),
                    StatTile(
                      label: '목표 매도가',
                      value: '${Won.compact(target)}원',
                      icon: Icons.sell_rounded,
                      color: AppColors.gold,
                    ),
                    StatTile(
                      label: '기대 수익률',
                      value: Pct.of(principal <= 0 ? 0 : (target - principal) / principal * 100),
                      icon: Icons.trending_up_rounded,
                      color: AppColors.primary,
                    ),
                  ],
                ),
                const Gap(20),
                for (final p in projects) ...[
                  _ProjectCard(
                    project: p,
                    statusLabel: _statusLabel[p.status] ?? p.status,
                    statusColor: _statusColor[p.status] ?? AppColors.textFaint,
                    onEdit: () => editBuiltinRecord(context, ref, landSpec,
                        initial: _landToMap(p), id: p.id),
                    onDelete: () => deleteBuiltinRecord(
                        context, ref, landSpec, p.id,
                        name: p.name),
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

class _ProjectCard extends StatelessWidget {
  final LandProject project;
  final String statusLabel;
  final Color statusColor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _ProjectCard({
    required this.project,
    required this.statusLabel,
    required this.statusColor,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      accent: statusColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(project.name,
                    style: const TextStyle(
                        fontSize: AppFont.section, fontWeight: FontWeight.w700)),
              ),
              Pill(statusLabel, color: statusColor),
              RecordMenu(onEdit: onEdit, onDelete: onDelete),
            ],
          ),
          const Gap(14),
          Row(
            children: [
              _metric('원금', '${Won.compact(project.principal)}원'),
              _metric('목표가', '${Won.compact(project.targetPrice)}원'),
              _metric('기대수익', Pct.of(project.expectedReturnPct)),
            ],
          ),
          if (project.targetFund > 0) ...[
            const Gap(16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                    '사업자금 ${Won.compact(project.reserveFund)} / 목표 ${Won.compact(project.targetFund)}원',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: AppFont.label)),
                Text('${(project.fundProgress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                        color: Color(0xFFB4844E),
                        fontWeight: FontWeight.w800)),
              ],
            ),
            const Gap(8),
            ProgressBar(value: project.fundProgress, color: const Color(0xFFB4844E)),
          ],
          if (project.catalyst != null) ...[
            const Gap(16),
            _row(Icons.rocket_launch_rounded, '개발호재', project.catalyst!),
          ],
          if (project.analysis != null) ...[
            const Gap(10),
            _row(Icons.analytics_rounded, '분석', project.analysis!),
          ],
          if (project.expertOpinion != null) ...[
            const Gap(10),
            _row(Icons.verified_rounded, '전문가 의견', project.expertOpinion!),
          ],
        ],
      ),
    );
  }

  Widget _metric(String label, String value) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: AppFont.caption)),
            const Gap(3),
            Text(value,
                style:
                    const TextStyle(fontSize: AppFont.section, fontWeight: FontWeight.w800)),
          ],
        ),
      );

  Widget _row(IconData icon, String label, String value) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppColors.textFaint),
          const Gap(8),
          Text('$label  ',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: AppFont.label)),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: AppFont.label, height: 1.4)),
          ),
        ],
      );
}
