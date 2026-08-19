import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// 실시간 USD→KRW 환율 (무료 open.er-api, CORS 허용).
/// 실패 시 기본값 1400 으로 폴백해 앱이 멈추지 않도록.
final usdKrwProvider = FutureProvider<double>((ref) async {
  try {
    final res = await http
        .get(Uri.parse('https://open.er-api.com/v6/latest/USD'))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final krw = (data['rates']?['KRW'] as num?)?.toDouble();
      if (krw != null && krw > 0) return krw;
    }
  } catch (_) {
    // 네트워크/CORS 실패 → 폴백
  }
  return 1400;
});
