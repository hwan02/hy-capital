import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_providers.dart';

final authControllerProvider =
    AsyncNotifierProvider<AuthController, void>(AuthController.new);

class AuthController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  SupabaseClient get _sb => ref.read(supabaseProvider);

  Future<void> signIn(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _sb.auth.signInWithPassword(email: email.trim(), password: password);
    });
  }

  Future<void> signUp(String email, String password, String name) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _sb.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'display_name': name.trim()},
      );
    });
  }

  Future<void> signOut() async {
    await _sb.auth.signOut();
  }
}
