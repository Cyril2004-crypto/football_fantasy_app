import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../providers/team_provider.dart';
import '../providers/ops_dashboard_provider.dart';
import '../providers/team_analytics_provider.dart';
import '../services/auth_service.dart';
import '../services/league_service.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../models/league.dart';
import '../models/match.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../services/match_service.dart';
import '../widgets/custom_button.dart';
import 'login_screen.dart';
import 'team_status_screen.dart';
import 'create_league_screen.dart';
import 'join_league_screen.dart';
import 'league_details_screen.dart';
import 'livescore_screen.dart';
import 'news_screen.dart';
import 'ops_admin_screen.dart';
import 'team_analytics_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeTabScreen(),
    const TeamStatusScreen(),
    const LeaguesTabScreen(),
    const FixturesTabScreen(),
    const ProfileTabScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: AppStrings.home,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group),
            label: AppStrings.myTeam,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.emoji_events),
            label: AppStrings.leagues,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: AppStrings.fixtures,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: AppStrings.profile,
          ),
        ],
      ),
    );
  }
}

// Placeholder tab screens
class HomeTabScreen extends StatefulWidget {
  const HomeTabScreen({super.key});

  @override
  State<HomeTabScreen> createState() => _HomeTabScreenState();
}

class _HomeTabScreenState extends State<HomeTabScreen> {
  late Future<List<Match>> _matchesFuture;
  final MatchService _matchService = MatchService();

  @override
  void initState() {
    super.initState();
    _matchesFuture = _matchService.getPremierLeagueMatchesByMatchday(
      1,
      competitionId: 2021,
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = context.select<AuthProvider, String?>(
      (provider) => provider.user?.displayName,
    );
    final team = context.select<TeamProvider, Team?>(
      (provider) => provider.team,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.home),
        backgroundColor: AppColors.primary,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(gradient: AppColors.primaryGradient),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back!',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textLight.withValues(alpha: 0.9),
                    ),
                  ),
                  Text(
                    displayName ?? 'User',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.textLight,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Feature Shortcuts
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: _buildShortcutCard(
                      context,
                      title: 'Live Scores',
                      subtitle: 'In-play updates',
                      icon: Icons.live_tv,
                      color: AppColors.accent,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const LiveScoreScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildShortcutCard(
                      context,
                      title: 'News',
                      subtitle: 'Latest match updates',
                      icon: Icons.article_outlined,
                      color: AppColors.secondary,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const NewsScreen()),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Quick Stats
            if (team != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Team Overview',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            context,
                            'Points',
                            '${team.totalPoints}',
                            Icons.star_rounded,
                            AppColors.secondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            context,
                            'Gameweek',
                            '${team.gameweekPoints}',
                            Icons.trending_up,
                            AppColors.accent,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            context,
                            'Bank',
                            'Â£${team.remainingBudget.toStringAsFixed(1)}m',
                            Icons.account_balance_wallet,
                            AppColors.info,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Squad Composition
                    Text(
                      'Squad (${team.players.length}/15)',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 8),
                    _buildSquadComposition(context, team.players),
                  ],
                ),
              ),

