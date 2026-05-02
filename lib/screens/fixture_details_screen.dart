import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../models/match.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/sportmonks_service.dart';

class FixtureDetailsScreen extends StatefulWidget {
  final Match match;

  const FixtureDetailsScreen({super.key, required this.match});

  @override
  State<FixtureDetailsScreen> createState() => _FixtureDetailsScreenState();
}

class _FixtureDetailsScreenState extends State<FixtureDetailsScreen> {
  final SportmonksService _sportmonksService = SportmonksService(
    ApiService(AuthService()),
  );

  late final Future<_FixtureDetailsData> _detailsFuture;
  String? _fixtureVenue;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _detailsFuture = _loadFixtureDetails().then((details) {
      if (mounted) {
        setState(() {
          _fixtureVenue = details.venue;
        });
      }
      return details;
    });
  }

  Future<_FixtureDetailsData> _loadFixtureDetails() async {
    try {
      final fixtureId = await _resolveSportmonksFixtureId();
      if (fixtureId == null) {
        return const _FixtureDetailsData(
          stats: _FixtureStatsData(
            statusMessage:
                'Unable to resolve this fixture in the stats provider.',
          ),
          timeline: <_FixtureEventItem>[],
          venue: null,
          homeLineup: <_LineupPlayer>[],
          awayLineup: <_LineupPlayer>[],
        );
      }

      final centre = await _sportmonksService.getFixtureMatchCentre(fixtureId);
      final data = centre['data'] is Map<String, dynamic>
          ? centre['data'] as Map<String, dynamic>
          : const <String, dynamic>{};

      try {
        debugPrint('Match centre data for fixture $fixtureId: ${jsonEncode(data)}');
      } catch (_) {}

      var stats = _statsFromList(
        data['statistics'] is List
            ? data['statistics'] as List<dynamic>
            : const <dynamic>[],
      );

      if (!stats.hasAny) {
        final fromDateFixtures = await _loadStatsFromDateFixtures();
        if (fromDateFixtures.hasAny) {
          stats = fromDateFixtures;
        } else {
          stats = const _FixtureStatsData(
            statusMessage:
                'No detailed statistics returned yet for this fixture.',
          );
        }
      }

      final timeline = _extractTimeline(data);
      final parsedLineups = _extractLineups(data);
      final venue = _extractVenue(data) ?? widget.match.venue;
      final annotatedLineups = _annotateSubstitutions(
        parsedLineups.home,
        parsedLineups.away,
        timeline,
      );
      return _FixtureDetailsData(
        stats: stats,
        timeline: timeline,
        venue: venue,
        homeLineup: annotatedLineups.home,
        awayLineup: annotatedLineups.away,
      );
    } catch (_) {
      return const _FixtureDetailsData(
        stats: _FixtureStatsData(
          statusMessage: 'Could not load match details right now.',
        ),
        timeline: <_FixtureEventItem>[],
        venue: null,
        homeLineup: <_LineupPlayer>[],
        awayLineup: <_LineupPlayer>[],
      );
    }
  }

  Future<_FixtureStatsData> _loadStatsFromDateFixtures() async {
    final currentHome = _normalizeTeamName(widget.match.homeTeamName);
    final currentAway = _normalizeTeamName(widget.match.awayTeamName);
    final utcDate = widget.match.kickoffTime.toUtc();
    final candidateDates = [
      utcDate.subtract(const Duration(days: 1)),
      utcDate,
      utcDate.add(const Duration(days: 1)),
    ];

    for (final candidate in candidateDates) {
      final date =
          '${candidate.year.toString().padLeft(4, '0')}-${candidate.month.toString().padLeft(2, '0')}-${candidate.day.toString().padLeft(2, '0')}';

      final response = await _sportmonksService.getFixturesByDate(date);
      final rows = response['data'] is List
          ? response['data'] as List<dynamic>
          : const <dynamic>[];

      final row = _findBestByTeams(rows, currentHome, currentAway);
      if (row == null) {
        continue;
      }

      final statistics = row['statistics'] is List
          ? row['statistics'] as List<dynamic>
          : const <dynamic>[];
      final extracted = _statsFromList(statistics);
      if (extracted.hasAny) {
        return extracted;
      }
    }

    return const _FixtureStatsData();
  }

  _FixtureStatsData _statsFromList(List<dynamic> statistics) {
    int? homePossession;
    int? awayPossession;
    int? homeShotsTotal;
    int? awayShotsTotal;
    int? homeShotsOnTarget;
    int? awayShotsOnTarget;
    int? homeShotsOffTarget;
    int? awayShotsOffTarget;

    for (final entry in statistics) {
      if (entry is! Map<String, dynamic>) {
        continue;
      }

      final type =
          (_readString(entry['type'], const ['developer_name']) ??
                  _readString(entry['type'], const ['name']) ??
                  '')
              .toUpperCase();

      final location = (_readString(entry, const ['location']) ?? '')
          .toLowerCase();
      final value = _readInt(entry['data'], const ['value']);
      if (value == null || location.isEmpty) {
        continue;
      }

      final isHome = location == 'home' || location == 'local';

      switch (type) {
        case 'BALL_POSSESSION':
          if (isHome) {
            homePossession = value;
          } else {
            awayPossession = value;
          }
          break;
        case 'SHOTS_TOTAL':
        case 'GOAL_ATTEMPTS':
          if (isHome) {
            homeShotsTotal = value;
          } else {
            awayShotsTotal = value;
          }
          break;
        case 'SHOTS_ON_TARGET':
          if (isHome) {
            homeShotsOnTarget = value;
          } else {
            awayShotsOnTarget = value;
          }
          break;
        case 'SHOTS_OFF_TARGET':
          if (isHome) {
            homeShotsOffTarget = value;
          } else {
            awayShotsOffTarget = value;
          }
          break;
      }
    }

    return _FixtureStatsData(
      homePossession: homePossession,
      awayPossession: awayPossession,
      homeShotsTotal: homeShotsTotal,
      awayShotsTotal: awayShotsTotal,
      homeShotsOnTarget: homeShotsOnTarget,
      awayShotsOnTarget: awayShotsOnTarget,
      homeShotsOffTarget: homeShotsOffTarget,
      awayShotsOffTarget: awayShotsOffTarget,
    );
  }

  List<_FixtureEventItem> _extractTimeline(Map<String, dynamic> data) {
    final events = data['events'] is List
        ? data['events'] as List<dynamic>
        : const <dynamic>[];

    final items = <_FixtureEventItem>[];
    for (final event in events) {
      if (event is! Map<String, dynamic>) {
        continue;
      }

      final minute = _readInt(event, const ['minute']);
      final eventType =
          (_readString(event['type'], const ['name']) ??
                  _readString(event['type'], const ['developer_name']) ??
                  'Match event')
              .replaceAll('_', ' ')
              .trim();
      final playerName = _readString(event['player'], const ['name']);
      final relatedPlayerName = _readString(event['relatedplayer'], const [
        'name',
      ]);
      final teamName =
          _readString(event['team'], const ['name']) ??
          _readString(event['participant'], const ['name']);
      final commentary = _readString(event, const [
        'commentary',
        'description',
        'text',
      ]);

      items.add(
        _FixtureEventItem(
          minute: minute,
          type: eventType,
          playerName: playerName,
          relatedPlayerName: relatedPlayerName,
          teamName: teamName,
          commentary: commentary,
        ),
      );
    }

    items.sort((a, b) {
      final am = a.minute ?? -1;
      final bm = b.minute ?? -1;
      return am.compareTo(bm);
    });
    return items;
  }

  String? _extractVenue(Map<String, dynamic> data) {
    // Common shapes:
    // data['venue'] => String
    // data['venue'] => Map { 'name': 'Stadium', ... }
    // data['venue'] => Map { 'data': { 'name': 'Stadium' } }
    final venueNode = data['venue'];

    if (venueNode is String && venueNode.trim().isNotEmpty) {
      return venueNode.trim();
    }

    if (venueNode is Map<String, dynamic>) {
      final name = _readString(venueNode, const ['name', 'display_name']);
      if (name != null && name.isNotEmpty) return name;

      final inner = venueNode['data'];
      if (inner is Map<String, dynamic>) {
        final innerName = _readString(inner, const ['name', 'display_name', 'venue', 'venue_name']);
        if (innerName != null && innerName.isNotEmpty) return innerName;
      }
    }

    // Some payloads put a top-level venue_name or similar key
    final top = _readString(data, const ['venue_name', 'venue_full_name', 'venue']);
    if (top != null && top.isNotEmpty) return top;

    return null;
  }

  ({List<_LineupPlayer> home, List<_LineupPlayer> away}) _extractLineups(
    Map<String, dynamic> data,
  ) {
    final participants = data['participants'] is List
        ? data['participants'] as List<dynamic>
        : const <dynamic>[];

    String? homeParticipantId;
    String? awayParticipantId;
    for (final participant in participants) {
      if (participant is! Map<String, dynamic>) {
        continue;
      }
      final id = _readString(participant, const ['id']);
      final location =
          (_readString(participant['meta'], const ['location']) ?? '')
              .toLowerCase();
      if (location == 'home' || location == 'local') {
        homeParticipantId = id;
      } else if (location == 'away' || location == 'visitor') {
        awayParticipantId = id;
      }
    }

    final lineups = data['lineups'] is List
        ? data['lineups'] as List<dynamic>
        : const <dynamic>[];

    var home = <_LineupPlayer>[];
    var away = <_LineupPlayer>[];

    for (var index = 0; index < lineups.length; index++) {
      final raw = lineups[index];
      if (raw is! Map<String, dynamic>) {
        continue;
      }

      final playerName =
          _readString(raw['player'], const ['display_name', 'name']) ??
          _readString(raw, const ['player_name', 'playerName']);
      if (playerName == null || playerName.isEmpty) {
        continue;
      }

      final position = _readString(raw, const ['position']);
      final shirtNumber = _readInt(raw, const ['number', 'shirt_number']);
        final lineupType =
          (_readString(raw['type'], const ['name']) ??
              _readString(raw['type'], const ['developer_name']) ??
              '')
            .toLowerCase();
        final isStarter = _isStarterLineupType(lineupType);

      final teamId = _readString(raw, const ['team_id', 'participant_id']);
      final player = _LineupPlayer(
        name: playerName,
        position: position,
        shirtNumber: shirtNumber,
        isStarter: isStarter,
        wasSubbedIn: false,
        wasSubbedOut: false,
        rawOrder: index,
      );

      if (teamId != null && teamId == homeParticipantId) {
        home.add(player);
      } else if (teamId != null && teamId == awayParticipantId) {
        away.add(player);
      } else if (home.length <= away.length) {
        home.add(player);
      } else {
        away.add(player);
      }
    }

    int sortLineup(_LineupPlayer a, _LineupPlayer b) {
      if (a.isStarter != b.isStarter) {
        return a.isStarter ? -1 : 1;
      }
      final an = a.shirtNumber ?? 999;
      final bn = b.shirtNumber ?? 999;
      if (an != bn) {
        return an.compareTo(bn);
      }
      return a.name.compareTo(b.name);
    }

    home.sort(sortLineup);
    away.sort(sortLineup);

    home = _ensureStartingElevens(home);
    away = _ensureStartingElevens(away);

    return (home: home, away: away);
  }

  bool _isStarterLineupType(String lineupType) {
    if (lineupType.contains('bench') ||
        lineupType.contains('reserve') ||
        lineupType.contains('substitute')) {
      return false;
    }

    if (lineupType.contains('starting') ||
        lineupType.contains('starter') ||
        lineupType.contains('lineup') ||
        lineupType.contains('xi') ||
        lineupType.contains('eleven')) {
      return true;
    }

    return false;
  }

  List<_LineupPlayer> _ensureStartingElevens(List<_LineupPlayer> players) {
    final starterCount = players.where((player) => player.isStarter).length;
    if (starterCount > 0 || players.isEmpty) {
      return players;
    }

    final ordered = [...players]..sort((a, b) => a.rawOrder.compareTo(b.rawOrder));
    final result = <_LineupPlayer>[];
    for (var index = 0; index < ordered.length; index++) {
      result.add(
        ordered[index].copyWith(
          isStarter: index < 11,
        ),
      );
    }

    result.sort((a, b) {
      if (a.isStarter != b.isStarter) {
        return a.isStarter ? -1 : 1;
      }
      final an = a.shirtNumber ?? 999;
      final bn = b.shirtNumber ?? 999;
      if (an != bn) {
        return an.compareTo(bn);
      }
      return a.rawOrder.compareTo(b.rawOrder);
    });

    return result;
  }

  ({List<_LineupPlayer> home, List<_LineupPlayer> away}) _annotateSubstitutions(
    List<_LineupPlayer> homeLineup,
    List<_LineupPlayer> awayLineup,
    List<_FixtureEventItem> timeline,
  ) {
    var home = homeLineup;
    var away = awayLineup;

    for (final event in timeline) {
      if (!event.type.toLowerCase().contains('substitut')) {
        continue;
      }

      final first = event.playerName;
      final second = event.relatedPlayerName;
      if (first == null || second == null) {
        continue;
      }

      final firstMatch = _findLineupPlayer(first, home, away);
      final secondMatch = _findLineupPlayer(second, home, away);

      if (firstMatch != null && secondMatch != null) {
        final firstStarter = firstMatch.player.isStarter;
        final secondStarter = secondMatch.player.isStarter;

        if (firstStarter && !secondStarter) {
          home = _markPlayer(home, firstMatch.index, wasSubbedOut: true);
          away = _markPlayer(away, secondMatch.index, wasSubbedIn: true);
        } else if (!firstStarter && secondStarter) {
          home = _markPlayer(home, firstMatch.index, wasSubbedIn: true);
          away = _markPlayer(away, secondMatch.index, wasSubbedOut: true);
        } else {
          home = _markPlayer(home, firstMatch.index, wasSubbedOut: firstStarter);
          away = _markPlayer(away, secondMatch.index, wasSubbedIn: !secondStarter);
        }
      }
    }

    return (home: home, away: away);
  }

  ({int index, _LineupPlayer player})? _findLineupPlayer(
    String playerName,
    List<_LineupPlayer> home,
    List<_LineupPlayer> away,
  ) {
    final normalized = _normalizeTeamName(playerName);

    for (var index = 0; index < home.length; index++) {
      if (_normalizeTeamName(home[index].name) == normalized) {
        return (index: index, player: home[index]);
      }
    }

    for (var index = 0; index < away.length; index++) {
      if (_normalizeTeamName(away[index].name) == normalized) {
        return (index: index, player: away[index]);
      }
    }

    return null;
  }

  List<_LineupPlayer> _markPlayer(
    List<_LineupPlayer> players,
    int index, {
    bool? wasSubbedIn,
    bool? wasSubbedOut,
  }) {
    return [
      for (var i = 0; i < players.length; i++)
        if (i == index)
          players[i].copyWith(
            wasSubbedIn: wasSubbedIn ?? players[i].wasSubbedIn,
            wasSubbedOut: wasSubbedOut ?? players[i].wasSubbedOut,
          )
        else
          players[i],
    ];
  }

  Future<int?> _resolveSportmonksFixtureId() async {
    final currentHome = _normalizeTeamName(widget.match.homeTeamName);
    final currentAway = _normalizeTeamName(widget.match.awayTeamName);

    final directId = int.tryParse(widget.match.id);
    if (directId != null) {
      final centre = await _sportmonksService.getFixtureMatchCentre(directId);
      final data = centre['data'] is Map<String, dynamic>
          ? centre['data'] as Map<String, dynamic>
          : const <String, dynamic>{};
      final teams = _extractHomeAwayTeamNames(data);
      if (teams != null) {
        final home = _normalizeTeamName(teams.$1);
        final away = _normalizeTeamName(teams.$2);
        if (home == currentHome && away == currentAway) {
          return directId;
        }
      }
    }

    final liveResponse = await _sportmonksService.getInplayLivescores();
    final liveRows = liveResponse['data'] is List
        ? liveResponse['data'] as List<dynamic>
        : const <dynamic>[];
    final liveMatch = _findBestByTeams(liveRows, currentHome, currentAway);
    final liveId = _readInt(liveMatch, const ['id']);
    if (liveId != null) {
      return liveId;
    }

    final utcDate = widget.match.kickoffTime.toUtc();
    final candidateDates = [
      utcDate.subtract(const Duration(days: 1)),
      utcDate,
      utcDate.add(const Duration(days: 1)),
    ];

    for (final candidate in candidateDates) {
      final date =
          '${candidate.year.toString().padLeft(4, '0')}-${candidate.month.toString().padLeft(2, '0')}-${candidate.day.toString().padLeft(2, '0')}';

      final dateResponse = await _sportmonksService.getFixturesByDate(date);
      final dateRows = dateResponse['data'] is List
          ? dateResponse['data'] as List<dynamic>
          : const <dynamic>[];
      final dateMatch = _findBestByTeams(dateRows, currentHome, currentAway);
      final dateId = _readInt(dateMatch, const ['id']);
      if (dateId != null) {
        return dateId;
      }
    }

    return null;
  }

  Map<String, dynamic>? _findBestByTeams(
    List<dynamic> rows,
    String currentHome,
    String currentAway,
  ) {
    Map<String, dynamic>? fallback;

    for (final row in rows) {
      if (row is! Map<String, dynamic>) {
        continue;
      }

      final teams = _extractHomeAwayTeamNames(row);
      if (teams == null) {
        continue;
      }

      final home = _normalizeTeamName(teams.$1);
      final away = _normalizeTeamName(teams.$2);

      final exact = home == currentHome && away == currentAway;
      if (exact) {
        return row;
      }

      final swapped = home == currentAway && away == currentHome;
      if (swapped) {
        fallback ??= row;
        continue;
      }

      final fuzzyHome = _isLikelySameTeam(home, currentHome);
      final fuzzyAway = _isLikelySameTeam(away, currentAway);
      if (fuzzyHome && fuzzyAway) {
        fallback ??= row;
      }
    }

    return fallback;
  }

  (String, String)? _extractHomeAwayTeamNames(Map<String, dynamic> row) {
    final participants = row['participants'] is List
        ? row['participants'] as List<dynamic>
        : const <dynamic>[];
    if (participants.length < 2) {
      return null;
    }

    String? home;
    String? away;
    for (final p in participants) {
      if (p is! Map<String, dynamic>) {
        continue;
      }

      final name = _readString(p, const ['name']);
      if (name == null || name.isEmpty) {
        continue;
      }

      final meta = p['meta'] is Map<String, dynamic>
          ? p['meta'] as Map<String, dynamic>
          : const <String, dynamic>{};
      final location = (_readString(meta, const ['location']) ?? '')
          .toLowerCase();

      if (location == 'home' || location == 'local') {
        home = name;
      } else if (location == 'away' || location == 'visitor') {
        away = name;
      }
    }

    if (home != null && away != null) {
      return (home, away);
    }

    final first = _readString(participants[0], const ['name']) ?? '';
    final second = _readString(participants[1], const ['name']) ?? '';
    if (first.isEmpty || second.isEmpty) {
      return null;
    }
    return (first, second);
  }

  bool _isLikelySameTeam(String providerName, String appName) {
    if (providerName == appName) {
      return true;
    }
    if (providerName.contains(appName) || appName.contains(providerName)) {
      return true;
    }

    final providerTokens = providerName
        .split(' ')
        .where((t) => t.isNotEmpty && t.length > 2)
        .toSet();
    final appTokens = appName
        .split(' ')
        .where((t) => t.isNotEmpty && t.length > 2)
        .toSet();

    if (providerTokens.isEmpty || appTokens.isEmpty) {
      return false;
    }

    final overlap = providerTokens.intersection(appTokens).length;
    final minSize = providerTokens.length < appTokens.length
        ? providerTokens.length
        : appTokens.length;
    return overlap >= 1 && overlap * 2 >= minSize;
  }

  int? _readInt(dynamic source, List<String> keys) {
    if (source is! Map<String, dynamic>) {
      return null;
    }

    for (final key in keys) {
      final value = source[key];
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }

    return null;
  }

  String? _readString(dynamic source, List<String> keys) {
    if (source is! Map<String, dynamic>) {
      return null;
    }

    for (final key in keys) {
      final value = source[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
      if (value != null) {
        final asString = value.toString().trim();
        if (asString.isNotEmpty) {
          return asString;
        }
      }
    }

    return null;
  }

  String _normalizeTeamName(String value) {
    return value
        .toLowerCase()
        .replaceAll('fc', '')
        .replaceAll('.', '')
        .replaceAll('&', 'and')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final match = widget.match;
    final localKickoff = match.kickoffTime.toLocal();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fixture Details'),
        backgroundColor: AppColors.primary,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.pageGradient),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: AppColors.mutedLavender,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${match.homeTeamName} vs ${match.awayTeamName}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatKickoff(localKickoff),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildStatusChip(context, match.status),
                    if (match.homeScore != null && match.awayScore != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Score: ${match.homeScore} - ${match.awayScore}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Match Info',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow('Gameweek', '${match.gameweek}'),
                    _buildInfoRow(
                      'Venue',
                      _fixtureVenue ?? match.venue ?? 'TBD',
                    ),
                    _buildInfoRow('Fixture ID', match.id),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildTabBar(context),
            const SizedBox(height: 12),
            FutureBuilder<_FixtureDetailsData>(
              future: _detailsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final details =
                    snapshot.data ??
                    const _FixtureDetailsData(
                      stats: _FixtureStatsData(),
                      timeline: <_FixtureEventItem>[],
                      venue: null,
                      homeLineup: <_LineupPlayer>[],
                      awayLineup: <_LineupPlayer>[],
                    );

                return Column(
                  children: [
                    if (_selectedTabIndex == 0) ...[
                      _buildStatisticsCard(context, details.stats),
                      const SizedBox(height: 12),
                      _buildLineupsCard(
                        context,
                        details.homeLineup,
                        details.awayLineup,
                      ),
                    ] else if (_selectedTabIndex == 1) ...[
                      _buildPlayByPlayCard(context, details.timeline),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildTabButton('Stats & Lineups', 0),
          const SizedBox(width: 8),
          _buildTabButton('Play by Play', 1),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int tabIndex) {
    final isSelected = _selectedTabIndex == tabIndex;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTabIndex = tabIndex;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.mutedLavender,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildPlayByPlayCard(
    BuildContext context,
    List<_FixtureEventItem> timeline,
  ) {
    final spotlightEvent = timeline.isNotEmpty ? timeline.last : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Play by Play',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Animated match events from the live feed.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            if (spotlightEvent == null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.mutedLavender,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'No match events yet. The live pitch animation will appear when the feed starts.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else ...[
              _buildPitchBoard(context, spotlightEvent),
              const SizedBox(height: 16),
              Text(
                'Recent plays',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ...timeline.reversed.take(6).toList().asMap().entries.map((
                entry,
              ) {
                final index = entry.key;
                final event = entry.value;
                return _buildPlayByPlayEvent(
                  context,
                  event,
                  index,
                  timeline.length,
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPitchBoard(BuildContext context, _FixtureEventItem event) {
    final visual = _eventVisualFor(event);
    final team = event.teamName ?? 'Live feed';
    final player = event.playerName ?? 'Unknown player';
    final related = event.relatedPlayerName == null
        ? ''
        : ' (${event.relatedPlayerName})';
    final minute = event.minute == null ? '-' : '${event.minute}\'';

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.94, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: Container(
        height: 250,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF114F1F), Color(0xFF0A3816)],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _PitchPainter())),
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.42),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(visual.icon, color: visual.color, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            visual.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        minute,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 68,
                left: 16,
                right: 16,
                child: Text(
                  '$player$related',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Positioned(
                top: 100,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.32),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    team,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Align(
                  alignment: _eventAlignment(event),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.85, end: 1),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutBack,
                    builder: (context, scale, child) {
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: visual.color.withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: visual.color.withValues(alpha: 0.14),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              visual.icon,
                              color: visual.color,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                visual.label,
                                style: TextStyle(
                                  color: visual.color,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (event.commentary != null &&
                                  event.commentary!.isNotEmpty)
                                Text(
                                  event.commentary!,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: AppColors.textPrimary),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 16,
                child: TweenAnimationBuilder<Alignment>(
                  tween: AlignmentTween(
                    begin: const Alignment(-0.9, 0.6),
                    end: _eventAlignment(event),
                  ),
                  duration: const Duration(milliseconds: 750),
                  curve: Curves.easeOutCubic,
                  builder: (context, alignment, child) {
                    return Align(alignment: alignment, child: child);
                  },
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: visual.color, width: 3),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayByPlayEvent(
    BuildContext context,
    _FixtureEventItem event,
    int index,
    int totalEvents,
  ) {
    final minute = event.minute == null ? '-' : '${event.minute}\'';
    final player = event.playerName ?? 'Unknown player';
    final related = event.relatedPlayerName == null
        ? ''
        : ' (${event.relatedPlayerName})';
    final visual = _eventVisualFor(event);
    final isLastEvent = index == totalEvents - 1;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.94, end: 1),
      duration: Duration(milliseconds: 250 + (index * 60)),
      curve: Curves.easeOutCubic,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: visual.color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
                if (!isLastEvent)
                  Container(
                    width: 2,
                    height: 38,
                    color: AppColors.textSecondary.withValues(alpha: 0.25),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.mutedLavender.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: visual.color.withValues(alpha: 0.16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                visual.label,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: visual.color,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$player$related',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: visual.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            minute,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: visual.color,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                      ],
                    ),
                    if (event.teamName != null &&
                        event.teamName!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        event.teamName!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    if (event.commentary != null &&
                        event.commentary!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        event.commentary!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _EventVisual _eventVisualFor(_FixtureEventItem event) {
    final type = event.type.toLowerCase();

    if (type.contains('goal')) {
      return const _EventVisual('Goal', Icons.sports_soccer, Colors.green);
    }
    if (type.contains('yellow')) {
      return const _EventVisual(
        'Yellow Card',
        Icons.square_outlined,
        Colors.amber,
      );
    }
    if (type.contains('red')) {
      return const _EventVisual(
        'Red Card',
        Icons.stop_circle_outlined,
        Colors.red,
      );
    }
    if (type.contains('substitut')) {
      return const _EventVisual('Substitution', Icons.swap_horiz, Colors.blue);
    }
    if (type.contains('pass')) {
      return const _EventVisual('Pass', Icons.alt_route, Colors.cyan);
    }
    if (type.contains('throw')) {
      return const _EventVisual('Throw in', Icons.compare_arrows, Colors.white);
    }
    if (type.contains('corner')) {
      return const _EventVisual('Corner', Icons.flag_outlined, Colors.orange);
    }
    if (type.contains('var')) {
      return const _EventVisual(
        'VAR',
        Icons.video_call_outlined,
        Colors.purple,
      );
    }
    return const _EventVisual('Match Event', Icons.bolt, Colors.white);
  }

  Alignment _eventAlignment(_FixtureEventItem event) {
    final minute = event.minute ?? 45;
    final type = event.type.toLowerCase();
    final normalizedMinute = (minute % 100) / 50 - 1;

    double vertical;
    if (type.contains('goal')) {
      vertical = -0.1;
    } else if (type.contains('substitut')) {
      vertical = 0.45;
    } else if (type.contains('yellow') || type.contains('red')) {
      vertical = 0.18;
    } else if (type.contains('throw') || type.contains('pass')) {
      vertical = -0.45;
    } else {
      vertical = 0.12;
    }

    return Alignment(normalizedMinute.clamp(-0.92, 0.92), vertical);
  }

  Widget _buildStatisticsCard(BuildContext context, _FixtureStatsData stats) {
    final hasAnyData = stats.hasAny;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Match Statistics',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (!hasAnyData)
              Text(
                stats.statusMessage ??
                    'No statistics available for this fixture yet.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              )
            else ...[
              _buildStatLine(
                'Possession',
                _formatPercent(stats.homePossession),
                _formatPercent(stats.awayPossession),
              ),
              _buildStatLine(
                'Total Shots',
                _formatInt(stats.homeShotsTotal),
                _formatInt(stats.awayShotsTotal),
              ),
              _buildStatLine(
                'Shots On Target',
                _formatInt(stats.homeShotsOnTarget),
                _formatInt(stats.awayShotsOnTarget),
              ),
              _buildStatLine(
                'Shots Off Target',
                _formatInt(stats.homeShotsOffTarget),
                _formatInt(stats.awayShotsOffTarget),
              ),
              _buildStatLine('Total Shot xG', 'N/A', 'N/A'),
              const SizedBox(height: 6),
              Text(
                'xG is not available on this provider endpoint for this fixture.',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLineupsCard(
    BuildContext context,
    List<_LineupPlayer> homeLineup,
    List<_LineupPlayer> awayLineup,
  ) {
    final hasLineups = homeLineup.isNotEmpty || awayLineup.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lineups',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (!hasLineups)
              Text(
                'Lineups are not published yet for this fixture.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildLineupColumn(
                      context,
                      title: widget.match.homeTeamName,
                      players: homeLineup,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildLineupColumn(
                      context,
                      title: widget.match.awayTeamName,
                      players: awayLineup,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineupColumn(
    BuildContext context, {
    required String title,
    required List<_LineupPlayer> players,
  }) {
    final starters = players.where((player) => player.isStarter).toList();
    final bench = players.where((player) => !player.isStarter).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        _buildLineupSection(
          context,
          title: 'Starting XI',
          players: starters,
        ),
        const SizedBox(height: 12),
        _buildLineupSection(
          context,
          title: 'Bench',
          players: bench,
        ),
      ],
    );
  }

  Widget _buildLineupSection(
    BuildContext context, {
    required String title,
    required List<_LineupPlayer> players,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 6),
        if (players.isEmpty)
          Text(
            'None',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          )
        else
          ...players.map((player) {
            final number = player.shirtNumber == null
                ? ''
                : '#${player.shirtNumber} ';
            final icon = player.wasSubbedIn
                ? Icons.input
                : player.wasSubbedOut
                    ? Icons.output
                    : player.isStarter
                        ? Icons.verified
                        : Icons.chair_alt;
            final iconColor = player.wasSubbedIn
                ? Colors.green
                : player.wasSubbedOut
                    ? Colors.orange
                    : player.isStarter
                        ? AppColors.primary
                        : AppColors.textSecondary;
            final statusLabel = player.wasSubbedIn
                ? 'Sub in'
                : player.wasSubbedOut
                    ? 'Sub out'
                    : player.isStarter
                        ? 'Starter'
                        : 'Bench';

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(icon, size: 14, color: iconColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '$number${player.name}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      statusLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: iconColor,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildStatLine(String metric, String home, String away) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 54,
            child: Text(
              home,
              textAlign: TextAlign.left,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              metric,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          SizedBox(
            width: 54,
            child: Text(
              away,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  String _formatInt(int? value) => value?.toString() ?? 'N/A';

  String _formatPercent(int? value) => value == null ? 'N/A' : '$value%';

  Widget _buildStatusChip(BuildContext context, MatchStatus status) {
    final label = _statusLabel(status);
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _formatKickoff(DateTime kickoff) {
    final yyyy = kickoff.year.toString().padLeft(4, '0');
    final mm = kickoff.month.toString().padLeft(2, '0');
    final dd = kickoff.day.toString().padLeft(2, '0');
    final hh = kickoff.hour.toString().padLeft(2, '0');
    final min = kickoff.minute.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd $hh:$min';
  }

  String _statusLabel(MatchStatus status) {
    switch (status) {
      case MatchStatus.scheduled:
        return 'Scheduled';
      case MatchStatus.live:
        return 'Live';
      case MatchStatus.completed:
        return 'Completed';
      case MatchStatus.postponed:
        return 'Postponed';
    }
  }

  Color _statusColor(MatchStatus status) {
    switch (status) {
      case MatchStatus.scheduled:
        return AppColors.info;
      case MatchStatus.live:
        return AppColors.accent;
      case MatchStatus.completed:
        return AppColors.success;
      case MatchStatus.postponed:
        return AppColors.warning;
    }
  }

  String? detailsVenue(_FixtureDetailsData? details) {
    final venue = details?.venue?.trim();
    if (venue == null || venue.isEmpty) {
      return null;
    }
    return venue;
  }
}

class _FixtureDetailsData {
  final _FixtureStatsData stats;
  final List<_FixtureEventItem> timeline;
  final String? venue;
  final List<_LineupPlayer> homeLineup;
  final List<_LineupPlayer> awayLineup;

  const _FixtureDetailsData({
    required this.stats,
    required this.timeline,
    required this.venue,
    required this.homeLineup,
    required this.awayLineup,
  });
}

class _FixtureStatsData {
  final int? homePossession;
  final int? awayPossession;
  final int? homeShotsTotal;
  final int? awayShotsTotal;
  final int? homeShotsOnTarget;
  final int? awayShotsOnTarget;
  final int? homeShotsOffTarget;
  final int? awayShotsOffTarget;
  final String? statusMessage;

  const _FixtureStatsData({
    this.homePossession,
    this.awayPossession,
    this.homeShotsTotal,
    this.awayShotsTotal,
    this.homeShotsOnTarget,
    this.awayShotsOnTarget,
    this.homeShotsOffTarget,
    this.awayShotsOffTarget,
    this.statusMessage,
  });

  bool get hasAny =>
      homePossession != null ||
      awayPossession != null ||
      homeShotsTotal != null ||
      awayShotsTotal != null ||
      homeShotsOnTarget != null ||
      awayShotsOnTarget != null ||
      homeShotsOffTarget != null ||
      awayShotsOffTarget != null;
}

class _FixtureEventItem {
  final int? minute;
  final String type;
  final String? playerName;
  final String? relatedPlayerName;
  final String? teamName;
  final String? commentary;

  const _FixtureEventItem({
    required this.minute,
    required this.type,
    required this.playerName,
    required this.relatedPlayerName,
    required this.teamName,
    required this.commentary,
  });
}

class _EventVisual {
  final String label;
  final IconData icon;
  final Color color;

  const _EventVisual(this.label, this.icon, this.color);
}

class _PitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.34);

    const penaltyWidth = 76.0;
    const penaltyHeight = 118.0;

    canvas.drawRect(Offset.zero & size, paint);
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      paint,
    );
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 38, paint);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 2, paint);
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        (size.height - penaltyHeight) / 2,
        penaltyWidth,
        penaltyHeight,
      ),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        size.width - penaltyWidth,
        (size.height - penaltyHeight) / 2,
        penaltyWidth,
        penaltyHeight,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LineupPlayer {
  final String name;
  final String? position;
  final int? shirtNumber;
  final bool isStarter;
  final bool wasSubbedIn;
  final bool wasSubbedOut;
  final int rawOrder;

  const _LineupPlayer({
    required this.name,
    required this.position,
    required this.shirtNumber,
    required this.isStarter,
    required this.wasSubbedIn,
    required this.wasSubbedOut,
    required this.rawOrder,
  });

  _LineupPlayer copyWith({
    String? name,
    String? position,
    int? shirtNumber,
    bool? isStarter,
    bool? wasSubbedIn,
    bool? wasSubbedOut,
    int? rawOrder,
  }) {
    return _LineupPlayer(
      name: name ?? this.name,
      position: position ?? this.position,
      shirtNumber: shirtNumber ?? this.shirtNumber,
      isStarter: isStarter ?? this.isStarter,
      wasSubbedIn: wasSubbedIn ?? this.wasSubbedIn,
      wasSubbedOut: wasSubbedOut ?? this.wasSubbedOut,
      rawOrder: rawOrder ?? this.rawOrder,
    );
  }
}
