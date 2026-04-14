import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../models/team.dart';
import '../models/player.dart';
import '../services/points_calculator_service.dart';
import '../services/league_sync_service.dart';
import '../services/player_service.dart';
import '../services/team_service.dart';
import '../utilities/mock_data.dart';

class TeamProvider with ChangeNotifier {
  final TeamService _teamService;
  final PointsCalculatorService _pointsCalculatorService =
      PointsCalculatorService();
  final LeagueSyncService _leagueSyncService = LeagueSyncService();
  final PlayerService _playerService = PlayerService();
  
  Team? _team;
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<firebase_auth.User?>? _authSubscription;

  static const String _guestUid = 'guest';
  static const String _lastUidPrefsKey = 'team_cache_last_uid';

  TeamProvider(this._teamService) {
    _authSubscription = firebase_auth.FirebaseAuth.instance
        .authStateChanges()
        .listen((user) async {
      if (user == null) {
        return;
      }

      await _migrateGuestCacheToUser(user.uid);
      if (!_isLoading) {
        await loadMyTeam();
      }
    });
  }

  Team? get team => _team;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasTeam => _team != null && _team!.players.isNotEmpty;
  List<Player> get players => _team?.players ?? [];

  Future<void> loadMyTeam() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final remoteTeam = await _teamService.getMyTeam();
      final cachedTeam = await _loadTeamFromCache();

      if (remoteTeam == null) {
        _team = cachedTeam;
      } else if (remoteTeam.players.isEmpty && cachedTeam != null && cachedTeam.players.isNotEmpty) {
        // Keep richer cached squad when backend payload omits players.
        _team = cachedTeam.copyWith(
          id: remoteTeam.id,
          name: remoteTeam.name,
          userId: remoteTeam.userId,
          remainingBudget: remoteTeam.remainingBudget,
          totalPoints: remoteTeam.totalPoints,
          gameweekPoints: remoteTeam.gameweekPoints,
          createdAt: remoteTeam.createdAt,
          updatedAt: remoteTeam.updatedAt,
        );
      } else {
        _team = remoteTeam;
      }

