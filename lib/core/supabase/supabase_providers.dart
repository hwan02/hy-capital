import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 전역 Supabase 클라이언트.
final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// 인증 상태 스트림 (로그인/로그아웃에 반응).
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseProvider).auth.onAuthStateChange;
});

/// 현재 세션의 유저 (없으면 null).
final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authStateProvider); // 변화 시 재평가
  return ref.watch(supabaseProvider).auth.currentUser;
});
