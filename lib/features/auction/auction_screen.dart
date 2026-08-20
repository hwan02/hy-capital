import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/data/data_providers.dart';
import '../../core/edit/builtin_crud.dart';
import '../../core/edit/builtin_specs.dart';
import '../../core/format/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../core/widgets/module_page.dart';
import '../../models/models.dart';
import 'package:go_router/go_router.dart';
import '../knowledge/knowledge_screen.dart';

const _teal = Color(0xFF14B8A6);

Future<void> _quickAdd(BuildContext context, WidgetRef ref) async {
  final c = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('경매 물건 추가', style: TextStyle(fontSize: AppFont.section)),
      content: TextField(
        controller: c,
        autofocus: true,
        decoration: const InputDecoration(
            labelText: '물건명 / 단지', hintText: '예: 인천 송도 더샵'),
        onSubmitted: (v) => Navigator.pop(context, v.trim()),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('취소')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _teal),
          onPressed: () => Navigator.pop(context, c.text.trim()),
          child: const Text('추가'),
        ),
      ],
    ),
  );
  if (name == null || name.isEmpty) return;
  try {
    final sb = ref.read(supabaseProvider);
    final row = await sb
        .from('auction_properties')
        .insert({
          'user_id': sb.auth.currentUser!.id,
          'title': name,
          'status': 'interest',
          'verdict': 'HOLD',
        })
        .select()
        .single();
    invalidateAll(ref);
    if (context.mounted) context.go('/auction/${row['id']}');
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('추가 실패: $e'), backgroundColor: AppColors.rose),
      );
    }
  }
}

const _statusLabel = {
  'interest': '관심',
  'researching': '조사중',
  'visited': '현장방문',
  'bidding': '입찰예정',
  'won': '낙찰',
  'sold': '매각완료',
  'pass': 'PASS',
};
const _statusColor = {
  'interest': AppColors.sky,
  'researching': AppColors.gold,
  'visited': _teal,
  'bidding': AppColors.violet,
  'won': AppColors.primary,
  'sold': AppColors.textFaint,
  'pass': AppColors.rose,
};

Color _verdictColor(String v) => switch (v) {
      'GO' => AppColors.primary,
      'PASS' => AppColors.rose,
      _ => AppColors.gold,
    };

class AuctionScreen extends ConsumerStatefulWidget {
  const AuctionScreen({super.key});

  @override
  ConsumerState<AuctionScreen> createState() => _AuctionScreenState();
}

