import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/sportmonks_service.dart';

class LiveScoreScreen extends StatefulWidget {
  const LiveScoreScreen({super.key});

  @override
  State<LiveScoreScreen> createState() => _LiveScoreScreenState();
}

class _LiveScoreScreenState extends State<LiveScoreScreen> {
  final SportmonksService _sportmonksService = SportmonksService(
    ApiService(AuthService()),
  );
  late Future<List<_LiveScoreItem>> _future;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _future = _loadLivescores();
  }

  Future<List<_LiveScoreItem>> _loadLivescores() async {
    try {
      final response = await _sportmonksService.getInplayLivescores();
      final data = response['data'];
      final rows = data is List ? data : const <dynamic>[];

      final items = rows
          .whereType<Map<String, dynamic>>()
          .map(_parseItem)
          .whereType<_LiveScoreItem>()
          .toList();

      if (items.isEmpty) {
        _statusMessage = 'No live matches right now';
      } else {
        _statusMessage = null;
      }
      return items;
    } catch (e) {
      _statusMessage =
          'Live scores need a SPORTMONKS_API_TOKEN in dart_defines.local.json';
      return const <_LiveScoreItem>[];
    }
  }

  _LiveScoreItem? _parseItem(Map<String, dynamic> row) {
    final participants = row['participants'];
    final participantList = participants is List
        ? participants
        : const <dynamic>[];

    final homeName = participantList.isNotEmpty
        ? _readString(participantList.first, const ['name']) ?? 'Home Team'
        : 'Home Team';
    final awayName = participantList.length > 1
        ? _readString(participantList[1], const ['name']) ?? 'Away Team'
        : 'Away Team';

    final scores = row['scores'];
    final scoreList = scores is List ? scores : const <dynamic>[];

    int? homeScore;
    int? awayScore;

    for (final entry in scoreList) {
      final scoreMap = entry is Map<String, dynamic>
          ? entry
          : const <String, dynamic>{};
      final desc =
          (_readString(scoreMap, const ['description', 'type', 'name']) ?? '')
              .toLowerCase();
      final value = _readInt(scoreMap, const [
        'score',
        'goals',
        'home',
        'away',
      ]);
      if (value == null) {
        continue;
      }

      if (desc.contains('home') || desc.contains('local')) {
        homeScore = value;
      } else if (desc.contains('away') || desc.contains('visitor')) {
        awayScore = value;
      } else if (homeScore == null) {
        homeScore = value;
      } else {
        awayScore ??= value;
      }
    }

    final leagueMap = row['league'] is Map<String, dynamic>
        ? row['league'] as Map<String, dynamic>
        : const <String, dynamic>{};

    final countryMap = leagueMap['country'] is Map<String, dynamic>
        ? leagueMap['country'] as Map<String, dynamic>
        : const <String, dynamic>{};

    return _LiveScoreItem(
      homeName: homeName,
      awayName: awayName,
      homeScore: homeScore,
      awayScore: awayScore,
      league: _readString(leagueMap, const ['name']) ?? 'League',
      country: _readString(countryMap, const ['name']),
      state:
          _readString(row, const ['state', 'status', 'fixture_status']) ??
          'LIVE',
    );
  }

  int? _readInt(Map<String, dynamic> source, List<String> keys) {
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

  Future<void> _refresh() async {
    setState(() {
      _future = _loadLivescores();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Scores'),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _future = _loadLivescores();
              });
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<_LiveScoreItem>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final matches = snapshot.data ?? const <_LiveScoreItem>[];
            if (matches.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 44,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _statusMessage ?? 'No live matches right now',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: matches.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = matches[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'LIVE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.country == null
                                    ? item.league
                                    : '${item.country} - ${item.league}',
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                            ),
                            Text(
                              item.state,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${item.homeName}\n${item.awayName}',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${item.homeScore ?? 0} - ${item.awayScore ?? 0}',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _LiveScoreItem {
  final String homeName;
  final String awayName;
  final int? homeScore;
  final int? awayScore;
  final String league;
  final String? country;
  final String state;

  const _LiveScoreItem({
    required this.homeName,
    required this.awayName,
    required this.homeScore,
    required this.awayScore,
    required this.league,
    required this.country,
    required this.state,
  });
}
