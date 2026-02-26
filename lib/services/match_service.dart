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
}
