import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// 앱 기본 모듈 정의 (기획서 순서).
class ModuleDef {
  final String path;
  final String label;
  final IconData icon;
  final Color color;
  const ModuleDef(this.path, this.label, this.icon, this.color);
}

const kModules = <ModuleDef>[
  ModuleDef('/dashboard', 'Dashboard', Icons.dashboard_rounded, AppColors.primary),
  ModuleDef('/money', '자금 흐름', Icons.swap_horiz_rounded, AppColors.gold),
  ModuleDef('/airbnb', 'Airbnb', Icons.house_rounded, AppColors.sky),
  ModuleDef('/shorts', 'Shorts', Icons.play_circle_fill_rounded, AppColors.rose),
  ModuleDef('/land', '토지', Icons.terrain_rounded, Color(0xFFB4844E)),
  ModuleDef('/auction', '부동산', Icons.location_city_rounded, Color(0xFF14B8A6)),
  ModuleDef('/dividend', '배당금', Icons.savings_rounded, AppColors.primary),
  ModuleDef('/ipo', '공모주', Icons.confirmation_number_rounded, Color(0xFF6366F1)),
  ModuleDef('/books', '책', Icons.menu_book_rounded, Color(0xFFB4844E)),
  ModuleDef('/goals', 'Goals', Icons.flag_rounded, AppColors.violet),
];
