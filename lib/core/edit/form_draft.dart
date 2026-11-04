import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 입력 중인 폼을 이 기기(웹은 localStorage)에 임시저장한다.
///
/// 메모를 쓰다가 앱을 껐다 켜거나 창이 닫히면 쓴 내용이 통째로 날아갔다.
/// 폼이 열려 있는 동안 주기적으로 적어 두고, 같은 폼을 다시 열면 채운다.
/// DB 에 저장이 «성공한 뒤»에만 지운다 — 저장이 실패해도 남아 있게.
class FormDraft {
  FormDraft._();

  static const _prefix = 'hy.draft.';

  /// 이보다 오래된 임시저장은 버린다.
  static const maxAge = Duration(days: 30);

  /// [key] 의 임시저장. 없거나 오래됐으면 null.
  static Future<({Map<String, String> fields, DateTime savedAt})?> load(
      String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefix + key);
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final at = DateTime.parse(m['at'] as String);
      if (DateTime.now().difference(at) > maxAge) {
        await prefs.remove(_prefix + key);
        return null;
      }
      final fields = (m['fields'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v as String));
      return (fields: fields, savedAt: at);
    } catch (_) {
      await prefs.remove(_prefix + key); // 깨진 값
      return null;
    }
  }

  static Future<void> save(String key, Map<String, String> fields) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _prefix + key,
        jsonEncode({
          'at': DateTime.now().toIso8601String(),
          'fields': fields,
        }));
  }

  static Future<void> clear(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefix + key);
  }
}
