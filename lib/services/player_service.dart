import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/player.dart';

class PlayerService {
  SupabaseClient get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      throw Exception(
        'Supabase is not initialized. Configure SUPABASE_URL and SUPABASE_ANON_KEY.',
      );
    }
  }

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
          .where(
            (player) =>
                player.name.toLowerCase().contains(normalizedQuery) ||
                player.clubName.toLowerCase().contains(normalizedQuery),
          )
          .toList();
    } catch (e) {
      throw Exception('Failed to search players: $e');
    }
  }

  Future<List<Player>> getPlayersByIds(List<String> playerExternalIds) async {
    if (playerExternalIds.isEmpty) {
      return const <Player>[];
    }

    try {
      final players = await _fetchPlayers();
      final wanted = playerExternalIds.toSet();
      return players.where((player) => wanted.contains(player.id)).toList();
    } catch (e) {
      throw Exception('Failed to fetch players by ids: $e');
    }
  }

  Future<List<Player>> _fetchPlayers({String? playerExternalId}) async {
    final teamRows = await _client
        .from('fd_teams')
        .select('id, external_id, name')
        .eq('provider', 'football-data');
    final teamById = <String, Map<String, dynamic>>{};
    for (final row in teamRows as List<dynamic>) {
      final team = row as Map<String, dynamic>;
      teamById[team['id'].toString()] = team;
    }

    var query = _client
        .from('fd_players')
        .select(
          'id, external_id, team_id, name, position, nationality, price, is_active',
        );

    if (playerExternalId != null) {
      query = query.eq('external_id', playerExternalId);
    }

    final rows = await query
        .eq('provider', 'football-data')
        .eq('is_active', true)
        .order('name');

    final playerRows = rows as List<dynamic>;
    final internalPlayerIds = playerRows
        .map((row) => (row as Map<String, dynamic>)['id'])
        .whereType<num>()
        .map((id) => id.toInt())
        .toList();

    final seasonAliases = AppConfig.currentFootballSeasonAliases;
    final totalsByPlayerId = <int, int>{};
    final latestGwPointsByPlayerId = <int, int>{};
    final injuredPlayerIds = <int>{};
    final suspendedPlayerIds = <int>{};

    if (internalPlayerIds.isNotEmpty) {
      final injuriesRows = await _client
          .from('fd_player_injuries')
          .select('player_id, status')
          .inFilter('season', seasonAliases)
          .inFilter('player_id', internalPlayerIds);

      for (final rawRow in injuriesRows as List<dynamic>) {
        final row = rawRow as Map<String, dynamic>;
        final playerId = (row['player_id'] as num?)?.toInt();
        final status = row['status']?.toString().toLowerCase() ?? '';
        if (playerId != null && status.contains('injur')) {
          injuredPlayerIds.add(playerId);
        }
      }

      final suspensionsRows = await _client
          .from('fd_player_suspensions')
          .select('player_id, matches_remaining')
          .inFilter('season', seasonAliases)
          .inFilter('player_id', internalPlayerIds);

      for (final rawRow in suspensionsRows as List<dynamic>) {
        final row = rawRow as Map<String, dynamic>;
        final playerId = (row['player_id'] as num?)?.toInt();
        final matchesRemaining = (row['matches_remaining'] as num?)?.toInt() ?? 0;
        if (playerId != null && matchesRemaining > 0) {
          suspendedPlayerIds.add(playerId);
        }
      }

      final latestGwRows = await _client
          .from('fd_player_gameweek_points')
          .select('gameweek')
          .inFilter('season', seasonAliases)
          .order('gameweek', ascending: false)
          .limit(1);

      final latestGameweek = (latestGwRows as List<dynamic>).isNotEmpty
          ? latestGwRows.first['gameweek']?.toInt()
          : null;

      final pointsRows = await _client
          .from('fd_player_gameweek_points')
          .select('player_id, gameweek, points')
          .inFilter('season', seasonAliases)
          .inFilter('player_id', internalPlayerIds);

      for (final rawRow in pointsRows as List<dynamic>) {
        final row = rawRow as Map<String, dynamic>;
        final playerId = (row['player_id'] as num?)?.toInt();
        if (playerId == null) continue;

        final points = (row['points'] as num?)?.toInt() ?? 0;
        final gameweek = (row['gameweek'] as num?)?.toInt();

        totalsByPlayerId.update(
          playerId,
          (value) => value + points,
          ifAbsent: () => points,
        );
        if (latestGameweek != null && gameweek == latestGameweek) {
          latestGwPointsByPlayerId.update(
            playerId,
            (value) => value + points,
            ifAbsent: () => points,
          );
        }
      }
    }

    return playerRows.map((row) {
      final data = row as Map<String, dynamic>;
      final teamId = data['team_id']?.toString();
      final team = teamId != null ? teamById[teamId] : null;
      final internalPlayerId = (data['id'] as num?)?.toInt();

      return Player(
        id: data['external_id'].toString(),
        name: data['name'] as String? ?? 'Unknown Player',
        clubId: team?['external_id']?.toString() ?? teamId ?? '',
        clubName: team?['name'] as String? ?? 'Unknown Team',
        position: _positionFromRaw(data['position'] as String?),
        price:
            (data['price'] as num?)?.toDouble() ??
            _defaultPrice(data['position'] as String?),
        points: internalPlayerId == null
            ? 0
            : (totalsByPlayerId[internalPlayerId] ?? 0),
        gameweekPoints: internalPlayerId == null
            ? 0
            : (latestGwPointsByPlayerId[internalPlayerId] ?? 0),
        nationality: data['nationality'] as String? ?? '',
        isInjured: internalPlayerId != null && injuredPlayerIds.contains(internalPlayerId),
        isSuspended:
            internalPlayerId != null && suspendedPlayerIds.contains(internalPlayerId),
        form: 0.0,
      );
    }).toList();
  }

  PlayerPosition _positionFromRaw(String? position) {
    final value = (position ?? '').toLowerCase();
    if (value.contains('goal')) {
      return PlayerPosition.goalkeeper;
    }
    if (value.contains('def')) {
      return PlayerPosition.defender;
    }
    if (value.contains('mid')) {
      return PlayerPosition.midfielder;
    }
    if (value.contains('forw') || value.contains('strik')) {
      return PlayerPosition.forward;
    }
    return PlayerPosition.midfielder;
  }

  double _defaultPrice(String? position) {
    final value = (position ?? '').toLowerCase();
    if (value.contains('goal')) {
      return 5.0;
    }
    if (value.contains('def')) {
      return 5.5;
    }
    if (value.contains('mid')) {
      return 6.5;
    }
    if (value.contains('forw') || value.contains('strik')) {
      return 7.5;
    }
    return 5.0;
  }
}
