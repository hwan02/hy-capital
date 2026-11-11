import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hy_capital/core/data/swr_client.dart';

void main() {
  late int now;
  late int hits;
  late String body;
  late SwrClient c;
  final url = Uri.parse('https://x.supabase.co/rest/v1/books?select=*');

  setUp(() {
    now = 1000000;
    hits = 0;
    body = '[{"id":1}]';
    SwrClient.onChanged = null;
    c = SwrClient(
      MockClient((req) async {
        if (req.method == 'GET') hits++;
        return http.Response(req.method == 'GET' ? body : '', 200,
            headers: {'content-type': 'application/json'});
      }),
      () => now,
    );
  });

  test('두 번째 읽기는 저장분 — 방금 받은 것은 다시 받지 않는다', () async {
    expect((await c.get(url)).body, body);
    expect((await c.get(url)).body, body);
    expect(hits, 1);
  });

  test('오래된 저장분은 먼저 돌려주고 뒤에서 새로 받는다 — 달라졌으면 알린다', () async {
    await c.get(url);
    var changed = 0;
    SwrClient.onChanged = () => changed++;
    now += 60000;
    body = '[{"id":1},{"id":2}]';
    expect((await c.get(url)).body, '[{"id":1}]'); // 옛것이 바로 온다
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(hits, 2);
    expect(changed, 1);
    expect((await c.get(url)).body, body); // 다시 읽으면 새것, 조회는 안 나간다
    expect(hits, 2);
  });

  test('내용이 같으면 알리지 않는다', () async {
    await c.get(url);
    var changed = 0;
    SwrClient.onChanged = () => changed++;
    now += 60000;
    await c.get(url);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(hits, 2);
    expect(changed, 0);
  });

  test('고친 표는 저장분을 버리고 서버에서 바로 읽는다', () async {
    await c.get(url);
    now += 10;
    await c.patch(Uri.parse('https://x.supabase.co/rest/v1/books?id=eq.1'),
        body: '{}');
    now += 10;
    body = '[{"id":1,"t":"new"}]';
    expect((await c.get(url)).body, body);
    expect(hits, 2);
  });

  test('다른 표를 고치면 — 저장분을 바로 주되 뒤에서 꼭 새로 받는다(합계 표 등)', () async {
    await c.get(url);
    now += 10;
    await c.patch(Uri.parse('https://x.supabase.co/rest/v1/goals?id=eq.1'),
        body: '{}');
    now += 10;
    body = '[{"id":1,"sum":2}]';
    var changed = 0;
    SwrClient.onChanged = () => changed++;
    expect((await c.get(url)).body, '[{"id":1}]');
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(hits, 2);
    expect(changed, 1);
  });

  test('데이터 조회가 아니면(로그인 등) 건드리지 않는다', () async {
    final auth = Uri.parse('https://x.supabase.co/auth/v1/user');
    await c.get(auth);
    await c.get(auth);
    expect(hits, 2);
  });
}
