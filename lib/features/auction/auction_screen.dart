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
import '../../core/widgets/money_field.dart';
import '../../core/widgets/module_page.dart';
import '../../models/models.dart';
import 'package:go_router/go_router.dart';
import '../knowledge/knowledge_screen.dart';
import '../questions/lecture_questions_screen.dart';
import 'auction_paste.dart';

const _teal = Color(0xFF14B8A6);

/// 붙여넣기 한 판으로 물건을 등록한다. 사용자가 받는 카톡/사이트 텍스트에
/// 필요한 숫자가 다 들어있으므로 손입력을 최소화한다.
Future<void> _quickAdd(BuildContext context, WidgetRef ref) async {
  final c = TextEditingController();
  final saved = await showDialog<ParsedAuction>(
    context: context,
    builder: (_) => _PasteDialog(controller: c),
  );
  if (saved == null) return;
  try {
    final sb = ref.read(supabaseProvider);
    final row = await sb
        .from('auction_properties')
        .insert({
          'user_id': sb.auth.currentUser!.id,
          'title': saved.title ?? '이름 없는 물건',
          'status': 'interest',
          'verdict': 'HOLD',
          if (saved.caseNo != null) 'case_no': saved.caseNo,
          if (saved.address != null) 'address': saved.address,
          if (saved.court != null) 'court': saved.court,
          if (saved.propertyKind != null) 'property_kind': saved.propertyKind,
          if (saved.appraisalPrice > 0) 'appraisal_price': saved.appraisalPrice,
          if (saved.minPrice > 0) 'min_price': saved.minPrice,
          if (saved.depositOrTenth > 0) 'deposit': saved.depositOrTenth,
          if (saved.bidDate != null)
            'bid_date': saved.bidDate!.toUtc().toIso8601String(),
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

/// 텍스트를 붙여넣으면 아래에 파싱 결과를 즉시 미리보기로 보여준다.
class _PasteDialog extends StatefulWidget {
  final TextEditingController controller;
  const _PasteDialog({required this.controller});

  @override
  State<_PasteDialog> createState() => _PasteDialogState();
}

class _PasteDialogState extends State<_PasteDialog> {
  ParsedAuction _p = const ParsedAuction();

  @override
  Widget build(BuildContext context) {
    final t = widget.controller.text.trim();
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('경매 물건 추가',
          style: TextStyle(fontSize: AppFont.section)),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                  '카톡으로 받은 글이나 경매사이트 화면을 그대로 붙여넣으세요.\n'
                  '사건번호·최저가·보증금·입찰일·법원을 자동으로 뽑습니다.',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: AppFont.label,
                      height: 1.5)),
              const Gap(12),
              TextField(
                controller: widget.controller,
                autofocus: true,
                maxLines: 7,
                minLines: 4,
                style: const TextStyle(fontSize: AppFont.label, height: 1.45),
                onChanged: (v) =>
                    setState(() => _p = parseAuctionText(v)),
                decoration: const InputDecoration(
                    hintText: '여기에 붙여넣기 (물건명만 적어도 됩니다)'),
              ),
              if (t.isNotEmpty) ...[
                const Gap(14),
                Row(children: [
                  Text('읽어낸 값 ${_p.filledCount}/8',
                      style: const TextStyle(
                          color: _teal,
                          fontSize: AppFont.label,
                          fontWeight: FontWeight.w800)),
                  const Gap(8),
                  const Expanded(
                    child: Text('빈 칸은 등록 후 상세에서 채우면 됩니다',
                        style: TextStyle(
                            color: AppColors.textFaint,
                            fontSize: AppFont.caption)),
                  ),
                ]),
                const Gap(8),
                _row('물건명', _p.title),
                _row('사건번호', _p.caseNo),
                _row('주소', _p.address),
                _row('종류', _p.propertyKind),
                _row('감정가',
                    _p.appraisalPrice > 0 ? '${Won.compact(_p.appraisalPrice)}원' : null),
                _row('최저가',
                    _p.minPrice > 0 ? '${Won.compact(_p.minPrice)}원' : null),
                _row(
                    '입찰보증금',
                    _p.depositOrTenth > 0
                        ? '${Won.compact(_p.depositOrTenth)}원'
                            '${_p.deposit > 0 ? "" : " (최저가 10% 추정)"}'
                        : null),
                _row('입찰일', _p.bidDate == null
                    ? null
                    : '${_p.bidDate!.year}.${_p.bidDate!.month}.${_p.bidDate!.day}'
                        ' ${_p.bidDate!.hour}시'),
                _row('법원', _p.court),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('취소')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _teal),
          onPressed: t.isEmpty
              ? null
              : () => Navigator.pop(
                  context,
                  // 파싱이 물건명을 못 잡았으면 입력한 텍스트 첫 줄을 쓴다.
                  _p.title != null
                      ? _p
                      : ParsedAuction(
                          title: t.split('\n').first.trim(),
                          caseNo: _p.caseNo,
                          address: _p.address,
                          court: _p.court,
                          propertyKind: _p.propertyKind,
                          appraisalPrice: _p.appraisalPrice,
                          minPrice: _p.minPrice,
                          deposit: _p.deposit,
                          bidDate: _p.bidDate,
                          areaSqm: _p.areaSqm,
                        )),
          child: const Text('추가'),
        ),
      ],
    );
  }

  Widget _row(String label, String? value) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 72,
              child: Text(label,
                  style: const TextStyle(
                      color: AppColors.textFaint, fontSize: AppFont.caption)),
            ),
            Expanded(
              child: Text(value ?? '—',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: AppFont.caption,
                      fontWeight:
                          value == null ? FontWeight.w400 : FontWeight.w700,
                      color: value == null
                          ? AppColors.textFaint
                          : AppColors.textPrimary)),
            ),
          ],
        ),
      );
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
  int _tab = 0; // 0=물건 · 1=자료실 · 2=강의 질문

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(auctionProvider);
    final cash = ref.watch(availableCashProvider).asData?.value ?? 0;
    const amber = Color(0xFFF59E0B);
    const orange = Color(0xFFF97316); // 강의 질문
    return ModulePage(
      title: '부동산',
      icon: Icons.location_city_rounded,
      color: switch (_tab) { 0 => _teal, 1 => amber, _ => orange },
      action: switch (_tab) {
        0 => AddButton(color: _teal, onTap: () => _quickAdd(context, ref)),
        1 => const KnowledgeActions(),
        _ => null,
      },
      children: [
        // 물건 / 자료실 / 강의 질문 전환 (좁은 화면에서 줄바꿈)
        Wrap(spacing: 8, runSpacing: 8, children: [
          ModuleTab(
              label: '물건',
              icon: Icons.gavel_rounded,
              color: _teal,
              selected: _tab == 0,
              onTap: () => setState(() => _tab = 0)),
          ModuleTab(
              label: '자료실',
              icon: Icons.menu_book_rounded,
              color: amber,
              selected: _tab == 1,
              onTap: () => setState(() => _tab = 1)),
          ModuleTab(
              label: '강의 질문',
              icon: Icons.live_help_rounded,
              color: orange,
              selected: _tab == 2,
              onTap: () => setState(() => _tab = 2)),
        ]),
        const Gap(18),
        if (_tab == 2) const LectureQuestionsView(),
        if (_tab == 1) const KnowledgeView(excludeTag: '에어비앤비'),
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

            final byFilter = switch (_filter) {
              'all' => items,
              'GO' => items.where((p) => p.verdict == 'GO').toList(),
              final s => items.where((p) => p.status == s).toList(),
            }.toList()
              // 입찰일 임박순. 날짜 없는 건 뒤로, 지난 건 맨 뒤로.
              ..sort((a, b) {
                final da = a.daysToBid, db = b.daysToBid;
                int rank(int? d) => d == null ? 1 : (d < 0 ? 2 : 0);
                final r = rank(da).compareTo(rank(db));
                if (r != 0) return r;
                if (da == null || db == null) return 0;
                return da.compareTo(db);
              });

            // 자금 게이트는 '참고용' — 리스트는 숨기지 않고 전부 보여준다.
            // (정보성으로 물건을 모으는 단계라 예산 초과도 그대로 노출)
            final shortList =
                byFilter.where((p) => p.cashShort(cash)).toList();
            final filtered = byFilter;

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
                const Gap(12),
                _CashBanner(
                  cash: cash,
                  shortCount: shortList.length,
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
                    cash: cash,
                    onOpen: () => context.go('/auction/${p.id}'),
                    onDelete: () => deleteBuiltinRecord(
                        context, ref, auctionSpec, p.id,
                        name: p.title),
                    onSetVerdict: (v) async {
                      final sb = ref.read(supabaseProvider);
                      await sb
                          .from('auction_properties')
                          .update({'verdict': v}).eq('id', p.id);
                      invalidateAll(ref);
                    },
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
  final double cash; // 가용현금 — 자금 게이트 기준(참고용)
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final ValueChanged<String> onSetVerdict; // 할래(GO)/보류(HOLD)/패스(PASS)
  const _AuctionCard(
      {required this.p,
      required this.cash,
      required this.onOpen,
      required this.onDelete,
      required this.onSetVerdict});

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
    final short = p.cashShort(widget.cash);
    final vColor = short ? AppColors.textFaint : _verdictColor(p.verdict);
    final d = p.daysToBid;
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
              if (p.isPlus) ...[
                const Pill('플피', color: AppColors.violet),
                const Gap(6),
              ],
              if (d != null) ...[
                Pill(
                    p.bidPassed
                        ? '입찰 종료'
                        : (d == 0 ? '오늘 입찰' : 'D-$d'),
                    color: p.bidPassed
                        ? AppColors.textFaint
                        : (d <= 7 ? AppColors.rose : AppColors.violet)),
                const Gap(6),
              ],
              Pill(_statusLabel[p.status] ?? p.status,
                  color: _statusColor[p.status] ?? AppColors.textFaint),
              const Gap(6),
              _ScorePill(score: p.score, verdict: p.verdict, color: vColor),
              RecordMenu(onEdit: onOpen, onDelete: onDelete),
            ],
          ),
          // 자금 게이트 — 보증금이 안 되면 조사할 이유가 없다.
          if (short) ...[
            const Gap(12),
            _Warn(
              text: '입찰보증금 ${Won.compact(p.depositDue)}원 · '
                  '매수 예산 ${Won.compact(widget.cash)}원 → '
                  '${Won.compact(p.shortfall(widget.cash))}원 부족',
              color: AppColors.textFaint,
            ),
          ],
          // 경고 배너
          if (!short && (p.overMaxBid || p.belowTarget)) ...[
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
              if (p.isPlus) ...[
                // 플피형은 ROI 가 아니라 실투자금을 본다.
                _metric('전세', '${Won.compact(p.jeonsePrice)}원',
                    color: p.jeonseCoversBid ? AppColors.primary : null),
                _metric(p.ownCash <= 0 ? '플피' : '실투자금',
                    '${Won.compact(p.ownCash <= 0 ? p.plusPi : p.ownCash)}원',
                    color: p.ownCash <= 0 ? AppColors.primary : AppColors.gold),
              ] else
                _metric('필요현금', '${Won.compact(p.cashNeeded)}원',
                    color: AppColors.gold),
              _metric('예상순수익', '${Won.compact(p.netProfit)}원',
                  color: p.netProfit >= 0 ? AppColors.primary : AppColors.rose),
              if (!p.isPlus)
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
          const Gap(12),
          Row(children: [
            const Text('할까?',
                style: TextStyle(
                    fontSize: AppFont.label,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700)),
            const Gap(10),
            _vChip('GO', '할래'),
            const Gap(6),
            _vChip('HOLD', '보류'),
            const Gap(6),
            _vChip('PASS', '패스'),
          ]),
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

  Widget _vChip(String v, String label) {
    final on = widget.p.verdict == v;
    final c = _verdictColor(v);
    return GestureDetector(
      onTap: () => widget.onSetVerdict(v),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: on ? c.withValues(alpha: 0.18) : Colors.transparent,
          border: Border.all(color: on ? c : AppColors.border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                color: on ? c : AppColors.textSecondary,
                fontSize: AppFont.label,
                fontWeight: FontWeight.w800)),
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
  final Color? color;
  const _Warn({required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.rose;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(
              color == null
                  ? Icons.warning_amber_rounded
                  : Icons.account_balance_wallet_rounded,
              color: c,
              size: 16),
          const Gap(8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: c,
                    fontSize: AppFont.label,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}


/// 경매 화면 상단 전환 탭 (물건 / 자료실).

/// 가용현금 기준선 배너 — 내 돈으로 어디까지 입찰이 되는지 한 줄로 알려준다.
/// 자금부족으로 접힌 물건이 있으면 여기서 펼친다.
class _CashBanner extends ConsumerWidget {
  final double cash;
  final int shortCount;
  const _CashBanner({
    required this.cash,
    required this.shortCount,
  });

  /// 경매에 쓸 돈을 직접 입력한다. 전체 현금과 분리된 값.
  Future<void> _editBudget(
      BuildContext context, WidgetRef ref, double current) async {
    // MoneyField 가 콤마·환산을 처리하고, 값은 이 컨트롤러로 받는다.
    final c = TextEditingController(
        text: current > 0 ? current.toStringAsFixed(0) : '');
    final v = await showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('매수에 쓸 돈',
            style: TextStyle(fontSize: AppFont.section)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                '전체 현금이 아니라 «부동산 매수에만» 쓸 수 있는 금액을 넣으세요.\n'
                '이 값으로 물건마다 보증금이 되는지 판정합니다.',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: AppFont.label,
                    height: 1.5)),
            const Gap(14),
            MoneyField(
              label: '매수에 쓸 금액',
              initial: current,
              autofocus: true,
              accent: AppColors.gold,
              onChanged: (v) => c.text = v.toStringAsFixed(0),
              onSubmitted: (v) => Navigator.pop(context, v),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('취소')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.gold),
            onPressed: () => Navigator.pop(context, moneyValue(c.text)),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (v == null) return;
    final sb = ref.read(supabaseProvider);
    final uid = sb.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await sb
          .from('profiles')
          .update({'auction_budget': v}).eq('id', uid);
      invalidateAll(ref);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('저장 실패: $e'), backgroundColor: AppColors.rose));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (cash <= 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          const Icon(Icons.info_outline_rounded,
              size: 15, color: AppColors.textFaint),
          const Gap(8),
          const Expanded(
            child: Text('매수 예산을 정하면 매물마다 「보증금·계약금이 되는지」 자동으로 판정해요.',
                style: TextStyle(
                    color: AppColors.textFaint, fontSize: AppFont.label)),
          ),
          TextButton(
            onPressed: () => _editBudget(context, ref, 0),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.gold,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            child: const Text('설정',
                style: TextStyle(
                    fontSize: AppFont.label, fontWeight: FontWeight.w800)),
          ),
        ]),
      );
    }
    // 보증금이 최저가의 10% 라는 통상 기준 → 접근 가능한 최저가 상한.
    final maxMin = cash * 10;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          InkWell(
            onTap: () => _editBudget(context, ref, cash),
            borderRadius: BorderRadius.circular(7),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.account_balance_wallet_rounded,
                  size: 15, color: AppColors.gold),
              const Gap(8),
              Text('매수 예산 ${Won.compact(cash)}원',
                  style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: AppFont.label,
                      fontWeight: FontWeight.w800)),
              const Gap(4),
              const Icon(Icons.edit_rounded, size: 12, color: AppColors.gold),
            ]),
          ),
          Text('보증금 10% 기준 · 최저가 ${Won.compact(maxMin)}원까지 입찰 가능',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: AppFont.label)),
          if (shortCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.info_outline_rounded,
                    size: 13, color: AppColors.textFaint),
                const Gap(6),
                Text('예산 초과 $shortCount건 (참고용 · 숨기지 않음)',
                    style: const TextStyle(
                        color: AppColors.textFaint,
                        fontSize: AppFont.label,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
        ],
      ),
    );
  }
}
