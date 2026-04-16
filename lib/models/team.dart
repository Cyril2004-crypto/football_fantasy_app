import 'package:equatable/equatable.dart';
import 'player.dart';

class Team extends Equatable {
  final String id;
  final String userId;
  final String name;
  final List<Player> players;
  final double remainingBudget;
  final int totalPoints;
  final int gameweekPoints;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Team({
    required this.id,
    required this.userId,
    required this.name,
    required this.players,
    required this.remainingBudget,
    required this.totalPoints,
    required this.gameweekPoints,
    required this.createdAt,
    this.updatedAt,
  });

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      id: json['id'] as String,
      userId: json['userId'] as String,
      name: json['name'] as String,
      players:
          (json['players'] as List?)
              ?.map((p) => Player.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      remainingBudget: (json['remainingBudget'] as num).toDouble(),
      totalPoints: json['totalPoints'] as int? ?? 0,
      gameweekPoints: json['gameweekPoints'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'players': players.map((p) => p.toJson()).toList(),
      'remainingBudget': remainingBudget,
      'totalPoints': totalPoints,
      'gameweekPoints': gameweekPoints,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  Team copyWith({
    String? id,
    String? userId,
    String? name,
    List<Player>? players,
    double? remainingBudget,
    int? totalPoints,
    int? gameweekPoints,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Team(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      players: players ?? this.players,
      remainingBudget: remainingBudget ?? this.remainingBudget,
      totalPoints: totalPoints ?? this.totalPoints,
      gameweekPoints: gameweekPoints ?? this.gameweekPoints,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    name,
    players,
    remainingBudget,
    totalPoints,
    gameweekPoints,
    createdAt,
    updatedAt,
  ];
}
