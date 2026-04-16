import '../models/team.dart';
import '../constants/api_endpoints.dart';
import 'api_service.dart';

class TeamService {
  final ApiService _apiService;

  TeamService(this._apiService);

  // Get user's team
  Future<Team?> getMyTeam() async {
    try {
      final response = await _apiService.get(ApiEndpoints.myTeam);
      if (response['data'] == null) return null;
      return Team.fromJson(response['data'] as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to fetch team: $e');
    }
  }

  // Create team
  Future<Team> createTeam(String teamName, List<String> playerIds) async {
    try {
      final response = await _apiService.post(ApiEndpoints.createTeam, {
        'name': teamName,
        'playerIds': playerIds,
      });
      return Team.fromJson(response['data'] as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to create team: $e');
    }
  }

  // Update team
  Future<Team> updateTeam(String teamId, List<String> playerIds) async {
    try {
      final response = await _apiService.put(ApiEndpoints.updateTeam, {
        'teamId': teamId,
        'playerIds': playerIds,
      });
      return Team.fromJson(response['data'] as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to update team: $e');
    }
  }

  // Get team by ID
  Future<Team> getTeamById(String id) async {
    try {
      final response = await _apiService.get(ApiEndpoints.teamById(id));
      return Team.fromJson(response['data'] as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to fetch team: $e');
    }
  }
}
