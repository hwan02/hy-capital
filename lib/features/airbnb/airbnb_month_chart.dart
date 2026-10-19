// 에비 «월별 손익» 그래프 — 호점 카드와 호점 상세가 같이 쓴다.
//
// 알록달록한 누적 막대(분홍·노랑·민트 + 배지 + 테두리)는 «안 이쁘다»는
// 말을 세 번 들었다. 시안 셋 중 사용자가 고른 B안(2026-10-19):
//   · 회색 막대 = 매출. 그 안을 아래부터 순이익만큼 채운다 —
//     매출 중 얼마가 남았는지가 한눈에 보인다.
//   · 이번 달(또는 고른 달)만 초록, 나머지는 회색. 적자 달은 숫자만 빨강.
//   · 숫자는 배지 없이 막대 위 글자로.
//   · 마우스를 올리면 매출·비용·순이익·순이익률, 누르면 그 달로(상세 화면).
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../core/format/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';

const _revenue = Color(0xFF2B3446); // 매출 — 카드 바탕보다 한 톤 밝은 회색
const _revenueNow = Color(0xFF1E3B36); // 이번 달 매출 — 초록 기운
const _profit = Color(0xFF5B667E); // 지난 달 순이익 — 회색
const _profitNow = Color(0xFF34D399); // 이번 달 순이익 — 초록
const _loss = Color(0xFFF87171);

class AirbnbMonthChart extends StatelessWidget {
  final List<AirbnbMonthly> months;

  /// 초록으로 보일 달 — 보통 이번 달, 상세 화면에서는 고른 달.
  final DateTime? highlight;

  /// 막대를 누르면 — 상세 화면에서 그 달로 이동.
  final void Function(DateTime month)? onTap;

  final double barAreaHeight;

  const AirbnbMonthChart({
    super.key,
    required this.months,
    this.highlight,
    this.onTap,
    this.barAreaHeight = 150,
  });

  /// 「157.4만」 — 소수 첫째 자리까지(100만 이상도 반올림하지 않는다).
  static String man(double v) {
    if (v.abs() < 10000) return Won.compact(v);
    final s = (v / 10000).toStringAsFixed(1);
    return '${s.endsWith('.0') ? s.substring(0, s.length - 2) : s}만';
  }

  bool _hi(AirbnbMonthly m) =>
      highlight != null &&
      m.month.year == highlight!.year &&
      m.month.month == highlight!.month;

  @override
  Widget build(BuildContext context) {
    if (months.isEmpty) return const SizedBox.shrink();
    final top = months.fold<double>(1, (a, m) => m.revenue > a ? m.revenue : a);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(spacing: 14, runSpacing: 4, children: [
          _legend(_revenue, '매출'),
          _legend(_profitNow, '순이익'),
        ]),
        const Gap(14),
        SizedBox(
          height: barAreaHeight + 52,
          child: Stack(children: [
            // 바닥선
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Container(height: 1, color: AppColors.border),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final m in months)
                  Expanded(child: _column(context, m, top)),
              ],
            ),
          ]),
        ),
      ],
    );
  }

  Widget _legend(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 10,
            height: 10,
            decoration:
                BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
        const Gap(5),
        Text(label,
            style: const TextStyle(
                fontSize: AppFont.micro,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
      ]);

  Widget _column(BuildContext context, AirbnbMonthly m, double top) {
    final loss = m.netProfit < 0;
    final now = _hi(m);
    final h = barAreaHeight;
    final revH = (m.revenue / top * h).clamp(4.0, h);
    final profH = loss ? 0.0 : (m.netProfit / top * h).clamp(0.0, revH);
    final margin = m.revenue > 0 ? m.netProfit / m.revenue * 100 : 0.0;
    const radius = BorderRadius.vertical(top: Radius.circular(6));

    final bar = LayoutBuilder(builder: (context, c) {
      final w = (c.maxWidth * 0.56).clamp(14.0, 40.0);
      return Center(
        child: Container(
          width: w,
          height: revH,
          alignment: Alignment.bottomCenter,
          decoration: BoxDecoration(
            color: now ? _revenueNow : _revenue,
            borderRadius: radius,
          ),
          child: profH <= 0
              ? null
              : Container(
                  height: profH,
                  decoration: BoxDecoration(
                    color: now ? _profitNow : _profit,
                    borderRadius: profH >= revH - 1 ? radius : BorderRadius.zero,
                  ),
                ),
        ),
      );
    });

    final col = Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(man(m.netProfit),
              style: TextStyle(
                  fontSize: now ? AppFont.caption : AppFont.micro,
                  fontWeight: now ? FontWeight.w800 : FontWeight.w600,
                  color: loss
                      ? _loss
                      : now
                          ? _profitNow
                          : AppColors.textSecondary)),
        ),
        const Gap(6),
        bar,
        const Gap(8),
        Text('${m.month.month}월',
            style: TextStyle(
                fontSize: AppFont.micro,
                fontWeight: now ? FontWeight.w800 : FontWeight.w500,
                color: now ? AppColors.textPrimary : AppColors.textFaint)),
      ],
    );

    return Tooltip(
      waitDuration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      textStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: AppFont.caption,
          height: 1.55,
          fontWeight: FontWeight.w600),
      message: '${Dates.ym(m.month)}\n'
          '매출 ${man(m.revenue)}원\n'
          '비용 ${man(m.totalCost)}원\n'
          '순이익 ${man(m.netProfit)}원 (${margin.toStringAsFixed(0)}%)',
      child: onTap == null
          ? Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: col)
          : InkWell(
              onTap: () => onTap!(m.month),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2), child: col),
            ),
    );
  }
}
