import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/team.dart';
import 'auth_service.dart';

class LeagueSyncService {
  LeagueSyncService();

  final AuthService _authService = AuthService();

  Future<void> syncTeam(Team team) async {
    try {
      final idToken = await _authService.getIdToken();
      final uri = _leagueFunctionUri();

      if (uri == null || idToken == null || idToken.isEmpty) {
        return;
      }

      await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'action': 'syncTeam',
          'userId': _authService.currentUser?.id,
          'userName':
              _authService.currentUser?.displayName ??
              _authService.currentUser?.email,
          'teamName': team.name,
          'totalPoints': team.totalPoints,
          'gameweekPoints': team.gameweekPoints,
          'remainingBudget': team.remainingBudget,
        }),
      );
    } catch (_) {
      // Best effort only.
    }
  }

  Uri? _leagueFunctionUri() {
    final endpoint = AppConfig.supabaseLeagueFunctionUrl;
    if (endpoint.isEmpty) return null;
    return Uri.parse(endpoint);
  }
}
