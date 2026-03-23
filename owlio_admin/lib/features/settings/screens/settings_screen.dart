import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';

import '../../../core/supabase_client.dart';

/// Provider for loading all settings grouped by category
final settingsProvider =
    FutureProvider<Map<String, List<Map<String, dynamic>>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.systemSettings)
      .select()
      .order('category')
      .order('key');

  final settings = List<Map<String, dynamic>>.from(response);

  // Group by category
  final grouped = <String, List<Map<String, dynamic>>>{};
  for (final setting in settings) {
    final category = setting['category'] as String;
    grouped.putIfAbsent(category, () => []).add(setting);
  }

  return grouped;
});

class SettingsScreen extends ConsumerStatefulWidget {
  final String title;
  final List<String> categories;

  const SettingsScreen({
    required this.title,
    required this.categories,
    super.key,
  });

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const categoryLabels = {
    'xp': 'Genel XP',
    'xp_inline': 'Inline Activity XP',
    'xp_vocab': 'Vocab Session XP',
    'xp_bonus': 'Session & Combo Bonuses',
    'progression': 'Seviye ve İlerleme',
    'game': 'Oyun Ayarları',
    'app': 'Uygulama Yapılandırması',
  };

  static const categoryIcons = {
    'xp': Icons.star,
    'xp_inline': Icons.extension_rounded,
    'xp_vocab': Icons.school,
    'xp_bonus': Icons.local_fire_department_rounded,
    'progression': Icons.trending_up,
    'game': Icons.games,
    'app': Icons.settings_applications,
  };

  static const categoryColors = {
    'xp': Color(0xFFF59E0B),
    'xp_inline': Color(0xFFEC4899),
    'xp_vocab': Color(0xFF10B981),
    'xp_bonus': Color(0xFFEF4444),
    'progression': Color(0xFF8B5CF6),
    'game': Color(0xFF3B82F6),
    'app': Color(0xFF6B7280),
  };

  List<String> get categoryOrder => widget.categories;

  final Map<String, TextEditingController> _controllers = {};
  final Set<String> _savingKeys = {};

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _updateSetting(String key, String value) async {
    if (_savingKeys.contains(key)) return;

    setState(() => _savingKeys.add(key));

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase
          .from(DbTables.systemSettings)
          .update({'value': value})
          .eq('key', key);

      if (mounted) {
        // Refresh provider to update UI with new values
        ref.invalidate(settingsProvider);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$key güncellendi'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            width: 200,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _savingKeys.remove(key));
      }
    }
  }

  String _parseValue(dynamic jsonbValue) {
    if (jsonbValue is String) {
      return jsonbValue;
    }
    return jsonbValue.toString();
  }

  String _formatKey(String key) {
    return key
        .split('_')
        .map((word) =>
            word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1)}' : '')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => ref.invalidate(settingsProvider),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Yenile'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: settingsAsync.when(
        data: (groupedSettings) {
          if (groupedSettings.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.settings_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Ayar bulunamadı',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'system_settings tablosunu oluşturmak için migration çalıştırın',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Değişiklikler otomatik kaydedilir. Bu ayarlar veritabanında saklanır ancak ana uygulama entegrasyonu henüz yapılmadı.',
                          style: TextStyle(color: Colors.blue.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Settings sections
                ...categoryOrder
                    .where((cat) => groupedSettings.containsKey(cat))
                    .map((category) {
                  final settings = groupedSettings[category]!;
                  return _buildSection(category, settings);
                }),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
              const SizedBox(height: 16),
              Text('Hata: $error'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(settingsProvider),
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String category, List<Map<String, dynamic>> settings) {
    final label = categoryLabels[category] ?? category;
    final icon = categoryIcons[category] ?? Icons.settings;
    final color = categoryColors[category] ?? Colors.grey;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Settings card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: settings.asMap().entries.map((entry) {
                final index = entry.key;
                final setting = entry.value;
                final isLast = index == settings.length - 1;

                return Column(
                  children: [
                    _buildSettingRow(setting),
                    if (!isLast)
                      Divider(
                        color: Colors.grey.shade200,
                        height: 24,
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSettingRow(Map<String, dynamic> setting) {
    final key = setting['key'] as String;
    final value = _parseValue(setting['value']);
    final description = setting['description'] as String?;
    final isSaving = _savingKeys.contains(key);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label and description
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatKey(key),
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (description != null) ...[
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 16),

        // Input
        Expanded(
          flex: 1,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isSaving)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              _buildInput(key, value),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInput(String key, String value) {
    // Boolean (switch)
    if (value == 'true' || value == 'false') {
      return Switch(
        value: value == 'true',
        onChanged: (v) => _updateSetting(key, v.toString()),
      );
    }

    // Number
    if (double.tryParse(value) != null) {
      // Get or create controller
      _controllers.putIfAbsent(key, () => TextEditingController(text: value));
      final controller = _controllers[key]!;

      // Update controller if value changed externally
      if (controller.text != value && !_savingKeys.contains(key)) {
        controller.text = value;
      }

      return SizedBox(
        width: 100,
        child: TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.end,
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onFieldSubmitted: (v) {
            if (v.isNotEmpty && v != value) {
              _updateSetting(key, v);
            }
          },
        ),
      );
    }

    // Text
    _controllers.putIfAbsent(key, () => TextEditingController(text: value));
    final controller = _controllers[key]!;

    if (controller.text != value && !_savingKeys.contains(key)) {
      controller.text = value;
    }

    return SizedBox(
      width: 150,
      child: TextFormField(
        controller: controller,
        textAlign: TextAlign.end,
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: OutlineInputBorder(),
          isDense: true,
        ),
        onFieldSubmitted: (v) {
          if (v != value) {
            _updateSetting(key, v);
          }
        },
      ),
    );
  }
}
