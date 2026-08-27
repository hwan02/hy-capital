import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';

import '../../core/format/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/money_field.dart';

/// 부동산 경매 수익률 계산기 (독립형) — 낙찰가·비용을 넣으면
/// 총자기자본·실투자금·순수익·수익률을 월세/전세/매도 3시나리오로 계산.
/// 물건에 종속되지 않는 스크래치 계산기(저장 없음).
class AuctionCalculator extends StatefulWidget {
  const AuctionCalculator({super.key});

  @override
  State<AuctionCalculator> createState() => _AuctionCalculatorState();
}

class _AuctionCalculatorState extends State<AuctionCalculator> {
  // 낙찰
  double bid = 0; // 낙찰가
  double loanPct = 80; // 은행대출 비율 %
  double deposit = 0; // 입찰보증금
  // 취득비용
  double acqPct = 4.6; // 취득세율 %
  double legal = 0; // 법무비용
  // 기타비용
  double takeover = 0; // 인수 보증금
  double moving = 0; // 도비(이사비)
  double unpaid = 0; // 미납 관리비
  double repair = 0; // 수리비
  double agent = 0; // 중개비
  // 수입
  double wolDeposit = 0; // 월세 보증금
  double wolMonthly = 0; // 월세(월)
  double jeonse = 0; // 전세 보증금
  double sale = 0; // 매도가격
  // 지출
  double loanRate = 3.5; // 대출이자(연) %
  double mgmt = 0; // 관리·운영비
  double capGainPct = 6; // 양도소득세율 %
  double etc = 0; // 기타지출

  // ── 초기투자비 계산 ──
  double get loan => bid * loanPct / 100; // 은행대출
  double get balance => bid - deposit; // 증금 제외 잔금
  double get acqTax => bid * acqPct / 100; // 취득세
  double get acqTotal => acqTax + legal; // 취득비용 합
  double get etcTotal => takeover + moving + unpaid + repair + agent; // 기타비용 합
  double get costTotal => acqTotal + etcTotal; // 총비용
  double get ownCapital => bid - loan + costTotal; // 총자기자본(대출 사용)
  double get totalInvest => bid + costTotal; // 총투자금액(대출 미사용 기준)
  double get netWol => ownCapital - wolDeposit; // 실투자금(월세: 대출+월세보증금)
  double get netJeonse => totalInvest - jeonse; // 실투자금(전세: 전세가 대출 대체)

  // ── 수입 ──
  double get incomeWol => wolMonthly * 12; // 월세 연 임대수입
  double get incomeJeonse => jeonse; // 전세 총수입(보증금)
  double get incomeSale => sale; // 매도 총수입

  // ── 지출 ──
  double get loanInterest => loan * loanRate / 100; // 대출이자(연) — 월세 시나리오
  double get capGain => sale - totalInvest > 0 ? sale - totalInvest : 0; // 시세차익(양도세 과표)
  double get capTax => capGain * capGainPct / 100; // 양도소득세
  double get expWol => loanInterest + mgmt + etc;
  double get expJeonse => mgmt + etc; // 전세는 대출이자 없음
  double get expSale => capTax + etc;

  // ── 수익 ──
  double get profitWol => incomeWol - expWol; // 월세 연 순수익
  double get yieldWol => netWol > 0 ? profitWol / netWol * 100 : 0; // 월세 수익률
  double get profitSale => sale - totalInvest - capTax; // 매도 시세차익(세후)

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('부동산 경매 수익률 계산기',
            style:
                TextStyle(fontSize: AppFont.title, fontWeight: FontWeight.w800)),
        const Gap(2),
        const Text('노란칸(입력)만 채우면 나머지는 자동 계산 · 저장되지 않는 계산기',
            style: TextStyle(fontSize: AppFont.caption, color: AppColors.textFaint)),
        const Gap(16),

