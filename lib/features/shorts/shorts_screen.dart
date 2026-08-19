import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/data/data_providers.dart';
import '../../core/edit/builtin_crud.dart';
import '../../core/edit/builtin_specs.dart';
import '../../core/format/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/module_page.dart';
import '../../core/widgets/monthly_tracker.dart';
import '../../models/models.dart';

Map<String, dynamic> _channelToMap(ShortsChannel c) => {
      'name': c.name,
      'platform': c.platform,
      'link': c.link,
      'uploads': c.uploads,
      'views': c.views,
      'revenue': c.revenue,
      'net_profit': c.netProfit,
    };

class ShortsScreen extends ConsumerWidget {
  const ShortsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(shortsProvider);
    return ModulePage(
      title: 'Shorts',
      icon: Icons.play_circle_fill_rounded,
      color: AppColors.rose,
      action: AddButton(
        color: AppColors.rose,
        onTap: () => editBuiltinRecord(context, ref, shortsSpec),
      ),
      children: [
        async.when(
          loading: AsyncStatus.loading,
          error: AsyncStatus.error,
          data: (channels) {
            if (channels.isEmpty) {
              return const EmptyState(
                  icon: Icons.play_circle, message: '등록된 채널이 없습니다');
            }
            final revenue = channels.fold(0.0, (s, c) => s + c.revenue);
            final profit = channels.fold(0.0, (s, c) => s + c.netProfit);
            final views = channels.fold(0, (s, c) => s + c.views);
            final target = channels.fold(0.0, (s, c) => s + c.monthlyTarget);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MonthlyTracker(
                  category: 'shorts',
                  title: '숏폼 순이익',
                  target: target,
                  accent: AppColors.rose,
                ),
                const Gap(20),
                ResponsiveGrid(
                  minTileWidth: 160,
                  ratio: 1.3,
                  children: [
                    StatTile(
                      label: '총 매출',
                      value: '${Won.compact(revenue)}원',
                      icon: Icons.attach_money_rounded,
                      color: AppColors.gold,
                    ),
                    StatTile(
                      label: '총 순이익',
                      value: '${Won.compact(profit)}원',
                      icon: Icons.trending_up_rounded,
                      color: AppColors.primary,
                    ),
                    StatTile(
                      label: '누적 조회수',
                      value: NumberFormat.compact().format(views),
                      icon: Icons.visibility_rounded,
                      color: AppColors.sky,
                    ),
                    StatTile(
                      label: '채널 수',
                      value: '${channels.length}개',
                      icon: Icons.subscriptions_rounded,
                      color: AppColors.rose,
                    ),
                  ],
                ),
                const Gap(20),
                for (final c in channels) ...[
                  _ChannelCard(
                    channel: c,
                    onEdit: () => editBuiltinRecord(context, ref, shortsSpec,
                        initial: _channelToMap(c), id: c.id),
                    onDelete: () => deleteBuiltinRecord(
                        context, ref, shortsSpec, c.id,
                        name: c.name),
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

class _ChannelCard extends StatelessWidget {
  final ShortsChannel channel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _ChannelCard(
      {required this.channel, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      accent: AppColors.rose,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(channel.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              const Gap(10),
              Pill(channel.platform, color: AppColors.rose),
              if (channel.link?.isNotEmpty == true) ...[
                const Gap(8),
                InkWell(
                  onTap: () => launchUrl(Uri.parse(channel.link!),
                      mode: LaunchMode.externalApplication),
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Icon(Icons.link_rounded, size: 15, color: AppColors.sky),
                        Gap(3),
                        Text('채널 열기',
                            style: TextStyle(color: AppColors.sky, fontSize: 12.5)),
                      ],
                    ),
                  ),
                ),
              ],
              const Spacer(),
              RecordMenu(onEdit: onEdit, onDelete: onDelete),
            ],
          ),
          const Gap(16),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              _metric('업로드', '${channel.uploads}개'),
              _metric('조회수', NumberFormat.compact().format(channel.views)),
              _metric('매출', '${Won.compact(channel.revenue)}원'),
              _metric('순이익', '${Won.compact(channel.netProfit)}원'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 11.5)),
          const Gap(3),
          Text(value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        ],
      );
}
