import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/team_analytics.dart';

double calculateTeamFormScoreFromInputs(
  List<FormTrend> trends,
  List<InjuryRisk> injuryRisks,
) {
  if (trends.isEmpty) {
    return 50.0;
  }

  double formScore = 0;
  for (final trend in trends.take(5)) {
    formScore += trend.windowAverage;
  }
  formScore = (formScore / trends.take(5).length).clamp(0, 100);

  final highRiskPlayers = injuryRisks
      .where((r) => r.riskLevel == 'high')
      .length;
  final injuryPenalty = (highRiskPlayers * 5).toDouble();

  final finalScore = (formScore - injuryPenalty).clamp(0, 100);
  return finalScore.toDouble();
}

List<TransferRecommendation> buildTransferRecommendationsFromInputs({
  required List<Map<String, dynamic>> players,
  required List<Map<String, dynamic>> statsResponse,
  required List<Map<String, dynamic>> pointsResponse,
}) {
  final statsMap = <int, List<Map<String, dynamic>>>{};
  final pointsMap = <int, List<int>>{};

  for (final stat in statsResponse) {
    final playerId = stat['player_id'] as int;
    statsMap.putIfAbsent(playerId, () => []);
    statsMap[playerId]!.add(stat);
  }

  for (final point in pointsResponse) {
    final playerId = point['player_id'] as int;
    pointsMap.putIfAbsent(playerId, () => []);
    pointsMap[playerId]!.add(point['points'] as int);
  }

  final recommendations = players
      .map((player) {
        final playerId = player['id'] as int;
        final playerName = player['name'] as String? ?? 'Unknown';
        final position = player['position'] as String? ?? 'Unknown';

        final playerStats = statsMap[playerId] ?? [];
        final playerPoints = pointsMap[playerId] ?? [];

        final avgXg = playerStats.isEmpty
            ? 0.0
            : playerStats
                      .map((s) => (s['expected_goals'] as num?) ?? 0)
                      .reduce((a, b) => a + b) /
                  playerStats.length;

        final avgXa = playerStats.isEmpty
            ? 0.0
            : playerStats
                      .map((s) => (s['expected_assists'] as num?) ?? 0)
                      .reduce((a, b) => a + b) /
                  playerStats.length;

        final recentAvg = playerPoints.isEmpty
            ? 0
            : playerPoints.reduce((a, b) => a + b) ~/ playerPoints.length;

        final estimatedBasePrice = _estimatedPrice(position);
        final performanceMultiplier = (recentAvg / 10.0).clamp(0.5, 2.0);
        final estimatedPrice = estimatedBasePrice * performanceMultiplier;
        final estimatedValue =
            recentAvg.toDouble() * 1.5 + avgXg * 3 + avgXa * 3;

        final action = estimatedValue > estimatedPrice
            ? 'buy'
            : estimatedValue < (estimatedPrice * 0.7)
            ? 'sell'
            : 'hold';

        final priority = (estimatedValue / (estimatedPrice + 0.001))
            .clamp(1, 5)
            .toInt();

        return TransferRecommendation(
          playerId: playerId,
          playerName: playerName,
          position: position,
          estimatedValue: estimatedValue,
          estimatedPrice: estimatedPrice,
          recentPointsAverage: recentAvg,
          expectedGoals: avgXg,
          expectedAssists: avgXa,
          action: action,
          priority: priority,
        );
      })
      .where((r) => r.action != 'hold')
      .toList();

  recommendations.sort((a, b) => b.priority.compareTo(a.priority));
  return recommendations;
}

