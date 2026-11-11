// 브라우저 저장소 — 응답은 IndexedDB(큰 표도 들어간다), «고친 표» 표시는 localStorage.
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

class SwrStore {
  static const _name = 'hy_swr', _box = 'http', _dirtyKey = 'hy_swr_dirty';
  Future<web.IDBDatabase>? _db;

  Future<web.IDBDatabase> _open() => _db ??= () {
        final c = Completer<web.IDBDatabase>();
        final req = web.window.indexedDB.open(_name, 1);
        req.onupgradeneeded = ((web.Event _) {
          final db = req.result as web.IDBDatabase;
          if (!db.objectStoreNames.contains(_box)) db.createObjectStore(_box);
        }).toJS;
        req.onsuccess =
            ((web.Event _) => c.complete(req.result as web.IDBDatabase)).toJS;
        req.onerror = ((web.Event _) => c.completeError('indexedDB')).toJS;
        return c.future;
      }();

  Future<JSAny?> _done(web.IDBRequest req) {
    final c = Completer<JSAny?>();
    req.onsuccess = ((web.Event _) => c.complete(req.result)).toJS;
    req.onerror = ((web.Event _) => c.completeError('indexedDB')).toJS;
    return c.future;
  }

  // 저장소가 막혀 있어도(시크릿 창 등) 앱은 그냥 네트워크로 돈다.
  Future<Map<String, dynamic>?> get(String key) async {
    try {
      final db = await _open();
      final r = await _done(
          db.transaction(_box.toJS, 'readonly').objectStore(_box).get(key.toJS));
      if (r != null && r.isA<JSString>()) {
        return jsonDecode((r as JSString).toDart) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<void> put(String key, Map<String, dynamic> value) async {
    try {
      final db = await _open();
      await _done(db
          .transaction(_box.toJS, 'readwrite')
          .objectStore(_box)
          .put(jsonEncode(value).toJS, key.toJS));
    } catch (_) {}
  }

  String? readDirty() {
    try {
      return web.window.localStorage.getItem(_dirtyKey);
    } catch (_) {
      return null;
    }
  }

  void writeDirty(String json) {
    try {
      web.window.localStorage.setItem(_dirtyKey, json);
    } catch (_) {}
  }
}
