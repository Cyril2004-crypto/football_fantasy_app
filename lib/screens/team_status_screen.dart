import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/team_provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../utilities/currency_formatter.dart';
import '../widgets/custom_button.dart';
import '../widgets/loading_indicator.dart';
import 'pick_team_screen.dart';
import 'gameweek_points_screen.dart';
import 'transfers_screen.dart';
import 'create_league_screen.dart';
import 'join_league_screen.dart';

class TeamStatusScreen extends StatefulWidget {
  const TeamStatusScreen({super.key});

  @override
  State<TeamStatusScreen> createState() => _TeamStatusScreenState();
}

class _TeamStatusScreenState extends State<TeamStatusScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<TeamProvider>().loadMyTeam();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TeamProvider>(
        builder: (context, teamProvider, _) {
          if (teamProvider.isLoading) {
            return const LoadingIndicator(message: 'Loading team...');
          }

          if (!teamProvider.hasTeam) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.sports_soccer,
                    size: 80,
                    color: AppColors.primary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Team Yet',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create your fantasy team to get started',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: CustomButton(
                      text: AppStrings.selectTeam,
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const PickTeamScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          }

          final team = teamProvider.team!;

          return SingleChildScrollView(
            child: Column(
              children: [
                // Team Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        team.name,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: AppColors.textLight,
                              fontWeight: FontWeight.bold,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _StatCard(
                            label: 'Total Points',
                            value: CurrencyFormatter.formatPoints(team.totalPoints),
                            color: AppColors.secondary,
                          ),
                          _StatCard(
                            label: 'Gameweek Points',
                            value: CurrencyFormatter.formatPoints(team.gameweekPoints),
                            color: AppColors.secondary,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => GameweekPointsScreen(team: team),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _StatCard(
                            label: 'Squad Value',
                            value: CurrencyFormatter.formatBudget(
                              team.players.fold(0.0, (sum, p) => sum + p.price),
                            ),
                            color: AppColors.secondary,
                          ),
                          _StatCard(
                            label: 'Bank',
                            value: CurrencyFormatter.formatBudget(team.remainingBudget),
                            color: AppColors.secondary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Action Buttons
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CustomButton(
                        text: AppStrings.transfers,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const TransfersScreen(),
                            ),
                          );
                        },
                        backgroundColor: AppColors.accent,
                      ),
                      const SizedBox(height: 12),
                      CustomButton(
                        text: 'View Team',
                        onPressed: () {
                          // Show team composition
                          _showTeamComposition(context, team);
                        },
                        backgroundColor: AppColors.secondary,
                        textColor: AppColors.textPrimary,
                      ),
                    ],
                  ),
                ),
                // Leagues Section
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Leagues',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.emoji_events,
                                    color: AppColors.primary),
                                title: const Text('Global League'),
                                subtitle: const Text('15,342 players'),
                                trailing: const Text('Rank: 2,543'),
                              ),
                              const Divider(),
                              ListTile(
                                leading: const Icon(Icons.group,
                                    color: AppColors.primary),
                                title: const Text('Friends League'),
                                subtitle: const Text('8 players'),
                                trailing: const Text('Rank: 3'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              child: const Text(AppStrings.createLeague),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const CreateLeagueScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const JoinLeagueScreen(),
                                  ),
                                );
                              },
                              child: const Text(AppStrings.joinLeague),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Squad Details
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Squad (${team.players.length})',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: _buildPlayersByPosition(team.players),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
  }

  List<Widget> _buildPlayersByPosition(List players) {
    final positions = [
      ('Goalkeepers', players
          .where((p) => p.position.toString().contains('goalkeeper'))
          .toList()),
      ('Defenders', players
          .where((p) => p.position.toString().contains('defender'))
          .toList()),
      ('Midfielders', players
          .where((p) => p.position.toString().contains('midfielder'))
          .toList()),
      ('Forwards', players
          .where((p) => p.position.toString().contains('forward'))
          .toList()),
    ];

    final widgets = <Widget>[];
    for (int i = 0; i < positions.length; i++) {
      final (label, posPlayers) = positions[i];
      if (posPlayers.isEmpty) continue;

      widgets.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (i > 0) const Divider(),
            if (i > 0) const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            ...posPlayers.map((p) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '${p.name} (${p.clubName})',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                )),
          ],
        ),
      );
    }

    return widgets;
  }

  void _showTeamComposition(BuildContext context, dynamic team) {
    showDialog(
      context: context,
      builder: (context) => TeamCompositionDialog(team: team),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textLight.withOpacity(0.8),
              ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );

    if (onTap == null) {
      return content;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: content,
      ),
    );
  }
}

