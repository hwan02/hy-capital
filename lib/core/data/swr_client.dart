// 데이터 조회 캐시 — «지난번에 받은 것을 먼저 보여 주고, 뒤에서 새로 받아 바뀌었으면 고친다».
//
// 화면마다 처음 들어갈 때 0.3~1초씩 빈 화면(로딩)이었다. 표가 커서다
// (책 700KB · 물건 450KB · 구역 330KB). Supabase 로 가는 «읽기»(GET /rest/v1/…)를
// 여기서 가로채 브라우저에 저장해 둔 응답을 바로 돌려준다. 새 응답은 뒤에서 받고,
// 내용이 달라졌을 때만 [onChanged] 로 화면을 다시 읽힌다(그때는 방금 받은 것을 쓴다).
//
// «쓰기»(POST·PATCH·DELETE)가 성공하면 그 표의 저장분은 버린다 — 고친 직후에는
// 지금처럼 서버에서 바로 읽는다(옛 내용이 잠깐 보이지 않게). 다른 표도 그 쓰기로
// 바뀌었을 수 있어서(월별 합계 등) 쓰기 뒤 첫 읽기는 반드시 뒤에서 새로 받는다.
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'swr_store_stub.dart' if (dart.library.js_interop) 'swr_store_web.dart';

class SwrClient extends http.BaseClient {
  SwrClient([http.Client? inner, int Function()? clock])
      : _inner = inner ?? http.Client(),
        _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch) {
    try {
      final raw = _store.readDirty();
      if (raw != null) {
        (jsonDecode(raw) as Map).forEach((k, v) => _dirty['$k'] = v as int);
      }
    } catch (_) {}
  }

  /// 뒤에서 받은 응답이 저장분과 달랐다 — 화면이 다시 읽어야 한다.
  static void Function()? onChanged;

  /// 방금 받은 응답은 이 시간 동안 다시 받지 않는다 — [onChanged] 로 다시 읽을 때
  /// 같은 조회가 또 나가지 않게.
  static const _freshMs = 8000;

  final http.Client _inner;
  final _store = SwrStore();
  final _mem = <String, Map<String, dynamic>>{};
  final _inflight = <String>{};
  final _dirty = <String, int>{}; // 표 → 마지막으로 고친 시각(ms)
  int _lastWrite = 0; // 어느 표든 마지막으로 고친 시각
  Timer? _notify;

  final int Function() _clock; // 테스트에서 시간을 돌린다
  int get _now => _clock();

  /// /rest/v1/<표> 의 <표>. rpc 는 무엇을 고칠지 몰라 «*»(전부).
  static String? _table(Uri u) {
    final s = u.pathSegments;
    if (s.length < 3 || s[0] != 'rest' || s[1] != 'v1') return null;
    return s[2] == 'rpc' ? '*' : s[2];
  }

  // 같은 주소라도 «한 줄만»(Accept)·«개수 포함»(Prefer)·범위(Range)면 응답이 다르다.
  static String _key(http.BaseRequest r) => [
        r.url.toString(),
        r.headers['accept'] ?? '',
        r.headers['prefer'] ?? '',
        r.headers['range'] ?? '',
      ].join('|');

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final table = _table(request.url);
    if (table == null) return _inner.send(request);

    if (request.method != 'GET') {
      final res = await _inner.send(request);
      if (res.statusCode < 400) _markDirty(table);
      return res;
    }

    final key = _key(request);
    var hit = _mem[key] ?? await _store.get(key);
    if (hit != null) {
      final t = hit['t'] as int? ?? 0;
      final dirtyAt = _dirty[table] ?? _dirty['*'] ?? 0;
      if (t <= dirtyAt || t <= (_dirty['*'] ?? 0)) hit = null;
    }
    if (hit == null) {
      final res = await http.Response.fromStream(await _inner.send(request));
      _save(key, res);
      return _toStream(res.statusCode, res.bodyBytes, res.headers, request,
          res.reasonPhrase);
    }

    _mem[key] = hit;
    final t = hit['t'] as int;
    if ((_now - t > _freshMs || t <= _lastWrite) && _inflight.add(key)) {
      unawaited(_revalidate(request, key, hit['b'] as String));
    }
    return _toStream(
      hit['s'] as int,
      utf8.encode(hit['b'] as String),
      Map<String, String>.from(hit['h'] as Map),
      request,
      null,
    );
  }

  Future<void> _revalidate(http.BaseRequest orig, String key, String old) async {
    try {
      final req = http.Request('GET', orig.url)..headers.addAll(orig.headers);
      final res = await http.Response.fromStream(await _inner.send(req));
      final body = _save(key, res);
      if (body != null && body != old) {
        _notify?.cancel();
        _notify = Timer(const Duration(milliseconds: 250), () => onChanged?.call());
      }
    } catch (_) {
      // 오프라인·오류 — 저장분을 그대로 둔다.
    } finally {
      _inflight.remove(key);
    }
  }

  /// 정상 응답만 저장한다. 저장한 본문을 돌려준다(아니면 null).
  String? _save(String key, http.Response res) {
    if (res.statusCode != 200 && res.statusCode != 206) return null;
    final String body;
    try {
      body = utf8.decode(res.bodyBytes);
    } catch (_) {
      return null;
    }
    final entry = <String, dynamic>{
      's': res.statusCode,
      'b': body,
      't': _now,
      'h': {
        for (final e in res.headers.entries)
          // 길이·압축은 브라우저가 이미 푼 뒤라 본문과 안 맞는다.
          if (e.key != 'content-length' && e.key != 'content-encoding')
            e.key: e.value,
      },
    };
    _mem[key] = entry;
    unawaited(_store.put(key, entry));
    return body;
  }

  void _markDirty(String table) {
    _dirty[table] = _lastWrite = _now;
    _mem.removeWhere((k, _) =>
        table == '*' || k.contains('/rest/v1/$table?') || k.contains('/rest/v1/$table|'));
    _store.writeDirty(jsonEncode(_dirty));
  }

  static http.StreamedResponse _toStream(int status, List<int> bytes,
          Map<String, String> headers, http.BaseRequest request, String? reason) =>
      http.StreamedResponse(
        Stream.value(bytes),
        status,
        headers: headers,
        request: request,
        reasonPhrase: reason,
      );

  @override
  void close() => _inner.close();
}
