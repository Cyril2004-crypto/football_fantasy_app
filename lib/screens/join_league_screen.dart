import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../services/auth_service.dart';
import '../models/league.dart';
import '../services/league_service.dart';
import '../providers/team_provider.dart';

enum JoinLeagueMode { publicLeague, privateLeague }

class JoinLeagueScreen extends StatefulWidget {
  const JoinLeagueScreen({super.key});

  @override
  State<JoinLeagueScreen> createState() => _JoinLeagueScreenState();
}

class _JoinLeagueScreenState extends State<JoinLeagueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _leagueCodeController = TextEditingController();
  final LeagueService _leagueService = LeagueService(AuthService());

  JoinLeagueMode _selectedMode = JoinLeagueMode.publicLeague;
  League? _selectedPublicLeague;
  bool _isSubmitting = false;
  late Future<List<League>> _publicLeaguesFuture;

  @override
  void initState() {
    super.initState();
    _publicLeaguesFuture = _leagueService.getPublicLeagues();
  }

  @override
  void dispose() {
    _leagueCodeController.dispose();
    super.dispose();
  }

  Future<void> _joinLeague() async {
    if (_selectedMode == JoinLeagueMode.privateLeague &&
        !_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);
    final team = context.read<TeamProvider>().team;

    try {
      if (_selectedMode == JoinLeagueMode.privateLeague) {
        await _leagueService.joinLeague(
          leagueCode: _leagueCodeController.text.trim(),
          team: team,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Joined private league successfully')),
        );
      } else {
        final league = _selectedPublicLeague;
        if (league == null) {
          throw Exception('Please select a public league');
        }

        await _leagueService.joinLeague(
          leagueId: league.id,
          team: team,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Joined ${league.name}')),
        );
      }

      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to join right now. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join League'),
        backgroundColor: AppColors.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose league type',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              RadioListTile<JoinLeagueMode>(
                value: JoinLeagueMode.publicLeague,
                groupValue: _selectedMode,
                title: const Text('Public League'),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedMode = value);
                },
              ),
              RadioListTile<JoinLeagueMode>(
                value: JoinLeagueMode.privateLeague,
                groupValue: _selectedMode,
                title: const Text('Private League'),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedMode = value);
                },
              ),
              const SizedBox(height: 12),
              if (_selectedMode == JoinLeagueMode.publicLeague)
                FutureBuilder<List<League>>(
                  future: _publicLeaguesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: LinearProgressIndicator(),
                      );
                    }

                    final leagues = snapshot.data ?? [];
                    if (leagues.isEmpty) {
                      return const Text('No public leagues available yet.');
                    }

                    _selectedPublicLeague ??= leagues.first;

                    return DropdownButtonFormField<League>(
                      value: _selectedPublicLeague,
                      decoration: const InputDecoration(
                        labelText: 'Select Public League',
                        border: OutlineInputBorder(),
                      ),
                      items: leagues
                          .map(
                            (league) => DropdownMenuItem(
                              value: league,
                              child: Text('${league.name} • ${league.membersCount} members'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() => _selectedPublicLeague = value);
                      },
                    );
                  },
                )
              else
                TextFormField(
                  controller: _leagueCodeController,
                  decoration: const InputDecoration(
                    labelText: 'Private League Code',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (_selectedMode != JoinLeagueMode.privateLeague) {
                      return null;
                    }
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a league code';
                    }
                    return null;
                  },
                ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _joinLeague,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Join League'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}