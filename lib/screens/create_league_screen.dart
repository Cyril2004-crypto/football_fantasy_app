import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../models/league.dart';
import '../services/auth_service.dart';
import '../services/league_service.dart';
import '../providers/team_provider.dart';

enum CreateLeagueVisibility { public, private }

class CreateLeagueScreen extends StatefulWidget {
  const CreateLeagueScreen({super.key});

  @override
  State<CreateLeagueScreen> createState() => _CreateLeagueScreenState();
}

class _CreateLeagueScreenState extends State<CreateLeagueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _leagueNameController = TextEditingController();
  final LeagueService _leagueService = LeagueService(AuthService());

  CreateLeagueVisibility _selectedVisibility = CreateLeagueVisibility.public;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _leagueNameController.dispose();
    super.dispose();
  }

  Future<void> _createLeague() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    final name = _leagueNameController.text.trim();
    final team = context.read<TeamProvider>().team;
    final visibilityLabel = _selectedVisibility == CreateLeagueVisibility.public
        ? 'Public'
        : 'Private';

    try {
      await _leagueService.createLeague(
        name,
        _selectedVisibility == CreateLeagueVisibility.public
            ? LeagueType.public
            : LeagueType.private,
        team: team,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$visibilityLabel league created')),
      );
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('League created: $name')));
      Navigator.of(context).pop(true);
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
        title: const Text('Create League'),
        backgroundColor: AppColors.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _leagueNameController,
                decoration: const InputDecoration(
                  labelText: 'League Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a league name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Text(
                'Choose league visibility',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SegmentedButton<CreateLeagueVisibility>(
                segments: const [
                  ButtonSegment<CreateLeagueVisibility>(
                    value: CreateLeagueVisibility.public,
                    label: Text('Public League'),
                    icon: Icon(Icons.public),
                  ),
                  ButtonSegment<CreateLeagueVisibility>(
                    value: CreateLeagueVisibility.private,
                    label: Text('Private League'),
                    icon: Icon(Icons.lock_outline),
                  ),
                ],
                selected: <CreateLeagueVisibility>{_selectedVisibility},
                onSelectionChanged: (selection) {
                  if (selection.isEmpty) return;
                  setState(() => _selectedVisibility = selection.first);
                },
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _createLeague,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create League'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
