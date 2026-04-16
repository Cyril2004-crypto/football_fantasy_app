class ApiEndpoints {
  // Base URL - Update this with your backend API URL
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/api',
  );

  // football-data.org
  static const String footballDataBaseUrl = 'https://api.football-data.org/v4';
  static String premierLeagueMatchesByMatchday(int matchday) =>
      '$footballDataBaseUrl/competitions/PL/matches?matchday=$matchday';
  static String competitionMatchesByMatchday(int competitionId, int matchday) =>
      '$footballDataBaseUrl/competitions/$competitionId/matches?matchday=$matchday';

  // Sportmonks
  static const String sportmonksBaseUrl =
      'https://api.sportmonks.com/v3/football';
  static const String sportmonksInplayLivescores =
      '$sportmonksBaseUrl/livescores/inplay?include=participants;scores;periods;events;league.country;round';
  static String sportmonksFixtureMatchCentre(int fixtureId) =>
      '$sportmonksBaseUrl/fixtures/$fixtureId?include=participants;scores;events.type;events.player;events.relatedplayer;lineups.details.type;statistics.type';
  static String sportmonksFixtureNews(int fixtureId) =>
      '$sportmonksBaseUrl/fixtures/$fixtureId?include=prematchNews.lines;postmatchNews.lines;participants;league;venue;state;scores;events.type';
  static String sportmonksFixtureXgMatch(int fixtureId) =>
      '$sportmonksBaseUrl/fixtures/$fixtureId/xg?include=participants;lineups.details.type';

  // Authentication
  static const String register = '$baseUrl/auth/register';
  static const String login = '$baseUrl/auth/login';
  static const String logout = '$baseUrl/auth/logout';

  // Users
  static const String users = '$baseUrl/users';
  static String userById(String id) => '$users/$id';
  static String userProfile = '$users/profile';

  // Players
  static const String players = '$baseUrl/players';
  static String playerById(String id) => '$players/$id';
  static const String playersByPosition = '$players/position';
  static const String playersByTeam = '$players/team';

  // Teams
  static const String teams = '$baseUrl/teams';
  static String teamById(String id) => '$teams/$id';
  static const String myTeam = '$teams/my-team';
  static const String createTeam = '$teams/create';
  static const String updateTeam = '$teams/update';

  // Leagues
  static const String leagues = '$baseUrl/leagues';
  static String leagueById(String id) => '$leagues/$id';
  static const String createLeague = '$leagues/create';
  static const String joinLeague = '$leagues/join';
  static const String leagueStandings = '$leagues/standings';
  static const String myLeagues = '$leagues/my-leagues';

  // Matches
  static const String matches = '$baseUrl/matches';
  static String matchById(String id) => '$matches/$id';
  static const String liveMatches = '$matches/live';
  static const String upcomingMatches = '$matches/upcoming';
  static const String completedMatches = '$matches/completed';

  // Stats
  static const String stats = '$baseUrl/stats';
  static const String gameweekStats = '$stats/gameweek';
  static const String overallStats = '$stats/overall';

  // News
  static const String news = '$baseUrl/news';
  static const String expertTips = '$baseUrl/tips';
}
