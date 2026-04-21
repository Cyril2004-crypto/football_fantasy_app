import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../providers/team_provider.dart';
import '../providers/ops_dashboard_provider.dart';
import '../providers/team_analytics_provider.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/league_service.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../models/league.dart';
import '../models/match.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../services/match_service.dart';
import '../services/sportmonks_service.dart';
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
import 'fixture_details_screen.dart';

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

class HomeTabScreen extends StatefulWidget {
  const HomeTabScreen({super.key});

  @override
  State<HomeTabScreen> createState() => _HomeTabScreenState();
}

class _HomeTabScreenState extends State<HomeTabScreen> {
  late Future<List<Match>> _matchesFuture;
  final MatchService _matchService = MatchService();
  static const int _competitionId = 2021;
  int _selectedMatchday = 1;
  final Map<int, List<Match>> _matchesCache = <int, List<Match>>{};

  @override
  void initState() {
    super.initState();
    _matchesFuture = _loadMatches();
  }

  Future<List<Match>> _loadMatches() {
    final cached = _matchesCache[_selectedMatchday];
    if (cached != null) {
      return Future<List<Match>>.value(cached);
    }

    return _matchService
        .getPremierLeagueMatchesByMatchday(
          _selectedMatchday,
          competitionId: _competitionId,
        )
        .then((matches) {
          _matchesCache[_selectedMatchday] = matches;
          return matches;
        });
  }