class _AuctionScreenState extends ConsumerState<AuctionScreen> {
  String _filter = 'all'; // all | GO | <status>
  int _tab = 0; // 0=물건 · 1=자료실

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(auctionProvider);
    const amber = Color(0xFFF59E0B);
    return ModulePage(
      title: '경매',
      icon: Icons.gavel_rounded,
      color: _tab == 0 ? _teal : amber,
      action: _tab == 0
          ? AddButton(color: _teal, onTap: () => _quickAdd(context, ref))
          : const KnowledgeActions(),
      children: [
        // 물건 / 자료실 전환
        Row(children: [
          _TopTab(
              label: '물건',
              icon: Icons.gavel_rounded,
              color: _teal,
              selected: _tab == 0,
              onTap: () => setState(() => _tab = 0)),
          const Gap(8),
          _TopTab(
              label: '자료실',
              icon: Icons.menu_book_rounded,
              color: amber,
              selected: _tab == 1,
              onTap: () => setState(() => _tab = 1)),
        ]),
        const Gap(18),
        if (_tab == 1) const KnowledgeView(),
        if (_tab == 0)
          async.when(
          loading: AsyncStatus.loading,
          error: AsyncStatus.error,
          data: (items) {
            if (items.isEmpty) {
              return const EmptyState(
                icon: Icons.gavel_rounded,
                message: '등록된 경매 물건이 없어요.\n관심 물건을 추가해 투자 판단을 시작하세요.',
              );
            }
            final go = items.where((p) => p.verdict == 'GO').toList();
            final cashSum = go.fold(0.0, (s, p) => s + p.cashNeeded);
            final avgScore = items.isEmpty
                ? 0.0
                : items.fold(0.0, (s, p) => s + p.score) / items.length;

            final filtered = switch (_filter) {
              'all' => items,
              'GO' => items.where((p) => p.verdict == 'GO').toList(),
              final s => items.where((p) => p.status == s).toList(),
            };

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ResponsiveGrid(
                  minTileWidth: 160,
                  ratio: 1.5,
                  children: [
                    StatTile(
                      label: '관심 물건',
                      value: '${items.length}건',
                      icon: Icons.inventory_2_rounded,
                      color: _teal,
                    ),
                    StatTile(
                      label: 'GO 후보',
                      value: '${go.length}건',
                      icon: Icons.check_circle_rounded,
                      color: AppColors.primary,
                    ),
                    StatTile(
                      label: 'GO 총 필요현금',
                      value: '${Won.compact(cashSum)}원',
                      icon: Icons.account_balance_wallet_rounded,
                      color: AppColors.gold,
                    ),
                    StatTile(
                      label: '평균 투자점수',
                      value: avgScore.toStringAsFixed(0),
                      icon: Icons.speed_rounded,
                      color: AppColors.violet,
                    ),
                  ],
                ),
                const Gap(18),
                _FilterChips(
                  current: _filter,
                  onSelect: (f) => setState(() => _filter = f),
                ),
                const Gap(14),
                if (filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('해당 조건의 물건이 없어요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textFaint)),
                  ),
                for (final p in filtered) ...[
                  _AuctionCard(
                    p: p,
                    onOpen: () => context.go('/auction/${p.id}'),
                    onDelete: () => deleteBuiltinRecord(
                        context, ref, auctionSpec, p.id,
                        name: p.title),
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

class _FilterChips extends StatelessWidget {
  final String current;
  final ValueChanged<String> onSelect;
  const _FilterChips({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final chips = <(String, String)>[
      ('all', '전체'),
      ('GO', 'GO만'),
      ('interest', '관심'),
      ('researching', '조사중'),
      ('visited', '현장방문'),
      ('bidding', '입찰예정'),
      ('won', '낙찰'),
      ('sold', '매각완료'),
      ('pass', 'PASS'),
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (key, label) in chips)
          _Chip(
            label: label,
            selected: current == key,
            onTap: () => onSelect(key),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? _teal.withValues(alpha: 0.18) : Colors.transparent,
          border: Border.all(
              color: selected ? _teal : AppColors.border,
              width: selected ? 1.4 : 1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? _teal : AppColors.textSecondary,
                fontSize: AppFont.label,
                fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _AuctionCard extends StatefulWidget {
  final AuctionProperty p;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  const _AuctionCard(
      {required this.p, required this.onOpen, required this.onDelete});

  @override
  State<_AuctionCard> createState() => _AuctionCardState();
}

class _AuctionCardState extends State<_AuctionCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final onOpen = widget.onOpen;
    final onDelete = widget.onDelete;
    final vColor = _verdictColor(p.verdict);
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(16),
      child: GlassCard(
      accent: vColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: AppFont.section, fontWeight: FontWeight.w700)),
                    if ((p.address ?? '').isNotEmpty || (p.caseNo ?? '').isNotEmpty) ...[
                      const Gap(3),
                      Text(
                          [p.address, p.caseNo]
                              .where((e) => (e ?? '').isNotEmpty)
                              .join('  ·  '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.textFaint, fontSize: AppFont.label)),
                    ],
                  ],
                ),
              ),
              const Gap(8),
              Pill(_statusLabel[p.status] ?? p.status,
                  color: _statusColor[p.status] ?? AppColors.textFaint),
              const Gap(6),
              _ScorePill(score: p.score, verdict: p.verdict, color: vColor),
              RecordMenu(onEdit: onOpen, onDelete: onDelete),
            ],
          ),
          // 경고 배너
          if (p.overMaxBid || p.belowTarget) ...[
            const Gap(12),
            _Warn(
              text: p.overMaxBid
                  ? '입찰가가 최대입찰가(${Won.compact(p.maxBid)}원)를 초과 · 입찰 비추천'
                  : '예상순수익이 목표수익(${Won.compact(p.targetProfit)}원)에 미달',
            ),
          ],
          const Gap(12),
          Wrap(
            spacing: 22,
            runSpacing: 10,
            children: [
              _metric('현재시세', '${Won.compact(p.currentPrice)}원'),
              _metric('예상매도가', '${Won.compact(p.expectedSalePrice)}원'),
              _metric('예상입찰가', '${Won.compact(p.bidPrice)}원'),
              _metric('할인율', Pct.of(p.discountRate),
                  color: p.discountRate > 0 ? AppColors.primary : null),
              _metric('필요현금', '${Won.compact(p.cashNeeded)}원',
                  color: AppColors.gold),
              _metric('예상순수익', '${Won.compact(p.netProfit)}원',
                  color: p.netProfit >= 0 ? AppColors.primary : AppColors.rose),
              _metric('ROI', Pct.of(p.roi),
                  color: p.roi >= 0 ? AppColors.primary : AppColors.rose),
              _metric('최대입찰가', '${Won.compact(p.maxBid)}원',
                  color: AppColors.sky),
            ],
          ),
          if (_open && (p.memo ?? '').isNotEmpty) ...[
            const Gap(12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(p.memo!,
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: AppFont.label,
                      height: 1.55)),
            ),
          ],
          const Gap(10),
          Row(
            children: [
              if ((p.memo ?? '').isNotEmpty)
                InkWell(
                  onTap: () => setState(() => _open = !_open),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 3),
                    child: Row(children: [
                      Icon(
                          _open
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 16,
                          color: AppColors.textSecondary),
                      const Gap(3),
                      Text(_open ? '접기' : '추천포인트·입지·이력',
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: AppFont.label,
                              fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              const Spacer(),
              if (p.images.isNotEmpty) ...[
                const Icon(Icons.photo_library_rounded,
                    size: 13, color: AppColors.textFaint),
                const Gap(3),
                Text('${p.images.length}',
                    style: const TextStyle(
                        color: AppColors.textFaint, fontSize: AppFont.caption)),
                const Gap(8),
              ],
              const Text('상세 열기',
                  style: TextStyle(
                      color: _teal, fontSize: AppFont.label, fontWeight: FontWeight.w700)),
              const Icon(Icons.chevron_right_rounded, size: 16, color: _teal),
            ],
          ),
        ],
      ),
      ),
    );
  }

  Widget _metric(String label, String value, {Color? color}) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: AppFont.caption)),
          const Gap(3),
          Text(value,
              style: TextStyle(
                  fontSize: AppFont.section,
                  fontWeight: FontWeight.w800,
                  color: color ?? AppColors.textPrimary)),
        ],
      );
}

class _ScorePill extends StatelessWidget {
  final double score;
  final String verdict;
  final Color color;
  const _ScorePill(
      {required this.score, required this.verdict, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(verdict,
              style: TextStyle(
                  color: color, fontSize: AppFont.label, fontWeight: FontWeight.w900)),
          if (score > 0) ...[
            const Gap(6),
            Text('${score.toStringAsFixed(0)}점',
                style: TextStyle(
                    color: color, fontSize: AppFont.label, fontWeight: FontWeight.w700)),
          ],
        ],
      ),
    );
  }
}

class _Warn extends StatelessWidget {
  final String text;
  const _Warn({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.rose.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.rose.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.rose, size: 16),
          const Gap(8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: AppColors.rose,
                    fontSize: AppFont.label,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}


/// 경매 화면 상단 전환 탭 (물건 / 자료실).
class _TopTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _TopTab({
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
