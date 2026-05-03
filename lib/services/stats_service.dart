import '../constants/api_endpoints.dart';
import 'api_service.dart';

class StatsService {
  final ApiService _apiService;

  StatsService([ApiService? apiService]) : _apiService = apiService ?? ApiService();

  /// Fetch overall league statistics from backend.
  Future<Map<String, dynamic>> getOverallStats() async {
    final res = await _apiService.get(ApiEndpoints.overallStats);
    if (res['data'] is Map<String, dynamic>) {
      return res['data'] as Map<String, dynamic>;
    }
    return <String, dynamic>{};
  }

  /// Fetch per-gameweek statistics from backend.
  Future<Map<String, dynamic>> getGameweekStats() async {
    final res = await _apiService.get(ApiEndpoints.gameweekStats);
    if (res['data'] is Map<String, dynamic>) {
      return res['data'] as Map<String, dynamic>;
    }
    return <String, dynamic>{};
  }
}
