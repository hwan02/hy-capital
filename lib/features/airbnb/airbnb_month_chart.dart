// 에비 «월별 손익» 그래프 — 호점 카드와 호점 상세가 같이 쓴다.
//
// 순이익 막대 하나만 있을 땐 «그 달에 무슨 일이 있었나»가 안 보였고,
// 막대가 가늘고 밋밋해 눈에 안 들어왔다(2026-10-19).
//   · 막대 전체 높이 = 매출. 안을 «아래 비용 / 위 순이익»으로 나눈다 —
//     매출 중 얼마가 남았는지가 한눈에 보인다.
//   · 적자 달은 비용이 매출을 넘는다 — 넘친 만큼을 진한 빨강으로 얹는다.
//   · 막대 위 배지 = 순이익. 이번 달(또는 고른 달)만 밝게, 나머지는 옅게.
//   · 마우스를 올리면 매출·비용·순이익·순이익률, 누르면 그 달로(상세 화면).
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../core/format/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';

class AirbnbMonthChart extends StatelessWidget {
  final List<AirbnbMonthly> months;

  /// 밝게 보일 달 — 보통 이번 달, 상세 화면에서는 고른 달.
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
    // 막대 높이의 기준 — 매출과 비용 중 큰 쪽(적자 달은 비용이 더 크다).
    final top = months.fold<double>(
        1, (a, m) => [a, m.revenue, m.totalCost].reduce((x, y) => x > y ? x : y));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 범례
        Wrap(spacing: 14, runSpacing: 4, children: [
          _legend(AppColors.primary, '순이익'),
          _legend(AppColors.rose.withValues(alpha: 0.6), '비용'),
          const Text('막대 높이 = 매출',
              style: TextStyle(fontSize: AppFont.micro, color: AppColors.textFaint)),
        ]),
        const Gap(12),
        SizedBox(
          height: barAreaHeight + 64,
          child: Stack(children: [
            // 바닥선 — 막대가 서 있는 땅.
            Positioned(
              left: 0,
              right: 0,
              bottom: 30,
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
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary)),
      ]);

  Widget _column(BuildContext context, AirbnbMonthly m, double top) {
    final hi = _hi(m) || highlight == null;
    final loss = m.netProfit < 0;
    final h = barAreaHeight;
    // 정상 달: 비용(아래) + 순이익(위) = 매출. 적자 달: 매출(아래) + 넘친 비용(위).
    final lowH = (loss ? m.revenue : m.totalCost) / top * h;
    final upH = (loss ? -m.netProfit : m.netProfit) / top * h;
    final margin = m.revenue > 0 ? m.netProfit / m.revenue * 100 : 0.0;
    final netColor = loss ? AppColors.rose : AppColors.primary;
    // 지난달도 또렷하게 — 이번 달은 «빛»·진한 배지·굵은 글자로 구분한다.
    // (처음엔 지난달을 0.45 로 흐리게 했더니 막대가 탁하고 어두워 보였다.)
    final fade = hi ? 1.0 : 0.78;

    final bar = LayoutBuilder(builder: (context, c) {
      final w = (c.maxWidth * 0.62).clamp(16.0, 56.0);
      return Center(
        child: Container(
          width: w,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            boxShadow: _hi(m)
                ? [
                    BoxShadow(
                        color: netColor.withValues(alpha: 0.35),
                        blurRadius: 16,
                        spreadRadius: 1),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // 위 — 순이익(초록) 또는 넘친 비용(빨강)
              Container(
                height: upH.clamp(loss ? 3.0 : 0.0, h),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: loss
                        ? [AppColors.rose.withValues(alpha: fade),
                           const Color(0xFF9F1239).withValues(alpha: fade)]
                        : [AppColors.primary.withValues(alpha: fade),
                           const Color(0xFF15803D).withValues(alpha: fade)],
                  ),
                ),
              ),
              // 비용·순이익 경계 — 두 칸이 뭉개지지 않게.
              Container(height: 2, color: AppColors.surface),
              // 아래 — 비용(분홍) 또는 적자 달의 매출(금색)
              Container(
                height: (lowH - 2).clamp(0.0, h),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      (loss ? AppColors.gold : AppColors.rose)
                          .withValues(alpha: (hi ? 0.62 : 0.48)),
                      (loss ? AppColors.gold : AppColors.rose)
                          .withValues(alpha: (hi ? 0.38 : 0.28)),
                    ],
                  ),
                ),
              ),
            ]),
          ),
        ),
      );
    });

    final col = Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // 순이익 배지
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: _hi(m) ? netColor : netColor.withValues(alpha: hi ? 0.16 : 0.10),
            borderRadius: BorderRadius.circular(20),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('${loss ? '' : '+'}${man(m.netProfit)}',
                style: TextStyle(
                    fontSize: AppFont.micro,
                    fontWeight: FontWeight.w900,
                    color: _hi(m)
                        ? const Color(0xFF04130A)
                        : netColor.withValues(alpha: hi ? 1 : 0.7))),
          ),
        ),
        const Gap(6),
        bar,
        const Gap(8),
        Text('${m.month.month}월',
            style: TextStyle(
                fontSize: AppFont.label,
                fontWeight: _hi(m) ? FontWeight.w900 : FontWeight.w600,
                color: _hi(m) ? AppColors.textPrimary : AppColors.textFaint)),
      ],
    );

    return Tooltip(
      waitDuration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: netColor.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
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
