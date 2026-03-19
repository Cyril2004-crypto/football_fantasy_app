import 'package:flutter/foundation.dart';

import '../models/match.dart';
import '../constants/api_endpoints.dart';
import 'api_service.dart';

class MatchService {
  final ApiService _apiService;

  MatchService(this._apiService);

  // Get live matches
  Future<List<Match>> getLiveMatches() async {
    try {
      final response = await _apiService.get(ApiEndpoints.liveMatches);
      final matches = (response['data'] as List)
          .map((json) => Match.fromJson(json as Map<String, dynamic>))
          .toList();
      return matches;
    } catch (e) {
      throw Exception('Failed to fetch live matches: $e');
    }
  }

  // Get upcoming matches
  Future<List<Match>> getUpcomingMatches() async {
    try {
      final response = await _apiService.get(ApiEndpoints.upcomingMatches);
      final matches = (response['data'] as List)
          .map((json) => Match.fromJson(json as Map<String, dynamic>))
          .toList();
      return matches;
    } catch (e) {
      throw Exception('Failed to fetch upcoming matches: $e');
    }
  }

  // Get completed matches
  Future<List<Match>> getCompletedMatches() async {
    try {
      final response = await _apiService.get(ApiEndpoints.completedMatches);
      final matches = (response['data'] as List)
          .map((json) => Match.fromJson(json as Map<String, dynamic>))
          .toList();
      return matches;
    } catch (e) {
      throw Exception('Failed to fetch completed matches: $e');
    }
  }

  // Get match by ID
  Future<Match> getMatchById(String id) async {
    try {
      final response = await _apiService.get(ApiEndpoints.matchById(id));
      return Match.fromJson(response['data'] as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to fetch match: $e');
    }
  }

  // Get matches by gameweek
  Future<List<Match>> getMatchesByGameweek(int gameweek) async {
    try {
      final response = await _apiService.get('${ApiEndpoints.matches}?gameweek=$gameweek');
      final matches = (response['data'] as List)
          .map((json) => Match.fromJson(json as Map<String, dynamic>))
          .toList();
      return matches;
    } catch (e) {
      throw Exception('Failed to fetch matches by gameweek: $e');
    }
  }

  // Get EPL fixtures from football-data.org by matchday
  Future<List<Match>> getPremierLeagueMatchesByMatchday(
    int matchday, {
    String? apiToken,
  }) async {
    try {
      if (apiToken == null || apiToken.isEmpty) {
        throw Exception(
          'Missing FOOTBALL_DATA_API_TOKEN. Run with --dart-define=FOOTBALL_DATA_API_TOKEN=YOUR_TOKEN',
        );
      }

      final endpoint = ApiEndpoints.premierLeagueMatchesByMatchday(matchday);
      final headers = {
        'X-Auth-Token': apiToken,
      };

      Map<String, dynamic> response;
      try {
        response = await _apiService.getPublic(endpoint, headers: headers);
      } catch (e) {
        if (!kIsWeb) rethrow;

        final proxiedEndpoint =
            'https://corsproxy.io/?${Uri.encodeComponent(endpoint)}';
        try {
          response = await _apiService.getPublic(proxiedEndpoint, headers: headers);
        } catch (_) {
          throw Exception(
            'Web request blocked/failed (CORS or invalid token). Verify token and rerun with --dart-define=FOOTBALL_DATA_API_TOKEN=YOUR_TOKEN',
          );
        }
      }

      final matchesJson = (response['matches'] as List<dynamic>? ?? const []);

      return matchesJson.map((item) {
        final json = item as Map<String, dynamic>;
        final homeTeam = json['homeTeam'] as Map<String, dynamic>? ?? const {};
        final awayTeam = json['awayTeam'] as Map<String, dynamic>? ?? const {};
        final score = json['score'] as Map<String, dynamic>? ?? const {};
        final fullTime = score['fullTime'] as Map<String, dynamic>? ?? const {};
        final statusRaw = (json['status'] as String? ?? 'SCHEDULED').toUpperCase();

        return Match(
          id: (json['id']?.toString() ?? ''),
          homeTeamId: (homeTeam['id']?.toString() ?? ''),
          homeTeamName: (homeTeam['name'] as String? ?? 'Home Team'),
          awayTeamId: (awayTeam['id']?.toString() ?? ''),
          awayTeamName: (awayTeam['name'] as String? ?? 'Away Team'),
          homeScore: fullTime['home'] as int?,
          awayScore: fullTime['away'] as int?,
          status: _mapFootballDataStatus(statusRaw),
          kickoffTime: DateTime.tryParse(json['utcDate'] as String? ?? '') ?? DateTime.now(),
          gameweek: json['matchday'] as int? ?? matchday,
          venue: (json['venue'] as String?),
        );
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch EPL matchday $matchday fixtures: $e');
    }
  }

  MatchStatus _mapFootballDataStatus(String status) {
    switch (status) {
      case 'IN_PLAY':
      case 'PAUSED':
      case 'LIVE':
        return MatchStatus.live;
      case 'FINISHED':
        return MatchStatus.completed;
      case 'POSTPONED':
      case 'SUSPENDED':
      case 'CANCELLED':
        return MatchStatus.postponed;
      default:
        return MatchStatus.scheduled;
    }
  }
}
