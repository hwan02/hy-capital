// 웹이 아닌 곳(테스트) — 저장하지 않는다.
class SwrStore {
  Future<Map<String, dynamic>?> get(String key) async => null;
  Future<void> put(String key, Map<String, dynamic> value) async {}
  String? readDirty() => null;
  void writeDirty(String json) {}
}
