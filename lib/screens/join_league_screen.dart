import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/league_service.dart';

enum JoinLeagueMode { publicLeague, privateLeague }

class JoinLeagueScreen extends StatefulWidget {
  const JoinLeagueScreen({super.key});

  @override
  State<JoinLeagueScreen> createState() => _JoinLeagueScreenState();
}

class _JoinLeagueScreenState extends State<JoinLeagueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _leagueCodeController = TextEditingController();
  final LeagueService _leagueService =
      LeagueService(ApiService(AuthService()));

  JoinLeagueMode _selectedMode = JoinLeagueMode.publicLeague;
  String? _selectedPublicLeague;
  bool _isSubmitting = false;

  final List<String> _publicLeagueOptions = const [
    'Global League',
    'Top Scorers League',
    'Weekend Warriors League',
  ];

  @override
  void initState() {
    super.initState();
    _selectedPublicLeague = _publicLeagueOptions.first;
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

    try {
      if (_selectedMode == JoinLeagueMode.privateLeague) {
        await _leagueService.joinLeague(_leagueCodeController.text.trim());
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Joined private league successfully')),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Joined ${_selectedPublicLeague ?? 'public league'}'),
          ),
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
                DropdownButtonFormField<String>(
                  value: _selectedPublicLeague,
                  decoration: const InputDecoration(
                    labelText: 'Select Public League',
                    border: OutlineInputBorder(),
                  ),
                  items: _publicLeagueOptions
                      .map(
                        (league) => DropdownMenuItem(
                          value: league,
                          child: Text(league),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() => _selectedPublicLeague = value);
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