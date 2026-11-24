// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'modules.dart';

const _kKey = 'nav_hidden_menus';

/// 처음 숨김값 — [ModuleDef.hidden] 이 켜진 메뉴들.
Set<String> get _defaults =>
    {for (final m in kModules.where((m) => m.hidden)) m.path};

/// 사이드바에서 숨긴 메뉴(경로). 경매 「보여줄 탭」과 같은 방식으로
/// «이 브라우저»에만 둔다 — 화면 취향이라 기기마다 달라도 된다.
class HiddenMenus extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    try {
      final raw = html.window.localStorage[_kKey];
      if (raw == null) return _defaults;
      if (raw.isEmpty) return {};
      // 없어진 메뉴 경로는 버린다.
      final known = {for (final m in kModules) m.path};
      return raw.split(',').where(known.contains).toSet();
    } catch (_) {
      return _defaults;
    }
  }

  void _save(Set<String> v) {
    state = v;
    try {
      html.window.localStorage[_kKey] = v.join(',');
    } catch (_) {/* 저장 못 해도 화면은 돈다 */}
  }

  void toggle(String path) => _save(state.contains(path)
      ? ({...state}..remove(path))
      : {...state, path});

  void reset() => _save(_defaults);
}

final hiddenMenusProvider =
    NotifierProvider<HiddenMenus, Set<String>>(HiddenMenus.new);
