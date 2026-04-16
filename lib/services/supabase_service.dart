import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class SupabaseService {
  Future<void> syncFirebaseUser({
    required String firebaseUid,
    required String email,
    required String firebaseIdToken,
    String? displayName,
  }) async {
    if (!AppConfig.supabaseSyncEnabled) {
      debugPrint(
        'ℹ️ Supabase sync skipped (SUPABASE_SYNC_FUNCTION_URL missing).',
      );
      return;
    }
    if (firebaseIdToken.isEmpty) {
      debugPrint('ℹ️ Supabase sync skipped (Firebase ID token missing).');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(AppConfig.supabaseSyncFunctionUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $firebaseIdToken',
        },
        body: jsonEncode({
          // Convenience fields only; the function should trust the Firebase token.
          'firebase_uid': firebaseUid,
          'email': email,
          'username': displayName,
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          '⚠️ Supabase profile sync failed (${response.statusCode}): '
          '${response.body}',
        );
      }
    } catch (e) {
      // Sync is best-effort and should never block Firebase auth flow.
      debugPrint('⚠️ Supabase profile sync error: $e');
    }
  }
}
