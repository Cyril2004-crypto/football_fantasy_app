import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../models/player.dart';
import '../providers/player_provider.dart';
import '../providers/team_provider.dart';
import '../utilities/currency_formatter.dart';
import '../widgets/custom_button.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/error_widget.dart';

class TransfersScreen extends StatefulWidget {
	const TransfersScreen({super.key});

	@override
	State<TransfersScreen> createState() => _TransfersScreenState();
}

class _TransfersScreenState extends State<TransfersScreen> with SingleTickerProviderStateMixin {
	late TabController _tabController;
	String _searchQuery = '';
	Player? _playerToRemove; // Player being sold
	Player? _playerToAdd; // Player being bought
	bool _isProcessing = false;

	@override
	void initState() {
		super.initState();
		_tabController = TabController(length: 2, vsync: this);
		Future.microtask(() {
			context.read<PlayerProvider>().loadAllPlayers();
		});
	}

	@override
	void dispose() {
		_tabController.dispose();
		super.dispose();
	}

	double get _availableBudget {
		final teamProvider = context.read<TeamProvider>();
		if (teamProvider.team == null) return 0;

		double totalBudget = teamProvider.team!.remainingBudget;

		// Add back the price of the player being sold
		if (_playerToRemove != null) {
			totalBudget += _playerToRemove!.price;
		}

		return totalBudget;
	}

	bool get _canCompleteTransfer {
		if (_playerToRemove == null || _playerToAdd == null) {
			return false;
		}

		return _availableBudget >= _playerToAdd!.price;
	}

