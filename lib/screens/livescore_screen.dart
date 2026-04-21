import 'dart:async';

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
  Timer? _autoRefreshTimer;
  String? _statusMessage;
  DateTime? _lastUpdatedAt;

  @override
  void initState() {
    super.initState();
    _future = _loadLivescores();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      _triggerRefresh();
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
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
      _lastUpdatedAt = DateTime.now();
      return items;
    } catch (e) {
      _statusMessage =
          'Live scores need a SPORTMONKS_API_TOKEN in dart_defines.local.json';
      _lastUpdatedAt = DateTime.now();
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

    final homeParticipantId = participantList.isNotEmpty
        ? _readString(participantList.first, const ['id'])
        : null;
    final awayParticipantId = participantList.length > 1
        ? _readString(participantList[1], const ['id'])
        : null;

    final scores = row['scores'];
    final scoreList = scores is List ? scores : const <dynamic>[];

    int? homeScore;
    int? awayScore;
    int bestHomePriority = -1;
    int bestAwayPriority = -1;

    for (final entry in scoreList) {
      final scoreMap = entry is Map<String, dynamic>
          ? entry
          : const <String, dynamic>{};
      final desc =
          (_readString(scoreMap, const ['description', 'type', 'name']) ?? '')
              .toLowerCase();
      final value = _extractScoreValue(scoreMap);
      if (value == null) {
        continue;
      }

      final participantId = _readString(scoreMap, const ['participant_id']);
      final participantRole = _resolveParticipantRole(
        scoreMap,
        participantId: participantId,
        homeParticipantId: homeParticipantId,
        awayParticipantId: awayParticipantId,
      );
      final priority = _scorePriority(scoreMap, desc);

      if (participantRole == 'home' ||
          desc.contains('home') ||
          desc.contains('local')) {
        if (priority >= bestHomePriority) {
          bestHomePriority = priority;
          homeScore = value;
        }
      } else if (participantRole == 'away' ||
          desc.contains('away') ||
          desc.contains('visitor')) {
        if (priority >= bestAwayPriority) {
          bestAwayPriority = priority;
          awayScore = value;
        }
      } else if (homeScore == null || priority > bestHomePriority) {
        bestHomePriority = priority;
        homeScore = value;
      } else if (awayScore == null || priority > bestAwayPriority) {
        bestAwayPriority = priority;
        awayScore = value;
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

  int? _extractScoreValue(Map<String, dynamic> scoreMap) {
    final direct = _readInt(scoreMap, const ['goals', 'score', 'home', 'away']);
    if (direct != null) return direct;

    final scoreNode = scoreMap['score'];
    if (scoreNode is Map<String, dynamic>) {
      return _readInt(scoreNode, const ['goals', 'current', 'home', 'away']);
    }

    return null;
  }

  String? _resolveParticipantRole(
    Map<String, dynamic> scoreMap, {
    required String? participantId,
    required String? homeParticipantId,
    required String? awayParticipantId,
  }) {
    if (participantId != null) {
      if (participantId == homeParticipantId) return 'home';
      if (participantId == awayParticipantId) return 'away';
    }

    final participant = scoreMap['participant'];
    if (participant is Map<String, dynamic>) {
      final location = _readString(participant, const [
        'location',
        'type',
        'side',
      ])?.toLowerCase();
      if (location == 'home' || location == 'local') return 'home';
      if (location == 'away' || location == 'visitor') return 'away';

      final participantMapId = _readString(participant, const ['id']);
      if (participantMapId != null) {
        if (participantMapId == homeParticipantId) return 'home';
        if (participantMapId == awayParticipantId) return 'away';
      }
    }

    return null;
  }

  int _scorePriority(Map<String, dynamic> scoreMap, String description) {
    final normalized = description.toLowerCase();
    if (normalized.contains('current') ||
        normalized.contains('live') ||
        normalized.contains('fulltime') ||
        normalized.contains('full time')) {
      return 3;
    }
    if (normalized.contains('2nd') ||
        normalized.contains('second') ||
        normalized.contains('1st') ||
        normalized.contains('first') ||
        normalized.contains('half')) {
      return 2;
    }

    final typeId = _readInt(scoreMap, const ['type_id']);
    if (typeId != null && typeId >= 1500) {
      return 2;
    }

    return 1;
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
    _triggerRefresh();
    await _future;
  }

  void _triggerRefresh() {
    setState(() {
      _future = _loadLivescores();
    });
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
            onPressed: _triggerRefresh,
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
                  if (_lastUpdatedAt != null) ...[
                    Text(
                      'Last updated: ${_formatUpdatedTime(_lastUpdatedAt!)}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                  ],
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
              itemCount: matches.length + 1,
              separatorBuilder: (_, index) => index == 0
                  ? const SizedBox(height: 8)
                  : const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index == 0) {
                  final updated = _lastUpdatedAt;
                  if (updated == null) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    'Last updated: ${_formatUpdatedTime(updated)}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  );
                }

                final item = matches[index - 1];
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

  String _formatUpdatedTime(DateTime time) {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    final ss = time.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
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
