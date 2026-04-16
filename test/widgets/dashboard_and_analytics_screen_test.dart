import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:football_manager_companion_app2/models/ops_dashboard.dart';
import 'package:football_manager_companion_app2/models/player.dart';
import 'package:football_manager_companion_app2/models/team.dart';
import 'package:football_manager_companion_app2/models/team_analytics.dart';
import 'package:football_manager_companion_app2/providers/ops_dashboard_provider.dart';
import 'package:football_manager_companion_app2/providers/team_analytics_provider.dart';
import 'package:football_manager_companion_app2/providers/team_provider.dart';
import 'package:football_manager_companion_app2/screens/ops_admin_screen.dart';
import 'package:football_manager_companion_app2/screens/team_status_screen.dart';
import 'package:football_manager_companion_app2/screens/team_analytics_screen.dart';
import 'package:football_manager_companion_app2/services/api_service.dart';
import 'package:football_manager_companion_app2/services/ops_dashboard_service.dart';
import 'package:football_manager_companion_app2/services/team_service.dart';
import 'package:football_manager_companion_app2/services/team_analytics_service.dart';

class _FakeSupabaseClient implements SupabaseClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeOpsDashboardService extends OpsDashboardService {
  _FakeOpsDashboardService() : super(_FakeSupabaseClient());

  @override
  Future<OpsDashboardStatus> fetchDashboardStatus() async {
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

    final cronJobs = [
      CronJobStatus(
        jobId: 1,
        jobName: 'daily-sync-fd-data',
        schedule: '0 2 * * *',
        isActive: true,
      ),
      CronJobStatus(
        jobId: 2,
        jobName: 'evaluate-ingestion-alerts',
        schedule: '7,27,47 * * * *',
        isActive: true,
      ),
    ];

    return OpsDashboardStatus(
      cronJobs: cronJobs,
      activeAlerts: const [],
      latestSnapshot: snapshot,
      snapshotAgeMinutes: 16,
      isHealthy: true,
    );
  }
}

class _StaticOpsDashboardProvider extends OpsDashboardProvider {
  _StaticOpsDashboardProvider({
    required OpsDashboardStatus? status,
    bool isLoading = false,
    String? error,
  }) : _status = status,
       _isLoading = isLoading,
       _error = error,
       super(_FakeOpsDashboardService());

  final OpsDashboardStatus? _status;
  final bool _isLoading;
  final String? _error;

  @override
  OpsDashboardStatus? get status => _status;

  @override
  bool get isLoading => _isLoading;

  @override
  String? get error => _error;

  @override
  Future<void> loadDashboard() async {}
}

class _FakeTeamAnalyticsService extends TeamAnalyticsService {
  _FakeTeamAnalyticsService() : super(_FakeSupabaseClient());

  @override
  Future<TeamAnalytics> analyzeTeam({
    required String teamId,
    required String teamName,
    required List<dynamic> players,
    int recentGamesWindow = 5,
  }) async {
    return TeamAnalytics(
      teamId: teamId,
      teamName: teamName,
      formTrends: [
        FormTrend(gameweek: 1, points: 10, windowAverage: 8.0, trend: 'up'),
        FormTrend(
          gameweek: 2,
          points: 14,
          windowAverage: 11.0,
          trend: 'stable',
        ),
      ],
      injuryRisks: [
        InjuryRisk(
          playerId: 1,
          playerName: 'Player One',
          currentInjuries: 1,
          currentSuspensions: 0,
          riskScore: 20,
          riskLevel: 'low',
          expectedReturnDate: DateTime.parse('2026-04-20T00:00:00Z'),
        ),
      ],
      transferRecommendations: [
        TransferRecommendation(
          playerId: 2,
          playerName: 'Player Two',
          position: 'midfielder',
          estimatedValue: 18,
          estimatedPrice: 8,
          recentPointsAverage: 11,
          expectedGoals: 1.2,
          expectedAssists: 0.8,
          action: 'buy',
          priority: 5,
        ),
      ],
      teamFormScore: 78,
      highPriorityTransfers: 1,
    );
  }
}

