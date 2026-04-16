import 'package:equatable/equatable.dart';

enum MatchStatus { scheduled, live, completed, postponed }

class Match extends Equatable {
  final String id;
  final String homeTeamId;
  final String homeTeamName;
  final String? homeTeamBadge;
  final String awayTeamId;
  final String awayTeamName;
  final String? awayTeamBadge;
  final int? homeScore;
  final int? awayScore;
  final MatchStatus status;
  final DateTime kickoffTime;
  final int gameweek;
  final String? venue;

  const Match({
    required this.id,
    required this.homeTeamId,
    required this.homeTeamName,
    this.homeTeamBadge,
    required this.awayTeamId,
    required this.awayTeamName,
    this.awayTeamBadge,
    this.homeScore,
    this.awayScore,
    required this.status,
    required this.kickoffTime,
    required this.gameweek,
    this.venue,
  });

  factory Match.fromJson(Map<String, dynamic> json) {
    return Match(
      id: json['id'] as String,
      homeTeamId: json['homeTeamId'] as String,
      homeTeamName: json['homeTeamName'] as String,
      homeTeamBadge: json['homeTeamBadge'] as String?,
      awayTeamId: json['awayTeamId'] as String,
      awayTeamName: json['awayTeamName'] as String,
      awayTeamBadge: json['awayTeamBadge'] as String?,
      homeScore: json['homeScore'] as int?,
      awayScore: json['awayScore'] as int?,
      status: _statusFromString(json['status'] as String),
      kickoffTime: DateTime.parse(json['kickoffTime'] as String),
      gameweek: json['gameweek'] as int,
      venue: json['venue'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'homeTeamId': homeTeamId,
      'homeTeamName': homeTeamName,
      'homeTeamBadge': homeTeamBadge,
      'awayTeamId': awayTeamId,
      'awayTeamName': awayTeamName,
      'awayTeamBadge': awayTeamBadge,
      'homeScore': homeScore,
      'awayScore': awayScore,
      'status': _statusToString(status),
      'kickoffTime': kickoffTime.toIso8601String(),
      'gameweek': gameweek,
      'venue': venue,
    };
  }

  static MatchStatus _statusFromString(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
        return MatchStatus.scheduled;
      case 'live':
        return MatchStatus.live;
      case 'completed':
        return MatchStatus.completed;
      case 'postponed':
        return MatchStatus.postponed;
      default:
        return MatchStatus.scheduled;
    }
  }

  static String _statusToString(MatchStatus status) {
    switch (status) {
      case MatchStatus.scheduled:
        return 'scheduled';
      case MatchStatus.live:
        return 'live';
      case MatchStatus.completed:
        return 'completed';
      case MatchStatus.postponed:
        return 'postponed';
    }
  }

  @override
  List<Object?> get props => [
    id,
    homeTeamId,
    homeTeamName,
    homeTeamBadge,
    awayTeamId,
    awayTeamName,
    awayTeamBadge,
    homeScore,
    awayScore,
    status,
    kickoffTime,
    gameweek,
    venue,
  ];
}
