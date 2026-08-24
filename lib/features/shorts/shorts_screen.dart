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
import 'shorts_calendar.dart';

Map<String, dynamic> _channelToMap(ShortsChannel c) => {
      'name': c.name,
      'platform': c.platform,
      'link': c.link,
      'uploads': c.uploads,
      'views': c.views,
      'revenue': c.revenue,
      'net_profit': c.netProfit,
    };

const _insta = Color(0xFFE1306C);

/// 팔로워 수 표기 (1.2만 / 350만 / 8,500).
String _followers(double v) {
  if (v >= 10000) {
    final man = v / 10000;
    final t = man >= 100 ? man.toStringAsFixed(0) : man.toStringAsFixed(1);
    return '${t.endsWith('.0') ? t.substring(0, t.length - 2) : t}만';
  }
  return v.round().toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
}

class ShortsScreen extends ConsumerStatefulWidget {
  const ShortsScreen({super.key});

  @override
  ConsumerState<ShortsScreen> createState() => _ShortsScreenState();
}

class _ShortsScreenState extends ConsumerState<ShortsScreen> {
  int _tab = 0; // 0=내 채널 · 1=롤모델 · 2=편성표

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(shortsProvider);
    return ModulePage(
      title: 'Shorts',
      icon: Icons.play_circle_fill_rounded,
      color: _tab == 0
          ? AppColors.rose
          : (_tab == 1 ? _insta : AppColors.gold),
      action: _tab == 0
          ? AddButton(
              color: AppColors.rose,
              onTap: () => editBuiltinRecord(context, ref, shortsSpec))
          : _tab == 1
              ? AddButton(
                  color: _insta,
                  label: '롤모델',
                  onTap: () =>
                      editBuiltinRecord(context, ref, referenceAccountSpec))
              : AddButton(
                  color: AppColors.rose,
                  label: '편성',
                  onTap: () =>
                      editBuiltinRecord(context, ref, shortsSlotSpec)),
      children: [
        Row(children: [
          _ShortsTab(
              label: '내 채널',
              icon: Icons.play_circle_fill_rounded,
              color: AppColors.rose,
              selected: _tab == 0,
              onTap: () => setState(() => _tab = 0)),
          const Gap(8),
          _ShortsTab(
              label: '롤모델',
              icon: Icons.star_rounded,
              color: _insta,
              selected: _tab == 1,
              onTap: () => setState(() => _tab = 1)),
          const Gap(8),
          _ShortsTab(
              label: '편성표',
              icon: Icons.calendar_month_rounded,
              color: AppColors.gold,
              selected: _tab == 2,
              onTap: () => setState(() => _tab = 2)),
        ]),
        const Gap(18),
        if (_tab == 2) const ShortsCalendar(),
        if (_tab == 1) const _RoleModelList(),
        if (_tab == 0)
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
    final hasLink = channel.link?.isNotEmpty == true;
    return GlassCard(
      accent: AppColors.rose,
      onTap: hasLink
          ? () => _openLink(channel.link!)
          : null,
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
                        fontSize: AppFont.body, fontWeight: FontWeight.w700)),
              ),
              const Gap(8),
              Pill(channel.platform, color: AppColors.rose),
              if (hasLink) ...[
                const Gap(6),
                const Icon(Icons.open_in_new_rounded,
                    size: 14, color: AppColors.sky),
              ],
              const Spacer(),
              RecordMenu(onEdit: onEdit, onDelete: onDelete),
            ],
          ),
          const Gap(10),
          Wrap(
            spacing: 20,
            runSpacing: 8,
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
                  color: AppColors.textSecondary, fontSize: AppFont.caption)),
          const Gap(3),
          Text(value,
              style: const TextStyle(fontSize: AppFont.body, fontWeight: FontWeight.w800)),
        ],
      );
}

