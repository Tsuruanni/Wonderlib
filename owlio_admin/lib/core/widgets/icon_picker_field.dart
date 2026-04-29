import 'package:flutter/material.dart';

/// A form field for picking a Material icon by name from a curated grid.
///
/// Stores and reports values as the icon name string (e.g. `"school"`).
/// The actual `IconData` is looked up via [kAdminIcons].
class IconPickerField extends StatefulWidget {
  const IconPickerField({
    super.key,
    required this.initialValue,
    required this.onChanged,
    this.labelText,
    this.helperText,
    this.enabled = true,
  });

  final String? initialValue;
  final ValueChanged<String> onChanged;
  final String? labelText;
  final String? helperText;
  final bool enabled;

  @override
  State<IconPickerField> createState() => _IconPickerFieldState();
}

class _IconPickerFieldState extends State<IconPickerField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '');
  }

  @override
  void didUpdateWidget(covariant IconPickerField old) {
    super.didUpdateWidget(old);
    if ((old.initialValue ?? '') != (widget.initialValue ?? '') &&
        _controller.text != (widget.initialValue ?? '')) {
      _controller.text = widget.initialValue ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openDialog() async {
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => _IconPickerDialog(initialName: _controller.text),
    );
    if (picked != null) {
      _controller.text = picked;
      widget.onChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconData = kAdminIcons[_controller.text.trim()];
    return TextFormField(
      controller: _controller,
      enabled: widget.enabled,
      decoration: InputDecoration(
        labelText: widget.labelText,
        helperText: widget.helperText,
        hintText: 'school',
        border: const OutlineInputBorder(),
        prefixIcon: GestureDetector(
          onTap: widget.enabled ? _openDialog : null,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Icon(
                iconData ?? Icons.help_outline,
                size: 18,
                color: iconData == null
                    ? Colors.grey.shade500
                    : Colors.grey.shade800,
              ),
            ),
          ),
        ),
        suffixIcon: IconButton(
          tooltip: 'Simge seç',
          icon: const Icon(Icons.grid_view_outlined),
          onPressed: widget.enabled ? _openDialog : null,
        ),
      ),
      onChanged: widget.onChanged,
    );
  }
}

class _IconPickerDialog extends StatefulWidget {
  const _IconPickerDialog({required this.initialName});

  final String initialName;

  @override
  State<_IconPickerDialog> createState() => _IconPickerDialogState();
}

class _IconPickerDialogState extends State<_IconPickerDialog> {
  String _query = '';
  String _selected = '';

  @override
  void initState() {
    super.initState();
    _selected = widget.initialName;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? kAdminIcons.entries.toList()
        : kAdminIcons.entries
            .where((e) => e.key.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    return AlertDialog(
      title: const Text('Simge Seç'),
      content: SizedBox(
        width: 480,
        height: 460,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Ara (ör. school, star, book)',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'Aramaya uygun simge bulunamadı',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 8,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final entry = filtered[i];
                        final isSelected = entry.key == _selected;
                        return InkWell(
                          onTap: () => setState(() => _selected = entry.key),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.indigo.withValues(alpha: 0.1)
                                  : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.indigo
                                    : Colors.grey.shade200,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Tooltip(
                              message: entry.key,
                              child: Icon(
                                entry.value,
                                size: 22,
                                color: isSelected
                                    ? Colors.indigo
                                    : Colors.grey.shade800,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (_selected.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(
                      kAdminIcons[_selected] ?? Icons.help_outline,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _selected,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.of(context).pop(_selected),
          child: const Text('Seç'),
        ),
      ],
    );
  }
}

/// Curated set of Material icons that make sense in admin/education context.
/// Add freely; the picker dialog scales with the map size.
const Map<String, IconData> kAdminIcons = {
  // Education / content
  'school': Icons.school,
  'menu_book': Icons.menu_book,
  'auto_stories': Icons.auto_stories,
  'book': Icons.book,
  'library_books': Icons.library_books,
  'class_': Icons.class_,
  'cast_for_education': Icons.cast_for_education,
  'edit_note': Icons.edit_note,
  'description': Icons.description,
  'assignment': Icons.assignment,
  'fact_check': Icons.fact_check,
  'quiz': Icons.quiz,
  'lightbulb': Icons.lightbulb,
  'translate': Icons.translate,
  'spellcheck': Icons.spellcheck,
  'abc': Icons.abc,
  'format_quote': Icons.format_quote,
  'record_voice_over': Icons.record_voice_over,
  'volume_up': Icons.volume_up,
  'mic': Icons.mic,
  'image': Icons.image,
  'photo_library': Icons.photo_library,
  // Gamification / rewards
  'star': Icons.star,
  'star_outline': Icons.star_outline,
  'emoji_events': Icons.emoji_events,
  'workspace_premium': Icons.workspace_premium,
  'military_tech': Icons.military_tech,
  'verified': Icons.verified,
  'check_circle': Icons.check_circle,
  'celebration': Icons.celebration,
  'bolt': Icons.bolt,
  'flash_on': Icons.flash_on,
  'whatshot': Icons.whatshot,
  'local_fire_department': Icons.local_fire_department,
  'casino': Icons.casino,
  'card_giftcard': Icons.card_giftcard,
  'redeem': Icons.redeem,
  'diamond': Icons.diamond,
  'paid': Icons.paid,
  'monetization_on': Icons.monetization_on,
  'savings': Icons.savings,
  'leaderboard': Icons.leaderboard,
  'trending_up': Icons.trending_up,
  // People
  'person': Icons.person,
  'people': Icons.people,
  'group': Icons.group,
  'face': Icons.face,
  'pets': Icons.pets,
  // System / nav
  'home': Icons.home,
  'dashboard': Icons.dashboard,
  'settings': Icons.settings,
  'tune': Icons.tune,
  'notifications': Icons.notifications,
  'campaign': Icons.campaign,
  'history': Icons.history,
  'timeline': Icons.timeline,
  'bar_chart': Icons.bar_chart,
  'pie_chart': Icons.pie_chart,
  'analytics': Icons.analytics,
  'route': Icons.route,
  'map': Icons.map,
  'flag': Icons.flag,
  'place': Icons.place,
  // Actions
  'add': Icons.add,
  'edit': Icons.edit,
  'delete': Icons.delete,
  'save': Icons.save,
  'send': Icons.send,
  'search': Icons.search,
  'filter_alt': Icons.filter_alt,
  'sort': Icons.sort,
  'refresh': Icons.refresh,
  'sync': Icons.sync,
  'download': Icons.download,
  'upload': Icons.upload,
  'cloud_upload': Icons.cloud_upload,
  // Time / state
  'schedule': Icons.schedule,
  'event': Icons.event,
  'today': Icons.today,
  'lock': Icons.lock,
  'lock_open': Icons.lock_open,
  'visibility': Icons.visibility,
  'visibility_off': Icons.visibility_off,
  // Misc symbolic
  'extension': Icons.extension,
  'auto_awesome': Icons.auto_awesome,
  'spa': Icons.spa,
  'park': Icons.park,
  'wb_sunny': Icons.wb_sunny,
  'nightlight': Icons.nightlight,
  'palette': Icons.palette,
  'brush': Icons.brush,
};