class TeamCompositionDialog extends StatefulWidget {
  final dynamic team;

  const TeamCompositionDialog({super.key, required this.team});

  @override
  State<TeamCompositionDialog> createState() => _TeamCompositionDialogState();
}

class _TeamCompositionDialogState extends State<TeamCompositionDialog> {
  late Set<String> _startingXI;
  late Set<String> _bench;

  @override
  void initState() {
    super.initState();
    _startingXI = <String>{};
    _bench = <String>{};

    final allPlayers = widget.team.players;
    for (int i = 0; i < allPlayers.length; i++) {
      if (i < 11) {
        _startingXI.add(allPlayers[i].id);
      } else {
        _bench.add(allPlayers[i].id);
      }
    }
  }

  bool get _isValid => _startingXI.length == 11 && _bench.length == 4;

  int _getStarterCount(String position) {
    return _startingXI.where((id) {
      final player = widget.team.players.firstWhere((p) => p.id == id);
      return player.position.toString().contains(position);
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final allPlayers = widget.team.players;
    final startingPlayers = allPlayers.where((p) => _startingXI.contains(p.id)).toList();
    final benchPlayers = allPlayers.where((p) => _bench.contains(p.id)).toList();

    return AlertDialog(
      title: const Text('Manage Starting XI'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selected: ${_startingXI.length}/11 Starting + ${_bench.length}/4 Bench',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Formation: ${_getStarterCount('goalkeeper')}-${_getStarterCount('defender')}-${_getStarterCount('midfielder')}-${_getStarterCount('forward')}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Starting XI (${_startingXI.length}/11)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.primary,
                    ),
              ),
              const SizedBox(height: 8),
              if (_startingXI.isEmpty)
                const Text(
                  'Select 11 players for starting XI',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                )
              else
                ...startingPlayers.map((p) => _buildPlayerTile(p, true)),
              const SizedBox(height: 16),
              Text(
                'Bench (${_bench.length}/4)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.accent,
                    ),
              ),
              const SizedBox(height: 8),
              if (_bench.isEmpty)
                const Text(
                  'Select 4 players for bench',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                )
              else
                ...benchPlayers.map((p) => _buildPlayerTile(p, false)),
              const SizedBox(height: 16),
              Text(
                'Available (${allPlayers.length - _startingXI.length - _bench.length})',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              ..._buildAvailablePlayers(allPlayers),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _isValid
              ? () {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Starting XI saved! (${_startingXI.length}/11)',
                      ),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              : null,
          child: const Text('Save Lineup'),
        ),
      ],
    );
  }

  Widget _buildPlayerTile(player, bool isStarting) {
    return Card(
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isStarting ? AppColors.primary : AppColors.accent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            _positionShort(player.position),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.textLight,
            ),
          ),
        ),
        title: Text(player.name),
        subtitle: Text(
          '${player.clubName} • £${player.price.toStringAsFixed(1)}m',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: () => setState(() {
            isStarting ? _startingXI.remove(player.id) : _bench.remove(player.id);
          }),
        ),
      ),
    );
  }

  List<Widget> _buildAvailablePlayers(List allPlayers) {
    final available = allPlayers
        .where((p) => !_startingXI.contains(p.id) && !_bench.contains(p.id))
        .toList();

    if (available.isEmpty) {
      return [
        const Text(
          'All 15 players assigned',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ];
    }

    return available.map((player) {
      return Card(
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.textSecondary.withOpacity(0.3),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _positionShort(player.position),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          title: Text(player.name),
          subtitle: Text(
            '${player.clubName} • £${player.price.toStringAsFixed(1)}m',
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                if (value == 'starting' && _startingXI.length < 11) {
                  _startingXI.add(player.id);
                } else if (value == 'bench' && _bench.length < 4) {
                  _bench.add(player.id);
                }
              });
            },
            itemBuilder: (BuildContext context) => [
              if (_startingXI.length < 11)
                const PopupMenuItem<String>(
                  value: 'starting',
                  child: Text('Add to Starting XI'),
                ),
              if (_bench.length < 4)
                const PopupMenuItem<String>(
                  value: 'bench',
                  child: Text('Add to Bench'),
                ),
            ],
            child: const Icon(Icons.more_vert),
          ),
        ),
      );
    }).toList();
  }

  String _positionShort(dynamic position) {
    final value = position.toString();
    if (value.contains('goalkeeper')) return 'GK';
    if (value.contains('defender')) return 'DEF';
    if (value.contains('midfielder')) return 'MID';
    if (value.contains('forward')) return 'FWD';
    return 'PLY';
  }
}
