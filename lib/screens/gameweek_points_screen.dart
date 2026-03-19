import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/player.dart';
import '../models/team.dart';

class GameweekPointsScreen extends StatefulWidget {
  final Team team;

  const GameweekPointsScreen({super.key, required this.team});

  @override
  State<GameweekPointsScreen> createState() => _GameweekPointsScreenState();
}

class _GameweekPointsScreenState extends State<GameweekPointsScreen> {
  static const int _referenceGameweek = 11;
  int _selectedGameweek = _referenceGameweek;

  int _playerPointsForGameweek(Player player, int gameweek) {
    if (gameweek == _referenceGameweek) {
      return player.gameweekPoints;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final players = [...widget.team.players]
      ..sort((a, b) => _playerPointsForGameweek(b, _selectedGameweek)
          .compareTo(_playerPointsForGameweek(a, _selectedGameweek)));

    final teamGameweekPoints = players.fold<int>(
      0,
      (sum, player) => sum + _playerPointsForGameweek(player, _selectedGameweek),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gameweek Points'),
        backgroundColor: AppColors.primary,
      ),
      body: Column(
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
                  'Player-by-player breakdown for selected gameweek.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                if (_selectedGameweek != _referenceGameweek)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Detailed local data is currently available for GW $_referenceGameweek.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
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
                final points = _playerPointsForGameweek(player, _selectedGameweek);
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