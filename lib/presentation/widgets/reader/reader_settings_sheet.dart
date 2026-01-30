import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/reader_provider.dart';

/// Bottom sheet for reader customization
/// Includes font size, line height, theme, and vocabulary toggle
class ReaderSettingsSheet extends ConsumerWidget {
  const ReaderSettingsSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => const ReaderSettingsSheet(),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(readerSettingsProvider);
    final notifier = ref.read(readerSettingsProvider.notifier);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Reading Settings',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Font size
            _SettingRow(
              label: 'Font Size',
              value: '${settings.fontSize.toStringAsFixed(0)}',
              child: Row(
                children: [
                  IconButton(
                    onPressed: settings.fontSize > 14
                        ? () => notifier.setFontSize(settings.fontSize - 2)
                        : null,
                    icon: const Icon(Icons.text_decrease),
                  ),
                  Expanded(
                    child: Slider(
                      value: settings.fontSize,
                      min: 14,
                      max: 28,
                      divisions: 7,
                      onChanged: notifier.setFontSize,
                    ),
                  ),
                  IconButton(
                    onPressed: settings.fontSize < 28
                        ? () => notifier.setFontSize(settings.fontSize + 2)
                        : null,
                    icon: const Icon(Icons.text_increase),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Line height
            _SettingRow(
              label: 'Line Spacing',
              value: '${settings.lineHeight.toStringAsFixed(1)}',
              child: Slider(
                value: settings.lineHeight,
                min: 1.2,
                max: 2.0,
                divisions: 8,
                onChanged: notifier.setLineHeight,
              ),
            ),

            const SizedBox(height: 24),

            // Theme selector
            Text(
              'Theme',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: ReaderTheme.values.map((readerTheme) {
                final isSelected = settings.theme == readerTheme;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _ThemeChip(
                      theme: readerTheme,
                      isSelected: isSelected,
                      onTap: () => notifier.setTheme(readerTheme),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // Vocabulary highlights toggle
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Highlight vocabulary words'),
              subtitle: const Text('Tap words to see definitions'),
              value: settings.showVocabularyHighlights,
              onChanged: (_) => notifier.toggleVocabularyHighlights(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.label,
    required this.value,
    required this.child,
  });

  final String label;
  final String value;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

class _ThemeChip extends StatelessWidget {
  const _ThemeChip({
    required this.theme,
    required this.isSelected,
    required this.onTap,
  });

  final ReaderTheme theme;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: theme.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? colorScheme.primary : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Text(
              'Aa',
              style: TextStyle(
                color: theme.text,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              theme.name,
              style: TextStyle(
                color: theme.text,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
