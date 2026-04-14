class AppConfig {
  // API Configuration
  static const String apiBaseUrl = 'http://localhost:3000/api';
  static const Duration apiTimeout = Duration(seconds: 30);

  // Supabase Configuration (provided via --dart-define or dart-define-from-file)
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );
  static const bool supabaseEnabled =
      supabaseUrl != '' && supabaseAnonKey != '';
  static const String supabaseSyncFunctionUrl = String.fromEnvironment(
    'SUPABASE_SYNC_FUNCTION_URL',
    defaultValue: '',
  );
  static const bool supabaseSyncEnabled = supabaseSyncFunctionUrl != '';
  static const String firebaseWebVapidKey = String.fromEnvironment(
    'FIREBASE_WEB_VAPID_KEY',
    defaultValue: '',
  );
  static String get supabaseFunctionsBaseUrl {
    if (supabaseUrl.isEmpty) return '';
    final uri = Uri.parse(supabaseUrl);
    return '${uri.scheme}://${uri.host.replaceFirst('.supabase.co', '.functions.supabase.co')}';
  }

  static String get supabaseLeagueFunctionUrl =>
      supabaseFunctionsBaseUrl.isEmpty
      ? ''
      : '$supabaseFunctionsBaseUrl/league-actions';

  static String get currentFootballSeasonLabel {
    final startYear = currentFootballSeasonStartYear;
    return '$startYear/${startYear + 1}';
  }

  static int get currentFootballSeasonStartYear {
    final now = DateTime.now();
    return now.month >= 7 ? now.year : now.year - 1;
  }

  static List<String> get currentFootballSeasonAliases {
    final startYear = currentFootballSeasonStartYear;
    return <String>[
      '$startYear/${startYear + 1}',
      '$startYear',
      '${startYear}-${startYear + 1}',
    ];
  }

  // App Configuration
  static const String appVersion = '1.0.0';
  static const int teamBudget = 125; // Default budget in millions
  static const int maxPlayersPerTeam = 15;
  static const int maxPlayersFromSameClub = 3;

  // Team Formation
  static const int goalkeepersRequired = 2;
  static const int defendersRequired = 5;
  static const int midfieldersRequired = 5;
  static const int forwardsRequired = 3;

  // Playing Team Formation (11 players)
  static const int playingGoalkeepers = 1;
  static const int minDefenders = 3;
  static const int maxDefenders = 5;
  static const int minMidfielders = 2;
  static const int maxMidfielders = 5;
  static const int minForwards = 1;
  static const int maxForwards = 3;

  // Pagination
  static const int itemsPerPage = 20;

  // Cache Duration
  static const Duration cacheDuration = Duration(minutes: 30);

  // Image Sizes
  static const double playerImageSize = 80;
  static const double clubBadgeSize = 40;

  // Points System
  static const int pointsPerGoalGK = 10;
  static const int pointsPerGoalDEF = 6;
  static const int pointsPerGoalMID = 5;
  static const int pointsPerGoalFWD = 4;
  static const int pointsPerAssist = 3;
  static const int pointsPerCleanSheet = 4;
}
