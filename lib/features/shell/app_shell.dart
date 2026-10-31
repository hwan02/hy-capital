import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/data_providers.dart';
import '../../core/edit/icon_catalog.dart';
import '../../core/theme/app_theme.dart';
import '../../models/custom.dart';
import '../custom/module_editor.dart';
import 'modules.dart';

/// 반응형 셸: 넓은 화면은 사이드바(접으면 아이콘만), 좁은 화면은 Drawer.
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
      return _NavToggleKey(
          child: Scaffold(
        body: Row(
          children: [
            _SideNav(
              location: location,
              customs: customs,
              collapsed: ref.watch(sideNavCollapsedProvider),
              onToggle: () =>
                  ref.read(sideNavCollapsedProvider.notifier).toggle(),
            ),
            const VerticalDivider(width: 1, color: AppColors.border),
            Expanded(child: child),
          ],
        ),
      ));
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

/// `[` 키로 사이드바를 접고 편다.
///
/// 저장(Alt+Enter, [SaveKeyScope])과 같이 «키보드 자체»에 건다 — 포커스를
/// 가진 위젯이 없는 화면에서도 먹게. 입력칸에서 글을 쓰는 중이면 `[` 는
/// 글자이므로 건드리지 않는다. 조합키(Ctrl·Alt·Cmd)가 눌렸어도 무시한다.
class _NavToggleKey extends ConsumerStatefulWidget {
  final Widget child;
  const _NavToggleKey({required this.child});

  @override
  ConsumerState<_NavToggleKey> createState() => _NavToggleKeyState();
}

class _NavToggleKeyState extends ConsumerState<_NavToggleKey> {
  bool _onKey(KeyEvent e) {
    if (e is! KeyDownEvent || e.logicalKey != LogicalKeyboardKey.bracketLeft) {
      return false;
    }
    final kb = HardwareKeyboard.instance;
    if (kb.isControlPressed || kb.isAltPressed || kb.isMetaPressed) return false;
    final focus = FocusManager.instance.primaryFocus?.context;
    if (focus != null &&
        (focus.widget is EditableText ||
            focus.findAncestorStateOfType<EditableTextState>() != null)) {
      return false;
    }
    ref.read(sideNavCollapsedProvider.notifier).toggle();
    return true;
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// 로고 그라데이션 양끝 — 가운데는 AppColors.gold.
const _goldLight = Color(0xFFFFE7A3);
const _goldDeep = Color(0xFFC8921E);

class _SideNav extends ConsumerWidget {
  final String location;
  final List<CustomModule> customs;
  final VoidCallback? onNavigate;

  /// 아이콘만 남긴 좁은 레일. Drawer(모바일)에서는 쓰지 않는다.
  final bool collapsed;

  /// 로고를 눌렀을 때 접기/펼치기. null 이면 로고는 그냥 그림이다(Drawer).
  final VoidCallback? onToggle;
  const _SideNav({
    required this.location,
    required this.customs,
    this.onNavigate,
    this.collapsed = false,
    this.onToggle,
  });

  void _go(BuildContext context, String path) {
    onNavigate?.call();
    context.go(path);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 황금 모노그램 «HY». 전엔 초록·파랑 지갑 아이콘이었다.
    final logo = Container(
      height: 34,
      width: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_goldLight, AppColors.gold, _goldDeep],
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.28), blurRadius: 10),
        ],
      ),
      child: const Text('HY',
          style: TextStyle(
              color: Color(0xFF2A1D00),
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              fontSize: AppFont.label)),
    );
    // 로고를 누르면 접고 편다(단축키 `[`). 따로 «/» 버튼은 두지 않는다.
    // Drawer(모바일)에서는 onToggle 이 없어 로고는 그냥 그림이다.
    final logoTap = onToggle == null
        ? logo
        : Tooltip(
            message: collapsed ? '메뉴 펼치기  [' : '메뉴 접기  [',
            waitDuration: const Duration(milliseconds: 400),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(onTap: onToggle, child: logo),
            ),
          );

    // 애니메이션은 넣지 않는다 — 폭이 바뀌는 도중에 펼친 레이아웃이 좁은
    // 폭에 그려져 넘친다.
    return Container(
      width: collapsed ? 68 : 236,
      color: AppColors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: collapsed
                  ? const EdgeInsets.fromLTRB(0, 22, 0, 20)
                  : const EdgeInsets.fromLTRB(20, 22, 20, 20),
              child: collapsed
                  ? Center(child: logoTap)
                  : Row(
                      children: [
                        logoTap,
                        const Gap(10),
                        const Expanded(
                          child: Text('HY CAPITAL',
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.clip,
                              style: TextStyle(
                                  color: AppColors.gold,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                  fontSize: AppFont.section)),
                        ),
                      ],
                    ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: collapsed ? 10 : 12),
                children: [
                  for (final m in kModules.where((m) => !m.hidden))
                    _NavItem(
                      icon: m.icon,
                      label: m.label,
                      color: m.color,
                      selected: location.startsWith(m.path),
                      collapsed: collapsed,
                      onTap: () => _go(context, m.path),
                    ),
                  // 직접 만든 모듈도 같은 목록에 이어서 표시 (구분 없음).
                  for (final m in customs)
                    _NavItem(
                      icon: iconFor(m.icon),
                      label: m.name,
                      color: colorFromHex(m.colorHex),
                      selected: location == m.route,
                      collapsed: collapsed,
                      onTap: () => _go(context, m.route),
                    ),
                  const Gap(6),
                  _AddModuleButton(
                    collapsed: collapsed,
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
  final bool collapsed;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
    this.collapsed = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconW =
        Icon(icon, size: 20, color: selected ? color : AppColors.textFaint);
    if (collapsed) {
      // 아이콘만. 이름은 마우스를 올리면 보인다.
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Tooltip(
          message: label,
          waitDuration: const Duration(milliseconds: 300),
          child: Material(
            color: selected ? color.withValues(alpha: 0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: SizedBox(height: 42, child: Center(child: iconW)),
            ),
          ),
        ),
      );
    }
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
                iconW,
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
  final bool collapsed;
  const _AddModuleButton({required this.onTap, this.collapsed = false});
  @override
  Widget build(BuildContext context) {
    if (collapsed) {
      return Tooltip(
        message: '메뉴 추가',
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.only(top: 4),
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Center(
              child: Icon(Icons.add_rounded,
                  size: 19, color: AppColors.textSecondary),
            ),
          ),
        ),
      );
    }
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
            Text('메뉴 추가',
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

