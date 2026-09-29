import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hy_capital/core/widgets/tab_dedupe.dart';

void main() {
  late List<FocusNode> nodes;

  Future<void> pump(WidgetTester tester) async {
    nodes = List.generate(4, (i) => FocusNode(debugLabel: 'f$i'));
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => TabDedupe(child: child!),
      home: Scaffold(
        body: Column(children: [
          for (final n in nodes) TextField(focusNode: n),
        ]),
      ),
    ));
    nodes[0].requestFocus();
    await tester.pump();
  }

  int focused() => nodes.indexWhere((n) => n.hasFocus);

  Future<void> waitReal(WidgetTester t, int ms) =>
      t.runAsync(() => Future.delayed(Duration(milliseconds: ms)));

  testWidgets('Tab 한 번 = 한 칸', (tester) async {
    await pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(focused(), 1);
  });

  testWidgets('연달아 두 번 들어온 Tab 은 한 칸만', (tester) async {
    await pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab); // 조합 종료로 중복 발생 흉내
    await tester.pump();
    expect(focused(), 1);
  });

  testWidgets('사람이 따로 두 번 누르면 두 칸', (tester) async {
    await pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await waitReal(tester, 150);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(focused(), 2);
  });

  testWidgets('Shift+Tab 도 한 칸 뒤로', (tester) async {
    await pump(tester);
    nodes[2].requestFocus();
    await tester.pump();
    await waitReal(tester, 150);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(focused(), 1);
  });
}
