import 'package:flutter/foundation.dart';

import '../constants/api_endpoints.dart';
import '../models/player.dart';
import 'api_service.dart';
import 'points_calculator_service.dart';

class SportmonksService {
  final ApiService _apiService;

  const SportmonksService(this._apiService);

  static const String _tokenFromEnv = String.fromEnvironment(
    'SPORTMONKS_API_TOKEN',
    defaultValue: '',
  );

  Future<Map<String, dynamic>> getInplayLivescores({String? apiToken}) async {
    final resolvedToken = _resolveToken(apiToken);
    return _getWithToken(
      ApiEndpoints.sportmonksInplayLivescores,
      resolvedToken,
    );
  }

  Future<Map<String, dynamic>> getFixtureMatchCentre(
    int fixtureId, {
    String? apiToken,
  }) async {
    final resolvedToken = _resolveToken(apiToken);
    return _getWithToken(
      ApiEndpoints.sportmonksFixtureMatchCentre(fixtureId),
      resolvedToken,
    );
  }

  Future<Map<String, dynamic>> getFixtureNews(
    int fixtureId, {
    String? apiToken,
  }) async {
    final resolvedToken = _resolveToken(apiToken);
    return _getWithToken(
      ApiEndpoints.sportmonksFixtureNews(fixtureId),
      resolvedToken,
    );
  }

  Future<Map<String, dynamic>> getFixtureXgMatch(
    int fixtureId, {
    String? apiToken,
  }) async {
    final resolvedToken = _resolveToken(apiToken);
    return _getWithToken(
      ApiEndpoints.sportmonksFixtureXgMatch(fixtureId),
      resolvedToken,
    );
  }

  Future<List<PlayerGameweekInput>> getPlayerGameweekInputsFromFixture(
    int fixtureId, {
    String? apiToken,
    required Map<String, PlayerPosition> positionsByPlayerId,
  }) async {
    final fixtureResponse = await getFixtureMatchCentre(
      fixtureId,
      apiToken: apiToken,
    );

    final data = fixtureResponse['data'] as Map<String, dynamic>? ?? const {};
    final events = (data['events'] as List<dynamic>? ?? const []);

    final goalsByPlayerId = <String, int>{};
    final assistsByPlayerId = <String, int>{};

    for (final rawEvent in events) {
      final event = rawEvent as Map<String, dynamic>;
      final eventType = _resolveEventType(event);

      if (eventType.contains('goal')) {
        final scorerId = _extractPlayerId(event['player']);
        if (scorerId != null && positionsByPlayerId.containsKey(scorerId)) {
          goalsByPlayerId.update(
            scorerId,
            (value) => value + 1,
            ifAbsent: () => 1,
          );
        }
      }

      if (eventType.contains('assist')) {
        final assistId = _extractPlayerId(event['player']);
        if (assistId != null && positionsByPlayerId.containsKey(assistId)) {
          assistsByPlayerId.update(
            assistId,
            (value) => value + 1,
            ifAbsent: () => 1,
          );
        }
      }
    }

    return positionsByPlayerId.entries.map((entry) {
      final playerId = entry.key;
      return PlayerGameweekInput(
        playerId: playerId,
        position: entry.value,
        goals: goalsByPlayerId[playerId] ?? 0,
        assists: assistsByPlayerId[playerId] ?? 0,
        cleanSheet: false,
      );
    }).toList();
  }

  Future<Map<String, dynamic>> _getWithToken(
    String endpoint,
    String token,
  ) async {
    final tokenizedEndpoint = endpoint.contains('?')
        ? '$endpoint&api_token=$token'
        : '$endpoint?api_token=$token';

    try {
      return await _apiService.getPublic(tokenizedEndpoint);
    } catch (_) {
      if (!kIsWeb) rethrow;

      final proxiedEndpoint =
          'https://corsproxy.io/?${Uri.encodeComponent(tokenizedEndpoint)}';
      return _apiService.getPublic(proxiedEndpoint);
    }
  }

  String _resolveToken(String? token) {
    final resolved = (token ?? _tokenFromEnv).trim();
    if (resolved.isEmpty) {
      throw Exception(
        'Missing SPORTMONKS_API_TOKEN. Run with --dart-define=SPORTMONKS_API_TOKEN=YOUR_TOKEN',
      );
    }
    return resolved;
  }

  String _resolveEventType(Map<String, dynamic> event) {
    final type = event['type'];
    if (type is String) return type.toLowerCase();
    if (type is Map<String, dynamic>) {
      final developerName = type['developer_name']?.toString().toLowerCase();
      final name = type['name']?.toString().toLowerCase();
      return developerName ?? name ?? '';
    }
    return '';
  }

  String? _extractPlayerId(dynamic player) {
    if (player is Map<String, dynamic>) {
      final id = player['id'];
      if (id != null) return id.toString();
    }
    return null;
  }
}
