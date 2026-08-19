import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 커스텀 모듈에서 고를 수 있는 아이콘 목록 (문자열 키 ↔ IconData).
const Map<String, IconData> kIconCatalog = {
  'widgets': Icons.widgets_rounded,
  'star': Icons.star_rounded,
  'work': Icons.work_rounded,
  'home': Icons.home_rounded,
  'store': Icons.storefront_rounded,
  'car': Icons.directions_car_rounded,
  'flight': Icons.flight_rounded,
  'school': Icons.school_rounded,
  'fitness': Icons.fitness_center_rounded,
  'pets': Icons.pets_rounded,
  'restaurant': Icons.restaurant_rounded,
  'shopping': Icons.shopping_bag_rounded,
  'card': Icons.credit_card_rounded,
  'chart': Icons.insights_rounded,
  'wallet': Icons.account_balance_wallet_rounded,
  'coin': Icons.monetization_on_rounded,
  'gift': Icons.card_giftcard_rounded,
  'rocket': Icons.rocket_launch_rounded,
  'bulb': Icons.lightbulb_rounded,
  'heart': Icons.favorite_rounded,
  'camera': Icons.photo_camera_rounded,
  'music': Icons.music_note_rounded,
  'book': Icons.menu_book_rounded,
  'code': Icons.code_rounded,
};

IconData iconFor(String key) => kIconCatalog[key] ?? Icons.widgets_rounded;

/// 커스텀 모듈 색상 팔레트 (hex RRGGBB).
const List<String> kColorPalette = [
  '22C55E', // green
  '38BDF8', // sky
  'F5C24B', // gold
  'F43F5E', // rose
  '8B5CF6', // violet
  'B4844E', // land
  '34D399', // emerald
  'FB923C', // orange
  'E879F9', // pink
  '2DD4BF', // teal
];

Color colorFromHex(String hex) {
  final h = hex.replaceAll('#', '').trim();
  final v = int.tryParse(h, radix: 16) ?? 0x38BDF8;
  return Color(0xFF000000 | v);
}

String hexFromColor(Color c) {
  final argb = c.toARGB32();
  return (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();
}

const kDefaultModuleColor = AppColors.sky;
