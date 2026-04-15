import 'package:equatable/equatable.dart';

class IngestionAlert extends Equatable {
  final int id;
  final String source;
  final String alertCode;
  final String severity;
  final String message;
  final Map<String, dynamic>? context;
  final DateTime firstSeenAt;
  final DateTime lastSeenAt;
  final int occurrenceCount;
  final bool isActive;
  final DateTime? resolvedAt;
  final DateTime? lastNotifiedAt;

  const IngestionAlert({
    required this.id,
    required this.source,
    required this.alertCode,
    required this.severity,
    required this.message,
    this.context,
    required this.firstSeenAt,
    required this.lastSeenAt,
    required this.occurrenceCount,
    required this.isActive,
    this.resolvedAt,
    this.lastNotifiedAt,
  });

  factory IngestionAlert.fromJson(Map<String, dynamic> json) {
    return IngestionAlert(
      id: json['id'] as int,
      source: json['source'] as String,
      alertCode: json['alert_code'] as String,
      severity: json['severity'] as String,
      message: json['message'] as String,
      context: json['context'] as Map<String, dynamic>?,
      firstSeenAt: DateTime.parse(json['first_seen_at'] as String),
      lastSeenAt: DateTime.parse(json['last_seen_at'] as String),
      occurrenceCount: json['occurrence_count'] as int,
      isActive: json['is_active'] as bool,
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'] as String)
          : null,
      lastNotifiedAt: json['last_notified_at'] != null
          ? DateTime.parse(json['last_notified_at'] as String)
          : null,
    );
  }

  @override
  List<Object?> get props => [
        id,
        source,
        alertCode,
        severity,
        message,
        context,
        firstSeenAt,
        lastSeenAt,
        occurrenceCount,
        isActive,
        resolvedAt,
        lastNotifiedAt,
      ];
}

class HealthSnapshot extends Equatable {
  final int id;
  final String source;
  final DateTime snapshotAt;
  final int teamsCount;
  final int fixturesCount;
  final int playersCount;
  final int gameweekPointsCount;
  final int fixtureEventsCount;
  final int teamFormCount;
  final int playerMatchStatsCount;
  final int playerInjuriesCount;
  final int playerSuspensionsCount;
  final int rowsWithXg;
  final int rowsWithXa;

  const HealthSnapshot({
    required this.id,
    required this.source,
    required this.snapshotAt,
    required this.teamsCount,
    required this.fixturesCount,
    required this.playersCount,
    required this.gameweekPointsCount,
    required this.fixtureEventsCount,
    required this.teamFormCount,
    required this.playerMatchStatsCount,
    required this.playerInjuriesCount,
    required this.playerSuspensionsCount,
    required this.rowsWithXg,
    required this.rowsWithXa,
  });

  factory HealthSnapshot.fromJson(Map<String, dynamic> json) {
    return HealthSnapshot(
      id: json['id'] as int,
      source: json['source'] as String,
      snapshotAt: DateTime.parse(json['snapshot_at'] as String),
      teamsCount: json['teams_count'] as int,
      fixturesCount: json['fixtures_count'] as int,
      playersCount: json['players_count'] as int,
      gameweekPointsCount: json['gameweek_points_count'] as int,
      fixtureEventsCount: json['fixture_events_count'] as int,
      teamFormCount: json['team_form_count'] as int,
      playerMatchStatsCount: json['player_match_stats_count'] as int,
      playerInjuriesCount: json['player_injuries_count'] as int,
      playerSuspensionsCount: json['player_suspensions_count'] as int,
      rowsWithXg: json['rows_with_xg'] as int,
      rowsWithXa: json['rows_with_xa'] as int,
    );
  }

  @override
  List<Object?> get props => [
        id,
        source,
        snapshotAt,
        teamsCount,
        fixturesCount,
        playersCount,
        gameweekPointsCount,
        fixtureEventsCount,
        teamFormCount,
        playerMatchStatsCount,
        playerInjuriesCount,
        playerSuspensionsCount,
        rowsWithXg,
        rowsWithXa,
      ];
}

class CronJobStatus extends Equatable {
  final int jobId;
  final String jobName;
  final String schedule;
  final bool isActive;
  final DateTime? lastRunStart;
  final DateTime? lastRunEnd;
  final String? lastRunStatus;
  final String? lastRunMessage;

  const CronJobStatus({
    required this.jobId,
    required this.jobName,
    required this.schedule,
    required this.isActive,
    this.lastRunStart,
    this.lastRunEnd,
    this.lastRunStatus,
    this.lastRunMessage,
  });

  @override
  List<Object?> get props => [
        jobId,
        jobName,
        schedule,
        isActive,
        lastRunStart,
        lastRunEnd,
        lastRunStatus,
        lastRunMessage,
      ];
}

class OpsDashboardStatus extends Equatable {
  final List<CronJobStatus> cronJobs;
  final List<IngestionAlert> activeAlerts;
  final HealthSnapshot? latestSnapshot;
  final int snapshotAgeMinutes;
  final bool isHealthy;

  const OpsDashboardStatus({
    required this.cronJobs,
    required this.activeAlerts,
    this.latestSnapshot,
    required this.snapshotAgeMinutes,
    required this.isHealthy,
  });

  @override
  List<Object?> get props => [
        cronJobs,
        activeAlerts,
        latestSnapshot,
        snapshotAgeMinutes,
        isHealthy,
      ];
}
