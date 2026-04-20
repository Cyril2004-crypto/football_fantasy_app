import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/sportmonks_service.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  final SportmonksService _sportmonksService = SportmonksService(
    ApiService(AuthService()),
  );

  late Future<List<_NewsItem>> _future;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _future = _loadNews();
  }

  Future<List<_NewsItem>> _loadNews() async {
    try {
      final fixtureIds = await _resolveFixtureIdsForNews(limit: 6);
      if (fixtureIds.isEmpty) {
        _statusMessage =
            'No live or recent fixtures available for news right now';
        return const <_NewsItem>[];
      }

      final items = <_NewsItem>[];
      for (final fixtureId in fixtureIds) {
        try {
          final response = await _sportmonksService.getFixtureNews(fixtureId);
          var parsed = _extractNewsItems(response);

          if (parsed.isEmpty) {
            final centre = await _sportmonksService.getFixtureMatchCentre(
              fixtureId,
            );
            parsed = _extractEventNewsItems(centre);
          }

          items.addAll(parsed);
        } catch (_) {
          // Skip one fixture and continue loading others.
        }
      }

      if (items.isEmpty) {
        _statusMessage =
            'No Sportmonks news returned yet for recent fixtures';
        return const <_NewsItem>[];
      }

      _statusMessage = null;
      return items;
    } catch (e) {
      _statusMessage =
          'News needs a SPORTMONKS_API_TOKEN in dart_defines.local.json';
      return const <_NewsItem>[];
    }
  }

  Future<List<int>> _resolveFixtureIdsForNews({int limit = 6}) async {
    final ids = <int>[];
    final seen = <int>{};

    final liveResponse = await _sportmonksService.getInplayLivescores();
    final liveRows = liveResponse['data'] is List
        ? liveResponse['data'] as List<dynamic>
        : const <dynamic>[];

    for (final row in liveRows) {
      if (row is! Map<String, dynamic>) {
        continue;
      }
      final id = _readInt(row, const ['id']);
      if (id == null || seen.contains(id)) {
        continue;
      }
      seen.add(id);
      ids.add(id);
      if (ids.length >= limit) {
        return ids;
      }
    }

    // Fallback: pull recent fixtures (today, yesterday, and 2 days ago).
    final now = DateTime.now().toUtc();
    for (var offset = 0; offset <= 2; offset++) {
      final d = now.subtract(Duration(days: offset));
      final date = _formatDate(d);
      final dateResponse = await _sportmonksService.getFixturesByDate(date);
      final rows = dateResponse['data'] is List
          ? dateResponse['data'] as List<dynamic>
          : const <dynamic>[];

      for (final row in rows) {
        if (row is! Map<String, dynamic>) {
          continue;
        }
        final id = _readInt(row, const ['id']);
        if (id == null || seen.contains(id)) {
          continue;
        }
        seen.add(id);
        ids.add(id);
        if (ids.length >= limit) {
          return ids;
        }
      }
    }

    return ids;
  }

  String _formatDate(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  List<_NewsItem> _extractNewsItems(Map<String, dynamic> response) {
    final data = response['data'] is Map<String, dynamic>
        ? response['data'] as Map<String, dynamic>
        : const <String, dynamic>{};

    final homeName = _teamNameFromIndex(data, 0);
    final awayName = _teamNameFromIndex(data, 1);
    final fixtureTitle = '$homeName vs $awayName';

    final items = <_NewsItem>[];

    final prematchNews = data['prematchNews'] is List
        ? data['prematchNews'] as List<dynamic>
        : const <dynamic>[];
    final postmatchNews = data['postmatchNews'] is List
        ? data['postmatchNews'] as List<dynamic>
        : const <dynamic>[];

    for (final block in [...prematchNews, ...postmatchNews]) {
      final blockMap = block is Map<String, dynamic>
          ? block
          : const <String, dynamic>{};
      final lines = blockMap['lines'] is List
          ? blockMap['lines'] as List<dynamic>
          : const <dynamic>[];

      for (final line in lines) {
        if (line is! Map<String, dynamic>) {
          continue;
        }

        final title =
            _readString(line, const ['headline', 'title']) ??
            _readString(blockMap, const ['headline', 'title']) ??
            'Match Update';
        final content =
            _readString(line, const [
              'content',
              'summary',
              'description',
              'text',
            ]) ??
            'No details available.';

        items.add(
          _NewsItem(title: title, description: content, source: fixtureTitle),
        );
      }
    }

    if (items.isEmpty) {
      final events = data['events'] is List
          ? data['events'] as List<dynamic>
          : const <dynamic>[];

      for (final event in events) {
        if (event is! Map<String, dynamic>) {
          continue;
        }

        final minute = _readInt(event, const ['minute']);
        final playerName = _readString(event['player'], const ['name']);
        final eventType = (_readString(event['type'], const ['developer_name']) ??
                _readString(event['type'], const ['name']) ??
                'match event')
            .replaceAll('_', ' ')
            .trim();

        final title = minute == null
            ? eventType.toUpperCase()
          : '${eventType.toUpperCase()} - $minute\'';
        final description = playerName == null || playerName.isEmpty
            ? 'Event recorded for $fixtureTitle.'
            : '$playerName involved for $fixtureTitle.';

        items.add(
          _NewsItem(title: title, description: description, source: fixtureTitle),
        );
      }
    }

    return items;
  }

  List<_NewsItem> _extractEventNewsItems(Map<String, dynamic> response) {
    final data = response['data'] is Map<String, dynamic>
        ? response['data'] as Map<String, dynamic>
        : const <String, dynamic>{};

    final homeName = _teamNameFromIndex(data, 0);
    final awayName = _teamNameFromIndex(data, 1);
    final fixtureTitle = '$homeName vs $awayName';

    final events = data['events'] is List
        ? data['events'] as List<dynamic>
        : const <dynamic>[];
    final items = <_NewsItem>[];

    for (final event in events) {
      if (event is! Map<String, dynamic>) {
        continue;
      }

      final minute = _readInt(event, const ['minute']);
      final playerName = _readString(event['player'], const ['name']);
      final eventType = (_readString(event['type'], const ['developer_name']) ??
              _readString(event['type'], const ['name']) ??
              'match event')
          .replaceAll('_', ' ')
          .trim();

      final title = minute == null
          ? eventType.toUpperCase()
          : '${eventType.toUpperCase()} - $minute\'';
      final description = playerName == null || playerName.isEmpty
          ? 'Event recorded for $fixtureTitle.'
          : '$playerName involved for $fixtureTitle.';

      items.add(
        _NewsItem(title: title, description: description, source: fixtureTitle),
      );
    }

    return items;
  }

  String _teamNameFromIndex(Map<String, dynamic> fixture, int index) {
    final participants = fixture['participants'] is List
        ? fixture['participants'] as List<dynamic>
        : const <dynamic>[];

    if (participants.length <= index ||
        participants[index] is! Map<String, dynamic>) {
      return index == 0 ? 'Home Team' : 'Away Team';
    }

    return _readString(participants[index], const ['name']) ??
        (index == 0 ? 'Home Team' : 'Away Team');
  }

  int? _readInt(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }

  String? _readString(dynamic source, List<String> keys) {
    if (source is! Map<String, dynamic>) {
      return null;
    }

    for (final key in keys) {
      final value = source[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
      if (value != null) {
        final asString = value.toString().trim();
        if (asString.isNotEmpty) {
          return asString;
        }
      }
    }

    return null;
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _loadNews();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('News'),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _future = _loadNews();
              });
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<_NewsItem>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final items = snapshot.data ?? const <_NewsItem>[];
            if (items.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 44,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _statusMessage ?? 'No news available right now',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.description,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.source,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _NewsItem {
  final String title;
  final String description;
  final String source;

  const _NewsItem({
    required this.title,
    required this.description,
    required this.source,
  });
}
