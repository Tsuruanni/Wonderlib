import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';

import '../../../core/supabase_client.dart';
import '../../settings/screens/settings_screen.dart';

class NotificationGalleryScreen extends ConsumerStatefulWidget {
  const NotificationGalleryScreen({super.key});

  @override
  ConsumerState<NotificationGalleryScreen> createState() =>
      _NotificationGalleryScreenState();
}

class _NotificationGalleryScreenState
    extends ConsumerState<NotificationGalleryScreen> {
  final Set<String> _savingKeys = {};
  final Map<String, TextEditingController> _controllers = {};

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
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
        ref.invalidate(settingsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$key updated'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            width: 200,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _savingKeys.remove(key));
    }
  }

  String _getValue(Map<String, List<Map<String, dynamic>>> grouped, String key,
      String fallback) {
    final notifSettings = grouped['notification'] ?? [];
    for (final s in notifSettings) {
      if (s['key'] == key) {
        final v = s['value'];
        if (v is String) return v;
        return v.toString();
      }
    }
    return fallback;
  }

  bool _getBool(
      Map<String, List<Map<String, dynamic>>> grouped, String key) {
    return _getValue(grouped, key, 'true') == 'true';
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => ref.invalidate(settingsProvider),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Refresh'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: settingsAsync.when(
        data: (grouped) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.indigo.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.indigo.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Preview of all in-app notifications. Toggles control whether users see each notification type.',
                            style: TextStyle(color: Colors.indigo.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  _buildStreakExtendedCard(grouped),
                  const SizedBox(height: 16),
                  _buildMilestoneCard(grouped),
                  const SizedBox(height: 16),
                  _buildFreezeSavedCard(grouped),
                  const SizedBox(height: 16),
                  _buildStreakBrokenCard(grouped),
                  const SizedBox(height: 16),
                  _buildLevelUpCard(grouped),
                  const SizedBox(height: 16),
                  _buildLeagueChangeCard(grouped),
                  const SizedBox(height: 16),
                  _buildBadgeEarnedCard(grouped),
                ],
              ),
            ),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  // ==========================================
  // CARD BUILDERS
  // ==========================================

  Widget _buildStreakExtendedCard(
      Map<String, List<Map<String, dynamic>>> grouped) {
    return _NotifCard(
      icon: Icons.local_fire_department_rounded,
      iconColor: Colors.orange,
      title: 'Streak Extended',
      description: 'Shown every day when user opens the app',
      isEnabled: _getBool(grouped, 'notif_streak_extended'),
      isSaving: _savingKeys.contains('notif_streak_extended'),
      onToggle: (v) => _updateSetting('notif_streak_extended', v.toString()),
      preview: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _previewRow('Day 1', "Day 1! Let's go!",
              'Your learning streak starts today!'),
          const SizedBox(height: 8),
          _previewRow('Day 2+', 'Day X!', 'Rotating subtitle (by day):'),
          Padding(
            padding: const EdgeInsets.only(left: 80, top: 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: const [
                _SubtitleChip('Keep it up!'),
                _SubtitleChip("You're on fire!"),
                _SubtitleChip('Great habit!'),
                _SubtitleChip('Consistency is key!'),
                _SubtitleChip('Unstoppable!'),
                _SubtitleChip('Nice streak!'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestoneCard(
      Map<String, List<Map<String, dynamic>>> grouped) {
    return _NotifCard(
      icon: Icons.emoji_events,
      iconColor: Colors.amber,
      title: 'Milestone',
      description: 'Triggers at days 7, 14, 30, 60, 100',
      isEnabled: _getBool(grouped, 'notif_milestone'),
      isSaving: _savingKeys.contains('notif_milestone'),
      onToggle: (v) => _updateSetting('notif_milestone', v.toString()),
      preview: _previewRow(
          'Dialog', 'X-Day Streak!', '+YZ XP earned!'),
    );
  }

  Widget _buildFreezeSavedCard(
      Map<String, List<Map<String, dynamic>>> grouped) {
    return _NotifCard(
      icon: Icons.ac_unit,
      iconColor: Colors.blue.shade400,
      title: 'Freeze Saved',
      description: 'When streak freeze prevents streak from breaking',
      isEnabled: _getBool(grouped, 'notif_freeze_saved'),
      isSaving: _savingKeys.contains('notif_freeze_saved'),
      onToggle: (v) => _updateSetting('notif_freeze_saved', v.toString()),
      preview: _previewRow('Dialog', 'Streak Freeze Saved You!',
          'Your X-day streak is safe. N freezes left.'),
    );
  }

  Widget _buildStreakBrokenCard(
      Map<String, List<Map<String, dynamic>>> grouped) {
    final minDays = _getValue(grouped, 'notif_streak_broken_min', '3');
    _controllers.putIfAbsent(
        'notif_streak_broken_min', () => TextEditingController(text: minDays));
    final controller = _controllers['notif_streak_broken_min']!;
    if (controller.text != minDays &&
        !_savingKeys.contains('notif_streak_broken_min')) {
      controller.text = minDays;
    }

    return _NotifCard(
      icon: Icons.local_fire_department_rounded,
      iconColor: Colors.grey,
      title: 'Streak Broken',
      description: 'When user loses their streak',
      isEnabled: _getBool(grouped, 'notif_streak_broken'),
      isSaving: _savingKeys.contains('notif_streak_broken'),
      onToggle: (v) => _updateSetting('notif_streak_broken', v.toString()),
      preview: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Min days parameter
          Row(
            children: [
              Text('Min streak to trigger:',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700)),
              const SizedBox(width: 8),
              SizedBox(
                width: 60,
                child: TextFormField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onFieldSubmitted: (v) {
                    if (v.isNotEmpty && v != minDays) {
                      _updateSetting('notif_streak_broken_min', v);
                    }
                  },
                ),
              ),
              const SizedBox(width: 4),
              Text('days',
                  style:
                      TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            ],
          ),
          const SizedBox(height: 12),
          _previewRow('3-6 days', 'Welcome Back!',
              'Start a new streak today.'),
          const SizedBox(height: 6),
          _previewRow('7-9 days', 'Your X-day streak ended',
              'You can build it again!'),
          const SizedBox(height: 6),
          _previewRow('10-20 days', 'Your X-day streak was broken',
              "Don't give up!"),
          const SizedBox(height: 6),
          _previewRow('20+ days', 'Your X-day streak was broken',
              'That was impressive — you can do it again!'),
        ],
      ),
    );
  }

  Widget _buildLevelUpCard(
      Map<String, List<Map<String, dynamic>>> grouped) {
    return _NotifCard(
      icon: Icons.arrow_upward_rounded,
      iconColor: Colors.indigo,
      title: 'Level Up',
      description: 'When user gains enough XP to level up',
      isEnabled: _getBool(grouped, 'notif_level_up'),
      isSaving: _savingKeys.contains('notif_level_up'),
      onToggle: (v) => _updateSetting('notif_level_up', v.toString()),
      preview: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _previewRow('Title', 'Level Up!', null),
          const SizedBox(height: 6),
          _previewRow('Transition', 'Level X → Level Y', null),
          const SizedBox(height: 6),
          _previewRow('Subtitle', 'Great job! Keep it up!', null),
        ],
      ),
    );
  }

  Widget _buildBadgeEarnedCard(
      Map<String, List<Map<String, dynamic>>> grouped) {
    return _NotifCard(
      icon: Icons.emoji_events,
      iconColor: Colors.amber.shade700,
      title: 'Badge Earned',
      description: 'Shown when a student earns a new badge',
      isEnabled: _getBool(grouped, 'notif_badge_earned'),
      isSaving: _savingKeys.contains('notif_badge_earned'),
      onToggle: (v) => _updateSetting('notif_badge_earned', v.toString()),
      preview: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _previewRow('Single', 'New Badge!',
              '🏆 Streak Master  +100 XP'),
          const SizedBox(height: 8),
          _previewRow('Multiple', '2 New Badges!',
              '🔥 Streak Master +100 XP\n⭐ Rising Star +50 XP'),
        ],
      ),
    );
  }

  Widget _buildLeagueChangeCard(
      Map<String, List<Map<String, dynamic>>> grouped) {
    return _NotifCard(
      icon: Icons.military_tech,
      iconColor: Colors.amber.shade700,
      title: 'League Change',
      description: 'Weekly league promotion or demotion',
      isEnabled: _getBool(grouped, 'notif_league_change'),
      isSaving: _savingKeys.contains('notif_league_change'),
      onToggle: (v) => _updateSetting('notif_league_change', v.toString()),
      preview: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _previewRow('Promotion', 'League Promoted!',
              'OldTier → NewTier · Great work this week! Keep climbing!'),
          const SizedBox(height: 6),
          _previewRow('Demotion', 'League Demoted',
              'OldTier → NewTier · Keep practicing to climb back up!'),
        ],
      ),
    );
  }

  // ==========================================
  // HELPERS
  // ==========================================

  Widget _previewRow(String label, String title, String? subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 76,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade500,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              if (subtitle != null)
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade600)),
            ],
          ),
        ),
      ],
    );
  }
}

// ==========================================
// NOTIFICATION CARD WIDGET
// ==========================================

class _NotifCard extends StatelessWidget {
  const _NotifCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.isEnabled,
    required this.isSaving,
    required this.onToggle,
    required this.preview,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final bool isEnabled;
  final bool isSaving;
  final ValueChanged<bool> onToggle;
  final Widget preview;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(description,
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                if (isSaving)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                Switch(
                  value: isEnabled,
                  onChanged: onToggle,
                  activeColor: iconColor,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Preview section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MESSAGE PREVIEW',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade400,
                        letterSpacing: 1,
                      )),
                  const SizedBox(height: 10),
                  preview,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// SUBTITLE CHIP
// ==========================================

class _SubtitleChip extends StatelessWidget {
  const _SubtitleChip(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 12, color: Colors.orange.shade800)),
    );
  }
}