List<InjuryRisk> buildInjuryRisksFromInputs({
  required List<Map<String, dynamic>> players,
  required List<Map<String, dynamic>> injuriesResponse,
  required List<Map<String, dynamic>> suspensionsResponse,
}) {
  final injuriesMap = <int, List<DateTime>>{};
  final suspensionsMap = <int, List<DateTime>>{};

  for (final injury in injuriesResponse) {
    final playerId = injury['player_id'] as int;
    if (injury['expected_return_date'] != null) {
      injuriesMap.putIfAbsent(playerId, () => []);
      injuriesMap[playerId]!.add(
        DateTime.parse(injury['expected_return_date'] as String),
      );
    }
  }

  for (final suspension in suspensionsResponse) {
    final playerId = suspension['player_id'] as int;
    if (suspension['expected_return_date'] != null) {
      suspensionsMap.putIfAbsent(playerId, () => []);
      suspensionsMap[playerId]!.add(
        DateTime.parse(suspension['expected_return_date'] as String),
      );
    }
  }

  return players
      .map((player) {
        final playerId = player['id'] as int;
        final playerName = player['name'] as String? ?? 'Unknown';
        final injuries = injuriesMap[playerId]?.length ?? 0;
        final suspensions = suspensionsMap[playerId]?.length ?? 0;
        final totalIssues = injuries + suspensions;

        final riskScore = (totalIssues * 20).clamp(0, 100);
        final riskLevel = riskScore > 60
            ? 'high'
            : riskScore > 30
            ? 'medium'
            : 'low';

        DateTime? expectedReturnDate;
        if (injuriesMap[playerId] != null &&
            injuriesMap[playerId]!.isNotEmpty) {
          expectedReturnDate = injuriesMap[playerId]!.reduce(
            (a, b) => a.isAfter(b) ? a : b,
          );
        }
        if (suspensionsMap[playerId] != null &&
            suspensionsMap[playerId]!.isNotEmpty) {
          final suspensionReturn = suspensionsMap[playerId]!.reduce(
            (a, b) => a.isAfter(b) ? a : b,
          );
          if (expectedReturnDate == null ||
              suspensionReturn.isAfter(expectedReturnDate)) {
            expectedReturnDate = suspensionReturn;
          }
        }

        return InjuryRisk(
          playerId: playerId,
          playerName: playerName,
          currentInjuries: injuries,
          currentSuspensions: suspensions,
          riskScore: riskScore,
          riskLevel: riskLevel,
          expectedReturnDate: expectedReturnDate,
        );
      })
      .where((risk) => risk.riskScore > 0)
      .toList();
}

List<FormTrend> buildFormTrendsFromRows(
  List<Map<String, dynamic>> rows,
  int windowSize,
) {
  final Map<int, List<int>> groupedByGameweek = {};
  for (final row in rows) {
    final gameweek = row['gameweek'] as int;
    final points = row['points'] as int;
    groupedByGameweek.putIfAbsent(gameweek, () => []);
    groupedByGameweek[gameweek]!.add(points);
  }

  final trends = groupedByGameweek.entries.map((entry) {
    final gameweek = entry.key;
    final points = entry.value;
    final average = points.isEmpty
        ? 0
        : points.reduce((a, b) => a + b) / points.length;

    return FormTrend(
      gameweek: gameweek,
      points: points.reduce((a, b) => a + b),
      windowAverage: average.toDouble(),
      trend: 'stable',
    );
  }).toList();

  for (int i = 0; i < trends.length - 1; i++) {
    final current = trends[i].windowAverage;
    final previous = trends[i + 1].windowAverage;
    final diff = current - previous;

    trends[i] = trends[i].copyWith(
      trend: diff > 5
          ? 'up'
          : diff < -5
          ? 'down'
          : 'stable',
    );
  }

  return trends.reversed.take(windowSize).toList();
}

double _estimatedPrice(String position) {
  switch (position.toLowerCase()) {
    case 'goalkeeper':
      return 5.0;
    case 'defender':
      return 5.5;
    case 'midfielder':
      return 6.5;
    case 'forward':
      return 7.5;
    default:
      return 6.0;
  }
}

class TeamAnalyticsService {
  final SupabaseClient _supabase;

  TeamAnalyticsService(this._supabase);

  Future<TeamAnalytics> analyzeTeam({
    required String teamId,
    required String teamName,
    required List<dynamic> players,
    int recentGamesWindow = 5,
  }) async {
    try {
      // Fetch form trends from gameweek points
      final formTrends = await _fetchFormTrends(teamId, recentGamesWindow);

      // Fetch injury risks
      final injuryRisks = await _fetchInjuryRisks(players);

      // Fetch transfer recommendations
      final transferRecommendations = await _fetchTransferRecommendations(
        players,
      );

      // Calculate team form score (0-100)
      final teamFormScore = calculateTeamFormScoreFromInputs(
        formTrends,
        injuryRisks,
      );

      // Count high-priority transfers
      final highPriorityTransfers = transferRecommendations
          .where((t) => t.priority >= 4)
          .length;

      return TeamAnalytics(
        teamId: teamId,
        teamName: teamName,
        formTrends: formTrends,
        injuryRisks: injuryRisks,
        transferRecommendations: transferRecommendations,
        teamFormScore: teamFormScore,
        highPriorityTransfers: highPriorityTransfers,
      );
    } catch (e) {
      debugPrint('Error analyzing team: $e');
      throw Exception('Failed to analyze team: $e');
    }
  }

