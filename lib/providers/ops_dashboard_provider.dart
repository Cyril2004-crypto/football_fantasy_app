import 'package:flutter/material.dart';
import '../models/ops_dashboard.dart';
import '../services/ops_dashboard_service.dart';

class OpsDashboardProvider with ChangeNotifier {
  final OpsDashboardService _service;

  OpsDashboardStatus? _status;
  bool _isLoading = false;
  String? _error;

  OpsDashboardProvider(this._service);

  OpsDashboardStatus? get status => _status;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadDashboard() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _status = await _service.fetchDashboardStatus();
      _error = null;
    } catch (e) {
      _error = e.toString();
      print('Error loading dashboard: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshDashboard() async {
    await loadDashboard();
  }
}
