import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/constants/env_constants.dart';

Future<void> main() async {
  // Load env before Sentry (dotenv doesn't need Flutter binding)
  await dotenv.load(fileName: '.env');

  final sentryDsn = EnvConstants.sentryDsn;
  if (sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = sentryDsn;
        options.environment = EnvConstants.environment;
        options.tracesSampleRate = 0.2;
        options.sendDefaultPii = false; // K-12 privacy
        options.beforeSend = _filterSentryEvent;
      },
      appRunner: () => _initAndRunApp(),
    );
  } else {
    await _initAndRunApp();
  }
}

/// Filter out noisy Flutter errors that aren't actionable
SentryEvent? _filterSentryEvent(SentryEvent event, Hint hint) {
  final message = event.exceptions?.firstOrNull?.value ?? '';
  // RenderFlex overflow is a layout warning, not a real crash
  if (message.contains('RenderFlex overflowed')) return null;
  return event;
}

Future<void> _initAndRunApp() async {
  // Binding must be in the SAME zone as runApp (Sentry creates its own zone)
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: EnvConstants.supabaseUrl,
    anonKey: EnvConstants.supabaseAnonKey,
  );

  runApp(
    const ProviderScope(
      child: OwlioApp(),
    ),
  );
}
