import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_colors.dart';
import '../providers/live_match_provider.dart';
import '../widgets/pitch_painter.dart';

class LiveMatchScreen extends ConsumerStatefulWidget {
  final String fixtureId;
  final String homeTeamName;
  final String awayTeamName;
  final Stream<LiveMatchEvent> eventsStream;
  final DateTime? kickoffTime;
  final int? homeScore;
  final int? awayScore;
  final String? venue;
  final List<String> homePlayerLabels;
  final List<String> awayPlayerLabels;

  const LiveMatchScreen({
    super.key,
    required this.fixtureId,
    required this.homeTeamName,
    required this.awayTeamName,
    required this.eventsStream,
    this.kickoffTime,
    this.homeScore,
    this.awayScore,
    this.venue,
    this.homePlayerLabels = const [],
    this.awayPlayerLabels = const [],
  });

  @override
  ConsumerState<LiveMatchScreen> createState() => _LiveMatchScreenState();
}

class _LiveMatchScreenState extends ConsumerState<LiveMatchScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _passController;
  Timer? _clockTimer;
  String? _lastPassId;
  int _liveMinute = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _passController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    _refreshLiveMinute();
    _clockTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      setState(_refreshLiveMinute);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(liveMatchProvider(widget.fixtureId).notifier);
      notifier
        ..setMatchContext(
          homeTeamName: widget.homeTeamName,
          awayTeamName: widget.awayTeamName,
          homeScore: widget.homeScore,
          awayScore: widget.awayScore,
          venue: widget.venue,
          homePlayerLabels: widget.homePlayerLabels,
          awayPlayerLabels: widget.awayPlayerLabels,
        )
        ..bindEventStream(widget.eventsStream);
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _pulseController.dispose();
    _passController.dispose();
    super.dispose();
  }

  void _refreshLiveMinute() {
    final kickoff = widget.kickoffTime;
    if (kickoff == null) {
      final fallbackMinute = ref
          .read(liveMatchProvider(widget.fixtureId))
          .activeEvent
          ?.minute;
      _liveMinute = fallbackMinute ?? 0;
      return;
    }

    final elapsed = DateTime.now().difference(kickoff).inMinutes;
    _liveMinute = elapsed < 0 ? 0 : elapsed;
  }

  void _triggerPassAnimation(LiveMatchEvent event) {
    final passId = event.passLine?.id;
    if (passId == null || passId == _lastPassId) {
      return;
    }

    _lastPassId = passId;
    _passController
      ..reset()
      ..forward().whenComplete(() {
        if (!mounted) return;
        ref.read(liveMatchProvider(widget.fixtureId).notifier).clearActivePass();
      });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(liveMatchProvider(widget.fixtureId));
    final activeEvent = state.activeEvent;

    if (activeEvent != null && activeEvent.passLine != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _triggerPassAnimation(activeEvent);
        }
      });
    }

    final scoreText = '${state.homeScore ?? widget.homeScore ?? 0} - ${state.awayScore ?? widget.awayScore ?? 0}';
    final minuteText = _liveMinute > 0 ? "$_liveMinute'" : (activeEvent?.minute != null ? "${activeEvent!.minute}'" : "LIVE");

    return Scaffold(
      backgroundColor: const Color(0xFFF7F4FF),
      appBar: AppBar(
        title: const Text('Live Match'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildHeader(context, state, scoreText),
            const SizedBox(height: 16),
            AspectRatio(
              aspectRatio: 1.9,
              child: AnimatedBuilder(
                animation: Listenable.merge([_pulseController, _passController]),
                builder: (context, _) {
                  return CustomPaint(
                    painter: PitchPainter(
                      possessionSide: state.possessionSide,
                      possessionPulse: _pulseController.value,
                      passProgress: _passController.value,
                      homeMarkers: state.homeMarkers,
                      awayMarkers: state.awayMarkers,
                      activePass: state.activePass,
                      highlightEvent: state.activeEvent,
                    ),
                    child: Stack(
                      children: [
                        const SizedBox.expand(),
                        Positioned(
                          top: 16,
                          right: 16,
                          child: _minuteBadge(minuteText),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            _buildTimeline(context, state.recentEvents),
          ],
        ),
      ),
    );
  }

  Widget _minuteBadge(String minuteText) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        minuteText,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    LiveMatchState state,
    String scoreText,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${state.homeTeamName.isEmpty ? widget.homeTeamName : state.homeTeamName} vs ${state.awayTeamName.isEmpty ? widget.awayTeamName : state.awayTeamName}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                _statusChip('LIVE'),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              scoreText,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            if ((state.venue ?? widget.venue) != null) ...[
              const SizedBox(height: 6),
              Text(
                state.venue ?? widget.venue ?? '',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                _possessionPill(
                  context,
                  label: widget.homeTeamName,
                  selected: state.possessionSide == PossessionSide.home,
                  color: const Color(0xFF7C3AED),
                ),
                const SizedBox(width: 8),
                _possessionPill(
                  context,
                  label: widget.awayTeamName,
                  selected: state.possessionSide == PossessionSide.away,
                  color: const Color(0xFF2563EB),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.red,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _possessionPill(
    BuildContext context, {
    required String label,
    required bool selected,
    required Color color,
  }) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.16) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? color : AppColors.divider),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: selected ? color : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              ),
        ),
      ),
    );
  }

  Widget _buildTimeline(BuildContext context, List<LiveMatchEvent> events) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Events',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            if (events.isEmpty)
              Text(
                'Waiting for live events...',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              )
            else
              ...events.map((event) => _eventTile(context, event)),
          ],
        ),
      ),
    );
  }

  Widget _eventTile(BuildContext context, LiveMatchEvent event) {
    final color = _eventColor(event.eventType);
    final icon = _eventIcon(event.eventType);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.type,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: color,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    Text(
                      '${event.minute}\'',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${event.playerName ?? 'Unknown player'}${event.relatedPlayerName == null ? '' : ' (${event.relatedPlayerName})'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (event.commentary != null && event.commentary!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    event.commentary!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _eventColor(LiveMatchEventType type) {
    switch (type) {
      case LiveMatchEventType.goal:
        return Colors.green;
      case LiveMatchEventType.substitution:
        return Colors.blue;
      case LiveMatchEventType.yellowCard:
        return Colors.amber;
      case LiveMatchEventType.redCard:
        return Colors.red;
      case LiveMatchEventType.pass:
        return const Color(0xFF00A3FF);
      case LiveMatchEventType.throwIn:
        return const Color(0xFF8B5CF6);
      case LiveMatchEventType.corner:
        return const Color(0xFFF97316);
      default:
        return AppColors.primary;
    }
  }

  IconData _eventIcon(LiveMatchEventType type) {
    switch (type) {
      case LiveMatchEventType.goal:
        return Icons.sports_soccer;
      case LiveMatchEventType.substitution:
        return Icons.swap_horiz;
      case LiveMatchEventType.yellowCard:
        return Icons.square_outlined;
      case LiveMatchEventType.redCard:
        return Icons.stop_circle_outlined;
      case LiveMatchEventType.pass:
        return Icons.alt_route;
      case LiveMatchEventType.throwIn:
        return Icons.compare_arrows;
      case LiveMatchEventType.corner:
        return Icons.flag_outlined;
      case LiveMatchEventType.varCheck:
        return Icons.videocam_outlined;
      default:
        return Icons.bolt;
    }
  }
}