import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'firebase_options.dart';
import 'constants/app_colors.dart';
import 'constants/app_strings.dart';
import 'config/app_config.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'services/player_service.dart';
import 'services/team_service.dart';
import 'services/notification_service.dart';
import 'services/error_reporting_service.dart';
import 'services/ops_dashboard_service.dart';
import 'services/team_analytics_service.dart';
import 'providers/auth_provider.dart';
import 'providers/team_provider.dart';
import 'providers/player_provider.dart';
import 'providers/ops_dashboard_provider.dart';
import 'providers/team_analytics_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  final errorReporting = ErrorReportingService.instance;

  await runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      _configureGlobalErrorHandling(errorReporting);
      await _bootstrapAndRun();
    },
    (error, stack) {
      debugPrint('❌ Uncaught zone error: $error');
      errorReporting.recordError(error, stack, reason: 'runZonedGuarded');
    },
  );
}

void _configureGlobalErrorHandling(ErrorReportingService errorReporting) {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('❌ Flutter framework error: ${details.exceptionAsString()}');
    errorReporting.recordFlutterError(details);
  };

  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    debugPrint('❌ Unhandled async/platform error: $error');
    errorReporting.recordError(
      error,
      stack,
      reason: 'platformDispatcher.onError',
    );
    return true;
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.error_outline, color: Colors.red, size: 48),
              SizedBox(height: 12),
              Text(
                'A UI error occurred. Please restart the app.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  };
}

Future<void> _bootstrapAndRun() async {
  var supabaseReady = false;

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await ErrorReportingService.instance.initialize();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await NotificationService.instance.initialize();
    debugPrint('✅ Firebase initialized successfully!');
    debugPrint('📱 Firebase Apps: ${Firebase.apps.length}');
  } catch (e) {
    debugPrint('❌ Firebase initialization error: $e');
  }

  if (AppConfig.supabaseEnabled) {
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
      );
      supabaseReady = true;
      debugPrint('✅ Supabase initialized successfully!');
    } catch (e) {
      debugPrint('❌ Supabase initialization error: $e');
    }
  } else {
    debugPrint('ℹ️ Supabase skipped (SUPABASE_URL/SUPABASE_ANON_KEY missing).');
  }

  runApp(MyApp(supabaseReady: supabaseReady));
}

class MyApp extends StatelessWidget {
  final bool supabaseReady;

  const MyApp({super.key, required this.supabaseReady});

  @override
  Widget build(BuildContext context) {
    // Initialize services
    final authService = AuthService();
    final teamService = TeamService(ApiService(authService));

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(authService)),
        ChangeNotifierProvider(create: (_) => TeamProvider(teamService)),
        if (supabaseReady)
          ChangeNotifierProvider(
            create: (_) => PlayerProvider(PlayerService()),
          ),
        if (supabaseReady)
          ChangeNotifierProvider(
            create: (_) => OpsDashboardProvider(
              OpsDashboardService(Supabase.instance.client),
            ),
          ),
        if (supabaseReady)
          ChangeNotifierProvider(
            create: (_) => TeamAnalyticsProvider(
              TeamAnalyticsService(Supabase.instance.client),
            ),
          ),
      ],
      child: MaterialApp(
        title: AppStrings.appName,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            primary: AppColors.primary,
            secondary: AppColors.secondary,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textLight,
            elevation: 0,
          ),
          scaffoldBackgroundColor: AppColors.background,
          cardTheme: CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        home: Consumer<AuthProvider>(
          builder: (context, authProvider, _) {
            if (authProvider.status == AuthStatus.initial) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (authProvider.isAuthenticated) {
              return const HomeScreen();
            }

            return const LoginScreen();
          },
        ),
      ),
    );
  }
}