class _StaticTeamAnalyticsProvider extends TeamAnalyticsProvider {
  _StaticTeamAnalyticsProvider({
    required TeamAnalytics? analytics,
    bool isLoading = false,
    String? error,
  }) : _analytics = analytics,
       _isLoading = isLoading,
       _error = error,
       super(_FakeTeamAnalyticsService());

  final TeamAnalytics? _analytics;
  final bool _isLoading;
  final String? _error;

  @override
  TeamAnalytics? get analytics => _analytics;

  @override
  bool get isLoading => _isLoading;

  @override
  String? get error => _error;

  @override
  Future<void> analyzeTeam({
    required String teamId,
    required String teamName,
    required List<dynamic> players,
    int recentGamesWindow = 5,
  }) async {}
}

class _StaticTeamProvider extends TeamProvider {
  _StaticTeamProvider(Team team)
    : _team = team,
      super(_FakeTeamService(), disableAuthSubscription: true);

  final Team _team;

  @override
  Team? get team => _team;

  @override
  bool get isLoading => false;

  @override
  String? get errorMessage => null;

  @override
  bool get hasTeam => true;

  @override
  List<Player> get players => _team.players;

  @override
  Future<void> loadMyTeam() async {}
}

class _FakeApiService extends ApiService {
  _FakeApiService() : super();
}

class _FakeTeamService extends TeamService {
  _FakeTeamService() : super(_FakeApiService());

  @override
  Future<Team?> getMyTeam() async => _buildTeam();
}

Team _buildTeam() {
  return Team(
    id: 'team-1',
    userId: 'user-1',
    name: 'Test XI',
    players: [
      Player(
        id: '1',
        name: 'Player One',
        clubId: 'club-1',
        clubName: 'Club One',
        position: PlayerPosition.midfielder,
        price: 8.0,
        points: 100,
        gameweekPoints: 10,
        nationality: 'GB',
      ),
      Player(
        id: '2',
        name: 'Player Two',
        clubId: 'club-2',
        clubName: 'Club Two',
        position: PlayerPosition.forward,
        price: 7.5,
        points: 80,
        gameweekPoints: 7,
        nationality: 'GB',
      ),
    ],
    remainingBudget: 20,
    totalPoints: 180,
    gameweekPoints: 17,
    createdAt: DateTime.parse('2026-04-16T00:00:00Z'),
  );
}

OpsDashboardStatus _buildDashboardStatus() {
  return OpsDashboardStatus(
    cronJobs: [
      CronJobStatus(
        jobId: 1,
        jobName: 'daily-sync-fd-data',
        schedule: '0 2 * * *',
        isActive: true,
      ),
      CronJobStatus(
        jobId: 2,
        jobName: 'evaluate-ingestion-alerts',
        schedule: '7,27,47 * * * *',
        isActive: true,
      ),
    ],
    activeAlerts: const [],
    latestSnapshot: HealthSnapshot(
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
    ),
    snapshotAgeMinutes: 16,
    isHealthy: true,
  );
}

