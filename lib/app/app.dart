import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import 'router.dart';
import 'theme.dart';

class ReadEngApp extends ConsumerWidget {
  const ReadEngApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use ref.read - router instance never changes, only its internal state
    // Using ref.watch would cause MaterialApp to rebuild, creating duplicate Navigator widgets
    final router = ref.read(routerProvider);

    return MaterialApp.router(
      title: 'ReadEng',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('tr'),
        Locale('en'),
      ],
    );
  }
}
