import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/match.dart';
import '../config/app_config.dart';

class MatchService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Match>> getLiveMatches() async {
    try {
      return await _fetchMatches(statusFilter: MatchStatus.live);
    } catch (e) {
      throw Exception('Failed to fetch live matches: $e');
    }
  }

  Future<List<Match>> getUpcomingMatches() async {
    try {
      return await _fetchMatches(statusFilter: MatchStatus.scheduled);
    } catch (e) {
      throw Exception('Failed to fetch upcoming matches: $e');
    }
  }

  Future<List<Match>> getCompletedMatches() async {
    try {
      return await _fetchMatches(statusFilter: MatchStatus.completed);
    } catch (e) {
      throw Exception('Failed to fetch completed matches: $e');
    }
  }

  Future<Match> getMatchById(String id) async {
    try {
      final matches = await _fetchMatches(matchExternalId: id);
      if (matches.isEmpty) {
        throw Exception('Match not found');
      }
      return matches.first;
    } catch (e) {
      throw Exception('Failed to fetch match: $e');
    }
  }

  Future<List<Match>> getMatchesByGameweek(int gameweek) async {
    try {
      return await _fetchMatches(gameweek: gameweek);
    } catch (e) {
      throw Exception('Failed to fetch matches by gameweek: $e');
    }
  }

  Future<List<Match>> getPremierLeagueMatchesByMatchday(
    int matchday, {
    String? apiToken,
    int competitionId = 2021,
  }) async {
    try {
      return await _fetchMatches(
        gameweek: matchday,
        competitionExternalId: competitionId.toString(),
      );
    } catch (e) {
      throw Exception(
        'Failed to fetch competition $competitionId matchday $matchday fixtures: $e',
      );
    }
  }

  Future<List<Match>> _fetchMatches({
    int? gameweek,
    String? matchExternalId,
    MatchStatus? statusFilter,
    String? competitionExternalId,
  }) async {
    var query = _client
        .from('fd_fixtures')
        .select(
          'id, external_id, competition_id, season, gameweek, utc_kickoff, status, home_team_id, away_team_id, home_score, away_score, venue',
        );

    if (gameweek != null) {
      query = query.eq('gameweek', gameweek);
    }
    if (matchExternalId != null) {
      query = query.eq('external_id', matchExternalId);
    }

    final competitionRow = await _client
        .from('fd_competitions')
        .select('id')
        .eq('provider', 'football-data')
        .eq('external_id', competitionExternalId ?? '2021')
        .maybeSingle();

    if (competitionRow != null) {
      query = query.eq('competition_id', competitionRow['id']);
    }

    query = query.inFilter('season', AppConfig.currentFootballSeasonAliases);

    final rows = await query
        .eq('provider', 'football-data')
        .order('utc_kickoff');
    if ((rows as List).isEmpty) return const <Match>[];

    final teamRows = await _client
        .from('fd_teams')
        .select('id, external_id, name')
        .eq('provider', 'football-data');
    final teamsById = <String, Map<String, dynamic>>{};
    for (final row in teamRows as List<dynamic>) {
      final data = row as Map<String, dynamic>;
      teamsById[data['id'].toString()] = data;
    }

    return (rows as List<dynamic>)
        .map((row) {
          final data = row as Map<String, dynamic>;
          final homeTeam = teamsById[data['home_team_id'].toString()];
          final awayTeam = teamsById[data['away_team_id'].toString()];
          final status = _mapFootballDataStatus(
            (data['status'] as String? ?? 'SCHEDULED').toUpperCase(),
          );
          if (statusFilter != null && status != statusFilter) {
            return null;
          }

          return Match(
            id: data['external_id'].toString(),
            homeTeamId:
                homeTeam?['external_id']?.toString() ??
                data['home_team_id'].toString(),
            homeTeamName: homeTeam?['name'] as String? ?? 'Home Team',
            awayTeamId:
                awayTeam?['external_id']?.toString() ??
                data['away_team_id'].toString(),
            awayTeamName: awayTeam?['name'] as String? ?? 'Away Team',
            homeScore: data['home_score'] as int?,
            awayScore: data['away_score'] as int?,
            status: status,
            kickoffTime:
                DateTime.tryParse(data['utc_kickoff'] as String? ?? '') ??
                DateTime.now(),
            gameweek: data['gameweek'] as int? ?? 0,
            venue: data['venue'] as String?,
          );
        })
        .whereType<Match>()
        .toList();
  }

  MatchStatus _mapFootballDataStatus(String status) {
    switch (status) {
      case 'IN_PLAY':
      case 'PAUSED':
      case 'LIVE':
        return MatchStatus.live;
      case 'FINISHED':
        return MatchStatus.completed;
      case 'POSTPONED':
      case 'SUSPENDED':
      case 'CANCELLED':
        return MatchStatus.postponed;
      default:
        return MatchStatus.scheduled;
    }
  }
}
