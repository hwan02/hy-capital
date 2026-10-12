import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Alt+Enter = 「저장」.
///
/// 팝업마다 저장 콜백을 다시 꺼내 연결하지 않고, «저장 버튼»을 이걸로
/// 감싸기만 한다. Alt+Enter 를 누르면 «지금 맨 위에 떠 있는 화면(팝업)»의
/// 저장 버튼을 그대로 누른다 — 버튼이 비활성(onPressed == null)이면 아무 일도 없다.
///
///   SaveKey(child: FilledButton(onPressed: _submit, child: Text('저장')))
///
/// 같은 화면에 저장 버튼이 여러 개면 «마지막에 붙은 것»이 눌린다.
/// 그래서 팝업(한 화면에 저장 하나)에만 쓴다.
class SaveKey extends StatefulWidget {
  final Widget child;
  const SaveKey({super.key, required this.child});

  @override
  State<SaveKey> createState() => _SaveKeyState();

  /// 맨 위 화면의 저장 버튼을 누른다. 눌렀으면 true.
  static bool trigger() {
    for (final s in _SaveKeyState._live.reversed) {
      if (!s.mounted) continue;
      final route = ModalRoute.of(s.context);
      if (route != null && !route.isCurrent) continue;
      final action = s._action;
      if (action == null) return false; // 맨 위 팝업의 저장이 비활성 — 누르지 않는다
      action();
      return true;
    }
    return false;
  }
}

class _SaveKeyState extends State<SaveKey> {
  static final _live = <_SaveKeyState>[];

  VoidCallback? get _action {
    final c = widget.child;
    if (c is ButtonStyleButton) return c.onPressed;
    if (c is IconButton) return c.onPressed;
    return null;
  }

  @override
  void initState() {
    super.initState();
    _live.add(this);
  }

  @override
  void dispose() {
    _live.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// 앱 최상단에서 Alt+Enter 를 지켜본다 — [SaveKey] 와 짝.
class SaveKeyScope extends StatelessWidget {
  final Widget child;
  const SaveKeyScope({super.key, required this.child});

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final enter = e.logicalKey == LogicalKeyboardKey.enter ||
        e.logicalKey == LogicalKeyboardKey.numpadEnter;
    if (!enter || !HardwareKeyboard.instance.isAltPressed) {
      return KeyEventResult.ignored;
    }
    return SaveKey.trigger() ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) => Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: _onKey,
        child: child,
      );
}
