import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'components/book_widgets.dart';
import 'components/common_widgets.dart';
import 'components/activity_widgets.dart';
import 'components/reader_widgets.dart';

void main() {
  runApp(const WidgetbookApp());
}

class WidgetbookApp extends StatelessWidget {
  const WidgetbookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Widgetbook.material(
      directories: [
        // Book Widgets
        WidgetbookFolder(
          name: 'Book Widgets',
          children: bookWidgets,
        ),
        // Common Widgets
        WidgetbookFolder(
          name: 'Common Widgets',
          children: commonWidgets,
        ),
        // Activity Widgets
        WidgetbookFolder(
          name: 'Activity Widgets',
          children: activityWidgets,
        ),
        // Reader Widgets
        WidgetbookFolder(
          name: 'Reader Widgets',
          children: readerWidgets,
        ),
      ],
      addons: [
        // Theme addon
        MaterialThemeAddon(
          themes: [
            WidgetbookTheme(
              name: 'Light',
              data: ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFF4F46E5),
                  brightness: Brightness.light,
                ),
                useMaterial3: true,
              ),
            ),
            WidgetbookTheme(
              name: 'Dark',
              data: ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFF4F46E5),
                  brightness: Brightness.dark,
                ),
                useMaterial3: true,
              ),
            ),
          ],
        ),
        // Text scale addon
        TextScaleAddon(
          min: 1.0,
          max: 2.0,
        ),
        // Grid addon for alignment
        GridAddon(),
      ],
    );
  }
}
