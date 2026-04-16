import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/team.dart';
import '../models/team_analytics.dart';
import '../providers/team_analytics_provider.dart';
import '../constants/app_colors.dart';

class TeamAnalyticsScreen extends StatefulWidget {
  final Team team;

  const TeamAnalyticsScreen({super.key, required this.team});

  @override
  State<TeamAnalyticsScreen> createState() => _TeamAnalyticsScreenState();
}

class _TeamAnalyticsScreenState extends State<TeamAnalyticsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<TeamAnalyticsProvider>().analyzeTeam(
        teamId: widget.team.id,
        teamName: widget.team.name,
        players: widget.team.players,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.team.name} Analytics'),
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<TeamAnalyticsProvider>().analyzeTeam(
                teamId: widget.team.id,
                teamName: widget.team.name,
                players: widget.team.players,
              );
            },
          ),
        ],
      ),
      body: Consumer<TeamAnalyticsProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(child: Text('Error: ${provider.error}'));
          }

          final analytics = provider.analytics;
          if (analytics == null) {
            return const Center(child: Text('No analytics available'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Team Form Score
                _buildFormScoreCard(analytics),
                const SizedBox(height: 20),

                // Form Trends Chart
                if (analytics.formTrends.isNotEmpty)
                  _buildFormTrendsCard(analytics.formTrends),
                const SizedBox(height: 20),

                // Injury Risks
                if (analytics.injuryRisks.isNotEmpty)
                  _buildInjuryRisksCard(analytics.injuryRisks),
                const SizedBox(height: 20),

                // Transfer Recommendations
                if (analytics.transferRecommendations.isNotEmpty)
                  _buildTransferRecommendationsCard(
                    analytics.transferRecommendations,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFormScoreCard(TeamAnalytics analytics) {
    final scoreColor = analytics.teamFormScore > 70
        ? Colors.green
        : analytics.teamFormScore > 50
        ? Colors.orange
        : Colors.red;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Team Form Score',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  SizedBox(
                    width: 150,
                    height: 150,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: analytics.teamFormScore / 100,
                          strokeWidth: 8,
                          valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                          backgroundColor: Colors.grey.withValues(alpha: 0.2),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              analytics.teamFormScore.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: scoreColor,
                              ),
                            ),
                            const Text(
                              '/ 100',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildQuickStat(
                        'High Risk',
                        '${analytics.injuryRisks.where((r) => r.riskLevel == "high").length}',
                      ),
                      _buildQuickStat(
                        'Transfers',
                        '${analytics.highPriorityTransfers}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildFormTrendsCard(List<FormTrend> trends) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Form Trends (Last 5 Gameweeks)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: trends.take(5).length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, index) {
                final trend = trends[index];
                return _buildFormTrendTile(trend);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormTrendTile(FormTrend trend) {
    final trendIcon = trend.trend == 'up'
        ? Icons.trending_up
        : trend.trend == 'down'
        ? Icons.trending_down
        : Icons.trending_flat;
    final trendColor = trend.trend == 'up'
        ? Colors.green
        : trend.trend == 'down'
        ? Colors.red
        : Colors.orange;

    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gameweek ${trend.gameweek}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              '${trend.points} pts',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${trend.windowAverage.toStringAsFixed(1)} avg',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Icon(trendIcon, color: trendColor, size: 16),
          ],
        ),
      ],
    );
  }

  Widget _buildInjuryRisksCard(List<InjuryRisk> risks) {
    return Card(
      color: Colors.orange.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.medical_information, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Injury Risks (${risks.length})',
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
              itemCount: risks.length,
              separatorBuilder: (_, _) => const Divider(height: 12),
              itemBuilder: (context, index) {
                final risk = risks[index];
                return _buildInjuryRiskTile(risk);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInjuryRiskTile(InjuryRisk risk) {
    final riskColor = risk.riskLevel == 'high'
        ? Colors.red
        : risk.riskLevel == 'medium'
        ? Colors.orange
        : Colors.green;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    risk.playerName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Score: ${risk.riskScore}/100',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: riskColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                risk.riskLevel.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: riskColor,
                ),
              ),
            ),
          ],
        ),
        if (risk.expectedReturnDate != null)
          Text(
            'Est. return: ${risk.expectedReturnDate!.toLocal().toString().split(' ')[0]}',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
      ],
    );
  }

  Widget _buildTransferRecommendationsCard(
    List<TransferRecommendation> recommendations,
  ) {
    return Card(
      color: Colors.blue.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.swap_horiz, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Transfer Recommendations (${recommendations.length})',
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
              itemCount: recommendations.length,
              separatorBuilder: (_, _) => const Divider(height: 12),
              itemBuilder: (context, index) {
                final rec = recommendations[index];
                return _buildTransferRecTile(rec);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransferRecTile(TransferRecommendation rec) {
    final actionColor = rec.action == 'buy'
        ? Colors.green
        : rec.action == 'sell'
        ? Colors.red
        : Colors.orange;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rec.playerName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    rec.position,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: actionColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                rec.action.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: actionColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Value: ${rec.estimatedValue.toStringAsFixed(1)}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            Text(
              'Price: ${rec.estimatedPrice.toStringAsFixed(1)}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            Text(
              'xG: ${rec.expectedGoals.toStringAsFixed(1)}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }
}
