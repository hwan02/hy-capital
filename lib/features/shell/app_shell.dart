import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/data_providers.dart';
import '../../core/edit/icon_catalog.dart';
import '../../core/theme/app_theme.dart';
import '../../models/custom.dart';
import '../custom/module_editor.dart';
import 'modules.dart';

/// 반응형 셸: 넓은 화면은 사이드바, 좁은 화면은 Drawer.
class AppShell extends ConsumerWidget {
  final Widget child;
  final String location;
  const AppShell({super.key, required this.child, required this.location});

  String _currentTitle(List<CustomModule> customs) {
    for (final m in kModules) {
      if (location.startsWith(m.path)) return m.label;
    }
    for (final m in customs) {
      if (location == m.route) return m.name;
    }
    return 'HY CAPITAL';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final customs = ref.watch(customModulesProvider).asData?.value ?? [];

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            _SideNav(location: location, customs: customs),
            const VerticalDivider(width: 1, color: AppColors.border),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentTitle(customs)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => invalidateAll(ref),
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: AppColors.surface,
        child: _SideNav(
          location: location,
          customs: customs,
          onNavigate: () => Navigator.pop(context),
        ),
      ),
      body: child,
    );
  }
}

class _SideNav extends ConsumerWidget {
  final String location;
  final List<CustomModule> customs;
  final VoidCallback? onNavigate;
  const _SideNav({
    required this.location,
    required this.customs,
    this.onNavigate,
  });

  void _go(BuildContext context, String path) {
    onNavigate?.call();
    context.go(path);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: 236,
      color: AppColors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
              child: Row(
                children: [
                  Container(
                    height: 34,
                    width: 34,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, Color(0xFF0EA5E9)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded,
                        color: Colors.white, size: 19),
                  ),
                  const Gap(10),
                  const Text('HY CAPITAL',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          fontSize: AppFont.section)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final m in kModules)
                    _NavItem(
                      icon: m.icon,
                      label: m.label,
                      color: m.color,
                      selected: location.startsWith(m.path),
                      onTap: () => _go(context, m.path),
                    ),
                  // 직접 만든 모듈도 같은 목록에 이어서 표시 (구분 없음).
                  for (final m in customs)
                    _NavItem(
                      icon: iconFor(m.icon),
                      label: m.name,
                      color: colorFromHex(m.colorHex),
                      selected: location == m.route,
                      onTap: () => _go(context, m.route),
                    ),
                  const Gap(6),
                  _AddModuleButton(
                    onTap: () {
                      onNavigate?.call();
                      showModuleEditor(context, ref);
                    },
                  ),
                ],
              ),
            ),
            const Gap(8),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? color.withValues(alpha: 0.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(icon,
                    size: 20, color: selected ? color : AppColors.textFaint),
                const Gap(12),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: AppFont.body,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddModuleButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddModuleButton({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          children: [
            Icon(Icons.add_rounded, size: 19, color: AppColors.textSecondary),
            Gap(12),
            Text('모듈 추가',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: AppFont.body)),
          ],
        ),
      ),
    );
  }
}

