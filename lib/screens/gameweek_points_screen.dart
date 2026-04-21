import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_colors.dart';
import '../config/app_config.dart';
import '../models/player.dart';
import '../models/team.dart';

class GameweekPointsScreen extends StatefulWidget {
  final Team team;
  final SupabaseClient? clientOverride;

  const GameweekPointsScreen({
    super.key,
    required this.team,
    this.clientOverride,
  });

  @override
  State<GameweekPointsScreen> createState() => _GameweekPointsScreenState();
}

class _GameweekPointsScreenState extends State<GameweekPointsScreen> {
  int _selectedGameweek = 1;
  late Future<List<_PlayerGameweekBreakdown>> _pointsFuture;
  late final Map<String, Player> _playersByExternalId;

  SupabaseClient get _client {
    if (widget.clientOverride != null) {
      return widget.clientOverride!;
    }

    try {
      return Supabase.instance.client;
    } catch (_) {
      throw Exception(
        'Supabase is not initialized. Configure SUPABASE_URL and SUPABASE_ANON_KEY.',
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _playersByExternalId = {
      for (final player in widget.team.players) player.id: player,
    };
    _pointsFuture = _loadPlayerPointsForGameweek(_selectedGameweek);
  }

  Future<List<_PlayerGameweekBreakdown>> _loadPlayerPointsForGameweek(
    int gameweek,
  ) async {
    final playerIds = widget.team.players.map((player) => player.id).toList();
    if (playerIds.isEmpty) return const <_PlayerGameweekBreakdown>[];

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

    if (externalByInternalId.isEmpty) return const <_PlayerGameweekBreakdown>[];

    final pointRows = await _client
        .from('fd_player_gameweek_points')
        .select(
          'player_id, fixture_id, minutes, goals, assists, clean_sheet, yellow_cards, red_cards, saves, bonus, points',
        )
        .inFilter('season', AppConfig.currentFootballSeasonAliases)
        .eq('gameweek', gameweek)
        .inFilter('player_id', externalByInternalId.keys.toList());

    final internalPlayerIds = externalByInternalId.keys.toList();
    final fixtureIds = <int>{};
    for (final rawRow in pointRows as List<dynamic>) {
      final row = rawRow as Map<String, dynamic>;
      final fixtureId = (row['fixture_id'] as num?)?.toInt();
      if (fixtureId != null) {
        fixtureIds.add(fixtureId);
      }
    }

    final fixtureTitlesById = await _loadFixtureTitlesById(fixtureIds.toList());
    final eventsByFixtureAndPlayer = await _loadFixtureEventsByPlayer(
      fixtureIds.toList(),
      internalPlayerIds,
    );

    final breakdownByPlayerId = <String, _PlayerGameweekBreakdown>{};
    for (final rawRow in pointRows as List<dynamic>) {
      final row = rawRow as Map<String, dynamic>;
      final internalId = (row['player_id'] as num?)?.toInt();
      if (internalId == null) continue;

      final externalId = externalByInternalId[internalId];
      if (externalId == null) continue;

      final player = _playersByExternalId[externalId];
      if (player == null) continue;
      final fixtureId = (row['fixture_id'] as num?)?.toInt();
      final fixtureTitle = fixtureId == null
          ? 'Unknown fixture'
          : (fixtureTitlesById[fixtureId] ?? 'Fixture #$fixtureId');
      final events = fixtureId == null
          ? const <_FixtureEventLogItem>[]
          : eventsByFixtureAndPlayer[_fixturePlayerKey(
                  fixtureId,
                  internalId,
                )] ??
                const <_FixtureEventLogItem>[];
      final fixturePoints = (row['points'] as num?)?.toInt() ?? 0;

      breakdownByPlayerId.update(
        externalId,
        (existing) => existing.addFixture(
          _FixtureGameweekContribution(
            fixtureId: fixtureId ?? -1,
            fixtureTitle: fixtureTitle,
            points: fixturePoints,
            minutes: (row['minutes'] as num?)?.toInt() ?? 0,
            goals: (row['goals'] as num?)?.toInt() ?? 0,
            assists: (row['assists'] as num?)?.toInt() ?? 0,
            cleanSheet: row['clean_sheet'] as bool? ?? false,
            yellowCards: (row['yellow_cards'] as num?)?.toInt() ?? 0,
            redCards: (row['red_cards'] as num?)?.toInt() ?? 0,
            saves: (row['saves'] as num?)?.toInt() ?? 0,
            bonus: (row['bonus'] as num?)?.toInt() ?? 0,
            events: events,
          ),
          player: player,
        ),
        ifAbsent: () => _PlayerGameweekBreakdown.fromFixture(
          player: player,
          fixture: _FixtureGameweekContribution(
            fixtureId: fixtureId ?? -1,
            fixtureTitle: fixtureTitle,
            points: fixturePoints,
            minutes: (row['minutes'] as num?)?.toInt() ?? 0,
            goals: (row['goals'] as num?)?.toInt() ?? 0,
            assists: (row['assists'] as num?)?.toInt() ?? 0,
            cleanSheet: row['clean_sheet'] as bool? ?? false,
            yellowCards: (row['yellow_cards'] as num?)?.toInt() ?? 0,
            redCards: (row['red_cards'] as num?)?.toInt() ?? 0,
            saves: (row['saves'] as num?)?.toInt() ?? 0,
            bonus: (row['bonus'] as num?)?.toInt() ?? 0,
            events: events,
          ),
        ),
      );
    }

    return breakdownByPlayerId.values.toList();
  }

  Future<Map<int, String>> _loadFixtureTitlesById(List<int> fixtureIds) async {
    if (fixtureIds.isEmpty) return <int, String>{};

    final fixtureRows = await _client
        .from('fd_fixtures')
        .select('id, home_team_id, away_team_id')
        .inFilter('id', fixtureIds);

    final teamRows = await _client
        .from('fd_teams')
        .select('id, name')
        .eq('provider', 'football-data');

    final teamNamesById = <String, String>{};
    for (final rawRow in teamRows as List<dynamic>) {
      final row = rawRow as Map<String, dynamic>;
      teamNamesById[row['id'].toString()] = row['name']?.toString() ?? 'Team';
    }

    final titlesById = <int, String>{};
    for (final rawRow in fixtureRows as List<dynamic>) {
      final row = rawRow as Map<String, dynamic>;
      final fixtureId = (row['id'] as num?)?.toInt();
      if (fixtureId == null) continue;

      final homeName =
          teamNamesById[row['home_team_id'].toString()] ?? 'Home Team';
      final awayName =
          teamNamesById[row['away_team_id'].toString()] ?? 'Away Team';
      titlesById[fixtureId] = '$homeName vs $awayName';
    }

    return titlesById;
  }

  Future<Map<String, List<_FixtureEventLogItem>>> _loadFixtureEventsByPlayer(
    List<int> fixtureIds,
    List<int> playerIds,
  ) async {
    if (fixtureIds.isEmpty || playerIds.isEmpty) {
      return <String, List<_FixtureEventLogItem>>{};
    }

    final rows = await _client
        .from('fd_fixture_events')
        .select('fixture_id, player_id, event_type, minute, description')
        .inFilter('fixture_id', fixtureIds)
        .inFilter('player_id', playerIds);

    final grouped = <String, List<_FixtureEventLogItem>>{};
    for (final rawRow in rows as List<dynamic>) {
      final row = rawRow as Map<String, dynamic>;
      final fixtureId = (row['fixture_id'] as num?)?.toInt();
      final playerId = (row['player_id'] as num?)?.toInt();
      if (fixtureId == null || playerId == null) continue;

      final key = _fixturePlayerKey(fixtureId, playerId);
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(
        _FixtureEventLogItem(
          minute: (row['minute'] as num?)?.toInt(),
          eventType: row['event_type']?.toString() ?? 'event',
          description: row['description']?.toString(),
        ),
      );
    }

    for (final entries in grouped.values) {
      entries.sort((a, b) => (a.minute ?? 0).compareTo(b.minute ?? 0));
    }

    return grouped;
  }

  String _fixturePlayerKey(int fixtureId, int playerId) =>
      '$fixtureId:$playerId';

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
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.pageGradient),
        child: FutureBuilder<List<_PlayerGameweekBreakdown>>(
          future: _pointsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Could not load gameweek points right now.',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Please try again in a moment.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        onPressed: _reloadPoints,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final breakdownByPlayerId = {
              for (final item
                  in snapshot.data ?? const <_PlayerGameweekBreakdown>[])
                item.playerId: item,
            };
            final players = [...widget.team.players]
              ..sort(
                (a, b) => (breakdownByPlayerId[b.id]?.totalPoints ?? 0)
                    .compareTo(breakdownByPlayerId[a.id]?.totalPoints ?? 0),
              );

            final teamGameweekPoints = players.fold<int>(
              0,
              (sum, player) =>
                  sum + (breakdownByPlayerId[player.id]?.totalPoints ?? 0),
            );

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<int>(
                            initialValue: _selectedGameweek,
                            decoration: const InputDecoration(
                              labelText: 'Select Gameweek',
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
                            '${widget.team.name} | GW $_selectedGameweek Points: $teamGameweekPoints',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Points are pulled from stored gameweek stats. Tap a player for the scoring breakdown.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: players.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final player = players[index];
                      final breakdown = breakdownByPlayerId[player.id];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 2,
                        ),
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withValues(
                              alpha: 0.12,
                            ),
                            child: Text(
                              _positionShort(player.position),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          title: Text(player.name),
                          subtitle: Text(
                            player.clubName +
                                (breakdown == null
                                    ? ' · no gameweek data yet'
                                    : ' · ${breakdown.totalMinutes} mins, ${breakdown.totalGoals} goals, ${breakdown.totalAssists} assists'),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.mutedMint,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${breakdown?.totalPoints ?? 0} pts',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            16,
                            0,
                            16,
                            16,
                          ),
                          children: [
                            if (breakdown == null)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'No gameweek stats stored for this player yet.',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                ),
                              )
                            else
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _FormulaSummary(
                                    player: player,
                                    breakdown: breakdown,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Fixture log',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  ...breakdown.fixtures.map(
                                    (fixture) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: Card(
                                        color: AppColors.surface,
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      fixture.fixtureTitle,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .titleSmall
                                                          ?.copyWith(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                    ),
                                                  ),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 6,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          AppColors.mutedMint,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            999,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      '${fixture.points} pts',
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                children: [
                                                  _BreakdownChip(
                                                    'Minutes',
                                                    '${fixture.minutes}',
                                                  ),
                                                  _BreakdownChip(
                                                    'Goals',
                                                    '${fixture.goals}',
                                                  ),
                                                  _BreakdownChip(
                                                    'Assists',
                                                    '${fixture.assists}',
                                                  ),
                                                  _BreakdownChip(
                                                    'Clean Sheet',
                                                    fixture.cleanSheet
                                                        ? 'Yes'
                                                        : 'No',
                                                  ),
                                                  _BreakdownChip(
                                                    'Yellow Cards',
                                                    '${fixture.yellowCards}',
                                                  ),
                                                  _BreakdownChip(
                                                    'Red Cards',
                                                    '${fixture.redCards}',
                                                  ),
                                                  _BreakdownChip(
                                                    'Bonus',
                                                    '${fixture.bonus}',
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 10),
                                              if (fixture.events.isEmpty)
                                                Text(
                                                  'No match events recorded for this player in this fixture.',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: AppColors
                                                            .textSecondary,
                                                      ),
                                                )
                                              else ...[
                                                Text(
                                                  'Events',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .labelLarge
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                ),
                                                const SizedBox(height: 8),
                                                ...fixture.events.map(
                                                  (event) => Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          bottom: 6,
                                                        ),
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          _eventIcon(
                                                            event.eventType,
                                                          ),
                                                          size: 16,
                                                          color:
                                                              AppColors.primary,
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        Expanded(
                                                          child: Text(
                                                            '${event.minute ?? 0}\' - ${event.description ?? event.eventType}',
                                                            style:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .textTheme
                                                                    .bodySmall,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
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

class _PlayerGameweekBreakdown {
  final String playerId;
  final Player player;
  final List<_FixtureGameweekContribution> fixtures;

  int get totalMinutes =>
      fixtures.fold<int>(0, (sum, fixture) => sum + fixture.minutes);
  int get totalGoals =>
      fixtures.fold<int>(0, (sum, fixture) => sum + fixture.goals);
  int get totalAssists =>
      fixtures.fold<int>(0, (sum, fixture) => sum + fixture.assists);
  bool get cleanSheet => fixtures.any((fixture) => fixture.cleanSheet);
  int get yellowCards =>
      fixtures.fold<int>(0, (sum, fixture) => sum + fixture.yellowCards);
  int get redCards =>
      fixtures.fold<int>(0, (sum, fixture) => sum + fixture.redCards);
  int get bonus => fixtures.fold<int>(0, (sum, fixture) => sum + fixture.bonus);
  int get totalPoints =>
      fixtures.fold<int>(0, (sum, fixture) => sum + fixture.points);

  const _PlayerGameweekBreakdown({
    required this.playerId,
    required this.player,
    required this.fixtures,
  });

  factory _PlayerGameweekBreakdown.fromFixture({
    required Player player,
    required _FixtureGameweekContribution fixture,
  }) {
    return _PlayerGameweekBreakdown(
      playerId: player.id,
      player: player,
      fixtures: [fixture],
    );
  }

  _PlayerGameweekBreakdown addFixture(
    _FixtureGameweekContribution fixture, {
    required Player player,
  }) {
    return _PlayerGameweekBreakdown(
      playerId: playerId,
      player: player,
      fixtures: [...fixtures, fixture],
    );
  }
}

class _FixtureGameweekContribution {
  final int fixtureId;
  final String fixtureTitle;
  final int minutes;
  final int goals;
  final int assists;
  final bool cleanSheet;
  final int yellowCards;
  final int redCards;
  final int saves;
  final int bonus;
  final int points;
  final List<_FixtureEventLogItem> events;

  const _FixtureGameweekContribution({
    required this.fixtureId,
    required this.fixtureTitle,
    required this.minutes,
    required this.goals,
    required this.assists,
    required this.cleanSheet,
    required this.yellowCards,
    required this.redCards,
    required this.saves,
    required this.bonus,
    required this.points,
    required this.events,
  });
}

class _FixtureEventLogItem {
  final int? minute;
  final String eventType;
  final String? description;

  const _FixtureEventLogItem({
    required this.minute,
    required this.eventType,
    required this.description,
  });
}

class _FormulaSummary extends StatelessWidget {
  final Player player;
  final _PlayerGameweekBreakdown breakdown;

  const _FormulaSummary({required this.player, required this.breakdown});

  @override
  Widget build(BuildContext context) {
    final goalValue = _goalPointsForPosition(player.position);
    final cleanSheetValue =
        player.position == PlayerPosition.goalkeeper ||
            player.position == PlayerPosition.defender
        ? AppConfig.pointsPerCleanSheet
        : 0;
    final savesPoints = player.position == PlayerPosition.goalkeeper
        ? (breakdown.fixtures.fold<int>(
            0,
            (sum, fixture) => sum + (fixture.saves ~/ 3),
          ))
        : 0;
    final goalsPoints = breakdown.totalGoals * goalValue;
    final assistsPoints = breakdown.totalAssists * AppConfig.pointsPerAssist;
    final cleanSheetPoints =
        breakdown.fixtures.any((fixture) => fixture.cleanSheet)
        ? cleanSheetValue
        : 0;
    final bonusPoints = breakdown.bonus;
    final yellowPenalty = breakdown.yellowCards;
    final redPenalty = breakdown.redCards * 3;
    final computedTotal =
        goalsPoints +
        assistsPoints +
        cleanSheetPoints +
        bonusPoints +
        savesPoints -
        yellowPenalty -
        redPenalty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Points formula',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _BreakdownChip(
              'Goals',
              '${breakdown.totalGoals} x $goalValue = $goalsPoints',
            ),
            _BreakdownChip(
              'Assists',
              '${breakdown.totalAssists} x ${AppConfig.pointsPerAssist} = $assistsPoints',
            ),
            _BreakdownChip(
              'Clean Sheet',
              cleanSheetPoints > 0 ? '+$cleanSheetPoints' : '0',
            ),
            _BreakdownChip('Bonus', '+$bonusPoints'),
            _BreakdownChip(
              'Saves',
              player.position == PlayerPosition.goalkeeper
                  ? '+$savesPoints'
                  : '0',
            ),
            _BreakdownChip('Yellow Cards', '-$yellowPenalty'),
            _BreakdownChip('Red Cards', '-$redPenalty'),
            _BreakdownChip('Total', '${breakdown.totalPoints} pts'),
          ],
        ),
        if (computedTotal != breakdown.totalPoints) ...[
          const SizedBox(height: 6),
          Text(
            'Stored total differs from the live formula by ${breakdown.totalPoints - computedTotal}. The stored value is what the app currently uses.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          'Rule set: goals depend on position, assists are ${AppConfig.pointsPerAssist}, clean sheets are ${AppConfig.pointsPerCleanSheet} for GK/DEF, yellow cards are -1, red cards are -3, bonus is added directly, and goalkeeper saves add 1 per 3 saves.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

int _goalPointsForPosition(PlayerPosition position) {
  switch (position) {
    case PlayerPosition.goalkeeper:
      return AppConfig.pointsPerGoalGK;
    case PlayerPosition.defender:
      return AppConfig.pointsPerGoalDEF;
    case PlayerPosition.midfielder:
      return AppConfig.pointsPerGoalMID;
    case PlayerPosition.forward:
      return AppConfig.pointsPerGoalFWD;
  }
}

IconData _eventIcon(String eventType) {
  final type = eventType.toLowerCase();
  if (type.contains('goal')) return Icons.sports_soccer;
  if (type.contains('assist')) return Icons.add_circle_outline;
  if (type.contains('yellow')) return Icons.square_outlined;
  if (type.contains('red')) return Icons.stop_circle_outlined;
  if (type.contains('sub')) return Icons.swap_horiz;
  if (type.contains('save')) return Icons.safety_check;
  return Icons.bolt;
}

class _BreakdownChip extends StatelessWidget {
  final String label;
  final String value;

  const _BreakdownChip(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.mutedLavender,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}
