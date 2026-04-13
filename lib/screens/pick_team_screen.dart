import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player.dart';
import '../providers/player_provider.dart';
import '../providers/team_provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../config/app_config.dart';
import '../utilities/currency_formatter.dart';
import '../widgets/custom_button.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/error_widget.dart';

class PickTeamScreen extends StatefulWidget {
  const PickTeamScreen({super.key});

  @override
  State<PickTeamScreen> createState() => _PickTeamScreenState();
}

class _PickTeamScreenState extends State<PickTeamScreen> {
  final List<Player> _selectedPlayers = [];
  String _selectedPosition = '';
  late TextEditingController _teamNameController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _teamNameController = TextEditingController();
    Future.microtask(() {
      context.read<PlayerProvider>().loadAllPlayers();
    });
  }

  @override
  void dispose() {
    _teamNameController.dispose();
    super.dispose();
  }

  double get _remainingBudget {
    final spent = _selectedPlayers.fold<double>(0, (sum, p) => sum + p.price);
    return AppConfig.teamBudget - spent;
  }

  bool get _isTeamValid {
    if (_selectedPlayers.length != AppConfig.maxPlayersPerTeam) return false;

    final gkCount =
        _selectedPlayers.where((p) => p.position == PlayerPosition.goalkeeper).length;
    final defCount =
        _selectedPlayers.where((p) => p.position == PlayerPosition.defender).length;
    final midCount =
        _selectedPlayers.where((p) => p.position == PlayerPosition.midfielder).length;
    final fwdCount =
        _selectedPlayers.where((p) => p.position == PlayerPosition.forward).length;

    return gkCount == AppConfig.goalkeepersRequired &&
        defCount == AppConfig.defendersRequired &&
        midCount == AppConfig.midfieldersRequired &&
        fwdCount == AppConfig.forwardsRequired;
  }

  void _togglePlayerSelection(Player player) {
    setState(() {
      if (_selectedPlayers.any((p) => p.id == player.id)) {
        _selectedPlayers.removeWhere((p) => p.id == player.id);
      } else {
        // Check if position limit reached
        final positionCount = _selectedPlayers
            .where((p) => p.position == player.position)
            .length;

        final maxForPosition = _getMaxPlayersForPosition(player.position);
        if (positionCount < maxForPosition &&
            _remainingBudget >= player.price &&
            _selectedPlayers.length < AppConfig.maxPlayersPerTeam) {
          _selectedPlayers.add(player);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_getRejectionReason(player, positionCount, maxForPosition)),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    });
  }

  void _autoFillTeam() {
    setState(() {
      _selectedPlayers.clear();
      final playerProvider = context.read<PlayerProvider>();
      final allPlayers = playerProvider.players;

      // Sort by price ascending to maximize budget usage
      final sortedByPrice = List<Player>.from(allPlayers)
        ..sort((a, b) => a.price.compareTo(b.price));

      // Fill by position
      _fillPositionFromPlayers(
        sortedByPrice,
        PlayerPosition.goalkeeper,
        AppConfig.goalkeepersRequired,
      );
      _fillPositionFromPlayers(
        sortedByPrice,
        PlayerPosition.defender,
        AppConfig.defendersRequired,
      );
      _fillPositionFromPlayers(
        sortedByPrice,
        PlayerPosition.midfielder,
        AppConfig.midfieldersRequired,
      );
      _fillPositionFromPlayers(
        sortedByPrice,
        PlayerPosition.forward,
        AppConfig.forwardsRequired,
      );
    });
  }

  void _fillPositionFromPlayers(
    List<Player> players,
    PlayerPosition position,
    int required,
  ) {
    int added = 0;
    for (final player in players) {
      if (added >= required) break;
      if (player.position != position) continue;
      if (_selectedPlayers.any((p) => p.id == player.id)) continue;
      if (_remainingBudget >= player.price) {
        _selectedPlayers.add(player);
        added++;
      }
    }
  }

  int _getMaxPlayersForPosition(PlayerPosition position) {
    switch (position) {
      case PlayerPosition.goalkeeper:
        return AppConfig.goalkeepersRequired;
      case PlayerPosition.defender:
        return AppConfig.defendersRequired;
      case PlayerPosition.midfielder:
        return AppConfig.midfieldersRequired;
      case PlayerPosition.forward:
        return AppConfig.forwardsRequired;
    }
  }

  String _getRejectionReason(Player player, int currentCount, int maxCount) {
    if (_selectedPlayers.length >= AppConfig.maxPlayersPerTeam) {
      return 'Team is full (${AppConfig.maxPlayersPerTeam} players)';
    }
    if (_remainingBudget < player.price) {
      return 'Insufficient budget. Need ${CurrencyFormatter.formatPrice(player.price)}';
    }
    return 'Maximum ${maxCount} ${player.position.toString().split('.').last}s allowed';
  }

  Future<void> _createTeam() async {
    if (_teamNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a team name'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (!_isTeamValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid team composition'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final teamProvider = context.read<TeamProvider>();
      await teamProvider.createTeam(
        _teamNameController.text,
        _selectedPlayers.map((p) => p.id).toList(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Team created successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.selectTeam),
      ),
      body: Consumer<PlayerProvider>(
        builder: (context, playerProvider, _) {
          if (playerProvider.isLoading) {
            return const LoadingIndicator(message: 'Loading players...');
          }

          if (playerProvider.errorMessage != null) {
            return AppErrorWidget(
              message: playerProvider.errorMessage ?? 'Error loading players',
              onRetry: () => playerProvider.loadAllPlayers(),
            );
          }

          return Column(
            children: [
              // Team Info Summary
              Container(
                padding: const EdgeInsets.all(16),
                color: AppColors.primary,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Squad: ${_selectedPlayers.length}/${AppConfig.maxPlayersPerTeam}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AppColors.textLight,
                              ),
                        ),
                        Text(
                          'Budget: ${CurrencyFormatter.formatBudget(_remainingBudget)}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: _remainingBudget < 0
                                    ? AppColors.error
                                    : AppColors.secondary,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _TeamPositionIndicator(selectedPlayers: _selectedPlayers),
                  ],
                ),
              ),
              // Team Name Input
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _teamNameController,
                  decoration: InputDecoration(
                    labelText: AppStrings.teamName,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.sports_soccer),
                  ),
                ),
              ),
              // Position Filter Tabs
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _PositionFilterChip(
                        label: 'All',
                        onTap: () => setState(() => _selectedPosition = ''),
                        isSelected: _selectedPosition.isEmpty,
                      ),
                      _PositionFilterChip(
                        label: 'GK',
                        onTap: () => setState(() => _selectedPosition = 'goalkeeper'),
                        isSelected: _selectedPosition == 'goalkeeper',
                      ),
                      _PositionFilterChip(
                        label: 'DEF',
                        onTap: () => setState(() => _selectedPosition = 'defender'),
                        isSelected: _selectedPosition == 'defender',
                      ),
                      _PositionFilterChip(
                        label: 'MID',
                        onTap: () => setState(() => _selectedPosition = 'midfielder'),
                        isSelected: _selectedPosition == 'midfielder',
                      ),
                      _PositionFilterChip(
                        label: 'FWD',
                        onTap: () => setState(() => _selectedPosition = 'forward'),
                        isSelected: _selectedPosition == 'forward',
                      ),
                    ],
                  ),
                ),
              ),
              // Players List
              Expanded(
                child: ListView.builder(
                  itemCount: playerProvider.players.length,
                  itemBuilder: (context, index) {
                    final player = playerProvider.players[index];

                    if (_selectedPosition.isNotEmpty &&
                        !player.position.toString().contains(_selectedPosition)) {
                      return const SizedBox.shrink();
                    }

                    final isSelected =
                        _selectedPlayers.any((p) => p.id == player.id);

                    return _PlayerCard(
                      player: player,
                      isSelected: isSelected,
                      isDisabled: !isSelected &&
                          (_remainingBudget < player.price ||
                              _selectedPlayers.length >=
                                  AppConfig.maxPlayersPerTeam ||
                              _selectedPlayers
                                      .where((p) =>
                                          p.position == player.position)
                                      .length >=
                                  _getMaxPlayersForPosition(player.position)),
                      onTap: () => _togglePlayerSelection(player),
                    );
                  },
                ),
              ),
              // Bottom Action Buttons
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _autoFillTeam,
                            child: const Text(AppStrings.autoFill),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setState(() => _selectedPlayers.clear()),
                            child: const Text(AppStrings.clearTeam),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    CustomButton(
                      text: AppStrings.saveTeam,
                      onPressed: _isTeamValid && !_isLoading ? _createTeam : null,
                      isLoading: _isLoading,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TeamPositionIndicator extends StatelessWidget {
  final List<Player> selectedPlayers;

  const _TeamPositionIndicator({required this.selectedPlayers});

  @override
  Widget build(BuildContext context) {
    final gkCount = selectedPlayers
        .where((p) => p.position == PlayerPosition.goalkeeper)
        .length;
    final defCount =
        selectedPlayers.where((p) => p.position == PlayerPosition.defender).length;
    final midCount =
        selectedPlayers.where((p) => p.position == PlayerPosition.midfielder).length;
    final fwdCount =
        selectedPlayers.where((p) => p.position == PlayerPosition.forward).length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _PositionCount('GK', gkCount, AppConfig.goalkeepersRequired),
        _PositionCount('DEF', defCount, AppConfig.defendersRequired),
        _PositionCount('MID', midCount, AppConfig.midfieldersRequired),
        _PositionCount('FWD', fwdCount, AppConfig.forwardsRequired),
      ],
    );
  }
}

