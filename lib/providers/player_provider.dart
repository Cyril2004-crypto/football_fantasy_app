import 'package:flutter/foundation.dart';
import '../models/player.dart';
import '../services/player_service.dart';
import '../utilities/mock_data.dart';

class PlayerProvider with ChangeNotifier {
  final PlayerService _playerService;
  
  List<Player> _players = [];
  List<Player> _filteredPlayers = [];
  bool _isLoading = false;
  String? _errorMessage;
  PlayerPosition? _selectedPosition;
  String _searchQuery = '';

  PlayerProvider(this._playerService);

  List<Player> get players => _filteredPlayers.isEmpty && _searchQuery.isEmpty 
      ? _players 
      : _filteredPlayers;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  PlayerPosition? get selectedPosition => _selectedPosition;

  Future<void> loadAllPlayers() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      _players = await _playerService.getAllPlayers();
      _filteredPlayers = _players;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      // Use mock data as fallback when API is unavailable
      _players = MockData.getMockPlayers();
      _filteredPlayers = _players;
      _isLoading = false;
      _errorMessage = null; // Don't show error, just use mock data
      notifyListeners();
    }
  }

  Future<void> loadPlayersByPosition(PlayerPosition position) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      _selectedPosition = position;
      notifyListeners();

      _filteredPlayers = await _playerService.getPlayersByPosition(position);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      // Use mock data filtered by position as fallback
      final mockPlayers = MockData.getMockPlayers();
      _filteredPlayers = mockPlayers
          .where((p) => p.position == position)
          .toList();
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
    }
  }

  void filterPlayers(String query) {
    _searchQuery = query;
    if (query.isEmpty) {
      _filteredPlayers = _players;
    } else {
      _filteredPlayers = _players
          .where((player) =>
              player.name.toLowerCase().contains(query.toLowerCase()) ||
              player.clubName.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
    notifyListeners();
  }

  void clearFilter() {
    _selectedPosition = null;
    _searchQuery = '';
    _filteredPlayers = _players;
    notifyListeners();
  }

  Player? getPlayerById(String id) {
    try {
      return _players.firstWhere((player) => player.id == id);
    } catch (e) {
      return null;
    }
  }
}