            // Live Matches Section
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gameweek Matches',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<List<Match>>(
                    future: _matchesFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Container(
                          height: 120,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: AppColors.background,
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      if (snapshot.hasError ||
                          !snapshot.hasData ||
                          snapshot.data!.isEmpty) {
                        return Container(
                          height: 120,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: AppColors.background,
                          ),
                          child: Center(
                            child: Text(
                              'No matches available',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ),
                        );
                      }

                      final matches = snapshot.data!.take(5).toList();
                      return Column(
                        children: [
                          for (var i = 0; i < matches.length; i++) ...[
                            _buildMatchCard(context, matches[i]),
                            if (i < matches.length - 1)
                              const SizedBox(height: 8),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

            // FPL Tips
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FPL Insights',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildTipCard(
                    context,
                    'ðŸ’¡ Check Transfers',
                    'Review available players within your budget',
                    AppColors.primary,
                  ),
                  const SizedBox(height: 8),
                  _buildTipCard(
                    context,
                    'ðŸ“Š Form Matters',
                    'Players in great form will likely score more points',
                    AppColors.success,
                  ),
                  const SizedBox(height: 8),
                  _buildTipCard(
                    context,
                    'ðŸ›¡ï¸ Injury Watch',
                    'Monitor team news before gameweek deadline',
                    AppColors.warning,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildSquadComposition(BuildContext context, List<Player> players) {
    final gkCount = players
        .where((p) => p.position == PlayerPosition.goalkeeper)
        .length;
    final defCount = players
        .where((p) => p.position == PlayerPosition.defender)
        .length;
    final midCount = players
        .where((p) => p.position == PlayerPosition.midfielder)
        .length;
    final fwdCount = players
        .where((p) => p.position == PlayerPosition.forward)
        .length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildPositionBadge('GK', gkCount.toString(), Colors.amber),
          _buildPositionBadge('DEF', defCount.toString(), Colors.red),
          _buildPositionBadge('MID', midCount.toString(), Colors.green),
          _buildPositionBadge('FWD', fwdCount.toString(), Colors.blue),
        ],
      ),
    );
  }

  Widget _buildPositionBadge(String position, String count, Color color) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              count,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          position,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildMatchCard(BuildContext context, Match match) {
    final isFinished = match.status == MatchStatus.completed;
    final isLive = match.status == MatchStatus.live;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isLive
            ? AppColors.accent.withValues(alpha: 0.1)
            : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLive ? AppColors.accent : AppColors.divider,
        ),
      ),
      child: Column(
        children: [
          if (isLive)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'LIVE',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      match.homeTeamName,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      match.awayTeamName,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Score/Time
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    if (isFinished)
                      Text(
                        '${match.homeScore} - ${match.awayScore}',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                      )
                    else
                      Text(
                        '${match.kickoffTime.hour.toString().padLeft(2, '0')}:${match.kickoffTime.minute.toString().padLeft(2, '0')}',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTipCard(
    BuildContext context,
    String title,
    String description,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 6),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class MyTeamTabScreen extends StatelessWidget {
  const MyTeamTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.myTeam),
        backgroundColor: AppColors.primary,
      ),
      body: const Center(child: Text('My Team - Coming Soon')),
    );
  }
}

class LeaguesTabScreen extends StatefulWidget {
  const LeaguesTabScreen({super.key});

  @override
  State<LeaguesTabScreen> createState() => _LeaguesTabScreenState();
}

class _LeaguesTabScreenState extends State<LeaguesTabScreen> {
  late final LeagueService _leagueService;
  late Future<_LeaguesData> _future;

  @override
  void initState() {
    super.initState();
    _leagueService = LeagueService(AuthService());
    _future = _loadData();
  }

  Future<_LeaguesData> _loadData() async {
    final myLeagues = await _leagueService.getMyLeagues();
    final publicLeagues = await _leagueService.getPublicLeagues();
    return _LeaguesData(myLeagues: myLeagues, publicLeagues: publicLeagues);
  }

  void _refresh() {
    setState(() => _future = _loadData());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.leagues),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: FutureBuilder<_LeaguesData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final data =
                snapshot.data ??
                const _LeaguesData(myLeagues: [], publicLeagues: []);
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final refreshed = await Navigator.of(context)
                              .push<bool>(
                                MaterialPageRoute(
                                  builder: (_) => const CreateLeagueScreen(),
                                ),
                              );
                          if (refreshed == true) _refresh();
                        },
                        child: const Text(AppStrings.createLeague),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final refreshed = await Navigator.of(context)
                              .push<bool>(
                                MaterialPageRoute(
                                  builder: (_) => const JoinLeagueScreen(),
                                ),
                              );
                          if (refreshed == true) _refresh();
                        },
                        child: const Text(AppStrings.joinLeague),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'My Leagues',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                ..._buildLeagueCards(
                  data.myLeagues,
                  emptyText: 'You have not joined any leagues yet.',
                ),
                const SizedBox(height: 24),
                Text(
                  'Public Leagues',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                ..._buildLeagueCards(
                  data.publicLeagues,
                  emptyText: 'No public leagues found.',
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildLeagueCards(
    List<League> leagues, {
    required String emptyText,
  }) {
    if (leagues.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(emptyText),
        ),
      ];
    }

    return leagues
        .map(
          (league) => Card(
            child: ListTile(
              leading: Icon(
                league.type == LeagueType.public ? Icons.public : Icons.lock,
                color: AppColors.primary,
              ),
              title: Text(league.name),
              subtitle: Text(
                '${league.membersCount} members${league.code != null ? ' â€¢ Code: ${league.code}' : ''}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LeagueDetailsScreen(league: league),
                  ),
                );
              },
            ),
          ),
        )
        .toList();
  }
}