      if (_team != null) {
        _team = await _refreshTeamWithLatestPlayerPoints(_team!);
        await _saveTeamToCache(_team!);
        await _leagueSyncService.syncTeam(_team!);
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

  Future<void> createTeam(
    String teamName,
    List<String> playerIds, {
    List<Player>? selectedPlayers,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      _team = await _teamService.createTeam(teamName, playerIds);
      if ((_team?.players.isEmpty ?? true) && selectedPlayers != null && selectedPlayers.isNotEmpty) {
        final totalPrice = selectedPlayers.fold<double>(0.0, (sum, p) => sum + p.price);
        _team = _team!.copyWith(
          players: selectedPlayers,
          remainingBudget: AppConfig.teamBudget - totalPrice,
          totalPoints: _pointsCalculatorService.calculateStoredTeamTotalPoints(selectedPlayers),
          gameweekPoints: _pointsCalculatorService.calculateStoredTeamGameweekPoints(selectedPlayers),
          updatedAt: DateTime.now(),
        );
      }
      await _saveTeamToCache(_team!);
      await _leagueSyncService.syncTeam(_team!);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      try {
        final effectivePlayers = (selectedPlayers != null && selectedPlayers.isNotEmpty)
            ? selectedPlayers
            : MockData.getMockPlayers()
            .where((p) => playerIds.contains(p.id))
            .toList();

        final totalPrice = effectivePlayers.fold<double>(
          0.0,
          (sum, p) => sum + p.price,
        );

        _team = Team(
          id: const Uuid().v4(),
          userId: firebase_auth.FirebaseAuth.instance.currentUser?.uid ?? _guestUid,
          name: teamName,
            players: effectivePlayers,
          remainingBudget: AppConfig.teamBudget - totalPrice,
          totalPoints: _pointsCalculatorService
              .calculateStoredTeamTotalPoints(effectivePlayers),
          gameweekPoints: _pointsCalculatorService
              .calculateStoredTeamGameweekPoints(effectivePlayers),
          createdAt: DateTime.now(),
        );

        await _saveTeamToCache(_team!);
        await _leagueSyncService.syncTeam(_team!);
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

  Future<void> updateTeam(
    List<String> playerIds, {
    List<Player>? selectedPlayers,
  }) async {
    try {
      if (_team == null) return;
      
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      _team = await _teamService.updateTeam(_team!.id, playerIds);
      if ((_team?.players.isEmpty ?? true) && selectedPlayers != null && selectedPlayers.isNotEmpty) {
        final totalPrice = selectedPlayers.fold<double>(0.0, (sum, p) => sum + p.price);
        _team = _team!.copyWith(
          players: selectedPlayers,
          remainingBudget: AppConfig.teamBudget - totalPrice,
          totalPoints: _pointsCalculatorService.calculateStoredTeamTotalPoints(selectedPlayers),
          gameweekPoints: _pointsCalculatorService.calculateStoredTeamGameweekPoints(selectedPlayers),
          updatedAt: DateTime.now(),
        );
      }
      await _saveTeamToCache(_team!);
      await _leagueSyncService.syncTeam(_team!);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      try {
        if (_team == null) {
          throw Exception('Team not found');
        }

        final effectivePlayers = (selectedPlayers != null && selectedPlayers.isNotEmpty)
            ? selectedPlayers
            : MockData.getMockPlayers()
            .where((p) => playerIds.contains(p.id))
            .toList();

        final totalPrice = effectivePlayers.fold<double>(
          0.0,
          (sum, p) => sum + p.price,
        );

        _team = _team!.copyWith(
          players: effectivePlayers,
          remainingBudget: AppConfig.teamBudget - totalPrice,
          totalPoints: _pointsCalculatorService
              .calculateStoredTeamTotalPoints(effectivePlayers),
          gameweekPoints: _pointsCalculatorService
              .calculateStoredTeamGameweekPoints(effectivePlayers),
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
    final uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid ?? _guestUid;
    return _cacheKeyForUid(uid);
  }

  String _cacheKeyForUid(String uid) {
    return 'team_cache_$uid';
  }

  Future<void> _saveTeamToCache(Team team) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid ?? team.userId;
    final effectiveUid = uid.isEmpty ? _guestUid : uid;

    final normalizedTeam = team.copyWith(userId: effectiveUid);
    await prefs.setString(_cacheKeyForUid(effectiveUid), jsonEncode(normalizedTeam.toJson()));
    await prefs.setString(_lastUidPrefsKey, effectiveUid);

    if (effectiveUid != _guestUid) {
      await prefs.remove(_cacheKeyForUid(_guestUid));
    }
  }

  Future<Team?> _loadTeamFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final currentUid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    final candidateUids = <String>[
      if (currentUid != null && currentUid.isNotEmpty) currentUid,
      if (prefs.getString(_lastUidPrefsKey)?.isNotEmpty ?? false)
        prefs.getString(_lastUidPrefsKey)!,
      _guestUid,
    ];

    for (final uid in candidateUids.toSet()) {
      final raw = prefs.getString(_cacheKeyForUid(uid));
      if (raw == null || raw.isEmpty) {
        continue;
      }

      final json = jsonDecode(raw) as Map<String, dynamic>;
      final team = Team.fromJson(json);
      if (currentUid != null && currentUid.isNotEmpty && team.userId != currentUid) {
        return team.copyWith(userId: currentUid);
      }
      return team;
    }

    return null;
  }

  Future<void> _clearTeamFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey());
  }

  Future<void> _migrateGuestCacheToUser(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final guestKey = _cacheKeyForUid(_guestUid);
    final userKey = _cacheKeyForUid(uid);
    final existingUserRaw = prefs.getString(userKey);
    if (existingUserRaw != null && existingUserRaw.isNotEmpty) {
      await prefs.setString(_lastUidPrefsKey, uid);
      return;
    }

    final guestRaw = prefs.getString(guestKey);
    if (guestRaw == null || guestRaw.isEmpty) {
      await prefs.setString(_lastUidPrefsKey, uid);
      return;
    }

    final json = jsonDecode(guestRaw) as Map<String, dynamic>;
    final migrated = Team.fromJson(json).copyWith(userId: uid);
    await prefs.setString(userKey, jsonEncode(migrated.toJson()));
    await prefs.setString(_lastUidPrefsKey, uid);
    await prefs.remove(guestKey);
  }

  Future<Team> _refreshTeamWithLatestPlayerPoints(Team team) async {
    if (team.players.isEmpty) {
      return team;
    }

    try {
      final freshPlayers = await _playerService.getPlayersByIds(
        team.players.map((player) => player.id).toList(),
      );

      if (freshPlayers.isEmpty) {
        return team;
      }

      final freshById = <String, Player>{
        for (final player in freshPlayers) player.id: player,
      };

      final mergedPlayers = team.players
          .map((player) => freshById[player.id] ?? player)
          .toList();

      return team.copyWith(
        players: mergedPlayers,
        totalPoints:
            _pointsCalculatorService.calculateStoredTeamTotalPoints(mergedPlayers),
        gameweekPoints: _pointsCalculatorService
            .calculateStoredTeamGameweekPoints(mergedPlayers),
        updatedAt: DateTime.now(),
      );
    } catch (_) {
      return team;
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
