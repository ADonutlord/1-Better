import 'dart:typed_data';

import 'package:one_percent_better/services/e2ee_service.dart';
import 'package:one_percent_better/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// All authentication operations backed by Supabase Auth.
class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  SupabaseClient get _client => SupabaseService.instance.client;

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<AuthResponse> register({
    required String email,
    required String password,
    required String displayName,
    required String profession,
    required int? birthYear,
  }) async {
    final resp = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'display_name': displayName,
        'profession': profession,
        'birth_year': ?birthYear,
      },
    );
    await E2eeService.instance.ensureKeys();
    return resp;
  }

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final resp = await _client.auth.signInWithPassword(email: email, password: password);
    await E2eeService.instance.ensureKeys();
    return resp;
  }

  Future<void> logout() async {
    E2eeService.instance.reset();
    await _client.auth.signOut();
  }

  Future<void> resetPassword(String email) {
    return _client.auth.resetPasswordForEmail(email);
  }

  Future<void> updatePassword(String newPassword) {
    return _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<void> deleteAccount() async {
    await _client.rpc('delete_my_account');
    await _client.auth.signOut();
  }

  Future<void> updateDisplayName(String name) async {
    await _client.auth.updateUser(
      UserAttributes(data: {'display_name': name}),
    );
    await _client
        .from('profiles')
        .update({'display_name': name})
        .eq('id', currentUser!.id);
  }

  /// Updates the caller's profession and/or birth year. Passing null leaves
  /// that field unchanged. Validated server-side.
  Future<void> updateProfile({String? profession, int? birthYear}) {
    return _client.rpc('update_my_profile', params: {
      'p_profession': ?profession,
      'p_birth_year': ?birthYear,
    });
  }

  /// Uploads a profile picture and stores its public URL on the profile.
  /// Returns the public URL of the saved avatar.
  Future<String> updateAvatar(Uint8List bytes, String fileExtension) async {
    final userId = currentUser!.id;
    final path = '$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
    await _client.storage.from('avatars').uploadBinary(path, bytes);
    final url = _client.storage.from('avatars').getPublicUrl(path);
    await _client
        .from('profiles')
        .update({'avatar_url': url})
        .eq('id', userId);
    return url;
  }

  /// Removes the profile picture.
  Future<void> removeAvatar() async {
    final userId = currentUser!.id;
    final existing = await _client
        .from('profiles')
        .select('avatar_url')
        .eq('id', userId)
        .maybeSingle();
    final avatarUrl = existing?['avatar_url'] as String?;
    if (avatarUrl != null && avatarUrl.contains('/avatars/')) {
      try {
        final path = avatarUrl.split('/avatars/').last.split('?').first;
        await _client.storage.from('avatars').remove([path]);
      } catch (_) {
        // File may already be gone; ignore.
      }
    }
    await _client
        .from('profiles')
        .update({'avatar_url': null})
        .eq('id', userId);
  }
}