  Future<List<FormTrend>> _fetchFormTrends(
    String teamId,
    int windowSize,
  ) async {
    try {
      // Fetch recent gameweek points grouped by gameweek
      final response = await _supabase
          .from('fd_player_gameweek_points')
          .select('gameweek, points')
          .or(
            'player_id.in.(SELECT id FROM public.fd_players WHERE team_id=$teamId)',
          )
          .order('gameweek', ascending: false)
          .limit(windowSize * 15);

      // Group by gameweek and calculate average
      final Map<int, List<int>> groupedByGameweek = {};
      for (final row in response as List) {
        final gameweek = row['gameweek'] as int;
        final points = row['points'] as int;

        groupedByGameweek.putIfAbsent(gameweek, () => []);
        groupedByGameweek[gameweek]!.add(points);
      }

      // Convert to FormTrend list with trend calculation
      final trends = groupedByGameweek.entries.map((e) {
        final gameweek = e.key;
        final points = e.value;
        final average = points.isEmpty
            ? 0
            : points.reduce((a, b) => a + b) / points.length;

        return FormTrend(
          gameweek: gameweek,
          points: points.reduce((a, b) => a + b),
          windowAverage: average.toDouble(),
          trend: 'stable',
        );
      }).toList();

      // Calculate trends (up, down, stable)
      for (int i = 0; i < trends.length - 1; i++) {
        final current = trends[i].windowAverage;
        final previous = trends[i + 1].windowAverage;
        final diff = current - previous;

        trends[i] = trends[i].copyWith(
          trend: diff > 5
              ? 'up'
              : diff < -5
              ? 'down'
              : 'stable',
        );
      }

      return trends.reversed.toList();
    } catch (e) {
      debugPrint('Error fetching form trends: $e');
      return [];
    }
  }

  Future<List<InjuryRisk>> _fetchInjuryRisks(List<dynamic> players) async {
    try {
      final playerIds = players
          .map((p) => (p as Map).tryGet('id'))
          .whereType<int>()
          .toList();

      if (playerIds.isEmpty) {
        return [];
      }

      // Fetch injuries
      final injuriesResponse = await _supabase
          .from('fd_player_injuries')
          .select('player_id, expected_return_date')
          .inFilter('player_id', playerIds);

      // Fetch suspensions
      final suspensionsResponse = await _supabase
          .from('fd_player_suspensions')
          .select('player_id, expected_return_date')
          .inFilter('player_id', playerIds);

      final injuriesMap = <int, List<DateTime>>{};
      final suspensionsMap = <int, List<DateTime>>{};

      for (final injury in injuriesResponse as List) {
        final playerId = injury['player_id'] as int;
        if (injury['expected_return_date'] != null) {
          injuriesMap.putIfAbsent(playerId, () => []);
          injuriesMap[playerId]!.add(
            DateTime.parse(injury['expected_return_date'] as String),
          );
        }
      }

      for (final suspension in suspensionsResponse as List) {
        final playerId = suspension['player_id'] as int;
        if (suspension['expected_return_date'] != null) {
          suspensionsMap.putIfAbsent(playerId, () => []);
          suspensionsMap[playerId]!.add(
            DateTime.parse(suspension['expected_return_date'] as String),
          );
        }
      }

      final risks = players
          .map((p) {
            final player = p as Map;
            final playerId = player['id'] as int;
            final playerName = player['name'] as String? ?? 'Unknown';
            final injuries = injuriesMap[playerId]?.length ?? 0;
            final suspensions = suspensionsMap[playerId]?.length ?? 0;
            final totalIssues = injuries + suspensions;

            final riskScore = (totalIssues * 20).clamp(0, 100);
            final riskLevel = riskScore > 60
                ? 'high'
                : riskScore > 30
                ? 'medium'
                : 'low';

            DateTime? expectedReturnDate;
            if (injuriesMap[playerId] != null &&
                injuriesMap[playerId]!.isNotEmpty) {
              expectedReturnDate = injuriesMap[playerId]!.reduce(
                (a, b) => a.isAfter(b) ? a : b,
              );
            }
            if (suspensionsMap[playerId] != null &&
                suspensionsMap[playerId]!.isNotEmpty) {
              final suspensionReturn = suspensionsMap[playerId]!.reduce(
                (a, b) => a.isAfter(b) ? a : b,
              );
              if (expectedReturnDate == null ||
                  suspensionReturn.isAfter(expectedReturnDate)) {
                expectedReturnDate = suspensionReturn;
              }
            }

            return InjuryRisk(
              playerId: playerId,
              playerName: playerName,
              currentInjuries: injuries,
              currentSuspensions: suspensions,
              riskScore: riskScore,
              riskLevel: riskLevel,
              expectedReturnDate: expectedReturnDate,
            );
          })
          .where((r) => r.riskScore > 0)
          .toList();

      return risks;
    } catch (e) {
      debugPrint('Error fetching injury risks: $e');
      return [];
    }
  }

