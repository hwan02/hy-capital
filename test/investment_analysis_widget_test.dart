import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hy_capital/core/data/data_providers.dart';
import 'package:hy_capital/core/supabase/supabase_providers.dart';
import 'package:hy_capital/features/auction/investment_analysis_tab.dart';
import 'package:hy_capital/models/models.dart';

AuctionProperty get property => AuctionProperty.fromMap({
  'id': 'candidate-a',
  'title': '검증용 물건',
  'min_price': 100000000,
  'deposit': 20000000,
  'expected_sale_price': 0,
});

Future<void> showTab(
  WidgetTester tester, {
  List<CalcRecord> records = const [],
  double width = 1100,
  SupabaseClient? client,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (client == null)
          calcRecordsProvider.overrideWith((ref) async => records),
        if (client != null) supabaseProvider.overrideWithValue(client),
        profileProvider.overrideWith((ref) async => null),
      ],
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(body: InvestmentAnalysisTab(property: property)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('화면 저장→RLS 클라이언트 요청→새 스냅샷→재조회가 연결됨', (tester) async {
    final rows = <Map<String, dynamic>>[];
    final requests = <String>[];
    const uid = '11111111-1111-4111-8111-111111111111';
    final jwt =
        'e30.${base64Url.encode(utf8.encode(jsonEncode({'sub': uid, 'exp': DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000, 'role': 'authenticated'}))).replaceAll('=', '')}.fixture';
    final mock = MockClient((request) async {
      requests.add('${request.method} ${request.url.path}');
      final headers = {'content-type': 'application/json'};
      if (request.url.path == '/auth/v1/token') {
        return http.Response(
          jsonEncode({
            'access_token': jwt,
            'refresh_token': 'fixture',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': {
              'id': uid,
              'aud': 'authenticated',
              'role': 'authenticated',
              'created_at': '2026-01-01T00:00:00Z',
              'app_metadata': {},
              'user_metadata': {},
            },
          }),
          200,
          headers: headers,
          request: request,
        );
      }
      if (request.url.path == '/rest/v1/calc_records') {
        if (request.method == 'POST') {
          final data = jsonDecode(request.body) as Map<String, dynamic>;
          expect(data['user_id'], uid);
          expect(request.headers['authorization'], 'Bearer $jwt');
          final row = {
            ...data,
            'id': 'snapshot-${rows.length}',
            'created_at': '2026-10-30T12:00:00Z',
          };
          rows.insert(0, row);
          return http.Response(
            jsonEncode(row),
            201,
            headers: headers,
            request: request,
          );
        }
        return http.Response(
          jsonEncode(rows),
          200,
          headers: headers,
          request: request,
        );
      }
      return http.Response('{}', 404, headers: headers, request: request);
    });
    late SupabaseClient client;
    await tester.runAsync(() async {
      client = SupabaseClient(
        'https://fixture.invalid',
        'fixture-public-key',
        httpClient: mock,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      await client.auth.signInWithPassword(
        email: 'fixture@example.test',
        password: 'fixture-only',
      );
      await client.from('calc_records').select();
    });
    addTearDown(() => tester.runAsync(client.dispose));
    expect(client.auth.currentUser?.id, uid);
    await showTab(tester, client: client);
    await tester.tap(find.text('새 분석 버전 저장'));
    await tester.pumpAndSettle();
    expect(
      rows,
      hasLength(1),
      reason:
          '$requests; ${ProviderScope.containerOf(tester.element(find.byType(InvestmentAnalysisTab))).read(calcRecordsProvider).error}',
    );
    expect((rows.first['inputs'] as Map)['property_id'], 'candidate-a');
    expect((rows.first['inputs'] as Map)['_kind'], 'investment');
    expect(find.text('저장된 분석을 불러왔어요'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await showTab(tester, client: client);
    expect(find.text('저장된 분석을 불러왔어요'), findsOneWidget);
    await tester.tap(find.text('새 분석 버전 저장'));
    await tester.pumpAndSettle();
    expect(rows, hasLength(2)); // update가 아니라 append, 이전 근거 보존
    expect(tester.takeException(), isNull);
  });
  testWidgets('신규 물건은 감정가/미입력 세율로 추천하지 않음, 좁은 화면도 표시', (tester) async {
    await showTab(tester, width: 390);
    expect(find.text('입력 필요'), findsOneWidget);
    expect(find.text('입찰 검토'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('다른 물건의 분석 이력을 섞어 불러오지 않음', (tester) async {
    await showTab(
      tester,
      records: [
        CalcRecord(
          id: 'foreign',
          label: '다른 물건',
          createdAt: DateTime(2026, 10, 30),
          inputs: {
            '_kind': 'investment',
            'property_id': 'candidate-b',
            'analysis': {'version': 99},
          },
        ),
      ],
    );
    expect(find.text('새 분석 초안'), findsOneWidget);
    expect(find.text('입력 필요'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('다른 물건ID의 조사 JSON은 가져오기 거부, 초안 유지', (tester) async {
    await showTab(tester);
    await tester.tap(find.text('조사 결과 가져오기'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      jsonEncode({'property_id': 'candidate-b'}),
    );
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.textContaining('다른 물건 결과예요'), findsOneWidget);
    expect(find.text('새 분석 초안'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
