import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum PossessionSide { home, away, neutral }

enum LiveMatchEventType {
  pass,
  goal,
  substitution,
  yellowCard,
  redCard,
  throwIn,
  corner,
  shot,
  foul,
  varCheck,
  possessionChange,
  unknown,
}

class PitchPlayerMarker {
  final String id;
  final String label;
  final Offset position;
  final Color color;

  const PitchPlayerMarker({
    required this.id,
    required this.label,
    required this.position,
    required this.color,
  });
}

class PitchPassLine {
  final String id;
  final Offset from;
  final Offset to;
  final Color color;
  final LiveMatchEventType type;

  const PitchPassLine({
    required this.id,
    required this.from,
    required this.to,
    required this.color,
    required this.type,
  });
}

class LiveMatchEvent {
  final String id;
  final DateTime timestamp;
  final int minute;
  final String type;
  final LiveMatchEventType eventType;
  final String teamName;
  final String? playerName;
  final String? relatedPlayerName;
  final String? commentary;
  final PossessionSide possessionSide;
  final PitchPassLine? passLine;

  const LiveMatchEvent({
    required this.id,
    required this.timestamp,
    required this.minute,
    required this.type,
    required this.eventType,
    required this.teamName,
    required this.playerName,
    required this.relatedPlayerName,
    required this.commentary,
    required this.possessionSide,
    required this.passLine,
  });

  bool get isGoal => eventType == LiveMatchEventType.goal;
  bool get isPass => eventType == LiveMatchEventType.pass;

  LiveMatchEvent copyWith({
    String? id,
    DateTime? timestamp,
    int? minute,
    String? type,
    LiveMatchEventType? eventType,
    String? teamName,
    String? playerName,
    String? relatedPlayerName,
    String? commentary,
    PossessionSide? possessionSide,
    PitchPassLine? passLine,
  }) {
    return LiveMatchEvent(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      minute: minute ?? this.minute,
      type: type ?? this.type,
      eventType: eventType ?? this.eventType,
      teamName: teamName ?? this.teamName,
      playerName: playerName ?? this.playerName,
      relatedPlayerName: relatedPlayerName ?? this.relatedPlayerName,
      commentary: commentary ?? this.commentary,
      possessionSide: possessionSide ?? this.possessionSide,
      passLine: passLine ?? this.passLine,
    );
  }
}

class LiveMatchState {
  final String fixtureId;
  final String homeTeamName;
  final String awayTeamName;
  final int? homeScore;
  final int? awayScore;
  final String? venue;
  final PossessionSide possessionSide;
  final List<PitchPlayerMarker> homeMarkers;
  final List<PitchPlayerMarker> awayMarkers;
  final PitchPassLine? activePass;
  final LiveMatchEvent? activeEvent;
  final List<LiveMatchEvent> recentEvents;
  final bool isLoading;
  final String? errorMessage;
  final DateTime? lastUpdated;

  const LiveMatchState({
    required this.fixtureId,
    required this.homeTeamName,
    required this.awayTeamName,
    required this.homeScore,
    required this.awayScore,
    required this.venue,
    required this.possessionSide,
    required this.homeMarkers,
    required this.awayMarkers,
    required this.activePass,
    required this.activeEvent,
    required this.recentEvents,
    required this.isLoading,
    required this.errorMessage,
    required this.lastUpdated,
  });

  factory LiveMatchState.initial(String fixtureId) {
    return LiveMatchState(
      fixtureId: fixtureId,
      homeTeamName: '',
      awayTeamName: '',
      homeScore: null,
      awayScore: null,
      venue: null,
      possessionSide: PossessionSide.neutral,
      homeMarkers: _buildMarkers(
        teamName: 'home',
        labels: const [],
        isHome: true,
      ),
      awayMarkers: _buildMarkers(
        teamName: 'away',
        labels: const [],
        isHome: false,
      ),
      activePass: null,
      activeEvent: null,
      recentEvents: const [],
      isLoading: true,
      errorMessage: null,
      lastUpdated: null,
    );
  }

