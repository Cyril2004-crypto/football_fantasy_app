import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_colors.dart';
import '../config/app_config.dart';
import '../models/player.dart';
import '../models/team.dart';

class GameweekPointsScreen extends StatefulWidget {
  final Team team;

  const GameweekPointsScreen({super.key, required this.team});

  @override
  State<GameweekPointsScreen> createState() => _GameweekPointsScreenState();
}

class _GameweekPointsScreenState extends State<GameweekPointsScreen> {
  int _selectedGameweek = 1;
  late Future<Map<String, int>> _pointsFuture;

  final SupabaseClient _client = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _pointsFuture = _loadPlayerPointsForGameweek(_selectedGameweek);
  }

  Future<Map<String, int>> _loadPlayerPointsForGameweek(int gameweek) async {
    final playerIds = widget.team.players.map((player) => player.id).toList();
    if (playerIds.isEmpty) return {};

    final playerRows = await _client
        .from('fd_players')
        .select('id, external_id')
        .eq('provider', 'football-data')
        .inFilter('external_id', playerIds);

    final externalByInternalId = <int, String>{};
    for (final rawRow in playerRows as List<dynamic>) {
      final row = rawRow as Map<String, dynamic>;
      final internalId = (row['id'] as num?)?.toInt();
      final externalId = row['external_id']?.toString();
      if (internalId != null && externalId != null) {
        externalByInternalId[internalId] = externalId;
      }
    }

    if (externalByInternalId.isEmpty) return {};

    final pointRows = await _client
        .from('fd_player_gameweek_points')
        .select('player_id, points')
        .inFilter('season', AppConfig.currentFootballSeasonAliases)
        .eq('gameweek', gameweek)
        .inFilter('player_id', externalByInternalId.keys.toList());

    final pointsByPlayerId = <String, int>{};
    for (final rawRow in pointRows as List<dynamic>) {
      final row = rawRow as Map<String, dynamic>;
      final internalId = (row['player_id'] as num?)?.toInt();
      if (internalId == null) continue;

      final externalId = externalByInternalId[internalId];
      if (externalId == null) continue;

      final points = (row['points'] as num?)?.toInt() ?? 0;
      pointsByPlayerId.update(
        externalId,
        (value) => value + points,
        ifAbsent: () => points,
      );
    }

    return pointsByPlayerId;
  }

  void _reloadPoints() {
    setState(() {
      _pointsFuture = _loadPlayerPointsForGameweek(_selectedGameweek);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gameweek Points'),
        backgroundColor: AppColors.primary,
      ),
      body: FutureBuilder<Map<String, int>>(
        future: _pointsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final pointsByPlayerId = snapshot.data ?? const {};
          final players = [...widget.team.players]
            ..sort(
              (a, b) => (pointsByPlayerId[b.id] ?? 0).compareTo(
                pointsByPlayerId[a.id] ?? 0,
              ),
            );

          final teamGameweekPoints = players.fold<int>(
            0,
            (sum, player) => sum + (pointsByPlayerId[player.id] ?? 0),
          );

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<int>(
                      value: _selectedGameweek,
                      decoration: const InputDecoration(
                        labelText: 'Select Gameweek',
                        border: OutlineInputBorder(),
                      ),
                      items: List.generate(
                        38,
                        (index) => DropdownMenuItem<int>(
                          value: index + 1,
                          child: Text('Gameweek ${index + 1}'),
                        ),
                      ),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _selectedGameweek = value);
                        _reloadPoints();
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${widget.team.name} • GW $_selectedGameweek Points: $teamGameweekPoints',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Player-by-player breakdown for the selected gameweek.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: players.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final player = players[index];
                    final points = pointsByPlayerId[player.id] ?? 0;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary.withOpacity(0.12),
                        child: Text(
                          _positionShort(player.position),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      title: Text(player.name),
                      subtitle: Text(player.clubName),
                      trailing: Text(
                        '$points pts',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _positionShort(PlayerPosition position) {
    switch (position) {
      case PlayerPosition.goalkeeper:
        return 'GK';
      case PlayerPosition.defender:
        return 'DEF';
      case PlayerPosition.midfielder:
        return 'MID';
      case PlayerPosition.forward:
        return 'FWD';
    }
  }
}
