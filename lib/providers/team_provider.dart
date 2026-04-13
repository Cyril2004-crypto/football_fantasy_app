import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../models/team.dart';
import '../models/player.dart';
import '../services/points_calculator_service.dart';
import '../services/team_service.dart';
import '../utilities/mock_data.dart';

class TeamProvider with ChangeNotifier {
  final TeamService _teamService;
  final PointsCalculatorService _pointsCalculatorService =
      PointsCalculatorService();
  
  Team? _team;
  bool _isLoading = false;
  String? _errorMessage;

  TeamProvider(this._teamService);

  Team? get team => _team;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasTeam => _team != null;
  List<Player> get players => _team?.players ?? [];

  Future<void> loadMyTeam() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      _team = await _teamService.getMyTeam();
      if (_team != null) {
        await _saveTeamToCache(_team!);
      } else {
        _team = await _loadTeamFromCache();
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _team = await _loadTeamFromCache();
      _isLoading = false;
      _errorMessage = _team == null ? e.toString() : null;
      notifyListeners();
    }
  }

  Future<void> createTeam(String teamName, List<String> playerIds) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      _team = await _teamService.createTeam(teamName, playerIds);
      await _saveTeamToCache(_team!);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      try {
        final selectedPlayers = MockData.getMockPlayers()
            .where((p) => playerIds.contains(p.id))
            .toList();

        final totalPrice = selectedPlayers.fold<double>(
          0.0,
          (sum, p) => sum + p.price,
        );

        _team = Team(
          id: const Uuid().v4(),
          userId: firebase_auth.FirebaseAuth.instance.currentUser?.uid ?? 'local_user',
          name: teamName,
          players: selectedPlayers,
          remainingBudget: AppConfig.teamBudget - totalPrice,
          totalPoints: _pointsCalculatorService
              .calculateStoredTeamTotalPoints(selectedPlayers),
          gameweekPoints: _pointsCalculatorService
              .calculateStoredTeamGameweekPoints(selectedPlayers),
          createdAt: DateTime.now(),
        );

        await _saveTeamToCache(_team!);
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
        return;
      } catch (_) {
        // Fall through to original error handling.
      }

      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateTeam(List<String> playerIds) async {
    try {
      if (_team == null) return;
      
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      _team = await _teamService.updateTeam(_team!.id, playerIds);
      await _saveTeamToCache(_team!);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      try {
        if (_team == null) {
          throw Exception('Team not found');
        }

        final selectedPlayers = MockData.getMockPlayers()
            .where((p) => playerIds.contains(p.id))
            .toList();

        final totalPrice = selectedPlayers.fold<double>(
          0.0,
          (sum, p) => sum + p.price,
        );

        _team = _team!.copyWith(
          players: selectedPlayers,
          remainingBudget: AppConfig.teamBudget - totalPrice,
          totalPoints: _pointsCalculatorService
              .calculateStoredTeamTotalPoints(selectedPlayers),
          gameweekPoints: _pointsCalculatorService
              .calculateStoredTeamGameweekPoints(selectedPlayers),
          updatedAt: DateTime.now(),
        );

        await _saveTeamToCache(_team!);
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
        return;
      } catch (_) {
        // Fall through to original error handling.
      }

      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  void clearTeam() {
    _team = null;
    _clearTeamFromCache();
    notifyListeners();
  }

  String _cacheKey() {
    final uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    return 'team_cache_$uid';
  }

  Future<void> _saveTeamToCache(Team team) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey(), jsonEncode(team.toJson()));
  }

  Future<Team?> _loadTeamFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey());
    if (raw == null || raw.isEmpty) return null;

    final json = jsonDecode(raw) as Map<String, dynamic>;
    return Team.fromJson(json);
  }

  Future<void> _clearTeamFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey());
  }
}
