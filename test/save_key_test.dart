import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hy_capital/core/widgets/save_key.dart';

void main() {
  Future<void> altEnter(WidgetTester t) async {
    await t.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await t.pumpAndSettle();
  }

  Widget app(Widget home) => MaterialApp(
        builder: (context, child) => SaveKeyScope(child: child!),
        home: home,
      );

  testWidgets('팝업에서 Alt+Enter = 저장', (t) async {
    var pageSaved = 0, dialogSaved = 0;
    await t.pumpWidget(app(Builder(
      builder: (ctx) => Scaffold(
        body: Column(children: [
          SaveKey(
              child: FilledButton(
                  onPressed: () => pageSaved++, child: const Text('페이지 저장'))),
          TextButton(
            onPressed: () => showDialog(
              context: ctx,
              builder: (d) => AlertDialog(
                content: const TextField(autofocus: true),
                actions: [
                  SaveKey(
                      child: FilledButton(
                          onPressed: () {
                            dialogSaved++;
                            Navigator.pop(d);
                          },
                          child: const Text('저장'))),
                ],
              ),
            ),
            child: const Text('열기'),
          ),
        ]),
      ),
    )));
    await t.tap(find.text('열기'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), '월세');
    await altEnter(t);
    expect(dialogSaved, 1, reason: '맨 위 팝업의 저장이 눌린다');
    expect(pageSaved, 0, reason: '뒤에 깔린 페이지 저장은 안 눌린다');
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('저장 버튼이 비활성이면 아무 일도 없다', (t) async {
    await t.pumpWidget(app(const Scaffold(
      body: Column(children: [
        TextField(autofocus: true),
        SaveKey(child: FilledButton(onPressed: null, child: Text('저장'))),
      ]),
    )));
    await t.pump();
    await altEnter(t); // 예외 없이 지나가면 통과
  });

  testWidgets('Alt 없이 Enter 만으로는 안 눌린다', (t) async {
    var saved = 0;
    await t.pumpWidget(app(Scaffold(
      body: Column(children: [
        const TextField(autofocus: true),
        SaveKey(child: FilledButton(onPressed: () => saved++, child: const Text('저장'))),
      ]),
    )));
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pump();
    expect(saved, 0);
  });

  testWidgets('입력칸 없는 팝업(달력)에서도 Alt+Enter = 선택', (t) async {
    var picked = 0;
    await t.pumpWidget(app(Builder(
      builder: (ctx) => Scaffold(
        body: TextButton(
          onPressed: () => showDialog(
            context: ctx,
            builder: (d) => AlertDialog(
              content: const Text('달력'),
              actions: [
                SaveKey(
                    child: FilledButton(
                        onPressed: () {
                          picked++;
                          Navigator.pop(d);
                        },
                        child: const Text('선택'))),
              ],
            ),
          ),
          child: const Text('열기'),
        ),
      ),
    )));
    await t.tap(find.text('열기'));
    await t.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await t.pump();
    await altEnter(t);
    expect(picked, 1);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
