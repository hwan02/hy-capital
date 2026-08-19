import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../supabase/supabase_providers.dart';

/// 테이블 공용 insert/update/delete. user_id 자동 주입.
extension CrudRef on WidgetRef {
  /// id 가 있으면 update, 없으면 insert.
  Future<void> saveRow(
    String table,
    Map<String, dynamic> data, {
    String? id,
  }) async {
    final sb = read(supabaseProvider);
    final uid = sb.auth.currentUser?.id;
    if (uid == null) {
      throw Exception('세션이 없습니다. 잠시 후 다시 시도하세요.');
    }
    final clean = Map<String, dynamic>.from(data)..remove('id');
    if (id == null) {
      clean['user_id'] = uid;
      await sb.from(table).insert(clean);
    } else {
      await sb.from(table).update(clean).eq('id', id);
    }
  }

  Future<void> deleteRow(String table, String id) async {
    await read(supabaseProvider).from(table).delete().eq('id', id);
  }
}
