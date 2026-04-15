import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/ops_dashboard.dart';
import '../providers/ops_dashboard_provider.dart';
import '../constants/app_colors.dart';

class OpsAdminScreen extends StatefulWidget {
  const OpsAdminScreen({Key? key}) : super(key: key);

  @override
  State<OpsAdminScreen> createState() => _OpsAdminScreenState();
}

class _OpsAdminScreenState extends State<OpsAdminScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<OpsDashboardProvider>().loadDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ops Dashboard'),
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<OpsDashboardProvider>().loadDashboard();
            },
          ),
        ],
      ),
      body: Consumer<OpsDashboardProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (provider.error != null) {
            return Center(
              child: Text('Error: ${provider.error}'),
            );
          }

          final status = provider.status;
          if (status == null) {
            return const Center(
              child: Text('No data available'),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Health Status Card
                _buildHealthStatusCard(status),
                const SizedBox(height: 20),

                // Latest Snapshot
                if (status.latestSnapshot != null)
                  _buildSnapshotCard(status.latestSnapshot!),
                const SizedBox(height: 20),

                // Cron Jobs
                _buildCronJobsCard(status.cronJobs),
                const SizedBox(height: 20),

                // Active Alerts
                if (status.activeAlerts.isNotEmpty)
                  _buildAlertsCard(status.activeAlerts),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHealthStatusCard(OpsDashboardStatus status) {
    final bgColor = status.isHealthy
        ? Colors.green.withOpacity(0.1)
        : Colors.red.withOpacity(0.1);
    final statusColor = status.isHealthy ? Colors.green : Colors.red;
    final statusText = status.isHealthy ? 'Healthy' : 'Unhealthy';

    return Card(
      color: bgColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  status.isHealthy ? Icons.check_circle : Icons.error_outline,
                  color: statusColor,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'System Status',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 16,
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem('Cron Jobs', '${status.cronJobs.length}'),
                _buildStatItem(
                  'Active Cron',
                  '${status.cronJobs.where((j) => j.isActive).length}',
                ),
                _buildStatItem('Alerts', '${status.activeAlerts.length}'),
                _buildStatItem(
                  'Age',
                  status.latestSnapshot == null
                      ? 'N/A'
                      : '${status.snapshotAgeMinutes}m',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildSnapshotCard(HealthSnapshot snapshot) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Latest Snapshot',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Time: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(snapshot.snapshotAt)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.5,
              children: [
                _snapshotStat('Teams', snapshot.teamsCount),
                _snapshotStat('Fixtures', snapshot.fixturesCount),
                _snapshotStat('Players', snapshot.playersCount),
                _snapshotStat('Gameweek Points', snapshot.gameweekPointsCount),
                _snapshotStat('Events', snapshot.fixtureEventsCount),
                _snapshotStat('Match Stats', snapshot.playerMatchStatsCount),
                _snapshotStat('Injuries', snapshot.playerInjuriesCount),
                _snapshotStat('Suspensions', snapshot.playerSuspensionsCount),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _snapshotStat(String label, int value) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value.toString(),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildCronJobsCard(List<CronJobStatus> jobs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cron Jobs',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (jobs.isEmpty)
              const Text(
                'No monitored cron jobs available yet.\nEnsure the cron status RPC is installed and jobs are scheduled.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              )
            else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: jobs.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final job = jobs[index];
                return _buildCronJobTile(job);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCronJobTile(CronJobStatus job) {
    final statusColor = job.isActive ? Colors.green : Colors.orange;
    final statusIcon = job.isActive ? Icons.check_circle : Icons.warning;
    final lastRunColor = job.lastRunStatus == 'succeeded'
        ? Colors.green
        : Colors.red;

    return Column(
      children: [
        Row(
          children: [
            Icon(statusIcon, color: statusColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.jobName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Schedule: ${job.schedule}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (job.lastRunStart != null)
          Text(
            'Last run: ${DateFormat('HH:mm:ss').format(job.lastRunStart!)} - ${job.lastRunStatus ?? "N/A"}',
            style: TextStyle(
              fontSize: 11,
              color: lastRunColor,
            ),
          ),
      ],
    );
  }

  Widget _buildAlertsCard(List<IngestionAlert> alerts) {
    return Card(
      color: Colors.red.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber, color: Colors.red),
                const SizedBox(width: 12),
                Text(
                  'Active Alerts (${alerts.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: alerts.length,
              separatorBuilder: (_, __) => const Divider(height: 12),
              itemBuilder: (context, index) {
                final alert = alerts[index];
                return _buildAlertTile(alert);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertTile(IngestionAlert alert) {
    final severityColor = alert.severity == 'critical'
        ? Colors.red
        : Colors.orange;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: severityColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                alert.alertCode,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              alert.severity.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                color: severityColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          alert.message,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(
          'Seen ${alert.occurrenceCount}x - Last: ${DateFormat('HH:mm').format(alert.lastSeenAt)}',
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }
}
