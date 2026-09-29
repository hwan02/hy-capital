import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

/// 웹에서 Tab 한 번에 포커스가 두 칸 넘어가는 것을 막는다.
///
/// 한글을 조합하는 중에 Tab 을 누르면 브라우저가 조합을 끝내면서
/// Tab 키 이벤트가 연달아 두 번 들어오는 경우가 있다 — 팝업 폼에서
/// 「항목명」에 한글을 치고 Tab 을 누르면 「금액」을 건너뛰고 「메모」로 갔다.
///
/// 앱 최상단에서 Tab/Shift+Tab 을 지켜보다가, 직전 Tab 과 너무 가까이
/// 붙어 들어온 것은 삼킨다. 사람이 일부러 두 번 누르는 간격보다 훨씬 짧다.
class TabDedupe extends StatefulWidget {
  final Widget child;
  const TabDedupe({super.key, required this.child});

  @override
  State<TabDedupe> createState() => _TabDedupeState();
}

class _TabDedupeState extends State<TabDedupe> {
  static const _window = Duration(milliseconds: 80);
  // 이벤트의 timeStamp 는 웹에서 0 으로 올 때가 있어 믿지 않는다 — 벽시계로 잰다.
  final _clock = Stopwatch()..start();
  Duration? _last;

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e.logicalKey != LogicalKeyboardKey.tab || e is KeyUpEvent) {
      return KeyEventResult.ignored;
    }
    final t = _clock.elapsed;
    final dup = _last != null && (t - _last!).abs() < _window;
    _last = t;
    // 중복이면 여기서 삼키고, 아니면 기본 포커스 이동에 맡긴다.
    return dup ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) => Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: _onKey,
        child: widget.child,
      );
}
