import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../data/data_providers.dart';
import '../theme/app_theme.dart';

/// 모듈 화면 공통 래퍼: 최대폭 제한 + 헤더 + 당겨서 새로고침.
class ModulePage extends ConsumerWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final List<Widget> children;
  final Widget? action;

  /// 화면 우하단에 고정되는 버튼. 페이지가 길어도 스크롤 없이 누를 수 있다.
  final Widget? fab;
  final double maxWidth;

  const ModulePage({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.color,
    required this.children,
    this.action,
    this.fab,
    this.maxWidth = 1100,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 텍스트 드래그 선택·복사 허용 (웹 기본은 선택 불가).
    final page = SelectionArea(
        child: LayoutBuilder(builder: (context, c) {
          // 좁은 화면(모바일)은 여백을 줄여 거의 꽉 차게, 넓은 화면은 90% 폭.
          final narrow = c.maxWidth < 700;
          final w = narrow ? c.maxWidth : (c.maxWidth * 0.9).clamp(0.0, maxWidth);
          final pad = narrow ? 14.0 : 24.0;
          return ListView(
        padding: EdgeInsets.fromLTRB(pad, pad, pad, 60),
        children: [
          Center(
            child: SizedBox(
              width: w,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        height: 44,
                        width: 44,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: color, size: 24),
                      ),
                      const Gap(14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: AppFont.display,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            if (subtitle != null) ...[
                              const Gap(3),
                              Text(
                                subtitle!,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: AppFont.label,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: '새로고침',
                        onPressed: () => invalidateAll(ref),
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.refresh_rounded,
                            size: 18, color: AppColors.textFaint),
                      ),
                      if (action != null) action!,
                    ],
                  ),
                  const Gap(24),
                  ...children,
                ],
              ),
            ),
          ),
        ],
          );
        }),
    );

    // 당겨서 새로고침은 «터치 화면»에서만. 데스크톱에서는 휠로 목록 맨 위를
    // 넘길 때 실수로 발동해 전체 데이터가 다시 로드되고 화면이 깜빡인다.
    final width = MediaQuery.of(context).size.width;
    final body = width < 700
        ? RefreshIndicator(
            onRefresh: () async => invalidateAll(ref), child: page)
        : page;

    if (fab == null) return body;
    return Stack(children: [
      body,
      Positioned(right: 18, bottom: 22, child: fab!),
    ]);
  }
}

/// 반응형 그리드: 화면 폭에 따라 열 수 자동 조정.
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double minTileWidth;
  final double spacing;
  final double ratio;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minTileWidth = 220,
    this.spacing = 14,
    this.ratio = 1.5,
  });

  @override
  Widget build(BuildContext context) {
    // 높이는 내용에 맞춰 자동(Wrap) → 타일이 절대 넘치지 않는다.
    return LayoutBuilder(
      builder: (context, c) {
        var cols = (c.maxWidth / minTileWidth).floor().clamp(1, 6);
        // 항목 수보다 열이 많으면 낭비 → 항목 수에 맞춰 꽉 차게.
        if (children.isNotEmpty && cols > children.length) cols = children.length;
        final w = (c.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children) SizedBox(width: w, child: child),
          ],
        );
      },
    );
  }
}
