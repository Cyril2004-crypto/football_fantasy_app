import 'package:flutter/material.dart' hide ErrorWidget;
import 'package:provider/provider.dart';
import '../models/player.dart';
import '../providers/team_provider.dart';
import '../providers/player_provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../config/app_config.dart';
import '../utilities/currency_formatter.dart';
import '../widgets/custom_button.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/error_widget.dart' as custom_error;

class TransfersScreen extends StatefulWidget {
  const TransfersScreen({super.key});

  @override
  State<TransfersScreen> createState() => _TransfersScreenState();
}

class _TransfersScreenState extends State<TransfersScreen> {
  Player? _playerToSell;
  Player? _playerToBuy;
  final List<Player> _transfers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<PlayerProvider>().loadAllPlayers();
      context.read<TeamProvider>().loadMyTeam();
    });
  }

  double get _totalBudgetAfterTransfers {
    double budget = AppConfig.teamBudget.toDouble();
    for (final transfer in _transfers) {
      // Assuming even indices are sales, odd are purchases
      if (_transfers.indexOf(transfer) % 2 == 0) {
        budget += transfer.price;
      } else {
        budget -= transfer.price;
      }
    }
    return budget;
  }

  void _addTransfer() {
    if (_playerToSell == null || _playerToBuy == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both a player to sell and a player to buy'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_playerToSell!.id == _playerToBuy!.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot transfer the same player'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final salePrice = _playerToSell!.price;
    final purchasePrice = _playerToBuy!.price;

    if (salePrice < purchasePrice && _totalBudgetAfterTransfers < purchasePrice - salePrice) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Insufficient budget. Need ${CurrencyFormatter.formatPrice(purchasePrice - salePrice)} more',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _transfers.add(_playerToSell!);
      _transfers.add(_playerToBuy!);
      _playerToSell = null;
      _playerToBuy = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Transfer added: ${_playerToSell!.name} → ${_playerToBuy!.name}'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _removeTransfer(int index) {
    setState(() {
      _transfers.removeRange(index, index + 2);
    });
  }

  Future<void> _confirmTransfers() async {
    if (_transfers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No transfers to confirm'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final teamProvider = context.read<TeamProvider>();
      final currentTeam = teamProvider.team;

      if (currentTeam == null) {
        throw Exception('No team found');
      }

      // Build new player list
      final newPlayers = List<Player>.from(currentTeam.players);

      for (int i = 0; i < _transfers.length; i += 2) {
        final playerToRemove = _transfers[i];
        final playerToAdd = _transfers[i + 1];

        newPlayers.removeWhere((p) => p.id == playerToRemove.id);
        newPlayers.add(playerToAdd);
      }

      await teamProvider.updateTeam(
        newPlayers.map((p) => p.id).toList(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transfers confirmed successfully!'),
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
        title: const Text(AppStrings.transfers),
      ),
      body: Consumer2<TeamProvider, PlayerProvider>(
        builder: (context, teamProvider, playerProvider, _) {
          if (teamProvider.isLoading || playerProvider.isLoading) {
            return const LoadingIndicator(message: 'Loading...');
          }

          if (teamProvider.errorMessage != null) {
            return custom_error.ErrorWidget(
              message: teamProvider.errorMessage ?? 'Error loading team',
              onRetry: () => teamProvider.loadMyTeam(),
            );
          }

          final teamPlayers = teamProvider.players;

          return Column(
            children: [
              // Budget Section
              Container(
                padding: const EdgeInsets.all(16),
                color: AppColors.primary,
                child: Column(
                  children: [
                    Text(
                      'Budget Remaining',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textLight,
                          ),
                    ),
                    Text(
                      CurrencyFormatter.formatBudget(_totalBudgetAfterTransfers),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: _totalBudgetAfterTransfers < 0
                                ? AppColors.error
                                : AppColors.secondary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
              // Transfer Input Section
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sell Player Section
                      Text(
                        'Sell Player',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 150,
                        child: ListView.builder(
                          itemCount: teamPlayers.length,
                          itemBuilder: (context, index) {
                            final player = teamPlayers[index];
                            final isSelected = _playerToSell?.id == player.id;

                            return Card(
                              color: isSelected
                                  ? AppColors.error.withOpacity(0.1)
                                  : null,
                              child: ListTile(
                                onTap: () => setState(() {
                                  if (isSelected) {
                                    _playerToSell = null;
                                  } else {
                                    _playerToSell = player;
                                  }
                                }),
                                title: Text(player.name),
                                subtitle: Text('${player.clubName} • ${_getPositionString(player.position)}'),
                                trailing: isSelected
                                    ? const Icon(Icons.check_circle,
                                        color: AppColors.error)
                                    : Icon(Icons.radio_button_unchecked,
                                        color: AppColors.textSecondary),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Buy Player Section
                      Text(
                        'Buy Player',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 150,
                        child: ListView.builder(
                          itemCount: playerProvider.players.length,
                          itemBuilder: (context, index) {
                            final player = playerProvider.players[index];
                            final isSelected = _playerToBuy?.id == player.id;
                            final isInTeam =
                                teamPlayers.any((p) => p.id == player.id);

                            return Card(
                              color: isSelected
                                  ? AppColors.success.withOpacity(0.1)
                                  : null,
                              child: ListTile(
                                onTap: isInTeam
                                    ? null
                                    : () => setState(() {
                                          if (isSelected) {
                                            _playerToBuy = null;
                                          } else {
                                            _playerToBuy = player;
                                          }
                                        }),
                                title: Text(
                                  player.name,
                                  style: TextStyle(
                                    color: isInTeam
                                        ? AppColors.textSecondary
                                        : null,
                                  ),
                                ),
                                subtitle: Text(
                                  '${player.clubName} • ${CurrencyFormatter.formatPrice(player.price)}',
                                  style: TextStyle(
                                    color: isInTeam
                                        ? AppColors.textSecondary
                                        : null,
                                  ),
                                ),
                                trailing: isInTeam
                                    ? Icon(Icons.check, color: AppColors.textSecondary)
                                    : isSelected
                                        ? const Icon(Icons.check_circle,
                                            color: AppColors.success)
                                        : Icon(Icons.radio_button_unchecked,
                                            color: AppColors.textSecondary),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Add Transfer Button
                      CustomButton(
                        text: 'Add Transfer',
                        onPressed: _addTransfer,
                      ),
                      const SizedBox(height: 24),
                      // Pending Transfers
                      if (_transfers.isNotEmpty) ...[
                        Text(
                          'Pending Transfers (${_transfers.length ~/ 2})',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _transfers.length ~/ 2,
                          itemBuilder: (context, index) {
                            final sellPlayer = _transfers[index * 2];
                            final buyPlayer = _transfers[index * 2 + 1];

                            return Card(
                              child: ListTile(
                                title: Text(
                                  '${sellPlayer.name} → ${buyPlayer.name}',
                                ),
                                subtitle: Text(
                                  '${CurrencyFormatter.formatPrice(sellPlayer.price)} → ${CurrencyFormatter.formatPrice(buyPlayer.price)}',
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: AppColors.error),
                                  onPressed: () => _removeTransfer(index * 2),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Confirm Button
              if (_transfers.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: CustomButton(
                    text: 'Confirm All Transfers',
                    onPressed: _isLoading ? null : _confirmTransfers,
                    isLoading: _isLoading,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  String _getPositionString(PlayerPosition position) {
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
