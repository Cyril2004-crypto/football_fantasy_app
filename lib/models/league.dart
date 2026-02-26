import 'package:equatable/equatable.dart';

enum LeagueType { public, private }

class League extends Equatable {
  final String id;
  final String name;
  final String? code;
  final LeagueType type;
  final String createdBy;
  final int membersCount;
  final DateTime createdAt;

  const League({
    required this.id,
    required this.name,
    this.code,
    required this.type,
    required this.createdBy,
    required this.membersCount,
    required this.createdAt,
  });

  factory League.fromJson(Map<String, dynamic> json) {
    return League(
      id: json['id'] as String,
      name: json['name'] as String,
      code: json['code'] as String?,
      type: json['type'] == 'public' ? LeagueType.public : LeagueType.private,
      createdBy: json['createdBy'] as String,
      membersCount: json['membersCount'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'type': type == LeagueType.public ? 'public' : 'private',
      'createdBy': createdBy,
      'membersCount': membersCount,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, name, code, type, createdBy, membersCount, createdAt];
}

class LeagueStanding extends Equatable {
  final String userId;
  final String userName;
  final String teamName;
  final int rank;
  final int totalPoints;
  final int gameweekPoints;

  const LeagueStanding({
    required this.userId,
    required this.userName,
    required this.teamName,
    required this.rank,
    required this.totalPoints,
    required this.gameweekPoints,
  });

  factory LeagueStanding.fromJson(Map<String, dynamic> json) {
    return LeagueStanding(
      userId: json['userId'] as String,
      userName: json['userName'] as String,
      teamName: json['teamName'] as String,
      rank: json['rank'] as int,
      totalPoints: json['totalPoints'] as int,
      gameweekPoints: json['gameweekPoints'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'teamName': teamName,
      'rank': rank,
      'totalPoints': totalPoints,
      'gameweekPoints': gameweekPoints,
    };
  }

  @override
  List<Object?> get props => [userId, userName, teamName, rank, totalPoints, gameweekPoints];
}
