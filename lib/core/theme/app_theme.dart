import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// HY CAPITAL 디자인 시스템 — 프리미엄 핀테크 다크 테마.
class AppColors {
  AppColors._();

  static const bg = Color(0xFF0B0F1A); // 배경(딥 네이비)
  static const surface = Color(0xFF141A2A); // 카드
  static const surfaceAlt = Color(0xFF1B2233); // 카드(강조)
  static const border = Color(0xFF25304A);

  static const primary = Color(0xFF22C55E); // 성장/자유(에메랄드)
  static const primaryDim = Color(0xFF16311F);
  static const gold = Color(0xFFF5C24B); // 자산/현금
  static const sky = Color(0xFF38BDF8); // 정보
  static const violet = Color(0xFF8B5CF6); // AI
  static const rose = Color(0xFFF43F5E); // 경고/유출

  static const textPrimary = Color(0xFFF3F5FA);
  static const textSecondary = Color(0xFF9AA6C0);
  static const textFaint = Color(0xFF5D6B88);

  /// 모듈별 시그니처 색.
  static const Map<String, Color> module = {
    'dashboard': primary,
    'money': gold,
    'airbnb': sky,
    'shorts': rose,
    'land': Color(0xFFB4844E),
    'auction': Color(0xFF14B8A6),
    'dividend': primary,
    '토지': Color(0xFFB4844E),
    '경매': Color(0xFF14B8A6),
    '배당금': primary,
    'ipo': Color(0xFF6366F1),
    '공모주': Color(0xFF6366F1),
    'goals': violet,
    'weekly': Color(0xFF34D399),
    'ai': violet,
  };
}

/// 글자 크기 체계 — 앱 전체에서 **이 값만** 사용한다.
/// 새 UI를 만들 때 임의의 숫자(13, 14.5 …)를 쓰지 말고 아래 토큰을 고른다.
class AppFont {
  AppFont._();

  /// 34 — Freedom Score 등 화면의 주인공 숫자 하나.
  static const hero = 34.0;

  /// 22 — 카드 대표 금액·핵심 지표 숫자.
  static const display = 22.0;

  /// 18 — 화면 제목.
  static const title = 18.0;

  /// 16 — 섹션 제목, 카드 제목.
  static const section = 16.0;

  /// 14 — 본문, 목록 항목, 입력값. 기본값.
  static const body = 14.0;

  /// 12.5 — 라벨, 버튼, 탭, 표 헤더.
  static const label = 12.5;

  /// 11.5 — 보조 설명, 단위, 날짜.
  static const caption = 11.5;

  /// 10.5 — 배지·칩 안의 아주 작은 글자.
  static const micro = 10.5;
}

class AppTheme {
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = GoogleFonts.notoSansKrTextTheme(base.textTheme).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.surface,
        primary: AppColors.primary,
        secondary: AppColors.gold,
        error: AppColors.rose,
        onPrimary: Color(0xFF04130A),
        onSurface: AppColors.textPrimary,
      ),
      textTheme: textTheme,
      dividerColor: AppColors.border,
      cardColor: AppColors.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bg,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primaryDim,
        selectedIconTheme: IconThemeData(color: AppColors.primary),
        unselectedIconTheme: IconThemeData(color: AppColors.textFaint),
        selectedLabelTextStyle: TextStyle(color: AppColors.primary),
        unselectedLabelTextStyle: TextStyle(color: AppColors.textFaint),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: const Color(0xFF04130A),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: AppFont.section),
        ),
      ),
    );
  }
}

/// 공통 radius / 간격.
class Insets {
  static const double card = 20;
  static const double gap = 16;
  static const double radius = 18;
}
