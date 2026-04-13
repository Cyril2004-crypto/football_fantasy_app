import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/player.dart';

class PlayerService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Player>> getAllPlayers() async {
    try {
      return await _fetchPlayers();
    } catch (e) {
      throw Exception('Failed to fetch players: $e');
    }
  }

  Future<Player> getPlayerById(String id) async {
    try {
      final players = await _fetchPlayers(playerExternalId: id);
      if (players.isEmpty) {
        throw Exception('Player not found');
      }
      return players.first;
    } catch (e) {
      throw Exception('Failed to fetch player: $e');
    }
  }

  Future<List<Player>> getPlayersByPosition(PlayerPosition position) async {
    try {
      return (await _fetchPlayers())
          .where((player) => player.position == position)
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch players by position: $e');
    }
  }

  Future<List<Player>> getPlayersByTeam(String teamId) async {
    try {
      return (await _fetchPlayers())
          .where((player) => player.clubId == teamId)
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch players by team: $e');
    }
  }

  Future<List<Player>> searchPlayers(String query) async {
    try {
      final normalizedQuery = query.toLowerCase();
      return (await _fetchPlayers())
          .where((player) =>
              player.name.toLowerCase().contains(normalizedQuery) ||
              player.clubName.toLowerCase().contains(normalizedQuery))
          .toList();
    } catch (e) {
      throw Exception('Failed to search players: $e');
    }
  }

  Future<List<Player>> _fetchPlayers({String? playerExternalId}) async {
    final teamRows = await _client.from('fd_teams').select('id, external_id, name').eq('provider', 'football-data');
    final teamById = <String, Map<String, dynamic>>{};
    for (final row in teamRows as List<dynamic>) {
      final team = row as Map<String, dynamic>;
      teamById[team['id'].toString()] = team;
    }

    var query = _client
        .from('fd_players')
        .select('id, external_id, team_id, name, position, nationality, price, is_active');

    if (playerExternalId != null) {
      query = query.eq('external_id', playerExternalId);
    }

    final rows = await query
      .eq('provider', 'football-data')
      .eq('is_active', true)
      .order('name');

    return (rows as List<dynamic>).map((row) {
      final data = row as Map<String, dynamic>;
      final teamId = data['team_id']?.toString();
      final team = teamId != null ? teamById[teamId] : null;

      return Player(
        id: data['external_id'].toString(),
        name: data['name'] as String? ?? 'Unknown Player',
        clubId: team?['external_id']?.toString() ?? teamId ?? '',
        clubName: team?['name'] as String? ?? 'Unknown Team',
        position: _positionFromRaw(data['position'] as String?),
        price: (data['price'] as num?)?.toDouble() ?? _defaultPrice(data['position'] as String?),
        points: 0,
        gameweekPoints: 0,
        nationality: data['nationality'] as String? ?? '',
        form: 0.0,
      );
    }).toList();
  }

  PlayerPosition _positionFromRaw(String? position) {
    final value = (position ?? '').toLowerCase();
    if (value.contains('goal')) return PlayerPosition.goalkeeper;
    if (value.contains('def')) return PlayerPosition.defender;
    if (value.contains('mid')) return PlayerPosition.midfielder;
    if (value.contains('forw') || value.contains('strik')) return PlayerPosition.forward;
    return PlayerPosition.midfielder;
  }

  double _defaultPrice(String? position) {
    final value = (position ?? '').toLowerCase();
    if (value.contains('goal')) return 5.0;
    if (value.contains('def')) return 5.5;
    if (value.contains('mid')) return 6.5;
    if (value.contains('forw') || value.contains('strik')) return 7.5;
    return 5.0;
  }
}
