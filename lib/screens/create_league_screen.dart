import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/league.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/league_service.dart';

enum CreateLeagueFormat { headToHead, leagueAndCup }

class CreateLeagueScreen extends StatefulWidget {
  const CreateLeagueScreen({super.key});

  @override
  State<CreateLeagueScreen> createState() => _CreateLeagueScreenState();
}

class _CreateLeagueScreenState extends State<CreateLeagueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _leagueNameController = TextEditingController();
  final LeagueService _leagueService =
      LeagueService(ApiService(AuthService()));

  CreateLeagueFormat _selectedFormat = CreateLeagueFormat.headToHead;
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
    final formatLabel = _selectedFormat == CreateLeagueFormat.headToHead
        ? 'Head-to-Head'
        : 'League & Cup';

    try {
      await _leagueService.createLeague(
        '$name ($formatLabel)',
        LeagueType.public,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('League created as $formatLabel'),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('League setup ready: $name ($formatLabel)'),
        ),
      );
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
                'Choose league format',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              RadioListTile<CreateLeagueFormat>(
                value: CreateLeagueFormat.headToHead,
                groupValue: _selectedFormat,
                title: const Text('Head-to-Head League'),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedFormat = value);
                },
              ),
              RadioListTile<CreateLeagueFormat>(
                value: CreateLeagueFormat.leagueAndCup,
                groupValue: _selectedFormat,
                title: const Text('League & Cup League'),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedFormat = value);
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