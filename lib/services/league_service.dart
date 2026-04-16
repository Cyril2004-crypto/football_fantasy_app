import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/league.dart';
import '../models/team.dart';
import 'auth_service.dart';

class LeagueService {
  final AuthService _authService;

  LeagueService(this._authService);

  Future<List<League>> getMyLeagues() async {
    final data = await _invoke('myLeagues', {});
    return _asLeagueList(data['data']);
  }

  Future<League> createLeague(
    String name,
    LeagueType type, {
    Team? team,
  }) async {
    final data = await _invoke('createLeague', {
      'name': name,
      'type': type == LeagueType.public ? 'public' : 'private',
      ..._teamPayload(team),
    });

    return League.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<void> joinLeague({
    String? leagueId,
    String? leagueCode,
    Team? team,
  }) async {
    final data = await _invoke('joinLeague', {
      'leagueId': leagueId,
      'leagueCode': leagueCode,
      ..._teamPayload(team),
    });

    if (data['data'] == null) {
      throw Exception('Failed to join league');
    }
  }

  Future<List<LeagueStanding>> getLeagueStandings(String leagueId) async {
    final data = await _invoke('standings', {'leagueId': leagueId});
    return _asStandingList(data['data']);
  }

  Future<League> getLeagueById(String id) async {
    final leagues = await getMyLeagues();
    return leagues.firstWhere((league) => league.id == id);
  }

  Future<List<League>> getPublicLeagues() async {
    final data = await _invoke('publicLeagues', {});
    return _asLeagueList(data['data']);
  }

  Future<Map<String, dynamic>> _invoke(
    String action,
    Map<String, dynamic> body,
  ) async {
    final endpoint = AppConfig.supabaseLeagueFunctionUrl;
    if (endpoint.isEmpty) {
      throw Exception('League backend is not configured');
    }

    final token = await _authService.getIdToken();
    final user = _authService.currentUser;

    const authRequiredActions = <String>{
      'syncTeam',
      'createLeague',
      'joinLeague',
      'myLeagues',
      'standings',
    };

    if (authRequiredActions.contains(action)) {
      if (user == null) {
        throw Exception('Please sign in to continue');
      }
      if (token == null || token.isEmpty) {
        throw Exception('Authentication token missing. Please sign in again.');
      }
    }

    final response = await http.post(
      Uri.parse(endpoint),
      headers: {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'action': action,
        'userId': user?.id,
        'userName': user?.displayName ?? user?.email,
        'email': user?.email,
        ...body,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('League request failed: ${response.body}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Map<String, dynamic> _teamPayload(Team? team) {
    if (team == null) return {};
    return {
      'teamName': team.name,
      'totalPoints': team.totalPoints,
      'gameweekPoints': team.gameweekPoints,
      'remainingBudget': team.remainingBudget,
    };
  }

  List<League> _asLeagueList(dynamic value) {
    if (value is! List) return [];
    return value
        .map((json) => League.fromJson(Map<String, dynamic>.from(json as Map)))
        .toList();
  }

  List<LeagueStanding> _asStandingList(dynamic value) {
    if (value is! List) return [];
    return value
        .map(
          (json) =>
              LeagueStanding.fromJson(Map<String, dynamic>.from(json as Map)),
        )
        .toList();
  }
}
