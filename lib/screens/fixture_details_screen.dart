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

  late final Future<_FixtureStatsData> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = _loadStats();
  }

  Future<_FixtureStatsData> _loadStats() async {
    try {
      final fixtureId = await _resolveSportmonksFixtureId();
      if (fixtureId == null) {
        return const _FixtureStatsData(
          statusMessage: 'Unable to resolve this fixture in the stats provider.',
        );
      }

      final centre = await _sportmonksService.getFixtureMatchCentre(fixtureId);
      final data = centre['data'] is Map<String, dynamic>
          ? centre['data'] as Map<String, dynamic>
          : const <String, dynamic>{};

      final statistics = data['statistics'] is List
          ? data['statistics'] as List<dynamic>
          : const <dynamic>[];
      final fromCentre = _statsFromList(statistics);
      if (fromCentre.hasAny) {
        return fromCentre;
      }

      final fromDateFixtures = await _loadStatsFromDateFixtures();
      if (fromDateFixtures.hasAny) {
        return fromDateFixtures;
      }

      return const _FixtureStatsData(
        statusMessage: 'No detailed statistics returned yet for this fixture.',
      );
    } catch (_) {
      return const _FixtureStatsData(
        statusMessage: 'Could not load match stats right now.',
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

      final type = (_readString(entry['type'], const ['developer_name']) ??
              _readString(entry['type'], const ['name']) ??
              '')
          .toUpperCase();

      final location = (_readString(entry, const ['location']) ?? '').toLowerCase();
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
      final location =
          (_readString(meta, const ['location']) ?? '').toLowerCase();

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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
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
                  _buildInfoRow('Venue', match.venue ?? 'TBD'),
                  _buildInfoRow('Fixture ID', match.id),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FutureBuilder<_FixtureStatsData>(
                future: _statsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final stats = snapshot.data ?? const _FixtureStatsData();
                  final hasAnyData = stats.hasAny;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Match Statistics',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      if (!hasAnyData)
                        Text(
                          stats.statusMessage ??
                              'No statistics available for this fixture yet.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
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
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
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