/// Shorts 상단 전환 탭 (내 채널 / 롤모델).
class _ShortsTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _ShortsTab({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.16) : Colors.transparent,
          border: Border.all(
              color: selected ? color : AppColors.border,
              width: selected ? 1.4 : 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 17, color: selected ? color : AppColors.textFaint),
          const Gap(7),
          Text(label,
              style: TextStyle(
                  color: selected ? color : AppColors.textSecondary,
                  fontSize: AppFont.body,
                  fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}

/// 롤모델 계정 목록 — 플랫폼별 필터 + 링크 열기.
class _RoleModelList extends ConsumerStatefulWidget {
  const _RoleModelList();

  @override
  ConsumerState<_RoleModelList> createState() => _RoleModelListState();
}

class _RoleModelListState extends ConsumerState<_RoleModelList> {
  String _platform = '전체';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(referenceAccountsProvider);
    return async.when(
      loading: AsyncStatus.loading,
      error: AsyncStatus.error,
      data: (all) {
        if (all.isEmpty) {
          return const EmptyState(
            icon: Icons.star_outline_rounded,
            message: '롤모델 계정이 없어요.\n벤치마킹할 인스타·유튜브 계정을 추가하세요.',
          );
        }
        final platforms = <String>{for (final a in all) a.platform}.toList()
          ..sort();
        final list = _platform == '전체'
            ? all
            : all.where((a) => a.platform == _platform).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(spacing: 6, runSpacing: 6, children: [
              _pf('전체', all.length),
              for (final p in platforms)
                _pf(p, all.where((a) => a.platform == p).length),
            ]),
            const Gap(14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in list)
                  _RoleModelCard(
                    acct: a,
                    onEdit: () => editBuiltinRecord(
                        context, ref, referenceAccountSpec,
                        initial: {
                          'name': a.name,
                          'platform': a.platform,
                          'url': a.url,
                          'category': a.category,
                          'followers': a.followers,
                          'memo': a.memo,
                        },
                        id: a.id),
                    onDelete: () => deleteBuiltinRecord(
                        context, ref, referenceAccountSpec, a.id,
                        name: a.name),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _pf(String label, int n) {
    final sel = _platform == label;
    return InkWell(
      onTap: () => setState(() => _platform = label),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? _insta.withValues(alpha: 0.18) : Colors.transparent,
          border: Border.all(
              color: sel ? _insta : AppColors.border, width: sel ? 1.4 : 1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('$label $n',
            style: TextStyle(
                color: sel ? _insta : AppColors.textSecondary,
                fontSize: AppFont.label,
                fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _RoleModelCard extends StatelessWidget {
  final ReferenceAccount acct;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _RoleModelCard(
      {required this.acct, required this.onEdit, required this.onDelete});

  static const _pfColor = {
    'Instagram': _insta,
    'YouTube': AppColors.rose,
    'TikTok': AppColors.sky,
  };
  static const _pfIcon = {
    'Instagram': Icons.camera_alt_rounded,
    'YouTube': Icons.smart_display_rounded,
    'TikTok': Icons.music_note_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final c = _pfColor[acct.platform] ?? AppColors.textFaint;
    final hasUrl = (acct.url ?? '').isNotEmpty;
    return InkWell(
      onTap: hasUrl ? () => _openLink(acct.url!) : null,
      onLongPress: onEdit,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 7, 6, 7),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: c.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(_pfIcon[acct.platform] ?? Icons.public_rounded,
              size: 14, color: c),
          const Gap(6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 170),
            child: Text(acct.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: AppFont.label, fontWeight: FontWeight.w700)),
          ),
          if (acct.followers > 0) ...[
            const Gap(6),
            Text(_followers(acct.followers),
                style: const TextStyle(
                    color: AppColors.textFaint, fontSize: AppFont.micro)),
          ],
          if (hasUrl) ...[
            const Gap(5),
            Icon(Icons.open_in_new_rounded, size: 12, color: c),
          ],
          const Gap(2),
          PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            splashRadius: 14,
            constraints: const BoxConstraints(minWidth: 90),
            color: AppColors.surfaceAlt,
            onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', height: 36, child: Text('수정')),
              PopupMenuItem(value: 'delete', height: 36, child: Text('삭제')),
            ],
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 3, vertical: 2),
              child: Icon(Icons.more_horiz_rounded,
                  color: AppColors.textFaint, size: 15),
            ),
          ),
        ]),
      ),
    );
  }
}

/// 웹에서 새 탭으로 링크 열기. (Flutter web 은 webOnlyWindowName 없으면 새 창이 안 열린다)
Future<void> _openLink(String url) async {
  var u = url.trim();
  if (!u.startsWith('http')) u = 'https://$u';
  await launchUrl(
    Uri.parse(u),
    mode: LaunchMode.externalApplication,
    webOnlyWindowName: '_blank',
  );
}