  LiveMatchState copyWith({
    String? fixtureId,
    String? homeTeamName,
    String? awayTeamName,
    int? homeScore,
    int? awayScore,
    String? venue,
    PossessionSide? possessionSide,
    List<PitchPlayerMarker>? homeMarkers,
    List<PitchPlayerMarker>? awayMarkers,
    PitchPassLine? activePass,
    bool clearActivePass = false,
    LiveMatchEvent? activeEvent,
    bool clearActiveEvent = false,
    List<LiveMatchEvent>? recentEvents,
    bool? isLoading,
    String? errorMessage,
    DateTime? lastUpdated,
  }) {
    return LiveMatchState(
      fixtureId: fixtureId ?? this.fixtureId,
      homeTeamName: homeTeamName ?? this.homeTeamName,
      awayTeamName: awayTeamName ?? this.awayTeamName,
      homeScore: homeScore ?? this.homeScore,
      awayScore: awayScore ?? this.awayScore,
      venue: venue ?? this.venue,
      possessionSide: possessionSide ?? this.possessionSide,
      homeMarkers: homeMarkers ?? this.homeMarkers,
      awayMarkers: awayMarkers ?? this.awayMarkers,
      activePass: clearActivePass ? null : activePass ?? this.activePass,
      activeEvent: clearActiveEvent ? null : activeEvent ?? this.activeEvent,
      recentEvents: recentEvents ?? this.recentEvents,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

final liveMatchProvider = StateNotifierProvider.autoDispose
    .family<LiveMatchNotifier, LiveMatchState, String>((ref, fixtureId) {
      return LiveMatchNotifier(fixtureId: fixtureId);
    });

class LiveMatchNotifier extends StateNotifier<LiveMatchState> {
  final String fixtureId;
  StreamSubscription<LiveMatchEvent>? _subscription;

  LiveMatchNotifier({required this.fixtureId})
    : super(LiveMatchState.initial(fixtureId));

  void setMatchContext({
    required String homeTeamName,
    required String awayTeamName,
    int? homeScore,
    int? awayScore,
    String? venue,
    List<String> homePlayerLabels = const [],
    List<String> awayPlayerLabels = const [],
  }) {
    state = state.copyWith(
      homeTeamName: homeTeamName,
      awayTeamName: awayTeamName,
      homeScore: homeScore,
      awayScore: awayScore,
      venue: venue,
      homeMarkers: _buildMarkers(
        teamName: homeTeamName,
        labels: homePlayerLabels,
        isHome: true,
      ),
      awayMarkers: _buildMarkers(
        teamName: awayTeamName,
        labels: awayPlayerLabels,
        isHome: false,
      ),
      clearActivePass: true,
      clearActiveEvent: false,
      isLoading: false,
      lastUpdated: DateTime.now(),
    );
  }

  void bindEventStream(Stream<LiveMatchEvent> events) {
    _subscription?.cancel();
    state = state.copyWith(isLoading: false);
    _subscription = events.listen(
      _handleEvent,
      onError: (Object error, StackTrace stackTrace) {
        state = state.copyWith(
          errorMessage: error.toString(),
          isLoading: false,
        );
      },
    );
  }

  void clearActivePass() {
    state = state.copyWith(activePass: null);
  }

  void _handleEvent(LiveMatchEvent event) {
    final updatedEvents = <LiveMatchEvent>[event, ...state.recentEvents];
    state = state.copyWith(
      possessionSide: _resolvePossessionSide(event.teamName),
      activeEvent: event,
      activePass: event.passLine,
      recentEvents: updatedEvents.take(20).toList(),
      isLoading: false,
      errorMessage: null,
      lastUpdated: DateTime.now(),
    );
  }

  PossessionSide _resolvePossessionSide(String teamName) {
    final normalizedTeam = teamName.trim().toLowerCase();
    final normalizedHome = state.homeTeamName.trim().toLowerCase();
    final normalizedAway = state.awayTeamName.trim().toLowerCase();

    if (normalizedTeam.isNotEmpty && normalizedTeam == normalizedHome) {
      return PossessionSide.home;
    }

    if (normalizedTeam.isNotEmpty && normalizedTeam == normalizedAway) {
      return PossessionSide.away;
    }

    return state.possessionSide == PossessionSide.home
        ? PossessionSide.away
        : PossessionSide.home;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

List<PitchPlayerMarker> _buildMarkers({
  required String teamName,
  required List<String> labels,
  required bool isHome,
}) {
  final normalizedLabels = List<String>.generate(
    11,
    (index) => index < labels.length && labels[index].trim().isNotEmpty
        ? labels[index].trim()
        : '${index + 1}',
  );

  final positions = isHome
      ? const [
          Offset(0.10, 0.50),
          Offset(0.20, 0.18),
          Offset(0.22, 0.36),
          Offset(0.22, 0.64),
          Offset(0.20, 0.82),
          Offset(0.40, 0.22),
          Offset(0.42, 0.50),
          Offset(0.40, 0.78),
          Offset(0.62, 0.32),
          Offset(0.68, 0.50),
          Offset(0.62, 0.68),
        ]
      : const [
          Offset(0.90, 0.50),
          Offset(0.80, 0.18),
          Offset(0.78, 0.36),
          Offset(0.78, 0.64),
          Offset(0.80, 0.82),
          Offset(0.60, 0.22),
          Offset(0.58, 0.50),
          Offset(0.60, 0.78),
          Offset(0.38, 0.32),
          Offset(0.32, 0.50),
          Offset(0.38, 0.68),
        ];

  final color = isHome ? const Color(0xFF7C3AED) : const Color(0xFF2563EB);
  return List.generate(11, (index) {
    return PitchPlayerMarker(
      id: '$teamName-$index',
      label: normalizedLabels[index],
      position: positions[index],
      color: color,
    );
  });
}