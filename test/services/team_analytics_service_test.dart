import 'package:flutter_test/flutter_test.dart';
import 'package:football_manager_companion_app2/models/team_analytics.dart';
import 'package:football_manager_companion_app2/services/team_analytics_service.dart';

void main() {
  group('TeamAnalyticsService helpers', () {
    test('buildFormTrendsFromRows groups rows and calculates trends', () {
      final trends = buildFormTrendsFromRows([
        {'gameweek': 3, 'points': 20},
        {'gameweek': 3, 'points': 10},
        {'gameweek': 2, 'points': 6},
        {'gameweek': 2, 'points': 4},
        {'gameweek': 1, 'points': 1},
        {'gameweek': 1, 'points': 1},
      ], 3);

      expect(trends, hasLength(3));
      expect(trends.first.gameweek, 1);
      expect(trends[1].gameweek, 2);
      expect(trends.last.gameweek, 3);
      expect(trends.last.trend, 'up');
      expect(trends[1].trend, 'stable');
      expect(trends.first.points, 2);
      expect(trends.last.points, 30);
    });

    test('buildInjuryRisksFromInputs scores player availability risk', () {
      final risks = buildInjuryRisksFromInputs(
        players: [
          {'id': 1, 'name': 'Player One'},
          {'id': 2, 'name': 'Player Two'},
        ],
        injuriesResponse: [
          {'player_id': 1, 'expected_return_date': '2026-04-20T00:00:00Z'},
        ],
        suspensionsResponse: [
          {'player_id': 2, 'expected_return_date': '2026-04-18T00:00:00Z'},
        ],
      );

      expect(risks, hasLength(2));
      expect(risks.first.playerId, 1);
      expect(risks.first.playerName, 'Player One');
      expect(risks.first.riskScore, 20);
      expect(risks.first.riskLevel, 'low');
      expect(
        risks.first.expectedReturnDate,
        DateTime.parse('2026-04-20T00:00:00Z'),
      );
      expect(risks.last.playerId, 2);
      expect(risks.last.riskScore, 20);
    });

    test(
      'buildTransferRecommendationsFromInputs returns buy and sell recommendations',
      () {
        final recommendations = buildTransferRecommendationsFromInputs(
          players: [
            {'id': 1, 'name': 'Star Midfielder', 'position': 'midfielder'},
            {
              'id': 2,
              'name': 'Underperforming Defender',
              'position': 'defender',
            },
          ],
          statsResponse: [
            {'player_id': 1, 'expected_goals': 1.5, 'expected_assists': 1.0},
            {'player_id': 1, 'expected_goals': 1.0, 'expected_assists': 0.5},
            {'player_id': 2, 'expected_goals': 0.0, 'expected_assists': 0.0},
          ],
          pointsResponse: [
            {'player_id': 1, 'points': 15},
            {'player_id': 1, 'points': 12},
            {'player_id': 2, 'points': 1},
            {'player_id': 2, 'points': 2},
          ],
        );

        expect(recommendations, hasLength(2));
        expect(recommendations.first.action, 'buy');
        expect(recommendations.last.action, 'sell');
        expect(
          recommendations.first.priority,
          greaterThanOrEqualTo(recommendations.last.priority),
        );
      },
    );

    test('calculateTeamFormScoreFromInputs applies injury penalty', () {
      final score = calculateTeamFormScoreFromInputs(
        [
          FormTrend(
            gameweek: 1,
            points: 10,
            windowAverage: 10,
            trend: 'stable',
          ),
          FormTrend(gameweek: 2, points: 20, windowAverage: 20, trend: 'up'),
        ],
        [
          InjuryRisk(
            playerId: 1,
            playerName: 'Player One',
            currentInjuries: 0,
            currentSuspensions: 0,
            riskScore: 80,
            riskLevel: 'high',
            expectedReturnDate: null,
          ),
        ],
      );

      expect(score, closeTo(10, 0.001));
      expect(calculateTeamFormScoreFromInputs(const [], const []), 50.0);
    });
  });
}
