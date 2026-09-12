import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/edit/plain_controller.dart';
import '../../core/format/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/module_page.dart';
import '../../models/models.dart';
import 'calc_fields.dart';
import 'calc_history.dart';

/// 부동산 경매 수익률 계산기 — 월세/전세/매도 3시나리오.
/// 계산 결과를 이력으로 저장/수정/삭제할 수 있다(calc_records).
class AuctionCalculator extends ConsumerStatefulWidget {
  const AuctionCalculator({super.key});

  @override
  ConsumerState<AuctionCalculator> createState() => _AuctionCalculatorState();
}

class _AuctionCalculatorState extends ConsumerState<AuctionCalculator> {
  final _label = PlainController();
  String? _editingId; // 수정 중인 이력 id (null이면 새 계산)
  int _revision = 0; // MoneyField 초기값 갱신용 key

  // 낙찰
  double bid = 0, loanPct = 80, deposit = 0;
  // 취득비용
  double acqPct = 1.1, legal = 0;
  // 기타비용
  double takeover = 0, moving = 0, unpaid = 0, repair = 0, agent = 0;
  // 수입
  double wolDeposit = 0, wolMonthly = 0, jeonse = 0, sale = 0;
  // 지출
  double loanRate = 3.5, mgmt = 0, capGainPct = 6, etc = 0;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Map<String, dynamic> _inputs() => {
        'bid': bid, 'loanPct': loanPct, 'deposit': deposit,
        'acqPct': acqPct, 'legal': legal,
        'takeover': takeover, 'moving': moving, 'unpaid': unpaid,
        'repair': repair, 'agent': agent,
        'wolDeposit': wolDeposit, 'wolMonthly': wolMonthly,
        'jeonse': jeonse, 'sale': sale,
        'loanRate': loanRate, 'mgmt': mgmt, 'capGainPct': capGainPct, 'etc': etc,
      };

  void _load(CalcRecord r) {
    setState(() {
      _editingId = r.id;
      _label.text = r.label;
      bid = r.num_('bid'); loanPct = r.num_('loanPct'); deposit = r.num_('deposit');
      acqPct = r.num_('acqPct'); legal = r.num_('legal');
      takeover = r.num_('takeover'); moving = r.num_('moving'); unpaid = r.num_('unpaid');
      repair = r.num_('repair'); agent = r.num_('agent');
      wolDeposit = r.num_('wolDeposit'); wolMonthly = r.num_('wolMonthly');
      jeonse = r.num_('jeonse'); sale = r.num_('sale');
      loanRate = r.num_('loanRate'); mgmt = r.num_('mgmt');
      capGainPct = r.num_('capGainPct'); etc = r.num_('etc');
      _revision++;
    });
  }

  void _reset() {
    setState(() {
      _editingId = null; _label.clear();
      bid = 0; loanPct = 80; deposit = 0; acqPct = 1.1; legal = 0;
      takeover = 0; moving = 0; unpaid = 0; repair = 0; agent = 0;
      wolDeposit = 0; wolMonthly = 0; jeonse = 0; sale = 0;
      loanRate = 3.5; mgmt = 0; capGainPct = 6; etc = 0;
      _revision++;
    });
  }

  Future<void> _save() async {
    final id = await saveCalcRecord(context, ref,
        kind: 'auction',
        label: _label.text,
        inputs: _inputs(),
        editingId: _editingId);
    if (mounted && id != null) setState(() => _editingId = id);
  }

