import 'package:flutter/material.dart';
import '../models/team_analytics.dart';
import '../services/team_analytics_service.dart';

class TeamAnalyticsProvider with ChangeNotifier {
  final TeamAnalyticsService _service;

  TeamAnalytics? _analytics;
  bool _isLoading = false;
  String? _error;

  TeamAnalyticsProvider(this._service);

  TeamAnalytics? get analytics => _analytics;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> analyzeTeam({
    required String teamId,
    required String teamName,
    required List<dynamic> players,
    int recentGamesWindow = 5,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _analytics = await _service.analyzeTeam(
        teamId: teamId,
        teamName: teamName,
        players: players,
        recentGamesWindow: recentGamesWindow,
      );
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error analyzing team: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh({
    required String teamId,
    required String teamName,
    required List<dynamic> players,
  }) async {
    await analyzeTeam(
      teamId: teamId,
      teamName: teamName,
      players: players,
    );
  }
}
