import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/data/data_providers.dart';
import '../../core/format/formatters.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/money_field.dart';
import '../../models/models.dart';

/// 부동산 경매 수익률 계산기 — 월세/전세/매도 3시나리오.
/// 계산 결과를 이력으로 저장/수정/삭제할 수 있다(calc_records).
class AuctionCalculator extends ConsumerStatefulWidget {
  const AuctionCalculator({super.key});

  @override
  ConsumerState<AuctionCalculator> createState() => _AuctionCalculatorState();
}

class _AuctionCalculatorState extends ConsumerState<AuctionCalculator> {
  final _label = TextEditingController();
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
    final sb = ref.read(supabaseProvider);
    final uid = sb.auth.currentUser?.id;
    if (uid == null) return;
    final body = {'label': _label.text.trim().isEmpty ? '계산 ${DateTime.now().toString().substring(5, 16)}' : _label.text.trim(), 'inputs': _inputs()};
    try {
      if (_editingId != null) {
        await sb.from('calc_records').update(body).eq('id', _editingId!);
      } else {
        final row = await sb.from('calc_records').insert({'user_id': uid, ...body}).select().single();
        _editingId = row['id'] as String;
      }
      ref.invalidate(calcRecordsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('계산 이력 저장됨'), backgroundColor: AppColors.gold));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('저장 실패: $e'), backgroundColor: AppColors.rose));
      }
    }
  }

  Future<void> _delete(String id) async {
    final sb = ref.read(supabaseProvider);
    await sb.from('calc_records').delete().eq('id', id);
    if (_editingId == id) _editingId = null;
    ref.invalidate(calcRecordsProvider);
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

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(calcRecordsProvider);
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
            Wrap(spacing: 10, runSpacing: 10, children: [
              _money('낙찰가', bid, (v) => setState(() => bid = v)),
              _pct('은행대출 비율', loanPct, (v) => setState(() => loanPct = v)),
              _money('입찰보증금', deposit, (v) => setState(() => deposit = v)),
              _pct('취득세율', acqPct, (v) => setState(() => acqPct = v)),
              _money('법무비용', legal, (v) => setState(() => legal = v)),
              _money('인수 보증금', takeover, (v) => setState(() => takeover = v)),
              _money('이사비(도비)', moving, (v) => setState(() => moving = v)),
              _money('미납관리비', unpaid, (v) => setState(() => unpaid = v)),
              _money('수리비', repair, (v) => setState(() => repair = v)),
              _money('중개비', agent, (v) => setState(() => agent = v)),
            ]),
            const Gap(14),
            _calc('은행대출', loan),
            _calc('취득세', acqTax),
            _calc('총비용', costTotal),
            const Divider(height: 20, color: AppColors.border),
            _calc('총자기자본', ownCapital, strong: true, color: AppColors.gold),
            _calc('총투자금액', totalInvest, strong: true, color: AppColors.gold),
          ]),
        ),
        const Gap(14),

        _scenario('월세', Icons.calendar_view_month_rounded, AppColors.sky,
          inputs: [
            _money('월세 보증금', wolDeposit, (v) => setState(() => wolDeposit = v)),
            _money('월세(월)', wolMonthly, (v) => setState(() => wolMonthly = v)),
            _pct('대출이자(연)', loanRate, (v) => setState(() => loanRate = v)),
            _money('관리·운영비', mgmt, (v) => setState(() => mgmt = v)),
            _money('기타지출', etc, (v) => setState(() => etc = v)),
          ],
          rows: [('실투자금', netWol, false), ('연 임대수입', incomeWol, false), ('대출이자(연)', loanInterest, false), ('연 순수익', profitWol, true)],
          tailLabel: '연 수익률', tailValue: '${yieldWol.toStringAsFixed(1)}%'),
        const Gap(14),

        _scenario('전세 (플피)', Icons.account_balance_wallet_rounded, AppColors.violet,
          inputs: [_money('전세 보증금', jeonse, (v) => setState(() => jeonse = v))],
          rows: [('총투자금액', totalInvest, false), ('전세 보증금', jeonse, false), (netJeonse <= 0 ? '플피 (남는 돈)' : '실투자금', netJeonse.abs(), true)],
          tailLabel: netJeonse <= 0 ? '판정' : '실투자금',
          tailValue: netJeonse <= 0 ? '플피 성공' : '${Won.compact(netJeonse)}원',
          tailColor: netJeonse <= 0 ? AppColors.primary : AppColors.gold),
        const Gap(14),

        _scenario('매도 (차익)', Icons.sell_rounded, AppColors.primary,
          inputs: [
            _money('매도 가격', sale, (v) => setState(() => sale = v)),
            _pct('양도세율', capGainPct, (v) => setState(() => capGainPct = v)),
          ],
          rows: [('총투자금액', totalInvest, false), ('시세차익(과표)', capGain, false), ('양도소득세', capTax, false), ('세후 시세차익', profitSale, true)],
          tailLabel: '세후 차익', tailValue: '${Won.compact(profitSale)}원',
          tailColor: profitSale >= 0 ? AppColors.primary : AppColors.rose),
        const Gap(22),

        // 이력
        const SectionHeader('계산 이력'),
        const Gap(10),
        history.when(
          loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Text('불러오기 실패: $e', style: const TextStyle(color: AppColors.rose)),
          data: (list) {
            if (list.isEmpty) {
              return const Text('저장된 계산이 없어요. 위에서 계산하고 «이력 저장»을 눌러보세요.',
                  style: TextStyle(color: AppColors.textFaint, fontSize: AppFont.label));
            }
            return Column(children: [for (final r in list) _historyRow(r)]);
          },
        ),
      ],
    );
  }

  Widget _historyRow(CalcRecord r) {
    final bidV = r.num_('bid');
    final cost = r.num_('acqPct') / 100 * bidV + r.num_('legal') + r.num_('takeover') + r.num_('moving') + r.num_('unpaid') + r.num_('repair') + r.num_('agent');
    final total = bidV + cost;
    final netJ = total - r.num_('jeonse');
    final editing = _editingId == r.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        accent: editing ? AppColors.gold : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.label.isEmpty ? '(무제)' : r.label,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: AppFont.body, fontWeight: FontWeight.w700)),
              const Gap(3),
              Text('낙찰 ${Won.compact(bidV)} · 총투자 ${Won.compact(total)} · '
                  '${netJ <= 0 ? "플피" : "전세실투 ${Won.compact(netJ)}"}',
                  style: const TextStyle(fontSize: AppFont.caption, color: AppColors.textSecondary)),
            ]),
          ),
          TextButton(
            onPressed: () => _load(r),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.gold, minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
            child: const Text('불러오기/수정'),
          ),
          IconButton(
            onPressed: () => _delete(r.id),
            icon: const Icon(Icons.delete_outline_rounded, size: 19, color: AppColors.textFaint),
            tooltip: '삭제',
          ),
        ]),
      ),
    );
  }

  Widget _scenario(String title, IconData icon, Color color,
      {required List<Widget> inputs,
      required List<(String, double, bool)> rows,
      required String tailLabel,
      required String tailValue,
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
        Wrap(spacing: 10, runSpacing: 10, children: inputs),
        const Gap(12),
        for (final (l, v, s) in rows) _calc(l, v, strong: s, color: s ? color : null),
        const Gap(6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
              color: (tailColor ?? color).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(tailLabel, style: TextStyle(fontSize: AppFont.label, fontWeight: FontWeight.w700, color: tailColor ?? color)),
            Text(tailValue, style: TextStyle(fontSize: AppFont.display, fontWeight: FontWeight.w900, color: tailColor ?? color)),
          ]),
        ),
      ]),
    );
  }

  Widget _money(String label, double value, ValueChanged<double> onChanged) =>
      SizedBox(
        width: 160,
        child: MoneyField(
            key: ValueKey('$label-$_revision'),
            label: label, initial: value, accent: AppColors.gold, onChanged: onChanged),
      );

  Widget _pct(String label, double value, ValueChanged<double> onChanged) =>
      SizedBox(
        width: 110,
        child: TextFormField(
          key: ValueKey('$label-$_revision'),
          initialValue: value == 0 ? '' : (value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toString()),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          decoration: InputDecoration(labelText: label, isDense: true, suffixText: '%'),
          onChanged: (v) => onChanged(double.tryParse(v) ?? 0),
        ),
      );

  Widget _calc(String label, double value, {bool strong = false, Color? color}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label,
              style: TextStyle(
                  fontSize: strong ? AppFont.body : AppFont.label,
                  fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
                  color: strong ? (color ?? AppColors.textPrimary) : AppColors.textSecondary)),
          Text('${Won.compact(value)}원',
              style: TextStyle(
                  fontSize: strong ? AppFont.section : AppFont.body,
                  fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
                  color: strong ? (color ?? AppColors.textPrimary) : AppColors.textPrimary)),
        ]),
      );
}
