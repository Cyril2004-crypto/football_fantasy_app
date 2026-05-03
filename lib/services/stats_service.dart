import '../constants/api_endpoints.dart';
import 'api_service.dart';

class StatsService {
  final ApiService _apiService;

  StatsService([ApiService? apiService]) : _apiService = apiService ?? ApiService();

  /// Fetch overall league statistics from backend.
  Future<Map<String, dynamic>> getOverallStats() async {
    return _apiService.get(ApiEndpoints.overallStats);
  }

  /// Fetch per-gameweek statistics from backend.
  Future<Map<String, dynamic>> getGameweekStats() async {
    return _apiService.get(ApiEndpoints.gameweekStats);
  }
}
