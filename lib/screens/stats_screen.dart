import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../services/stats_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final StatsService _statsService = StatsService();
  bool _loading = true;
  Map<String, dynamic> _overall = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final overall = await _statsService.getOverallStats();
      if (mounted) {
        setState(() {
          _overall = overall;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _overall = {};
          _loading = false;
        });
      }
    }
  }

  List<Widget> _buildList(String title, List<dynamic>? items, String valueKey) {
    final list = items ?? [];
    if (list.isEmpty) {
      return [Text('No data available', style: TextStyle(color: AppColors.textSecondary))];
    }

    return list.map((it) {
      final name = it['name']?.toString() ?? 'Unknown';
      final team = it['team']?['name']?.toString() ?? it['club']?.toString() ?? '';
      final value = it[valueKey]?.toString() ?? '';
      return ListTile(
        title: Text(name),
        subtitle: team.isNotEmpty ? Text(team) : null,
        trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('League Stats'), backgroundColor: AppColors.primary),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Top Scorers', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ..._buildList('Top Scorers', _overall['top_scorers'] as List<dynamic>?, 'goals'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Top Assists', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ..._buildList('Top Assists', _overall['top_assists'] as List<dynamic>?, 'assists'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Clean Sheets', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ..._buildList('Clean Sheets', _overall['clean_sheets'] as List<dynamic>?, 'clean_sheets'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Discipline', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text('Most Yellow Cards', style: Theme.of(context).textTheme.labelLarge),
                          ..._buildList('Yellow', _overall['most_yellow_cards'] as List<dynamic>?, 'yellow'),
                          const SizedBox(height: 8),
                          Text('Most Red Cards', style: Theme.of(context).textTheme.labelLarge),
                          ..._buildList('Red', _overall['most_red_cards'] as List<dynamic>?, 'red'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