        // ── 초기투자비 ──
        GlassCard(
          accent: AppColors.gold,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              _calc('증금 제외 잔금', balance),
              _calc('취득세', acqTax),
              _calc('취득비용 합', acqTotal),
              _calc('기타비용 합', etcTotal),
              const Divider(height: 20, color: AppColors.border),
              _calc('총자기자본', ownCapital, strong: true, color: AppColors.gold),
              _calc('총투자금액', totalInvest, strong: true, color: AppColors.gold),
            ],
          ),
        ),
        const Gap(14),

        // ── 시나리오 3종 ──
        _scenario(
          '월세',
          Icons.calendar_view_month_rounded,
          AppColors.sky,
          inputs: [
            _money('월세 보증금', wolDeposit, (v) => setState(() => wolDeposit = v)),
            _money('월세(월)', wolMonthly, (v) => setState(() => wolMonthly = v)),
            _pct('대출이자(연)', loanRate, (v) => setState(() => loanRate = v)),
            _money('관리·운영비', mgmt, (v) => setState(() => mgmt = v)),
            _money('기타지출', etc, (v) => setState(() => etc = v)),
          ],
          rows: [
            ('실투자금', netWol, false),
            ('연 임대수입', incomeWol, false),
            ('대출이자(연)', loanInterest, false),
            ('연 순수익', profitWol, true),
          ],
          yieldLabel: '연 수익률',
          yieldValue: '${yieldWol.toStringAsFixed(1)}%',
        ),
        const Gap(14),
        _scenario(
          '전세 (플피)',
          Icons.account_balance_wallet_rounded,
          AppColors.violet,
          inputs: [
            _money('전세 보증금', jeonse, (v) => setState(() => jeonse = v)),
          ],
          rows: [
            ('총투자금액', totalInvest, false),
            ('전세 보증금', jeonse, false),
            (netJeonse <= 0 ? '플피 (남는 돈)' : '실투자금',
                netJeonse.abs(), true),
          ],
          yieldLabel: netJeonse <= 0 ? '판정' : '실투자금',
          yieldValue: netJeonse <= 0 ? '플피 성공' : '${Won.compact(netJeonse)}원',
          yieldColor: netJeonse <= 0 ? AppColors.primary : AppColors.gold,
        ),
        const Gap(14),
        _scenario(
          '매도 (차익)',
          Icons.sell_rounded,
          AppColors.primary,
          inputs: [
            _money('매도 가격', sale, (v) => setState(() => sale = v)),
            _pct('양도소득세율', capGainPct, (v) => setState(() => capGainPct = v)),
          ],
          rows: [
            ('총투자금액', totalInvest, false),
            ('시세차익(과표)', capGain, false),
            ('양도소득세', capTax, false),
            ('세후 시세차익', profitSale, true),
          ],
          yieldLabel: '세후 차익',
          yieldValue: '${Won.compact(profitSale)}원',
          yieldColor: profitSale >= 0 ? AppColors.primary : AppColors.rose,
        ),
        const Gap(10),
        const Text(
          '※ 취득세율·양도세율·대출비율은 상황마다 다름 → 실제 값으로 조정. 전세를 놓으면 경락대출은 통상 못 써서 전세 시나리오는 대출을 빼고 계산합니다.',
          style: TextStyle(
              fontSize: AppFont.caption, color: AppColors.textFaint, height: 1.5),
        ),
      ],
    );
  }

  Widget _scenario(
    String title,
    IconData icon,
    Color color, {
    required List<Widget> inputs,
    required List<(String, double, bool)> rows,
    required String yieldLabel,
    required String yieldValue,
    Color? yieldColor,
  }) {
    return GlassCard(
      accent: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 18, color: color),
            const Gap(8),
            Text(title,
                style: const TextStyle(
                    fontSize: AppFont.section, fontWeight: FontWeight.w800)),
          ]),
          const Gap(12),
          Wrap(spacing: 10, runSpacing: 10, children: inputs),
          const Gap(12),
          for (final (label, value, strong) in rows)
            _calc(label, value, strong: strong, color: strong ? color : null),
          const Gap(6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: (yieldColor ?? color).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(yieldLabel,
                  style: TextStyle(
                      fontSize: AppFont.label,
                      fontWeight: FontWeight.w700,
                      color: yieldColor ?? color)),
              Text(yieldValue,
                  style: TextStyle(
                      fontSize: AppFont.display,
                      fontWeight: FontWeight.w900,
                      color: yieldColor ?? color)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _money(String label, double value, ValueChanged<double> onChanged) =>
      SizedBox(
        width: 160,
        child: MoneyField(
            label: label, initial: value, accent: AppColors.gold, onChanged: onChanged),
      );

  Widget _pct(String label, double value, ValueChanged<double> onChanged) =>
      SizedBox(
        width: 110,
        child: TextFormField(
          initialValue: value == 0 ? '' : _fmtPct(value),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          decoration: InputDecoration(
              labelText: label, isDense: true, suffixText: '%'),
          onChanged: (v) => onChanged(double.tryParse(v) ?? 0),
        ),
      );

  String _fmtPct(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  Widget _calc(String label, double value,
          {bool strong = false, Color? color}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: strong ? AppFont.body : AppFont.label,
                    fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
                    color: strong
                        ? (color ?? AppColors.textPrimary)
                        : AppColors.textSecondary)),
            Text('${Won.compact(value)}원',
                style: TextStyle(
                    fontSize: strong ? AppFont.section : AppFont.body,
                    fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
                    color: strong
                        ? (color ?? AppColors.textPrimary)
                        : AppColors.textPrimary)),
          ],
        ),
      );
}
