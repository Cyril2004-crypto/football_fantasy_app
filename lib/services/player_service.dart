import '../models/player.dart';
import '../constants/api_endpoints.dart';
import 'api_service.dart';

class PlayerService {
  final ApiService _apiService;

  PlayerService(this._apiService);

  // Get all players
  Future<List<Player>> getAllPlayers() async {
    try {
      final response = await _apiService.get(ApiEndpoints.players);
      final players = (response['data'] as List)
          .map((json) => Player.fromJson(json as Map<String, dynamic>))
          .toList();
      return players;
    } catch (e) {
      throw Exception('Failed to fetch players: $e');
    }
  }

  // Get player by ID
  Future<Player> getPlayerById(String id) async {
    try {
      final response = await _apiService.get(ApiEndpoints.playerById(id));
      return Player.fromJson(response['data'] as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to fetch player: $e');
    }
  }

  // Get players by position
  Future<List<Player>> getPlayersByPosition(PlayerPosition position) async {
    try {
      final positionString = _positionToString(position);
      final response = await _apiService.get('${ApiEndpoints.playersByPosition}?position=$positionString');
      final players = (response['data'] as List)
          .map((json) => Player.fromJson(json as Map<String, dynamic>))
          .toList();
      return players;
    } catch (e) {
      throw Exception('Failed to fetch players by position: $e');
    }
  }

  // Get players by team
  Future<List<Player>> getPlayersByTeam(String teamId) async {
    try {
      final response = await _apiService.get('${ApiEndpoints.playersByTeam}?teamId=$teamId');
      final players = (response['data'] as List)
          .map((json) => Player.fromJson(json as Map<String, dynamic>))
          .toList();
      return players;
    } catch (e) {
      throw Exception('Failed to fetch players by team: $e');
    }
  }

  // Search players
  Future<List<Player>> searchPlayers(String query) async {
    try {
      final response = await _apiService.get('${ApiEndpoints.players}?search=$query');
      final players = (response['data'] as List)
          .map((json) => Player.fromJson(json as Map<String, dynamic>))
          .toList();
      return players;
    } catch (e) {
      throw Exception('Failed to search players: $e');
    }
  }

  String _positionToString(PlayerPosition position) {
    switch (position) {
      case PlayerPosition.goalkeeper:
        return 'goalkeeper';
      case PlayerPosition.defender:
        return 'defender';
      case PlayerPosition.midfielder:
        return 'midfielder';
      case PlayerPosition.forward:
        return 'forward';
    }
  }
}
