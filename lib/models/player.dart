import 'package:equatable/equatable.dart';

enum PlayerPosition { goalkeeper, defender, midfielder, forward }

class Player extends Equatable {
  final String id;
  final String name;
  final String clubId;
  final String clubName;
  final String? clubBadge;
  final String? photoUrl;
  final PlayerPosition position;
  final double price;
  final int points;
  final int gameweekPoints;
  final String nationality;
  final int goalsScored;
  final int assists;
  final int cleanSheets;
  final bool isInjured;
  final bool isSuspended;
  final double form;

  const Player({
    required this.id,
    required this.name,
    required this.clubId,
    required this.clubName,
    this.clubBadge,
    this.photoUrl,
    required this.position,
    required this.price,
    required this.points,
    required this.gameweekPoints,
    required this.nationality,
    this.goalsScored = 0,
    this.assists = 0,
    this.cleanSheets = 0,
    this.isInjured = false,
    this.isSuspended = false,
    this.form = 0.0,
  });

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'] as String,
      name: json['name'] as String,
      clubId: json['clubId'] as String,
      clubName: json['clubName'] as String,
      clubBadge: json['clubBadge'] as String?,
      photoUrl: json['photoUrl'] as String?,
      position: _positionFromString(json['position'] as String),
      price: (json['price'] as num).toDouble(),
      points: json['points'] as int,
      gameweekPoints: json['gameweekPoints'] as int? ?? 0,
      nationality: json['nationality'] as String,
      goalsScored: json['goalsScored'] as int? ?? 0,
      assists: json['assists'] as int? ?? 0,
      cleanSheets: json['cleanSheets'] as int? ?? 0,
      isInjured: json['isInjured'] as bool? ?? false,
      isSuspended: json['isSuspended'] as bool? ?? false,
      form: (json['form'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'clubId': clubId,
      'clubName': clubName,
      'clubBadge': clubBadge,
      'photoUrl': photoUrl,
      'position': _positionToString(position),
      'price': price,
      'points': points,
      'gameweekPoints': gameweekPoints,
      'nationality': nationality,
      'goalsScored': goalsScored,
      'assists': assists,
      'cleanSheets': cleanSheets,
      'isInjured': isInjured,
      'isSuspended': isSuspended,
      'form': form,
    };
  }

  static PlayerPosition _positionFromString(String position) {
    switch (position.toLowerCase()) {
      case 'goalkeeper':
      case 'gk':
        return PlayerPosition.goalkeeper;
      case 'defender':
      case 'def':
        return PlayerPosition.defender;
      case 'midfielder':
      case 'mid':
        return PlayerPosition.midfielder;
      case 'forward':
      case 'fwd':
        return PlayerPosition.forward;
      default:
        return PlayerPosition.midfielder;
    }
  }

  static String _positionToString(PlayerPosition position) {
    switch (position) {
      case PlayerPosition.goalkeeper:
        return 'goalkeeper';
      case PlayerPosition.defender:
        return 'defender';
      case PlayerPosition.midfielder:
        return 'midfielder';
      case PlayerPosition.forward:
        return 'forward';
    }
  }

  @override
  List<Object?> get props => [
    id,
    name,
    clubId,
    clubName,
    clubBadge,
    photoUrl,
    position,
    price,
    points,
    gameweekPoints,
    nationality,
    goalsScored,
    assists,
    cleanSheets,
    isInjured,
    isSuspended,
    form,
  ];
}