  // ── 계산 ──
  double get loan => bid * loanPct / 100;
  double get acqTax => bid * acqPct / 100;
  double get costTotal => acqTax + legal + takeover + moving + unpaid + repair + agent;
  double get ownCapital => bid - loan + costTotal;
  double get totalInvest => bid + costTotal;
  double get netWol => ownCapital - wolDeposit;
  double get netJeonse => totalInvest - jeonse;
  double get incomeWol => wolMonthly * 12;
  double get loanInterest => loan * loanRate / 100;
  double get capGain => sale - totalInvest > 0 ? sale - totalInvest : 0;
  double get capTax => capGain * capGainPct / 100;
  double get profitWol => incomeWol - (loanInterest + mgmt + etc);
  double get yieldWol => netWol > 0 ? profitWol / netWol * 100 : 0;
  double get profitSale => sale - totalInvest - capTax;
  /// 매도 수익률 — 분모는 «실투자금»(내 돈). 월세 수익률과 같은 기준.
  double get yieldSale => ownCapital > 0 ? profitSale / ownCapital * 100 : 0;
  /// 전세가율. 갭투자 판단에 쓴다.
  double get jeonseRate => bid > 0 ? jeonse / bid * 100 : 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          const Expanded(
            child: Text('경매 수익률 계산기',
                style: TextStyle(
                    fontSize: AppFont.title, fontWeight: FontWeight.w800)),
          ),
          if (_editingId != null)
            TextButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.add_rounded, size: 16),
              style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
              label: const Text('새 계산'),
            ),
        ]),
        const Gap(2),
        Text(
            _editingId != null
                ? '이력 수정 중 — 저장하면 갱신됩니다'
                : '노란칸만 채우면 자동 계산 · 저장하면 아래 이력에 남습니다',
            style: const TextStyle(
                fontSize: AppFont.caption, color: AppColors.textFaint)),
        const Gap(14),

        // 라벨 + 저장
        Row(children: [
          Expanded(
            child: TextField(
              controller: _label,
              decoration: const InputDecoration(
                  labelText: '이름/사건번호 (예: 남성아트빌 601호 2025타경10958)',
                  isDense: true),
            ),
          ),
          const Gap(10),
          FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
            onPressed: _save,
            icon: const Icon(Icons.save_rounded, size: 18),
            label: Text(_editingId != null ? '수정 저장' : '이력 저장'),
          ),
        ]),
        const Gap(16),

        // 초기투자비
        GlassCard(
          accent: AppColors.gold,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionHeader('초기투자비'),
            const Gap(14),
            ResponsiveGrid(minTileWidth: 150, spacing: 10, children: [
              calcMoney('낙찰가', bid, (v) => setState(() => bid = v), _revision),
              calcPct('은행대출 비율', loanPct, (v) => setState(() => loanPct = v), _revision),
              calcPct('취득세율', acqPct, (v) => setState(() => acqPct = v), _revision),
              calcMoney('법무비용', legal, (v) => setState(() => legal = v), _revision),
              calcMoney('인수 보증금', takeover, (v) => setState(() => takeover = v), _revision),
              calcMoney('이사비(도비)', moving, (v) => setState(() => moving = v), _revision),
              calcMoney('미납관리비', unpaid, (v) => setState(() => unpaid = v), _revision),
              calcMoney('수리비', repair, (v) => setState(() => repair = v), _revision),
              calcMoney('중개비', agent, (v) => setState(() => agent = v), _revision),
            ]),
            const Gap(14),
            calcRow('입찰보증금 (낙찰가 10%)', bid * 0.1),
            calcRow('은행대출', loan),
            calcRow('취득세', acqTax),
            calcRow('총비용', costTotal),
            const Divider(height: 20, color: AppColors.border),
            calcRow('총자기자본', ownCapital, strong: true, color: AppColors.gold),
            calcRow('총투자금액', totalInvest, strong: true, color: AppColors.gold),
          ]),
        ),
        const Gap(14),

        _scenario('월세', Icons.calendar_view_month_rounded, AppColors.sky,
          inputs: [
            calcMoney('월세 보증금', wolDeposit, (v) => setState(() => wolDeposit = v), _revision),
            calcMoney('월세(월)', wolMonthly, (v) => setState(() => wolMonthly = v), _revision),
            calcPct('대출이자(연)', loanRate, (v) => setState(() => loanRate = v), _revision),
            calcMoney('관리·운영비', mgmt, (v) => setState(() => mgmt = v), _revision),
            calcMoney('기타지출', etc, (v) => setState(() => etc = v), _revision),
          ],
          rows: [('실투자금', netWol, false), ('연 임대수입', incomeWol, false), ('대출이자(연)', loanInterest, false), ('연 순수익', profitWol, true)],
          tailLabel: '연 수익률', tailValue: '${yieldWol.toStringAsFixed(1)}%'),
        const Gap(14),

        _scenario('전세 (플피)', Icons.account_balance_wallet_rounded, AppColors.violet,
          inputs: [calcMoney('전세 보증금', jeonse, (v) => setState(() => jeonse = v), _revision)],
          rows: [('총투자금액', totalInvest, false), ('전세 보증금', jeonse, false), (netJeonse <= 0 ? '플피 (남는 돈)' : '실투자금', netJeonse.abs(), true)],
          extra: bid > 0 ? calcTextRow('전세가율 (낙찰가 대비)', '${jeonseRate.toStringAsFixed(1)}%') : null,
          tailLabel: netJeonse <= 0 ? '판정' : '실투자금',
          tailValue: netJeonse <= 0 ? '플피 성공' : '${Won.compact(netJeonse)}원',
          tailColor: netJeonse <= 0 ? AppColors.primary : AppColors.gold),
        const Gap(14),

        _scenario('매도 (차익)', Icons.sell_rounded, AppColors.primary,
          inputs: [
            calcMoney('매도 가격', sale, (v) => setState(() => sale = v), _revision),
            calcPct('양도세율', capGainPct, (v) => setState(() => capGainPct = v), _revision),
          ],
          rows: [('총투자금액', totalInvest, false), ('시세차익(과표)', capGain, false), ('양도소득세', capTax, false), ('세후 시세차익', profitSale, true)],
          extra: calcTextRow('세후 수익률 (실투자금 대비)',
              ownCapital > 0 ? '${yieldSale.toStringAsFixed(1)}%' : '—'),
          tailLabel: '세후 차익', tailValue: '${Won.compact(profitSale)}원',
          tailColor: profitSale >= 0 ? AppColors.primary : AppColors.rose),
        const Gap(22),

        CalcHistory(
          kind: 'auction',
          editingId: _editingId,
          onLoad: _load,
          onDelete: (id) {
            if (_editingId == id) setState(() => _editingId = null);
            deleteCalcRecord(ref, id);
          },
          summary: _summary,
        ),
      ],
    );
  }

  String _summary(CalcRecord r) {
    final bidV = r.num_('bid');
    final cost = r.num_('acqPct') / 100 * bidV + r.num_('legal') + r.num_('takeover') +
        r.num_('moving') + r.num_('unpaid') + r.num_('repair') + r.num_('agent');
    final total = bidV + cost;
    final netJ = total - r.num_('jeonse');
    return '낙찰 ${Won.compact(bidV)} · 총투자 ${Won.compact(total)} · '
        '${netJ <= 0 ? "플피" : "전세실투 ${Won.compact(netJ)}"}';
  }

  Widget _scenario(String title, IconData icon, Color color,
      {required List<Widget> inputs,
      required List<(String, double, bool)> rows,
      required String tailLabel,
      required String tailValue,
      Widget? extra,
      Color? tailColor}) {
    return GlassCard(
      accent: color,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 18, color: color),
          const Gap(8),
          Text(title, style: const TextStyle(fontSize: AppFont.section, fontWeight: FontWeight.w800)),
        ]),
        const Gap(12),
        ResponsiveGrid(minTileWidth: 150, spacing: 10, children: inputs),
        const Gap(12),
        for (final (l, v, s) in rows) calcRow(l, v, strong: s, color: s ? color : null),
        ?extra,
        const Gap(6),
        calcTail(tailLabel, tailValue, tailColor ?? color),
      ]),
    );
  }
}
