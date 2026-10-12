import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hy_capital/core/edit/record_form.dart';

void main() {
  Future<DateTime?> open(WidgetTester t, Future<void> Function() act) async {
    DateTime? result;
    var done = false;
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => TextButton(
          onPressed: () async {
            result = await pickDay(ctx, initial: DateTime(2026, 10, 6));
            done = true;
          },
          child: const Text('열기'),
        ),
      ),
    ));
    await t.tap(find.text('열기'));
    await t.pumpAndSettle();
    await act();
    await t.pumpAndSettle();
    return done ? result : null;
  }

  testWidgets('같은 날을 연달아 두 번 누르면 선택하고 닫힌다', (t) async {
    final r = await open(t, () async {
      await t.tap(find.text('5'));
      await t.pump(const Duration(milliseconds: 50));
      await t.tap(find.text('5'));
    });
    expect(r, DateTime(2026, 10, 5));
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('한 번 누르면 선택만 되고 안 닫힌다', (t) async {
    await open(t, () async {
      await t.tap(find.text('5'));
    });
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('다른 날을 연달아 누르면 닫히지 않는다', (t) async {
    await open(t, () async {
      await t.tap(find.text('5'));
      await t.pump(const Duration(milliseconds: 50));
      await t.tap(find.text('7'));
    });
    expect(find.byType(AlertDialog), findsOneWidget);
  });
}
