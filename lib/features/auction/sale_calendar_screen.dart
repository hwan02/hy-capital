// 경공매 달력 — 사이드 메뉴의 한 칸. 내용은 sale_calendar_view.dart.
// 부동산 탭 안에 있을 땐 두 번 눌러 들어가야 해서 따로 뺐다(2026-11-05).
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/module_page.dart';
import 'sale_calendar_view.dart';

class SaleCalendarScreen extends StatelessWidget {
  const SaleCalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModulePage(
      title: '경공매 달력',
      subtitle: '정비구역 안 경매·공매 — 매각기일에 꽂아 본다',
      icon: Icons.calendar_month_rounded,
      color: AppColors.gold,
      children: [SaleCalendarView()],
    );
  }
}
