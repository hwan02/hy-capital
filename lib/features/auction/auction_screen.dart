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
import '../questions/lecture_questions_screen.dart';
import 'auction_paste.dart';
import '../property/criteria_screen.dart';
import '../property/inherit.dart';
import '../property/survey_screen.dart';

const _teal = Color(0xFF14B8A6);

/// 붙여넣기 한 판으로 물건을 등록한다. 사용자가 받는 카톡/사이트 텍스트에
/// 필요한 숫자가 다 들어있으므로 손입력을 최소화한다.
Future<void> _quickAdd(BuildContext context, WidgetRef ref) async {
  final c = TextEditingController();
  final res = await showDialog<(ParsedAuction, String)>(
    context: context,
    builder: (_) => _PasteDialog(controller: c),
  );
  if (res == null) return;
  final saved = res.$1;
  final acq = res.$2;
  try {
    final sb = ref.read(supabaseProvider);
    final row = await sb
        .from('auction_properties')
        .insert({
          'user_id': sb.auth.currentUser!.id,
          'title': saved.title ?? '이름 없는 물건',
          'status': 'interest',
          'verdict': 'HOLD',
          'acquisition': acq,
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
  String _acq = 'auction'; // auction=경매 · quick_sale=급매

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
              // 경매 / 급매 — 셈은 같고 이름만 다르다
              Row(children: [
                for (final a in const [
                  ('auction', '경매', Icons.gavel_rounded),
                  ('quick_sale', '급매', Icons.bolt_rounded),
                ]) ...[
                  InkWell(
                    onTap: () => setState(() => _acq = a.$1),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 13, vertical: 7),
                      decoration: BoxDecoration(
                        color: _acq == a.$1
                            ? (a.$1 == 'auction' ? _teal : AppColors.gold)
                                .withValues(alpha: 0.18)
                            : Colors.transparent,
                        border: Border.all(
                            color: _acq == a.$1
                                ? (a.$1 == 'auction' ? _teal : AppColors.gold)
                                : AppColors.border,
                            width: _acq == a.$1 ? 1.4 : 1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(a.$3,
                            size: 14,
                            color: _acq == a.$1
                                ? (a.$1 == 'auction' ? _teal : AppColors.gold)
                                : AppColors.textFaint),
                        const Gap(6),
                        Text(a.$2,
                            style: TextStyle(
                                fontSize: AppFont.label,
                                fontWeight: FontWeight.w800,
                                color: _acq == a.$1
                                    ? (a.$1 == 'auction'
                                        ? _teal
                                        : AppColors.gold)
                                    : AppColors.textSecondary)),
                      ]),
                    ),
                  ),
                  const Gap(6),
                ],
              ]),
              const Gap(10),
              Text(
                  _acq == 'auction'
                      ? '카톡으로 받은 글이나 경매사이트 화면을 그대로 붙여넣으세요.\n'
                          '사건번호·최저가·보증금·입찰일·법원을 자동으로 뽑습니다.'
                      : '임장에서 들은 급매를 넣으세요. 단지명과 «부르는 값»만 있으면 됩니다.\n'
                          '계약금은 호가의 10%로 잡고, 시세는 단지 시세조사에서 가져옵니다.',
                  style: const TextStyle(
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
                decoration: InputDecoration(
                    hintText: _acq == 'auction'
                        ? '여기에 붙여넣기 (물건명만 적어도 됩니다)'
                        : '예: 남성아트빌 401호 1억 2,800만'),
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
                _row(_acq == 'auction' ? '최저가' : '부르는 값',
                    _p.minPrice > 0 ? '${Won.compact(_p.minPrice)}원' : null),
                _row(
                    _acq == 'auction' ? '입찰보증금' : '계약금(10%)',
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
                  (_p.title != null
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
                        ), _acq)),
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
  int _tab = 0; // 0=매물 · 1=단지·시세 · 2=기준 · 3=자료실 · 4=강의 질문

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(auctionProvider);
    final surveys = ref.watch(latestSurveysProvider).asData?.value ??
        const <String, PriceSurvey>{};
    const amber = Color(0xFFF59E0B);
    const orange = Color(0xFFF97316); // 강의 질문
    return ModulePage(
      title: '부동산',
      icon: Icons.location_city_rounded,
      color: switch (_tab) {
        0 => _teal,
        1 => AppColors.sky,
        2 => amber,
        3 => amber,
        _ => orange
      },
      action: switch (_tab) {
        0 => AddButton(color: _teal, onTap: () => _quickAdd(context, ref)),
        1 => Row(mainAxisSize: MainAxisSize.min, children: [
              AddButton(
                  color: AppColors.violet,
                  label: '구역',
                  onTap: () => editBuiltinRecord(context, ref, zoneSpec)),
              const Gap(8),
              AddButton(
                  color: AppColors.sky,
                  label: '단지',
                  onTap: () => editBuiltinRecord(context, ref, complexSpec)),
            ]),
        3 => const KnowledgeActions(),
        _ => null,
      },
      children: [
        // 물건 / 자료실 / 강의 질문 전환 (좁은 화면에서 줄바꿈)
        Wrap(spacing: 8, runSpacing: 8, children: [
          ModuleTab(
              label: '매물',
              icon: Icons.gavel_rounded,
              color: _teal,
              selected: _tab == 0,
              onTap: () => setState(() => _tab = 0)),
          ModuleTab(
              label: '단지·시세',
              icon: Icons.domain_rounded,
              color: AppColors.sky,
              selected: _tab == 1,
              onTap: () => setState(() => _tab = 1)),
          ModuleTab(
              label: '기준',
              icon: Icons.rule_rounded,
              color: amber,
              selected: _tab == 2,
              onTap: () => setState(() => _tab = 2)),
          ModuleTab(
              label: '자료실',
              icon: Icons.menu_book_rounded,
              color: amber,
              selected: _tab == 3,
              onTap: () => setState(() => _tab = 3)),
          ModuleTab(
              label: '강의 질문',
              icon: Icons.live_help_rounded,
              color: orange,
              selected: _tab == 4,
              onTap: () => setState(() => _tab = 4)),
        ]),
        const Gap(18),
        if (_tab == 4) const LectureQuestionsView(),
        if (_tab == 3) const KnowledgeView(excludeTag: '에어비앤비'),
        if (_tab == 2) const CriteriaView(),
        if (_tab == 1) const SurveyView(),
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

            // 예산으로 걸러내지 않는다 — 살 물건을 찾으면 자금을 맞추는 순서다.
            // 보증금·계약금은 «필요한 돈»으로 카드에 보여주기만 한다.
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
                    price: effectivePrice(p, surveys),
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
  final EffectivePrice price; // 단지에서 상속받은 시세
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final ValueChanged<String> onSetVerdict; // 할래(GO)/보류(HOLD)/패스(PASS)
  const _AuctionCard(
      {required this.p,
      required this.price,
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
    final vColor = _verdictColor(p.verdict);
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
              Pill(p.isSim ? '모의' : '실제',
                  color: p.isSim ? AppColors.violet : AppColors.primary),
              const Gap(6),
              if (p.isQuickSale) ...[
                const Pill('급매', color: AppColors.gold),
                const Gap(6),
              ],
              if (p.isPlus) ...[
                const Pill('플피', color: AppColors.violet),
                const Gap(6),
              ],
              if (!p.isQuickSale && d != null) ...[
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
          if (widget.price.stale) ...[
            const Gap(12),
            _Warn(
                text: '단지 시세조사가 ${widget.price.ageDays}일 전 기록 · '
                    '단지·시세 탭에서 갱신하세요',
                color: AppColors.gold),
          ],
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
              _metric(
                  widget.price.fromComplex ? '현재시세 · 단지' : '현재시세',
                  widget.price.sale <= 0
                      ? '—'
                      : '${Won.compact(widget.price.sale)}원',
                  color: widget.price.fromComplex ? AppColors.sky : null),
              _metric('예상매도가', '${Won.compact(p.expectedSalePrice)}원'),
              _metric('예상입찰가', '${Won.compact(p.bidPrice)}원'),
              _metric('할인율', Pct.of(p.discountRate),
                  color: p.discountRate > 0 ? AppColors.primary : null),
              if (p.isPlus) ...[
                // 플피형은 ROI 가 아니라 실투자금을 본다.
                _metric(widget.price.fromComplex ? '전세 · 단지' : '전세',
                    widget.price.jeonse <= 0
                        ? '—'
                        : '${Won.compact(widget.price.jeonse)}원',
                    color: widget.price.jeonse >= p.bidPrice && p.bidPrice > 0
                        ? AppColors.primary
                        : (widget.price.fromComplex ? AppColors.sky : null)),
                _metric(p.ownCash <= 0 ? '플피' : '실투자금',
                    '${Won.compact(p.ownCash <= 0 ? p.plusPi : p.ownCash)}원',
                    color: p.ownCash <= 0 ? AppColors.primary : AppColors.gold),
              ] else
                _metric('필요현금', '${Won.compact(p.cashNeeded)}원',
                    color: AppColors.gold),
              _metric('예상순수익', '${Won.compact(p.netProfit)}원',
                  color: p.netProfit >= 0 ? AppColors.primary : AppColors.rose),
              _metric(p.depositLabel, '${Won.compact(p.depositDue)}원',
                  color: AppColors.gold),
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