void main() {
  testWidgets('Ops dashboard screen renders live data cards', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<OpsDashboardProvider>.value(
        value: _StaticOpsDashboardProvider(status: _buildDashboardStatus()),
        child: const MaterialApp(home: OpsAdminScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Ops Dashboard'), findsOneWidget);
    expect(find.text('System Status'), findsOneWidget);
    expect(find.text('Healthy'), findsOneWidget);
    expect(find.text('Latest Snapshot'), findsOneWidget);
    expect(find.text('Cron Jobs'), findsAtLeastNWidgets(1));
    expect(find.text('Teams'), findsOneWidget);
    expect(find.text('Fixtures'), findsOneWidget);
  });

  testWidgets('Ops dashboard screen shows loading state', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<OpsDashboardProvider>.value(
        value: _StaticOpsDashboardProvider(status: null, isLoading: true),
        child: const MaterialApp(home: OpsAdminScreen()),
      ),
    );

    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('Ops dashboard screen shows no data state', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<OpsDashboardProvider>.value(
        value: _StaticOpsDashboardProvider(status: null),
        child: const MaterialApp(home: OpsAdminScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('No data available'), findsOneWidget);
  });

  testWidgets('Team analytics screen renders analytics sections', (
    tester,
  ) async {
    final team = _buildTeam();

    await tester.pumpWidget(
      ChangeNotifierProvider<TeamAnalyticsProvider>.value(
        value: _StaticTeamAnalyticsProvider(
          analytics: TeamAnalytics(
            teamId: team.id,
            teamName: team.name,
            formTrends: [
              FormTrend(
                gameweek: 1,
                points: 10,
                windowAverage: 8.0,
                trend: 'up',
              ),
              FormTrend(
                gameweek: 2,
                points: 14,
                windowAverage: 11.0,
                trend: 'stable',
              ),
            ],
            injuryRisks: [
              InjuryRisk(
                playerId: 1,
                playerName: 'Player One',
                currentInjuries: 1,
                currentSuspensions: 0,
                riskScore: 20,
                riskLevel: 'low',
                expectedReturnDate: DateTime.parse('2026-04-20T00:00:00Z'),
              ),
            ],
            transferRecommendations: [
              TransferRecommendation(
                playerId: 2,
                playerName: 'Player Two',
                position: 'midfielder',
                estimatedValue: 18,
                estimatedPrice: 8,
                recentPointsAverage: 11,
                expectedGoals: 1.2,
                expectedAssists: 0.8,
                action: 'buy',
                priority: 5,
              ),
            ],
            teamFormScore: 78,
            highPriorityTransfers: 1,
          ),
        ),
        child: MaterialApp(home: TeamAnalyticsScreen(team: team)),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Test XI Analytics'), findsOneWidget);
    expect(find.text('Team Form Score'), findsOneWidget);
    expect(find.text('Form Trends (Last 5 Gameweeks)'), findsOneWidget);
    expect(find.text('Injury Risks (1)'), findsOneWidget);
    expect(find.textContaining('Transfer Recommendations'), findsOneWidget);
    expect(find.text('78.0'), findsOneWidget);
    expect(find.text('Player Two'), findsOneWidget);
  });

  testWidgets('Team analytics screen shows no analytics state', (tester) async {
    final team = _buildTeam();

    await tester.pumpWidget(
      ChangeNotifierProvider<TeamAnalyticsProvider>.value(
        value: _StaticTeamAnalyticsProvider(analytics: null),
        child: MaterialApp(home: TeamAnalyticsScreen(team: team)),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('No analytics available'), findsOneWidget);
  });

  testWidgets(
    'Team status screen opens team analytics from the real button path',
    (tester) async {
      final team = _buildTeam();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<TeamProvider>.value(
              value: _StaticTeamProvider(team),
            ),
            ChangeNotifierProvider<TeamAnalyticsProvider>.value(
              value: _StaticTeamAnalyticsProvider(
                analytics: TeamAnalytics(
                  teamId: team.id,
                  teamName: team.name,
                  formTrends: const [],
                  injuryRisks: const [],
                  transferRecommendations: const [],
                  teamFormScore: 50,
                  highPriorityTransfers: 0,
                ),
              ),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: TeamStatusScreen())),
        ),
      );

      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Open Team Analytics'));
      await tester.tap(find.text('Open Team Analytics'));
      await tester.pumpAndSettle();

      expect(find.text('Test XI Analytics'), findsOneWidget);
      expect(find.text('Team Form Score'), findsOneWidget);
    },
  );
}
