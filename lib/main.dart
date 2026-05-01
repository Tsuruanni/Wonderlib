import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/constants/env_constants.dart';

void main() {
  // Wrap binding init, dotenv, Sentry init, Supabase init, and runApp in a
  // single error zone. Keeping them all in one zone prevents the zone-mismatch
  // warning Flutter prints when WidgetsFlutterBinding.ensureInitialized() runs
  // in one zone and runApp() runs in another (e.g., Sentry's appRunner zone).
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await dotenv.load(fileName: '.env');

    final sentryDsn = EnvConstants.sentryDsn;
    if (sentryDsn.isNotEmpty) {
      await SentryFlutter.init((options) {
        options.dsn = sentryDsn;
        options.environment = EnvConstants.environment;
        options.tracesSampleRate = 0.2;
        options.sendDefaultPii = false; // K-12 privacy
      });
    }

    await Supabase.initialize(
      url: EnvConstants.supabaseUrl,
      anonKey: EnvConstants.supabaseAnonKey,
    );

    runApp(
      const ProviderScope(
        child: OwlioApp(),
      ),
    );
  }, (error, stack) {
    // Stale refresh tokens (user signed out elsewhere, token aged out, server
    // rotated JWT secret, etc.) surface as AuthException during Supabase's
    // background refresh. These are expected and non-fatal — Supabase already
    // clears the session; the user just gets redirected to /login on next
    // route check. Don't pollute Sentry with these.
    if (error is AuthException) {
      debugPrint('Ignored expected auth error in zone: ${error.message}');
      return;
    }
    Sentry.captureException(error, stackTrace: stack);
  });
}
