import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ops_dashboard.dart';

CronJobStatus mapCronJobStatus(Map<String, dynamic> row) {
  return CronJobStatus(
    jobId: (row['jobid'] as num?)?.toInt() ?? 0,
    jobName: row['jobname'] as String? ?? 'unknown-job',
    schedule: row['schedule'] as String? ?? 'n/a',
    isActive: row['active'] as bool? ?? false,
    lastRunStart: row['last_run_start'] != null
        ? DateTime.parse(row['last_run_start'] as String)
        : null,
    lastRunEnd: row['last_run_end'] != null
        ? DateTime.parse(row['last_run_end'] as String)
        : null,
    lastRunStatus: row['last_run_status'] as String?,
    lastRunMessage: row['last_run_message'] as String?,
  );
}

int calculateSnapshotAgeMinutes(HealthSnapshot? snapshot, {DateTime? now}) {
  if (snapshot == null) return 9999;
  final reference = now ?? DateTime.now();
  return reference.difference(snapshot.snapshotAt).inMinutes;
}

bool isDashboardHealthy({
  required List<CronJobStatus> cronJobs,
  required List<IngestionAlert> activeAlerts,
  required HealthSnapshot? latestSnapshot,
}) {
  final hasSnapshot = latestSnapshot != null;
  final hasCronVisibility = cronJobs.isNotEmpty;
  final allVisibleCronActive = cronJobs.every((j) => j.isActive);
  return activeAlerts.isEmpty &&
      (!hasCronVisibility || allVisibleCronActive) &&
      hasSnapshot;
}

class OpsDashboardService {
  final SupabaseClient _supabase;

  OpsDashboardService(this._supabase);

  Future<List<CronJobStatus>> fetchCronJobs() async {
    try {
      final response = await _supabase.rpc('get_ops_cron_job_statuses');

      return (response as List)
          .map((row) => mapCronJobStatus(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Cron metadata is commonly restricted from anon clients in Supabase.
      // Do not fail the whole dashboard if cron tables are inaccessible.
      debugPrint('Cron jobs unavailable (continuing without cron section): $e');
      return const <CronJobStatus>[];
    }
  }

  Future<List<IngestionAlert>> fetchActiveAlerts() async {
    try {
      final response = await _supabase
          .from('ingestion_alert_events')
          .select()
          .eq('is_active', true)
          .order('severity', ascending: false)
          .order('last_seen_at', ascending: false);

      return (response as List)
          .map(
            (alert) => IngestionAlert.fromJson(alert as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      debugPrint('Error fetching active alerts: $e');
      throw Exception('Failed to fetch alerts: $e');
    }
  }

  Future<HealthSnapshot?> fetchLatestSnapshot(String source) async {
    try {
      final response = await _supabase
          .from('ingestion_health_snapshots')
          .select()
          .eq('source', source)
          .order('snapshot_at', ascending: false)
          .limit(1);

      if ((response as List).isNotEmpty) {
        return HealthSnapshot.fromJson(response.first);
      }

      // Fallback: use the latest snapshot regardless of source.
      final fallback = await _supabase
          .from('ingestion_health_snapshots')
          .select()
          .order('snapshot_at', ascending: false)
          .limit(1);

      if ((fallback as List).isEmpty) {
        return null;
      }

      return HealthSnapshot.fromJson(fallback.first);
    } catch (e) {
      debugPrint('Error fetching latest snapshot: $e');
      return null;
    }
  }

  Future<OpsDashboardStatus> fetchDashboardStatus() async {
    try {
      final cronJobs = await fetchCronJobs();
      final activeAlerts = await fetchActiveAlerts();
      final latestSnapshot = await fetchLatestSnapshot('sportmonks-enrichment');

      final snapshotAgeMinutes = calculateSnapshotAgeMinutes(latestSnapshot);
      final isHealthy = isDashboardHealthy(
        cronJobs: cronJobs,
        activeAlerts: activeAlerts,
        latestSnapshot: latestSnapshot,
      );

      return OpsDashboardStatus(
        cronJobs: cronJobs,
        activeAlerts: activeAlerts,
        latestSnapshot: latestSnapshot,
        snapshotAgeMinutes: snapshotAgeMinutes,
        isHealthy: isHealthy,
      );
    } catch (e) {
      debugPrint('Error fetching dashboard status: $e');
      throw Exception('Failed to fetch dashboard status: $e');
    }
  }
}