	Future<void> _completeTransfer() async {
		if (_playerToRemove == null || _playerToAdd == null || !_canCompleteTransfer) {
			return;
		}

		setState(() => _isProcessing = true);

		try {
			final teamProvider = context.mounted ? context.read<TeamProvider>() : null;
			if (teamProvider?.team == null) {
				throw Exception('Team not found');
			}

			// Create new player list with the transfer
			final currentPlayers = List<Player>.from(teamProvider!.team!.players);
			currentPlayers.removeWhere((p) => p.id == _playerToRemove!.id);
			currentPlayers.add(_playerToAdd!);

			// Update team with new players
			final playerIds = currentPlayers.map((p) => p.id).toList();
			await teamProvider.updateTeam(playerIds, selectedPlayers: currentPlayers);

			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(
						content: Text(
							'Transferred ${_playerToRemove!.name} to ${_playerToAdd!.name}',
						),
						backgroundColor: AppColors.success,
						duration: const Duration(seconds: 2),
					),
				);

				// Reset transfer selection
				setState(() {
					_playerToRemove = null;
					_playerToAdd = null;
					_searchQuery = '';
					_tabController.index = 0;
				});
			}
		} catch (e) {
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(
						content: Text('Transfer failed: $e'),
						backgroundColor: AppColors.error,
					),
				);
			}
		} finally {
			if (mounted) {
				setState(() => _isProcessing = false);
			}
		}
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text('Transfers'),
				bottom: TabBar(
					controller: _tabController,
					tabs: const [
						Tab(text: 'Your Squad'),
						Tab(text: 'Available Players'),
					],
				),
			),
			body: Column(
				children: [
					// Transfer Summary Card
					_buildTransferSummary(),

					// Tab Content
					Expanded(
						child: TabBarView(
							controller: _tabController,
							children: [
								// Your Squad Tab
								_buildSquadTab(),
								// Available Players Tab
								_buildAvailablePlayersTab(),
							],
						),
					),
				],
			),
			bottomNavigationBar: _buildBottomBar(),
		);
	}

	Widget _buildTransferSummary() {
		return Container(
			padding: const EdgeInsets.all(16),
			decoration: BoxDecoration(
				color: AppColors.secondary.withOpacity(0.1),
				border: Border(
					bottom: BorderSide(
						color: AppColors.divider,
						width: 1,
					),
				),
			),
			child: Column(
				children: [
					if (_playerToRemove != null)
						Padding(
							padding: const EdgeInsets.only(bottom: 12),
							child: Row(
								children: [
									Expanded(
										child: Column(
											crossAxisAlignment: CrossAxisAlignment.start,
											children: [
												Text(
													'Selling',
													style: Theme.of(context).textTheme.labelSmall,
												),
												const SizedBox(height: 4),
												Text(
													_playerToRemove!.name,
													style: Theme.of(context).textTheme.bodyMedium?.copyWith(
														fontWeight: FontWeight.bold,
													),
													maxLines: 1,
													overflow: TextOverflow.ellipsis,
												),
											],
										),
									),
									Text(
										'+ ${CurrencyFormatter.formatPrice(_playerToRemove!.price)}',
										style: Theme.of(context).textTheme.bodyMedium?.copyWith(
											color: AppColors.success,
											fontWeight: FontWeight.bold,
										),
									),
									const SizedBox(width: 8),
									IconButton(
										icon: const Icon(Icons.close, size: 20),
										onPressed: () => setState(() => _playerToRemove = null),
										padding: EdgeInsets.zero,
										constraints: const BoxConstraints(),
									),
								],
							),
						),
					if (_playerToAdd != null)
						Row(
							children: [
								Expanded(
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											Text(
												'Buying',
												style: Theme.of(context).textTheme.labelSmall,
											),
											const SizedBox(height: 4),
											Text(
												_playerToAdd!.name,
												style: Theme.of(context).textTheme.bodyMedium?.copyWith(
													fontWeight: FontWeight.bold,
												),
												maxLines: 1,
												overflow: TextOverflow.ellipsis,
											),
										],
									),
								),
								Text(
									'- ${CurrencyFormatter.formatPrice(_playerToAdd!.price)}',
									style: Theme.of(context).textTheme.bodyMedium?.copyWith(
										color: AppColors.error,
										fontWeight: FontWeight.bold,
									),
								),
								const SizedBox(width: 8),
								IconButton(
									icon: const Icon(Icons.close, size: 20),
									onPressed: () => setState(() => _playerToAdd = null),
									padding: EdgeInsets.zero,
									constraints: const BoxConstraints(),
								),
							],
						),
					const SizedBox(height: 12),
					Row(
						mainAxisAlignment: MainAxisAlignment.spaceBetween,
						children: [
							Column(
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									Text(
										'Available Budget',
										style: Theme.of(context).textTheme.labelSmall,
									),
									const SizedBox(height: 4),
									Text(
										CurrencyFormatter.formatBudget(_availableBudget),
										style: Theme.of(context).textTheme.bodyLarge?.copyWith(
											fontWeight: FontWeight.bold,
											color: _availableBudget >= (_playerToAdd?.price ?? 0)
												? AppColors.success
												: AppColors.error,
										),
									),
								],
							),
							if (_playerToAdd != null)
								Column(
									crossAxisAlignment: CrossAxisAlignment.end,
									children: [
										Text(
											'After Transfer',
											style: Theme.of(context).textTheme.labelSmall,
										),
										const SizedBox(height: 4),
										Text(
											CurrencyFormatter.formatBudget(
												_availableBudget - _playerToAdd!.price,
											),
											style: Theme.of(context).textTheme.bodyLarge?.copyWith(
												fontWeight: FontWeight.bold,
											),
										),
									],
								),
						],
					),
				],
			),
		);
	}

	Widget _buildSquadTab() {
		return Consumer2<TeamProvider, PlayerProvider>(
			builder: (context, teamProvider, playerProvider, _) {
				if (teamProvider.team == null) {
					return const Center(
						child: Text('No team found'),
					);
				}

				final currentSquad = teamProvider.team!.players;
				final filteredSquad = currentSquad
					.where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
						p.clubName.toLowerCase().contains(_searchQuery.toLowerCase()))
					.toList();

				return Column(
					children: [
						Padding(
							padding: const EdgeInsets.all(16),
							child: TextField(
								decoration: InputDecoration(
									hintText: 'Search squad...',
									prefixIcon: const Icon(Icons.search),
									border: OutlineInputBorder(
										borderRadius: BorderRadius.circular(8),
									),
									suffixIcon: _searchQuery.isNotEmpty
										? IconButton(
											icon: const Icon(Icons.clear),
											onPressed: () => setState(() => _searchQuery = ''),
										)
										: null,
								),
								onChanged: (value) => setState(() => _searchQuery = value),
							),
						),
						Expanded(
							child: filteredSquad.isEmpty
								? Center(
									child: Text(
										_searchQuery.isEmpty ? 'No players in squad' : 'No results',
										style: Theme.of(context).textTheme.bodyMedium?.copyWith(
											color: AppColors.textSecondary,
										),
									),
								)
								: ListView.separated(
									itemCount: filteredSquad.length,
									separatorBuilder: (_, __) => const Divider(height: 1),
									itemBuilder: (context, index) {
										final player = filteredSquad[index];
										final isSelected = _playerToRemove?.id == player.id;
										return _buildPlayerTile(player, isSelected, true);
									},
								),
						),
					],
				);
			},
		);
	}

	Widget _buildAvailablePlayersTab() {
		return Consumer2<TeamProvider, PlayerProvider>(
			builder: (context, teamProvider, playerProvider, _) {
				if (playerProvider.isLoading) {
					return const LoadingIndicator(message: 'Loading players...');
				}

				if (playerProvider.errorMessage != null) {
					return AppErrorWidget(
						message: playerProvider.errorMessage ?? 'Failed to load players',
					);
				}

				final currentSquadIds = teamProvider.team?.players.map((p) => p.id).toSet() ?? {};
				final availablePlayers = playerProvider.players
					.where((p) => !currentSquadIds.contains(p.id))
					.where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
						p.clubName.toLowerCase().contains(_searchQuery.toLowerCase()))
					.toList();

				return Column(
					children: [
						Padding(
							padding: const EdgeInsets.all(16),
							child: TextField(
								decoration: InputDecoration(
									hintText: 'Search available players...',
									prefixIcon: const Icon(Icons.search),
									border: OutlineInputBorder(
										borderRadius: BorderRadius.circular(8),
									),
									suffixIcon: _searchQuery.isNotEmpty
										? IconButton(
											icon: const Icon(Icons.clear),
											onPressed: () => setState(() => _searchQuery = ''),
										)
										: null,
								),
								onChanged: (value) => setState(() => _searchQuery = value),
							),
						),
						Expanded(
							child: availablePlayers.isEmpty
								? Center(
									child: Text(
										_searchQuery.isEmpty
											? 'No available players'
											: 'No results',
										style: Theme.of(context).textTheme.bodyMedium?.copyWith(
											color: AppColors.textSecondary,
										),
									),
								)
								: ListView.separated(
									itemCount: availablePlayers.length,
									separatorBuilder: (_, __) => const Divider(height: 1),
									itemBuilder: (context, index) {
										final player = availablePlayers[index];
										final isSelected = _playerToAdd?.id == player.id;
										return _buildPlayerTile(player, isSelected, false);
									},
								),
						),
					],
				);
			},
		);
	}

	Widget _buildPlayerTile(Player player, bool isSelected, bool isInSquad) {
		final positionLabel = _getPositionLabel(player.position);
		final canAfford = _availableBudget >= player.price;

		return Container(
			color: isSelected ? AppColors.primary.withOpacity(0.1) : null,
			child: ListTile(
				leading: Container(
					width: 40,
					height: 40,
					decoration: BoxDecoration(
						color: _getPositionColor(player.position),
						borderRadius: BorderRadius.circular(8),
					),
					child: Center(
						child: Text(
							positionLabel,
							style: Theme.of(context).textTheme.labelSmall?.copyWith(
								color: Colors.white,
								fontWeight: FontWeight.bold,
							),
						),
					),
				),
				title: Text(player.name),
				subtitle: Text(
					'${player.clubName}',
					maxLines: 1,
					overflow: TextOverflow.ellipsis,
				),
				trailing: Column(
					mainAxisAlignment: MainAxisAlignment.center,
					crossAxisAlignment: CrossAxisAlignment.end,
					children: [
						Text(
							CurrencyFormatter.formatPrice(player.price),
							style: Theme.of(context).textTheme.labelLarge?.copyWith(
								fontWeight: FontWeight.bold,
								color: !isInSquad && !canAfford
									? AppColors.error
									: AppColors.textPrimary,
							),
						),
						Text(
							'${player.gameweekPoints}pts',
							style: Theme.of(context).textTheme.labelSmall?.copyWith(
								color: AppColors.textSecondary,
							),
						),
					],
				),
				onTap: !isInSquad && !canAfford
					? null
					: () {
						setState(() {
							if (isInSquad) {
								// Toggle player to remove
								if (isSelected) {
									_playerToRemove = null;
								} else {
									_playerToRemove = player;
									_playerToAdd = null;
								}
							} else {
								// Toggle player to add
								if (isSelected) {
									_playerToAdd = null;
								} else {
									_playerToAdd = player;
								}
							}
						});
					},
				enabled: isInSquad || canAfford,
			),
		);
	}

	Widget _buildBottomBar() {
		return Container(
			padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
			decoration: BoxDecoration(
				color: AppColors.surface,
				border: Border(
					top: BorderSide(
						color: AppColors.divider,
						width: 1,
					),
				),
			),
			child: Column(
				mainAxisSize: MainAxisSize.min,
				children: [
					if (_playerToRemove != null && _playerToAdd == null)
						Padding(
							padding: const EdgeInsets.only(bottom: 12),
							child: Text(
								'Select a player to buy',
								style: Theme.of(context).textTheme.bodySmall?.copyWith(
									color: AppColors.textSecondary,
									fontStyle: FontStyle.italic,
								),
								textAlign: TextAlign.center,
							),
						),
					if (_playerToAdd != null && _playerToRemove == null)
						Padding(
							padding: const EdgeInsets.only(bottom: 12),
							child: Text(
								'Select a player to sell',
								style: Theme.of(context).textTheme.bodySmall?.copyWith(
									color: AppColors.textSecondary,
									fontStyle: FontStyle.italic,
								),
								textAlign: TextAlign.center,
							),
						),
					CustomButton(
						text: _isProcessing ? 'Processing...' : 'Complete Transfer',
						onPressed: (_playerToRemove != null && _playerToAdd != null && _canCompleteTransfer && !_isProcessing)
							? _completeTransfer
							: null,
						backgroundColor: _canCompleteTransfer ? AppColors.primary : AppColors.divider,
					),
				],
			),
		);
	}

	String _getPositionLabel(PlayerPosition position) {
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

	Color _getPositionColor(PlayerPosition position) {
		switch (position) {
			case PlayerPosition.goalkeeper:
				return Colors.amber;
			case PlayerPosition.defender:
				return Colors.red;
			case PlayerPosition.midfielder:
				return Colors.green;
			case PlayerPosition.forward:
				return Colors.blue;
		}
	}
}
