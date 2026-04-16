import 'package:flutter_test/flutter_test.dart';
import 'package:football_manager_companion_app2/models/ops_dashboard.dart';
import 'package:football_manager_companion_app2/services/ops_dashboard_service.dart';

void main() {
  group('OpsDashboardService helpers', () {
    test('mapCronJobStatus maps rpc row to cron job status', () {
      final job = mapCronJobStatus({
        'jobid': 6,
        'jobname': 'notify-ingestion-alerts',
        'schedule': '9,29,49 * * * *',
        'active': true,
        'last_run_start': '2026-04-16T07:09:00.015792+00:00',
        'last_run_end': '2026-04-16T07:09:00.029139+00:00',
        'last_run_status': 'succeeded',
        'last_run_message': '1 row',
      });

      expect(job.jobId, 6);
      expect(job.jobName, 'notify-ingestion-alerts');
      expect(job.schedule, '9,29,49 * * * *');
      expect(job.isActive, isTrue);
      expect(
        job.lastRunStart,
        DateTime.parse('2026-04-16T07:09:00.015792+00:00'),
      );
      expect(
        job.lastRunEnd,
        DateTime.parse('2026-04-16T07:09:00.029139+00:00'),
      );
      expect(job.lastRunStatus, 'succeeded');
      expect(job.lastRunMessage, '1 row');
    });

    test('calculateSnapshotAgeMinutes returns age in minutes', () {
      final snapshot = HealthSnapshot(
        id: 1,
        source: 'sportmonks-enrichment',
        snapshotAt: DateTime.parse('2026-04-16T07:00:00Z'),
        teamsCount: 20,
        fixturesCount: 380,
        playersCount: 650,
        gameweekPointsCount: 1000,
        fixtureEventsCount: 200,
        teamFormCount: 20,
        playerMatchStatsCount: 500,
        playerInjuriesCount: 12,
        playerSuspensionsCount: 4,
        rowsWithXg: 123,
        rowsWithXa: 234,
      );

      final age = calculateSnapshotAgeMinutes(
        snapshot,
        now: DateTime.parse('2026-04-16T07:16:00Z'),
      );

      expect(age, 16);
    });

    test('isDashboardHealthy requires snapshot and no active alerts', () {
      final jobs = [
        CronJobStatus(
          jobId: 1,
          jobName: 'job-a',
          schedule: '* * * * *',
          isActive: true,
        ),
        CronJobStatus(
          jobId: 2,
          jobName: 'job-b',
          schedule: '* * * * *',
          isActive: true,
        ),
      ];

      final snapshot = HealthSnapshot(
        id: 1,
        source: 'sportmonks-enrichment',
        snapshotAt: DateTime.parse('2026-04-16T07:00:00Z'),
        teamsCount: 20,
        fixturesCount: 380,
        playersCount: 650,
        gameweekPointsCount: 1000,
        fixtureEventsCount: 200,
        teamFormCount: 20,
        playerMatchStatsCount: 500,
        playerInjuriesCount: 12,
        playerSuspensionsCount: 4,
        rowsWithXg: 123,
        rowsWithXa: 234,
      );

      expect(
        isDashboardHealthy(
          cronJobs: jobs,
          activeAlerts: const [],
          latestSnapshot: snapshot,
        ),
        isTrue,
      );

      expect(
        isDashboardHealthy(
          cronJobs: jobs,
          activeAlerts: [
            IngestionAlert(
              id: 99,
              source: 'sportmonks-enrichment',
              alertCode: 'stale_snapshot',
              severity: 'critical',
              message: 'Latest snapshot is stale',
              context: const {},
              firstSeenAt: DateTime.parse('2026-04-16T07:00:00Z'),
              lastSeenAt: DateTime.parse('2026-04-16T07:05:00Z'),
              occurrenceCount: 1,
              isActive: true,
            ),
          ],
          latestSnapshot: snapshot,
        ),
        isFalse,
      );
    });
  });
}
