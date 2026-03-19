import 'package:flutter/foundation.dart';
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
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      // Silently fail without showing error for loading
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
    }
  }

  Future<void> createTeam(String teamName, List<String> playerIds) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      _team = await _teamService.createTeam(teamName, playerIds);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      // Fallback: Create team locally when API is unavailable
      try {
        final mockPlayers = MockData.getMockPlayers();
        final selectedPlayers = mockPlayers
            .where((p) => playerIds.contains(p.id))
            .toList();

        final totalPrice = selectedPlayers.fold(0.0, (sum, p) => sum + p.price);
        final totalPoints =
            _pointsCalculatorService.calculateStoredTeamTotalPoints(selectedPlayers);
        final gameweekPoints = _pointsCalculatorService
            .calculateStoredTeamGameweekPoints(selectedPlayers);
        
        _team = Team(
          id: const Uuid().v4(),
          userId: 'local_user',
          name: teamName,
          players: selectedPlayers,
          remainingBudget: AppConfig.teamBudget - totalPrice,
          totalPoints: totalPoints,
          gameweekPoints: gameweekPoints,
          createdAt: DateTime.now(),
        );
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      } catch (fallbackError) {
        _isLoading = false;
        _errorMessage = fallbackError.toString();
        notifyListeners();
        rethrow;
      }
    }
  }

  Future<void> updateTeam(List<String> playerIds) async {
    try {
      if (_team == null) return;
      
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      _team = await _teamService.updateTeam(_team!.id, playerIds);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      // Fallback: Update team locally when API is unavailable
      try {
        if (_team == null) throw Exception('Team not found');
        
        final mockPlayers = MockData.getMockPlayers();
        final selectedPlayers = mockPlayers
            .where((p) => playerIds.contains(p.id))
            .toList();

        final totalPrice = selectedPlayers.fold(0.0, (sum, p) => sum + p.price);
        final totalPoints =
            _pointsCalculatorService.calculateStoredTeamTotalPoints(selectedPlayers);
        final gameweekPoints = _pointsCalculatorService
            .calculateStoredTeamGameweekPoints(selectedPlayers);
        
        _team = _team!.copyWith(
          players: selectedPlayers,
          remainingBudget: AppConfig.teamBudget - totalPrice,
          totalPoints: totalPoints,
          gameweekPoints: gameweekPoints,
          updatedAt: DateTime.now(),
        );
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      } catch (fallbackError) {
        _isLoading = false;
        _errorMessage = fallbackError.toString();
        notifyListeners();
        rethrow;
      }
    }
  }

  void clearTeam() {
    _team = null;
    notifyListeners();
  }
}
