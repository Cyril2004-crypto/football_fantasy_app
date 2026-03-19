import '../config/app_config.dart';
import '../models/player.dart';

class PlayerGameweekInput {
  final String playerId;
  final PlayerPosition position;
  final int goals;
  final int assists;
  final bool cleanSheet;

  const PlayerGameweekInput({
    required this.playerId,
    required this.position,
    this.goals = 0,
    this.assists = 0,
    this.cleanSheet = false,
  });
}

class PointsCalculatorService {
  int calculatePlayerGameweekPoints(PlayerGameweekInput input) {
    final goalPoints = input.goals * _goalPointsForPosition(input.position);
    final assistPoints = input.assists * AppConfig.pointsPerAssist;
    final cleanSheetPoints = _cleanSheetPointsForPosition(
      position: input.position,
      cleanSheet: input.cleanSheet,
    );

    return goalPoints + assistPoints + cleanSheetPoints;
  }

  Map<String, int> calculatePlayersGameweekPoints(
    List<PlayerGameweekInput> inputs,
  ) {
    return {
      for (final input in inputs)
        input.playerId: calculatePlayerGameweekPoints(input),
    };
  }

  int calculateTeamGameweekPoints({
    required Map<String, int> playerPointsById,
    required List<String> startingPlayerIds,
    String? captainPlayerId,
    String? viceCaptainPlayerId,
    Map<String, bool>? playedByPlayerId,
  }) {
    var total = 0;

    for (final playerId in startingPlayerIds) {
      total += playerPointsById[playerId] ?? 0;
    }

    if (captainPlayerId == null) {
      return total;
    }

    final captainPlayed = playedByPlayerId?[captainPlayerId] ?? true;
    if (captainPlayed) {
      total += playerPointsById[captainPlayerId] ?? 0;
      return total;
    }

    if (viceCaptainPlayerId != null) {
      final viceCaptainPlayed = playedByPlayerId?[viceCaptainPlayerId] ?? true;
      if (viceCaptainPlayed) {
        total += playerPointsById[viceCaptainPlayerId] ?? 0;
      }
    }

    return total;
  }

  int calculateUpdatedTotalPoints({
    required int currentTotalPoints,
    required int gameweekPoints,
  }) {
    return currentTotalPoints + gameweekPoints;
  }

  int calculateStoredTeamTotalPoints(List<Player> players) {
    return players.fold<int>(0, (sum, player) => sum + player.points);
  }

  int calculateStoredTeamGameweekPoints(List<Player> players) {
    return players.fold<int>(0, (sum, player) => sum + player.gameweekPoints);
  }

  int _goalPointsForPosition(PlayerPosition position) {
    switch (position) {
      case PlayerPosition.goalkeeper:
        return AppConfig.pointsPerGoalGK;
      case PlayerPosition.defender:
        return AppConfig.pointsPerGoalDEF;
      case PlayerPosition.midfielder:
        return AppConfig.pointsPerGoalMID;
      case PlayerPosition.forward:
        return AppConfig.pointsPerGoalFWD;
    }
  }

  int _cleanSheetPointsForPosition({
    required PlayerPosition position,
    required bool cleanSheet,
  }) {
    if (!cleanSheet) {
      return 0;
    }

    if (position == PlayerPosition.goalkeeper ||
        position == PlayerPosition.defender) {
      return AppConfig.pointsPerCleanSheet;
    }

    return 0;
  }
}