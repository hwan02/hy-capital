import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// 앱 기본 모듈 정의 (기획서 순서).
class ModuleDef {
  final String path;
  final String label;
  final IconData icon;
  final Color color;

  /// 메뉴에서 숨긴다. 주소(라우트)는 살아 있어서 링크로는 들어갈 수 있다.
  final bool hidden;
  const ModuleDef(this.path, this.label, this.icon, this.color,
      {this.hidden = false});
}

const kModules = <ModuleDef>[
  ModuleDef('/dashboard', 'Dashboard', Icons.dashboard_rounded, AppColors.primary),
  ModuleDef('/money', '자금 흐름', Icons.swap_horiz_rounded, AppColors.gold),
  // 월급·Shorts·토지는 지금 안 쓴다 — 메뉴에서만 숨긴다(2026-10-31).
  ModuleDef('/salary', '월급', Icons.payments_rounded, AppColors.primary,
      hidden: true),
  ModuleDef('/airbnb', '에비', Icons.house_rounded, AppColors.sky),
  ModuleDef('/shorts', 'Shorts', Icons.play_circle_fill_rounded, AppColors.rose,
      hidden: true),
  ModuleDef('/land', '토지', Icons.terrain_rounded, Color(0xFFB4844E),
      hidden: true),
  ModuleDef('/auction', '부동산', Icons.location_city_rounded, Color(0xFF14B8A6)),
  ModuleDef('/dividend', '배당금', Icons.savings_rounded, AppColors.primary),
  ModuleDef('/ipo', '공모주', Icons.confirmation_number_rounded, Color(0xFF6366F1)),
  ModuleDef('/books', '책', Icons.menu_book_rounded, Color(0xFFB4844E)),
  ModuleDef('/goals', 'Goals', Icons.flag_rounded, AppColors.violet),
];
