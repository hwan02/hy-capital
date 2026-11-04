// 메모를 쓰다가 앱을 껐다 켜면 쓴 글이 날아갔다(11/04).
// 폼이 열려 있는 동안 주기적으로 임시저장하고, 다시 열면 채운다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hy_capital/core/edit/field_spec.dart';
import 'package:hy_capital/core/edit/form_draft.dart';
import 'package:hy_capital/core/edit/record_form.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _fields = [
  FieldSpec(key: 'body', label: '메모', type: FieldType.longtext, required: true),
];

/// 폼을 연다. 돌려주는 건 «닫힐 때 값»을 담은 상자 — Future 를 그대로
/// 돌려주면 async 함수가 그걸 기다려서(닫힐 때까지) 테스트가 멈춘다.
Future<({Future<Map<String, dynamic>?> result})> Function() _opener(
    WidgetTester t) {
  late BuildContext ctx;
  return () async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (c) {
        ctx = c;
        return const SizedBox.expand();
      })),
    ));
    final f = showRecordForm(ctx,
        title: '메모 추가', fields: _fields, draftKey: 'memos:new');
    await t.pumpAndSettle();
    return (result: f);
  };
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('★ 쓰는 동안 2초마다 임시저장 → 다시 열면 채워진다', (t) async {
    t.view.physicalSize = const Size(1200, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final open = _opener(t);
    await open();
    await t.enterText(find.byType(TextFormField), '통화하다 들은 숫자 4.5억');
    await t.pump(const Duration(seconds: 3));
    expect((await FormDraft.load('memos:new'))?.fields['body'],
        '통화하다 들은 숫자 4.5억');

    // 앱을 껐다 켠 것처럼 화면을 통째로 갈아 끼우고 다시 연다.
    await t.pumpWidget(const SizedBox());
    await open();
    expect(find.text('통화하다 들은 숫자 4.5억'), findsOneWidget);
    expect(find.textContaining('임시저장된 내용을 불러왔습니다'), findsOneWidget);
  });

  testWidgets('버리기 → 빈 칸 · 임시저장 삭제', (t) async {
    t.view.physicalSize = const Size(1200, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await FormDraft.save('memos:new', {'body': '지울 글'});
    await _opener(t)();
    expect(find.text('지울 글'), findsOneWidget);
    await t.tap(find.text('버리기'));
    await t.pump();
    expect(find.text('지울 글'), findsNothing);
    expect(await FormDraft.load('memos:new'), isNull);
  });

  testWidgets('★ 저장으로 닫은 뒤 호출한 쪽이 지우면 되살아나지 않는다', (t) async {
    t.view.physicalSize = const Size(1200, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final open = _opener(t);
    final fut = (await open()).result;
    await t.enterText(find.byType(TextFormField), '저장할 글');
    await t.tap(find.text('저장'));
    await t.pump(); // pop 은 됐고 닫힘 애니메이션 중
    expect((await fut)?['body'], '저장할 글');
    // DB 저장 성공 → 호출한 쪽이 지운다(builtin_crud 와 같은 순서).
    await FormDraft.clear('memos:new');
    await t.pumpAndSettle(); // 이제 dispose
    await t.pump(const Duration(seconds: 3));
    expect(await FormDraft.load('memos:new'), isNull);
  });
}
