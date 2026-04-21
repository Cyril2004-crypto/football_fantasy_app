import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:football_manager_companion_app2/models/player.dart';
import 'package:football_manager_companion_app2/models/team.dart';
import 'package:football_manager_companion_app2/models/team_analytics.dart';
import 'package:football_manager_companion_app2/providers/player_provider.dart';
import 'package:football_manager_companion_app2/providers/team_analytics_provider.dart';
import 'package:football_manager_companion_app2/providers/team_provider.dart';
import 'package:football_manager_companion_app2/screens/gameweek_points_screen.dart';
import 'package:football_manager_companion_app2/screens/login_screen.dart';
import 'package:football_manager_companion_app2/screens/team_status_screen.dart';
import 'package:football_manager_companion_app2/services/api_service.dart';
import 'package:football_manager_companion_app2/services/player_service.dart';
import 'package:football_manager_companion_app2/services/team_analytics_service.dart';
import 'package:football_manager_companion_app2/services/team_service.dart';

class _SmokeTeamService extends TeamService {
  _SmokeTeamService() : super(_SmokeApiService());

  @override
  Future<Team?> getMyTeam() async => _buildTeam();

  @override
  Future<Team> createTeam(String teamName, List<String> playerIds) async {
    return _buildTeam(name: teamName);
  }

  @override
  Future<Team> updateTeam(String teamId, List<String> playerIds) async {
    return _buildTeam();
  }
}

class _SmokeApiService extends ApiService {
  _SmokeApiService() : super();
}

class _SmokePlayerService extends PlayerService {
  _SmokePlayerService() : super();

  @override
  Future<List<Player>> getAllPlayers() async => _buildPlayers();
}

class _SmokeTeamAnalyticsService extends TeamAnalyticsService {
  _SmokeTeamAnalyticsService() : super(_SmokeSupabaseClient());

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
      ],
      injuryRisks: const [],
      transferRecommendations: const [],
      teamFormScore: 72,
      highPriorityTransfers: 0,
    );
  }
}

class _SmokeSupabaseClient implements SupabaseClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Team _buildTeam({String name = 'Test XI'}) {
  return Team(
    id: 'team-1',
    userId: 'user-1',
    name: name,
    players: _buildPlayers(),
    remainingBudget: 12.5,
    totalPoints: 180,
    gameweekPoints: 17,
    createdAt: DateTime.parse('2026-04-17T00:00:00Z'),
  );
}

List<Player> _buildPlayers() {
  return [
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
  ];
}

Widget _wrapLogin(Widget child) {
  return MaterialApp(home: child);
}

Widget _wrapTeamStatus(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<TeamProvider>(
        create: (_) => _StaticTeamProvider(_buildTeam()),
      ),
      ChangeNotifierProvider<PlayerProvider>(
        create: (_) => _StaticPlayerProvider(_buildPlayers()),
      ),
      ChangeNotifierProvider<TeamAnalyticsProvider>(
        create: (_) => TeamAnalyticsProvider(_SmokeTeamAnalyticsService()),
      ),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

class _StaticTeamProvider extends TeamProvider {
  _StaticTeamProvider(Team team)
      : _team = team,
        super(_SmokeTeamService(), disableAuthSubscription: true);

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

  @override
  Future<void> updateTeam(
    List<String> playerIds, {
    List<Player>? selectedPlayers,
  }) async {}
}

class _StaticPlayerProvider extends PlayerProvider {
  _StaticPlayerProvider(List<Player> players)
      : _players = players,
        super(_SmokePlayerService());

  final List<Player> _players;

  @override
  List<Player> get players => _players;

  @override
  Future<void> loadAllPlayers() async {}
}

void main() {
  testWidgets('login screen renders primary entry points', (tester) async {
    await tester.pumpWidget(_wrapLogin(const LoginScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Sign Up'), findsOneWidget);
  });

  testWidgets(
    'critical flow smoke test covers team, transfers, and league entry points',
    (tester) async {
      await tester.pumpWidget(_wrapTeamStatus(const TeamStatusScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Open Team Analytics'), findsOneWidget);
      expect(find.text('Create League'), findsOneWidget);
      expect(find.text('Join League'), findsOneWidget);
      expect(find.text('Transfers'), findsOneWidget);
      expect(find.text('Gameweek Points'), findsOneWidget);

      await tester.tap(find.text('Open Team Analytics'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Analytics'), findsOneWidget);
      expect(find.text('Team Form Score'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Transfers'));
      await tester.pumpAndSettle();
      expect(find.text('Transfers'), findsWidgets);
      expect(find.text('Your Squad'), findsOneWidget);
      expect(find.text('Available Players'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      // These actions are intentionally asserted as visible only here because
      // their destination screens currently instantiate Firebase-auth services.
      await tester.ensureVisible(find.text('Create League'));
      await tester.pumpAndSettle();
      expect(find.text('Create League'), findsOneWidget);

      await tester.ensureVisible(find.text('Join League'));
      await tester.pumpAndSettle();
      expect(find.text('Join League'), findsOneWidget);
    },
  );

  testWidgets('gameweek points view shows recoverable error state', (tester) async {
    final team = _buildTeam();

    await tester.pumpWidget(
      MaterialApp(
        home: GameweekPointsScreen(
          team: team,
          clientOverride: _SmokeSupabaseClient(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Gameweek Points'), findsOneWidget);
    expect(find.text('Could not load gameweek points right now.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}