  void _onMatchdayChanged(int value) {
    if (value == _selectedMatchday) {
      return;
    }

    setState(() {
      _selectedMatchday = value;
      _matchesFuture = _loadMatches();
    });
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Gameweek Matches',
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          'GW $_selectedMatchday',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.primary,
                      thumbColor: AppColors.primary,
                      inactiveTrackColor: AppColors.divider,
                      overlayColor: AppColors.primary.withValues(alpha: 0.12),
                      trackHeight: 4,
                    ),
                    child: Slider(
                      min: 1,
                      max: 38,
                      divisions: 37,
                      label: 'GW $_selectedMatchday',
                      value: _selectedMatchday.toDouble(),
                      onChanged: (value) {
                        _onMatchdayChanged(value.round());
                      },
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

                      final matches = snapshot.data!;
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
                  const SizedBox(height: 4),
                  Text(
                    _buildInsightSubtitle(displayName, team),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._buildInsightCards(context, team, displayName),
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

  String _buildInsightSubtitle(String? displayName, Team? team) {
    final hour = DateTime.now().hour;
    final timeLabel = hour < 12
        ? 'morning'
        : hour < 18
            ? 'afternoon'
            : 'evening';

    if (team == null) {
      return '${displayName != null ? 'Hi $displayName,' : 'Hi there,'} your $timeLabel checklist is to build a squad and keep an eye on live form.';
    }

    return '${displayName != null ? 'Hi $displayName,' : 'Hi there,'} here is what matters for ${team.name} right now.';
  }

  List<Widget> _buildInsightCards(
    BuildContext context,
    Team? team,
    String? displayName,
  ) {
    final insights = _generateInsightCards(team: team, displayName: displayName);

    return [
      for (var i = 0; i < insights.length; i++) ...[
        _buildTipCard(
          context,
          insights[i].title,
          insights[i].description,
          insights[i].color,
        ),
        if (i < insights.length - 1) const SizedBox(height: 8),
      ],
    ];
  }

  List<_InsightCardData> _generateInsightCards({
    required Team? team,
    required String? displayName,
  }) {
    final now = DateTime.now();
    final cards = <_InsightCardData>[];

    cards.add(_timeAwareCard(now));

    if (team == null || team.players.isEmpty) {
      cards.add(
        _InsightCardData(
          title: '🧩 Build Your Core',
          description:
              'Create a balanced squad first — a steady base makes later upgrades much easier.',
          color: AppColors.primary,
        ),
      );
      cards.add(
        _InsightCardData(
          title: '⭐ Watch Form Early',
          description:
              'When you do pick your first players, start with high-form options rather than chasing last week only.',
          color: AppColors.success,
        ),
      );
      return cards;
    }

    final topPlayer = _topPlayerByScore(team.players);
    final injuredCount = team.players.where((p) => p.isInjured).length;
    final suspendedCount = team.players.where((p) => p.isSuspended).length;
    final forwardCount = team.players
        .where((p) => p.position == PlayerPosition.forward)
        .length;
    final averageForm = team.players.isEmpty
        ? 0.0
        : team.players.fold<double>(0, (sum, p) => sum + p.form) /
            team.players.length;

    cards.add(
      _InsightCardData(
        title: '📈 ${team.name} snapshot',
        description:
            'You are on ${team.totalPoints} total points with £${team.remainingBudget.toStringAsFixed(1)}m in the bank.',
        color: AppColors.primary,
      ),
    );

    if (topPlayer != null) {
      cards.add(
        _InsightCardData(
          title: '🌟 ${topPlayer.name} is leading',
          description:
              '${topPlayer.clubName}’s ${topPlayer.position.name} has ${topPlayer.points} total points and ${topPlayer.gameweekPoints} this gameweek.',
          color: AppColors.success,
        ),
      );
    }

    if (injuredCount + suspendedCount > 0) {
      cards.add(
        _InsightCardData(
          title: '🛡️ Availability check',
          description:
              '$injuredCount injured and $suspendedCount suspended players are in your squad — review them before the deadline.',
          color: AppColors.warning,
        ),
      );
    } else {
      cards.add(
        _InsightCardData(
          title: '✅ Availability looks clean',
          description:
              'No injured or suspended players detected, so your squad is currently low-risk for the next deadline.',
          color: AppColors.success,
        ),
      );
    }

    if (team.remainingBudget <= 2.0) {
      cards.add(
        _InsightCardData(
          title: '💷 Budget is tight',
          description:
              'With only £${team.remainingBudget.toStringAsFixed(1)}m left, prioritise one-for-one upgrades over a full restructure.',
          color: AppColors.accent,
        ),
      );
    } else {
      cards.add(
        _InsightCardData(
          title: '🔁 You have room to move',
          description:
              'Your bank gives you flexibility, so you can target value picks without breaking the rest of the squad.',
          color: AppColors.info,
        ),
      );
    }

    if (forwardCount < 2) {
      cards.add(
        _InsightCardData(
          title: '🎯 Forward line is light',
          description:
              'You only have $forwardCount forward${forwardCount == 1 ? '' : 's'} right now, so it may be worth checking attacking upside.',
          color: Colors.orange,
        ),
      );
    }

    if (averageForm >= 6.5) {
      cards.add(
        _InsightCardData(
          title: '🔥 Team form is healthy',
          description:
              'Your squad’s average form is ${averageForm.toStringAsFixed(1)}, which suggests holding steady could be the smart move.',
          color: AppColors.success,
        ),
      );
    }

    return cards.take(4).toList();
  }

  _InsightCardData _timeAwareCard(DateTime now) {
    if (now.weekday == DateTime.friday || now.weekday == DateTime.saturday) {
      return _InsightCardData(
        title: '⏰ Deadline mode',
        description:
            'It’s close to the weekend window, so double-check captaincy, injuries, and bench order before locking in moves.',
        color: AppColors.warning,
      );
    }

    if (now.hour < 12) {
      return _InsightCardData(
        title: '☀️ Morning reset',
        description:
            'Use the quieter start of the day to review transfers and confirm no last-minute team news has changed.',
        color: AppColors.primary,
      );
    }

    if (now.hour < 18) {
      return _InsightCardData(
        title: '📊 Afternoon check-in',
        description:
            'This is a good time to compare form and fixtures, especially if you’re planning one transfer rather than a full rebuild.',
        color: AppColors.info,
      );
    }

    return _InsightCardData(
      title: '🌙 Evening watchlist',
      description:
          'Before the day ends, scan for injuries, suspensions, and any live match momentum that affects your next move.',
      color: AppColors.accent,
    );
  }

  Player? _topPlayerByScore(List<Player> players) {
    if (players.isEmpty) return null;

    final sorted = [...players]..sort((a, b) {
      final pointsComparison = b.points.compareTo(a.points);
      if (pointsComparison != 0) return pointsComparison;
      return b.gameweekPoints.compareTo(a.gameweekPoints);
    });
    return sorted.first;
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

class _InsightCardData {
  final String title;
  final String description;
  final Color color;

  const _InsightCardData({
    required this.title,
    required this.description,
    required this.color,
  });
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
  final SportmonksService _sportmonksService = SportmonksService(
    ApiService(AuthService()),
  );
  late Future<List<Match>> _fixturesFuture;
  int _selectedMatchday = 1;
  static const int _competitionId = 2021;
  final Map<int, List<Match>> _fixturesCache = <int, List<Match>>{};
  final Map<String, List<Map<String, dynamic>>> _sportmonksDateCache =
      <String, List<Map<String, dynamic>>>{};

  @override
  void initState() {
    super.initState();
    _matchService = MatchService();
    _fixturesFuture = _loadFixtures();
  }

  Future<List<Match>> _loadFixtures() async {
    final cached = _fixturesCache[_selectedMatchday];
    if (cached != null) {
      return Future<List<Match>>.value(cached);
    }

    final matches = await _matchService.getPremierLeagueMatchesByMatchday(
      _selectedMatchday,
      competitionId: _competitionId,
    );
    final enriched = await _enrichFixturesFromSportmonks(matches);
    _fixturesCache[_selectedMatchday] = enriched;
    return enriched;
  }

  Future<List<Match>> _enrichFixturesFromSportmonks(List<Match> matches) async {
    if (matches.isEmpty) return const <Match>[];

    final dateKeys = <String>{};
    for (final match in matches) {
      for (final dt in _candidateDates(match.kickoffTime.toUtc())) {
        dateKeys.add(_formatDate(dt));
      }
    }

    for (final date in dateKeys) {
      if (_sportmonksDateCache.containsKey(date)) {
        continue;
      }

      try {
        final response = await _sportmonksService.getFixturesByDate(date);
        final rows = response['data'] is List
            ? response['data'] as List<dynamic>
            : const <dynamic>[];
        _sportmonksDateCache[date] = rows
            .whereType<Map<String, dynamic>>()
            .toList();
      } catch (_) {
        _sportmonksDateCache[date] = const <Map<String, dynamic>>[];
      }
    }

    return matches.map((match) {
      final row = _findSportmonksFixtureForMatch(match);
      if (row == null) {
        return match;
      }

      final status = _statusFromSportmonksRow(row, fallback: match.status);
      final score = _scoreFromSportmonksRow(row);

      return Match(
        id: match.id,
        homeTeamId: match.homeTeamId,
        homeTeamName: match.homeTeamName,
        homeTeamBadge: match.homeTeamBadge,
        awayTeamId: match.awayTeamId,
        awayTeamName: match.awayTeamName,
        awayTeamBadge: match.awayTeamBadge,
        homeScore: score.$1 ?? match.homeScore,
        awayScore: score.$2 ?? match.awayScore,
        status: status,
        kickoffTime: match.kickoffTime,
        gameweek: match.gameweek,
        venue: match.venue,
      );
    }).toList();
  }

  Map<String, dynamic>? _findSportmonksFixtureForMatch(Match match) {
    final wantedHome = _normalizeTeamName(match.homeTeamName);
    final wantedAway = _normalizeTeamName(match.awayTeamName);
    final kickoffUtc = match.kickoffTime.toUtc();

    Map<String, dynamic>? best;
    int bestScore = -1;

    for (final dt in _candidateDates(kickoffUtc)) {
      final date = _formatDate(dt);
      final rows = _sportmonksDateCache[date] ?? const <Map<String, dynamic>>[];

      for (final row in rows) {
        final teams = _extractHomeAwayTeamNames(row);
        if (teams == null) {
          continue;
        }

        final home = _normalizeTeamName(teams.$1);
        final away = _normalizeTeamName(teams.$2);

        int score = 0;
        if (home == wantedHome && away == wantedAway) {
          score += 4;
        } else if (home == wantedAway && away == wantedHome) {
          score += 2;
        } else {
          final homeLikely = _isLikelySameTeam(home, wantedHome);
          final awayLikely = _isLikelySameTeam(away, wantedAway);
          if (homeLikely && awayLikely) {
            score += 2;
          } else {
            continue;
          }
        }

        final rowKickoff = _readString(row, const ['starting_at', 'starting_at_timestamp']);
        final parsedKickoff = rowKickoff == null ? null : DateTime.tryParse(rowKickoff);
        if (parsedKickoff != null) {
          final diff = parsedKickoff.toUtc().difference(kickoffUtc).inHours.abs();
          if (diff <= 3) {
            score += 3;
          } else if (diff <= 12) {
            score += 1;
          }
        }

        if (score > bestScore) {
          bestScore = score;
          best = row;
        }
      }
    }

    return best;
  }

  (int?, int?) _scoreFromSportmonksRow(Map<String, dynamic> row) {
    final participants = row['participants'] is List
        ? row['participants'] as List<dynamic>
        : const <dynamic>[];

    final homeParticipantId = participants.isNotEmpty
        ? _readString(participants.first, const ['id'])
        : null;
    final awayParticipantId = participants.length > 1
        ? _readString(participants[1], const ['id'])
        : null;

    final scores = row['scores'] is List
        ? row['scores'] as List<dynamic>
        : const <dynamic>[];

    int? homeScore;
    int? awayScore;
    int bestHomePriority = -1;
    int bestAwayPriority = -1;

    for (final item in scores) {
      if (item is! Map<String, dynamic>) {
        continue;
      }

      final value = _readInt(item, const ['goals', 'score']);
      if (value == null) {
        continue;
      }

      final desc =
          (_readString(item, const ['description', 'type', 'name']) ?? '')
              .toLowerCase();
      final participantId = _readString(item, const ['participant_id']);
      final priority = _scorePriority(desc, item);

      final participantRole = _resolveParticipantRole(
        item,
        participantId: participantId,
        homeParticipantId: homeParticipantId,
        awayParticipantId: awayParticipantId,
      );

      if (participantRole == 'home' ||
          desc.contains('home') ||
          desc.contains('local')) {
        if (priority >= bestHomePriority) {
          bestHomePriority = priority;
          homeScore = value;
        }
      } else if (participantRole == 'away' ||
          desc.contains('away') ||
          desc.contains('visitor')) {
        if (priority >= bestAwayPriority) {
          bestAwayPriority = priority;
          awayScore = value;
        }
      }
    }

    return (homeScore, awayScore);
  }

  MatchStatus _statusFromSportmonksRow(
    Map<String, dynamic> row, {
    required MatchStatus fallback,
  }) {
    final state = row['state'];
    final statusText =
        (_readString(state, const ['short_name', 'state', 'name']) ??
                _readString(row, const ['status']) ??
                '')
            .toLowerCase();

    if (statusText.contains('ft') ||
        statusText.contains('finished') ||
        statusText.contains('fulltime') ||
        statusText.contains('full time')) {
      return MatchStatus.completed;
    }
    if (statusText.contains('live') ||
        statusText.contains('inplay') ||
        statusText.contains('in play') ||
        statusText.contains('ht') ||
        statusText.contains('1h') ||
        statusText.contains('2h')) {
      return MatchStatus.live;
    }
    if (statusText.contains('postponed') ||
        statusText.contains('suspended') ||
        statusText.contains('cancelled')) {
      return MatchStatus.postponed;
    }

    return fallback;
  }

  String? _resolveParticipantRole(
    Map<String, dynamic> scoreMap, {
    required String? participantId,
    required String? homeParticipantId,
    required String? awayParticipantId,
  }) {
    if (participantId != null) {
      if (participantId == homeParticipantId) return 'home';
      if (participantId == awayParticipantId) return 'away';
    }

    final participant = scoreMap['participant'];
    if (participant is Map<String, dynamic>) {
      final location =
          _readString(participant, const ['location', 'type', 'side'])
              ?.toLowerCase();
      if (location == 'home' || location == 'local') return 'home';
      if (location == 'away' || location == 'visitor') return 'away';
    }
    return null;
  }

  int _scorePriority(String description, Map<String, dynamic> scoreMap) {
    if (description.contains('current') ||
        description.contains('live') ||
        description.contains('fulltime') ||
        description.contains('full time')) {
      return 3;
    }
    if (description.contains('2nd') ||
        description.contains('second') ||
        description.contains('1st') ||
        description.contains('first') ||
        description.contains('half')) {
      return 2;
    }

    final typeId = _readInt(scoreMap, const ['type_id']);
    if (typeId != null && typeId >= 1500) {
      return 2;
    }

    return 1;
  }

  (String, String)? _extractHomeAwayTeamNames(Map<String, dynamic> row) {
    final participants = row['participants'] is List
        ? row['participants'] as List<dynamic>
        : const <dynamic>[];
    if (participants.length < 2) {
      return null;
    }

    String? home;
    String? away;
    for (final p in participants) {
      if (p is! Map<String, dynamic>) {
        continue;
      }

      final name = _readString(p, const ['name']);
      if (name == null || name.isEmpty) {
        continue;
      }

      final meta = p['meta'] is Map<String, dynamic>
          ? p['meta'] as Map<String, dynamic>
          : const <String, dynamic>{};
      final location =
          (_readString(meta, const ['location']) ?? '').toLowerCase();

      if (location == 'home' || location == 'local') {
        home = name;
      } else if (location == 'away' || location == 'visitor') {
        away = name;
      }
    }

    if (home != null && away != null) {
      return (home, away);
    }

    final first = _readString(participants[0], const ['name']) ?? '';
    final second = _readString(participants[1], const ['name']) ?? '';
    if (first.isEmpty || second.isEmpty) {
      return null;
    }
    return (first, second);
  }

  bool _isLikelySameTeam(String providerName, String appName) {
    if (providerName == appName) {
      return true;
    }
    if (providerName.contains(appName) || appName.contains(providerName)) {
      return true;
    }

    final providerTokens = providerName
        .split(' ')
        .where((t) => t.isNotEmpty && t.length > 2)
        .toSet();
    final appTokens = appName
        .split(' ')
        .where((t) => t.isNotEmpty && t.length > 2)
        .toSet();
    if (providerTokens.isEmpty || appTokens.isEmpty) {
      return false;
    }

    final overlap = providerTokens.intersection(appTokens).length;
    final minSize = providerTokens.length < appTokens.length
        ? providerTokens.length
        : appTokens.length;
    return overlap >= 1 && overlap * 2 >= minSize;
  }

  String _normalizeTeamName(String value) {
    return value
        .toLowerCase()
        .replaceAll('fc', '')
        .replaceAll('.', '')
        .replaceAll('&', 'and')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<DateTime> _candidateDates(DateTime utcDate) {
    return [
      utcDate.subtract(const Duration(days: 1)),
      utcDate,
      utcDate.add(const Duration(days: 1)),
    ];
  }

  String _formatDate(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  int? _readInt(dynamic source, List<String> keys) {
    if (source is! Map<String, dynamic>) {
      return null;
    }

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

  void _refresh() {
    setState(() {
      _fixturesCache.remove(_selectedMatchday);
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
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.pageGradient),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Text(
                        'Matchweek',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _selectedMatchday,
                          decoration: const InputDecoration(
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
                      final scoreText = (match.homeScore != null && match.awayScore != null)
                          ? '${match.homeScore} - ${match.awayScore}'
                          : 'vs';
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                            child: const Icon(Icons.sports_soccer, color: AppColors.primary),
                          ),
                          title: Text(
                            '${match.homeTeamName} vs ${match.awayTeamName}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${match.kickoffTime.toLocal()}'.split('.').first,
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.mutedLavender,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              scoreText,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => FixtureDetailsScreen(match: match),
                              ),
                            );
                          },
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
