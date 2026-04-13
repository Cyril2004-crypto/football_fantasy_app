import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../models/match.dart';
import '../services/match_service.dart';
import '../widgets/custom_button.dart';
import 'login_screen.dart';
import 'team_status_screen.dart';

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
      body: _screens[_currentIndex],
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
class HomeTabScreen extends StatelessWidget {
  const HomeTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.home),
        backgroundColor: AppColors.primary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Welcome, ${user?.displayName ?? user?.email ?? 'User'}!',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            Text(
              'Home Screen - Coming Soon',
              style: Theme.of(context).textTheme.titleLarge,
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
      body: const Center(
        child: Text('My Team - Coming Soon'),
      ),
    );
  }
}

class LeaguesTabScreen extends StatelessWidget {
  const LeaguesTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.leagues),
        backgroundColor: AppColors.primary,
      ),
      body: const Center(
        child: Text('Leagues - Coming Soon'),
      ),
    );
  }
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

    return _matchService.getPremierLeagueMatchesByMatchday(
      _selectedMatchday,
      competitionId: _competitionId,
    ).then((matches) {
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
                    value: _selectedMatchday,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                          const Icon(Icons.error_outline, size: 40, color: AppColors.error),
                          const SizedBox(height: 12),
                          Text(
                            'Failed to load EPL fixtures for matchweek $_selectedMatchday',
                            style: Theme.of(context).textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${snapshot.error}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
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
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final match = fixtures[index];
                      return Card(
                        child: ListTile(
                          title: Text('${match.homeTeamName} vs ${match.awayTeamName}'),
                          subtitle: Text(
                            '${match.kickoffTime.toLocal()}'.split('.').first,
                          ),
                          trailing: (match.homeScore != null && match.awayScore != null)
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

class ProfileTabScreen extends StatelessWidget {
  const ProfileTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.profile),
        backgroundColor: AppColors.primary,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
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
              const SizedBox(height: 48),
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
      ),
    );
  }
}
