import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../models/league.dart';
import '../services/auth_service.dart';
import '../services/league_service.dart';

class LeagueDetailsScreen extends StatefulWidget {
  final League league;

  const LeagueDetailsScreen({super.key, required this.league});

  @override
  State<LeagueDetailsScreen> createState() => _LeagueDetailsScreenState();
}

class _LeagueDetailsScreenState extends State<LeagueDetailsScreen> {
  late final LeagueService _leagueService;
  late Future<List<LeagueStanding>> _standingsFuture;

  @override
  void initState() {
    super.initState();
    _leagueService = LeagueService(AuthService());
    _standingsFuture = _leagueService.getLeagueStandings(widget.league.id);
  }

  void _refresh() {
    setState(() {
      _standingsFuture = _leagueService.getLeagueStandings(widget.league.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.league.name),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<List<LeagueStanding>>(
        future: _standingsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Failed to load standings: ${snapshot.error}',
                  style: const TextStyle(color: AppColors.error),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final standings = snapshot.data ?? const <LeagueStanding>[];
          if (standings.isEmpty) {
            return const Center(
              child: Text('No standings available yet.'),
            );
          }

          return Column(
            children: [
              _LeagueSummaryCard(league: widget.league),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  itemCount: standings.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final standing = standings[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _rankColor(standing.rank),
                          child: Text(
                            '${standing.rank}',
                            style: const TextStyle(
                              color: AppColors.textLight,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          standing.teamName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(standing.userName),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${standing.totalPoints} pts',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'GW: ${standing.gameweekPoints}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _rankColor(int rank) {
    if (rank == 1) return const Color(0xFFFFB300);
    if (rank == 2) return const Color(0xFF90A4AE);
    if (rank == 3) return const Color(0xFF8D6E63);
    return AppColors.primary;
  }
}

class _LeagueSummaryCard extends StatelessWidget {
  final League league;

  const _LeagueSummaryCard({required this.league});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            league.name,
            style: const TextStyle(
              color: AppColors.textLight,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Members: ${league.membersCount}',
            style: const TextStyle(color: AppColors.textLight),
          ),
          if (league.code != null) ...[
            const SizedBox(height: 4),
            Text(
              'Code: ${league.code}',
              style: const TextStyle(color: AppColors.textLight),
            ),
          ],
        ],
      ),
    );
  }
}