class _PositionCount extends StatelessWidget {
  final String position;
  final int current;
  final int required;

  const _PositionCount(this.position, this.current, this.required);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          position,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textLight,
              ),
        ),
        Text(
          '$current/$required',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: current == required ? AppColors.secondary : AppColors.textLight,
              ),
        ),
      ],
    );
  }
}

class _PositionFilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isSelected;

  const _PositionFilterChip({
    required this.label,
    required this.onTap,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        backgroundColor: Colors.transparent,
        selectedColor: AppColors.primary,
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.textSecondary,
        ),
        labelStyle: TextStyle(
          color: isSelected ? AppColors.textLight : AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  final Player player;
  final bool isSelected;
  final bool isDisabled;
  final VoidCallback onTap;

  const _PlayerCard({
    required this.player,
    required this.isSelected,
    required this.isDisabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Card(
        color: isSelected ? AppColors.primary.withOpacity(0.1) : null,
        child: ListTile(
          onTap: isDisabled ? null : onTap,
          leading: CircleAvatar(
            backgroundColor: _getPositionColor(),
            child: Text(
              _getPositionInitial(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          title: Text(
            player.name,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isDisabled ? AppColors.textSecondary : null,
            ),
          ),
          subtitle: Text(
            player.clubName,
            style: TextStyle(
              color: isDisabled ? AppColors.textSecondary : null,
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyFormatter.formatPrice(player.price),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDisabled ? AppColors.textSecondary : null,
                    ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle, color: AppColors.success, size: 18)
              else if (!isDisabled)
                Icon(Icons.add_circle_outline,
                    color: AppColors.primary, size: 18)
              else
                Icon(Icons.lock, color: AppColors.textSecondary, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Color _getPositionColor() {
    switch (player.position) {
      case PlayerPosition.goalkeeper:
        return AppColors.goalkeeper;
      case PlayerPosition.defender:
        return AppColors.defender;
      case PlayerPosition.midfielder:
        return AppColors.midfielder;
      case PlayerPosition.forward:
        return AppColors.forward;
    }
  }

  String _getPositionInitial() {
    switch (player.position) {
      case PlayerPosition.goalkeeper:
        return 'GK';
      case PlayerPosition.defender:
        return 'D';
      case PlayerPosition.midfielder:
        return 'M';
      case PlayerPosition.forward:
        return 'F';
    }
  }
}
