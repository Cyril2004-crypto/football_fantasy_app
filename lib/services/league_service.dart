import '../models/league.dart';
import '../constants/api_endpoints.dart';
import 'api_service.dart';

class LeagueService {
  final ApiService _apiService;

  LeagueService(this._apiService);

  // Get user's leagues
  Future<List<League>> getMyLeagues() async {
    try {
      final response = await _apiService.get(ApiEndpoints.myLeagues);
      final leagues = (response['data'] as List)
          .map((json) => League.fromJson(json as Map<String, dynamic>))
          .toList();
      return leagues;
    } catch (e) {
      throw Exception('Failed to fetch leagues: $e');
    }
  }

  // Create league
  Future<League> createLeague(String name, LeagueType type) async {
    try {
      final response = await _apiService.post(
        ApiEndpoints.createLeague,
        {
          'name': name,
          'type': type == LeagueType.public ? 'public' : 'private',
        },
      );
      return League.fromJson(response['data'] as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to create league: $e');
    }
  }

  // Join league
  Future<void> joinLeague(String leagueCode) async {
    try {
      await _apiService.post(
        ApiEndpoints.joinLeague,
        {'code': leagueCode},
      );
    } catch (e) {
      throw Exception('Failed to join league: $e');
    }
  }

  // Get league standings
  Future<List<LeagueStanding>> getLeagueStandings(String leagueId) async {
    try {
      final response = await _apiService.get('${ApiEndpoints.leagueStandings}/$leagueId');
      final standings = (response['data'] as List)
          .map((json) => LeagueStanding.fromJson(json as Map<String, dynamic>))
          .toList();
      return standings;
    } catch (e) {
      throw Exception('Failed to fetch league standings: $e');
    }
  }

  // Get league by ID
  Future<League> getLeagueById(String id) async {
    try {
      final response = await _apiService.get(ApiEndpoints.leagueById(id));
      return League.fromJson(response['data'] as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to fetch league: $e');
    }
  }

  // Get public leagues
  Future<List<League>> getPublicLeagues() async {
    try {
      final response = await _apiService.get('${ApiEndpoints.leagues}?type=public');
      final leagues = (response['data'] as List)
          .map((json) => League.fromJson(json as Map<String, dynamic>))
          .toList();
      return leagues;
    } catch (e) {
      throw Exception('Failed to fetch public leagues: $e');
    }
  }

  // Get EPL competition details from football-data.org
  Future<Map<String, dynamic>> getPremierLeagueCompetition({String? apiToken}) async {
    try {
      return await _apiService.getPublic(
        ApiEndpoints.premierLeagueCompetition,
        headers: {
          if (apiToken != null && apiToken.isNotEmpty) 'X-Auth-Token': apiToken,
        },
      );
    } catch (e) {
      throw Exception('Failed to fetch Premier League competition: $e');
    }
  }
}
