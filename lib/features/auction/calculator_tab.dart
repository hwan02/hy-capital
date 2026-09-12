// 계산기 탭 — «경매» 와 «정비구역» 두 모드.
//
// 한 화면에 다 넣지 않는 이유: 입력 전제가 다르다. 경매는 낙찰가·입찰보증금
// 10%·명도비용에서 출발하고, 정비구역은 매매가·분담금·대장아파트 시세에서
// 출발한다. 섞으면 «입찰보증금» 같은 줄이 의미 없이 떠서 읽기가 어렵다.
// (모아타운/신통기획 탭을 나눈 것과 같은 판단)
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import 'auction_calculator.dart';
import 'redev_calculator.dart';

const _teal = Color(0xFF14B8A6);

class CalculatorTab extends StatefulWidget {
  const CalculatorTab({super.key});

  @override
  State<CalculatorTab> createState() => _CalculatorTabState();
}

class _CalculatorTabState extends State<CalculatorTab> {
  bool _redev = false;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // 가로 스크롤 금지 — Wrap 으로 접힌다.
      Wrap(spacing: 8, runSpacing: 8, children: [
        ModuleTab(
            label: '경매',
            icon: Icons.gavel_rounded,
            color: _teal,
            selected: !_redev,
            onTap: () => setState(() => _redev = false)),
        ModuleTab(
            label: '정비구역',
            icon: Icons.apartment_rounded,
            color: AppColors.sky,
            selected: _redev,
            onTap: () => setState(() => _redev = true)),
      ]),
      const Gap(18),
      if (_redev) const RedevCalculator() else const AuctionCalculator(),
    ]);
  }
}
