import 'package:equatable/equatable.dart';

class FormTrend extends Equatable {
  final int gameweek;
  final int points;
  final double windowAverage;
  final String trend; // 'up', 'down', 'stable'

  const FormTrend({
    required this.gameweek,
    required this.points,
    required this.windowAverage,
    required this.trend,
  });

  @override
  List<Object?> get props => [gameweek, points, windowAverage, trend];
}

class InjuryRisk extends Equatable {
  final int playerId;
  final String playerName;
  final int currentInjuries;
  final int currentSuspensions;
  final int riskScore; // 0-100
  final String riskLevel; // 'low', 'medium', 'high'
  final DateTime? expectedReturnDate;

  const InjuryRisk({
    required this.playerId,
    required this.playerName,
    required this.currentInjuries,
    required this.currentSuspensions,
    required this.riskScore,
    required this.riskLevel,
    this.expectedReturnDate,
  });

  @override
  List<Object?> get props => [
    playerId,
    playerName,
    currentInjuries,
    currentSuspensions,
    riskScore,
    riskLevel,
    expectedReturnDate,
  ];
}

class TransferRecommendation extends Equatable {
  final int playerId;
  final String playerName;
  final String position;
  final double estimatedValue;
  final double estimatedPrice;
  final int recentPointsAverage;
  final double expectedGoals;
  final double expectedAssists;
  final String action; // 'buy', 'sell', 'hold'
  final int priority; // 1-5, 5 being highest

  const TransferRecommendation({
    required this.playerId,
    required this.playerName,
    required this.position,
    required this.estimatedValue,
    required this.estimatedPrice,
    required this.recentPointsAverage,
    required this.expectedGoals,
    required this.expectedAssists,
    required this.action,
    required this.priority,
  });

  @override
  List<Object?> get props => [
    playerId,
    playerName,
    position,
    estimatedValue,
    estimatedPrice,
    recentPointsAverage,
    expectedGoals,
    expectedAssists,
    action,
    priority,
  ];
}

class TeamAnalytics extends Equatable {
  final String teamId;
  final String teamName;
  final List<FormTrend> formTrends;
  final List<InjuryRisk> injuryRisks;
  final List<TransferRecommendation> transferRecommendations;
  final double teamFormScore; // 0-100
  final int highPriorityTransfers; // count of priority >= 4

  const TeamAnalytics({
    required this.teamId,
    required this.teamName,
    required this.formTrends,
    required this.injuryRisks,
    required this.transferRecommendations,
    required this.teamFormScore,
    required this.highPriorityTransfers,
  });

  @override
  List<Object?> get props => [
    teamId,
    teamName,
    formTrends,
    injuryRisks,
    transferRecommendations,
    teamFormScore,
    highPriorityTransfers,
  ];
}