class _LeaguesData {
  final List<League> myLeagues;
  final List<League> publicLeagues;

  const _LeaguesData({required this.myLeagues, required this.publicLeagues});
}

class FixturesTabScreen extends StatefulWidget {
  const FixturesTabScreen({super.key});

  @override
  State<FixturesTabScreen> createState() => _FixturesTabScreenState();
}

class _FixturesTabScreenState extends State<FixturesTabScreen> {
  late final MatchService _matchService;
  late Future<List<Match>> _fixturesFuture;
  int _selectedMatchday = 1;
  static const int _competitionId = 2021;
  final Map<int, List<Match>> _fixturesCache = <int, List<Match>>{};

  @override
  void initState() {
    super.initState();
    _matchService = MatchService();
    _fixturesFuture = _loadFixtures();
  }

  Future<List<Match>> _loadFixtures() {
    final cached = _fixturesCache[_selectedMatchday];
    if (cached != null) {
      return Future<List<Match>>.value(cached);
    }

    return _matchService
        .getPremierLeagueMatchesByMatchday(
          _selectedMatchday,
          competitionId: _competitionId,
        )
        .then((matches) {
          _fixturesCache[_selectedMatchday] = matches;
          return matches;
        });
  }

  void _refresh() {
    setState(() {
      _fixturesFuture = _loadFixtures();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.fixtures),
        backgroundColor: AppColors.primary,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Text(
                  'Matchweek',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _selectedMatchday,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: List.generate(
                      38,
                      (index) => DropdownMenuItem<int>(
                        value: index + 1,
                        child: Text('Week ${index + 1}'),
                      ),
                    ),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedMatchday = value;
                        _fixturesFuture = _loadFixtures();
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Match>>(
              future: _fixturesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 40,
                            color: AppColors.error,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Failed to load EPL fixtures for matchweek $_selectedMatchday',
                            style: Theme.of(context).textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${snapshot.error}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _refresh,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final fixtures = snapshot.data ?? const <Match>[];
                if (fixtures.isEmpty) {
                  return Center(
                    child: Text(
                      'No fixtures found for matchweek $_selectedMatchday',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _refresh(),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: fixtures.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final match = fixtures[index];
                      return Card(
                        child: ListTile(
                          title: Text(
                            '${match.homeTeamName} vs ${match.awayTeamName}',
                          ),
                          subtitle: Text(
                            '${match.kickoffTime.toLocal()}'.split('.').first,
                          ),
                          trailing:
                              (match.homeScore != null &&
                                  match.awayScore != null)
                              ? Text('${match.homeScore} - ${match.awayScore}')
                              : const Text('vs'),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileTabScreen extends StatefulWidget {
  const ProfileTabScreen({super.key});

  @override
  State<ProfileTabScreen> createState() => _ProfileTabScreenState();
}

class _ProfileTabScreenState extends State<ProfileTabScreen> {
  static const List<String> _eplClubs = <String>[
    'Arsenal',
    'Aston Villa',
    'Bournemouth',
    'Brentford',
    'Brighton',
    'Burnley',
    'Chelsea',
    'Crystal Palace',
    'Everton',
    'Fulham',
    'Leeds United',
    'Liverpool',
    'Manchester City',
    'Manchester United',
    'Newcastle United',
    'Nottingham Forest',
    'Sunderland',
    'Tottenham',
    'West Ham',
    'Wolves',
  ];

  static const List<String> _eplPlayers = <String>[
    'Erling Haaland',
    'Mohamed Salah',
    'Bukayo Saka',
    'Cole Palmer',
    'Son Heung-min',
    'Bruno Fernandes',
    'Alexander Isak',
    'Phil Foden',
    'Ollie Watkins',
    'Declan Rice',
    'Virgil van Dijk',
    'William Saliba',
    'Rodri',
    'Martin Odegaard',
    'Jarrod Bowen',
    'Kaoru Mitoma',
  ];

  String? _favoriteClub;
  Set<String> _favoritePlayers = <String>{};
  bool _prefsReady = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_prefsReady) {
      _loadPreferences();
    }
  }

  String _clubPrefKey(String userId) => 'profile_favorite_club_$userId';
  String _playersPrefKey(String userId) => 'profile_favorite_players_$userId';

  Future<void> _loadPreferences() async {
    final user = context.read<AuthProvider>().user;
    final userId = user?.id ?? 'guest';
    final prefs = await SharedPreferences.getInstance();

    final club = prefs.getString(_clubPrefKey(userId));
    final players = prefs.getStringList(_playersPrefKey(userId)) ?? <String>[];

    if (!mounted) return;
    setState(() {
      _favoriteClub = club;
      _favoritePlayers = players.toSet();
      _prefsReady = true;
    });
  }

  Future<void> _savePreferences() async {
    final user = context.read<AuthProvider>().user;
    final userId = user?.id ?? 'guest';
    final prefs = await SharedPreferences.getInstance();

    if (_favoriteClub == null || _favoriteClub!.isEmpty) {
      await prefs.remove(_clubPrefKey(userId));
    } else {
      await prefs.setString(_clubPrefKey(userId), _favoriteClub!);
    }

    await prefs.setStringList(
      _playersPrefKey(userId),
      _favoritePlayers.toList()..sort(),
    );
  }

  Future<void> _toggleFavoritePlayer(String player) async {
    setState(() {
      if (_favoritePlayers.contains(player)) {
        _favoritePlayers.remove(player);
      } else {
        _favoritePlayers.add(player);
      }
    });
    await _savePreferences();
  }

  Future<void> _selectFavoriteClub(String club) async {
    setState(() {
      _favoriteClub = _favoriteClub == club ? null : club;
    });
    await _savePreferences();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final team = context.watch<TeamProvider>().team;
    final hasOpsProvider = _hasProvider<OpsDashboardProvider>(context);
    final hasAnalyticsProvider = _hasProvider<TeamAnalyticsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.profile),
        backgroundColor: AppColors.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: user?.photoUrl != null
                        ? NetworkImage(user!.photoUrl!)
                        : null,
                    child: user?.photoUrl == null
                        ? const Icon(Icons.person, size: 50)
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.displayName ?? 'User',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user?.email ?? '',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Favorite EPL Club',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (!_prefsReady)
              const LinearProgressIndicator(minHeight: 2)
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _eplClubs
                    .map(
                      (club) => ChoiceChip(
                        label: Text(club),
                        selected: _favoriteClub == club,
                        onSelected: (_) => _selectFavoriteClub(club),
                        selectedColor: AppColors.primary.withValues(alpha: 0.2),
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: 24),
            Text(
              'Favorite EPL Players',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose as many as you want.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            if (!_prefsReady)
              const LinearProgressIndicator(minHeight: 2)
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _eplPlayers
                    .map(
                      (player) => FilterChip(
                        label: Text(player),
                        selected: _favoritePlayers.contains(player),
                        onSelected: (_) => _toggleFavoritePlayer(player),
                        selectedColor: AppColors.secondary.withValues(
                          alpha: 0.3,
                        ),
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: 28),
            if (_prefsReady)
              Text(
                'Selected club: ${_favoriteClub ?? 'None'}\nSelected players: ${_favoritePlayers.isEmpty ? 'None' : _favoritePlayers.length}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Advanced Tools',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ops and analytics features are available when Supabase is initialized.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: hasOpsProvider
                          ? () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const OpsAdminScreen(),
                                ),
                              );
                            }
                          : null,
                      icon: const Icon(Icons.monitor_heart_outlined),
                      label: const Text('Open Ops Dashboard'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: hasAnalyticsProvider && team != null
                          ? () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      TeamAnalyticsScreen(team: team),
                                ),
                              );
                            }
                          : null,
                      icon: const Icon(Icons.analytics_outlined),
                      label: const Text('Open Team Analytics'),
                    ),
                    if (team == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Create or load your team first to view team analytics.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            CustomButton(
              text: AppStrings.logout,
              onPressed: () async {
                await context.read<AuthProvider>().signOut();
                if (context.mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                }
              },
              backgroundColor: AppColors.error,
            ),
          ],
        ),
      ),
    );
  }

  bool _hasProvider<T>(BuildContext context) {
    try {
      context.read<T>();
      return true;
    } catch (_) {
      return false;
    }
  }
}
