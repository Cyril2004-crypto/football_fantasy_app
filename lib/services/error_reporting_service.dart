import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class ErrorReportingService {
  ErrorReportingService._();

  static final ErrorReportingService instance = ErrorReportingService._();

  bool _isEnabled = false;

  Future<void> initialize() async {
    if (kIsWeb) {
      debugPrint('ℹ️ Crash reporting disabled on web.');
      return;
    }

    try {
      final shouldEnableCollection = !kDebugMode;
      await FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(shouldEnableCollection);
      _isEnabled = shouldEnableCollection;
      debugPrint('✅ Crash reporting ${_isEnabled ? 'enabled' : 'disabled'}');
    } catch (e) {
      debugPrint('⚠️ Crash reporting init failed: $e');
      _isEnabled = false;
    }
  }

  void recordFlutterError(FlutterErrorDetails details) {
    if (!_isEnabled) return;
    unawaited(FirebaseCrashlytics.instance.recordFlutterFatalError(details));
  }

  void recordError(
    Object error,
    StackTrace stack, {
    bool fatal = true,
    String? reason,
  }) {
    if (!_isEnabled) return;
    unawaited(
      FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        fatal: fatal,
        reason: reason,
      ),
    );
  }
}