  Future<List<TransferRecommendation>> _fetchTransferRecommendations(
    List<dynamic> players,
  ) async {
    try {
      final playerIds = players
          .map((p) => (p as Map).tryGet('id'))
          .whereType<int>()
          .toList();

      if (playerIds.isEmpty) {
        return [];
      }

      // Fetch recent stats for each player
      final statsResponse = await _supabase
          .from('fd_player_match_stats')
          .select('player_id, expected_goals, expected_assists')
          .inFilter('player_id', playerIds)
          .order('updated_at', ascending: false)
          .limit(playerIds.length * 5);

      // Fetch recent gameweek points
      final pointsResponse = await _supabase
          .from('fd_player_gameweek_points')
          .select('player_id, points')
          .inFilter('player_id', playerIds)
          .order('updated_at', ascending: false)
          .limit(playerIds.length * 5);

      final statsMap = <int, List<Map>>{};
      final pointsMap = <int, List<int>>{};

      for (final stat in statsResponse as List) {
        final playerId = stat['player_id'] as int;
        statsMap.putIfAbsent(playerId, () => []);
        statsMap[playerId]!.add(stat as Map);
      }

      for (final point in pointsResponse as List) {
        final playerId = point['player_id'] as int;
        pointsMap.putIfAbsent(playerId, () => []);
        pointsMap[playerId]!.add(point['points'] as int);
      }

      final recommendations = players
          .map((p) {
            final player = p as Map;
            final playerId = player['id'] as int;
            final playerName = player['name'] as String? ?? 'Unknown';
            final position = player['position'] as String? ?? 'Unknown';

            final playerStats = statsMap[playerId] ?? [];
            final playerPoints = pointsMap[playerId] ?? [];

            final avgXg = playerStats.isEmpty
                ? 0.0
                : playerStats
                          .map((s) => (s['expected_goals'] as num?) ?? 0)
                          .reduce((a, b) => a + b) /
                      playerStats.length;

            final avgXa = playerStats.isEmpty
                ? 0.0
                : playerStats
                          .map((s) => (s['expected_assists'] as num?) ?? 0)
                          .reduce((a, b) => a + b) /
                      playerStats.length;

            final recentAvg = playerPoints.isEmpty
                ? 0
                : playerPoints.reduce((a, b) => a + b) ~/ playerPoints.length;

            final estimatedBasePrice = _estimatedPrice(position);
            final performanceMultiplier = (recentAvg / 10.0).clamp(0.5, 2.0);
            final estimatedPrice = estimatedBasePrice * performanceMultiplier;
            final estimatedValue =
                (recentAvg.toDouble() * 1.5 + avgXg * 3 + avgXa * 3);

            final action = estimatedValue > estimatedPrice
                ? 'buy'
                : estimatedValue < (estimatedPrice * 0.7)
                ? 'sell'
                : 'hold';

            final priority = (estimatedValue / (estimatedPrice + 0.001))
                .clamp(1, 5)
                .toInt();

            return TransferRecommendation(
              playerId: playerId,
              playerName: playerName,
              position: position,
              estimatedValue: estimatedValue,
              estimatedPrice: estimatedPrice,
              recentPointsAverage: recentAvg,
              expectedGoals: avgXg,
              expectedAssists: avgXa,
              action: action,
              priority: priority,
            );
          })
          .where((r) => r.action != 'hold')
          .toList();

      recommendations.sort((a, b) => b.priority.compareTo(a.priority));
      return recommendations;
    } catch (e) {
      debugPrint('Error fetching transfer recommendations: $e');
      return [];
    }
  }
}

extension on Map {
  T? tryGet<T>(String key) {
    try {
      return this[key] as T?;
    } catch (e) {
      return null;
    }
  }
}

extension on FormTrend {
  FormTrend copyWith({
    int? gameweek,
    int? points,
    double? windowAverage,
    String? trend,
  }) {
    return FormTrend(
      gameweek: gameweek ?? this.gameweek,
      points: points ?? this.points,
      windowAverage: windowAverage ?? this.windowAverage,
      trend: trend ?? this.trend,
    );
  }
}
