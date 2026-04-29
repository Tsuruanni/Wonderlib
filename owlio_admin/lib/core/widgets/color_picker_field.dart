import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A form field that lets the user pick a color either by tapping a swatch
/// from a curated Material palette or by typing a hex code directly.
///
/// Stores and reports values as hex strings (e.g. `#58CC02`). Accepts both
/// `#RRGGBB` and `RRGGBB` on input; always emits the leading `#`.
class ColorPickerField extends StatefulWidget {
  const ColorPickerField({
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
  State<ColorPickerField> createState() => _ColorPickerFieldState();
}

class _ColorPickerFieldState extends State<ColorPickerField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '');
  }

  @override
  void didUpdateWidget(covariant ColorPickerField old) {
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

  Color? _parse(String value) {
    final cleaned = value.trim().replaceAll('#', '');
    if (cleaned.length != 6) return null;
    final v = int.tryParse(cleaned, radix: 16);
    if (v == null) return null;
    return Color(0xFF000000 | v);
  }

  String _normalize(String value) {
    final cleaned = value.trim().replaceAll('#', '').toUpperCase();
    if (cleaned.length != 6) return value;
    return '#$cleaned';
  }

  Future<void> _openDialog() async {
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => _ColorPickerDialog(initialHex: _controller.text),
    );
    if (picked != null) {
      _controller.text = picked;
      widget.onChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _parse(_controller.text);
    return TextFormField(
      controller: _controller,
      enabled: widget.enabled,
      decoration: InputDecoration(
        labelText: widget.labelText,
        helperText: widget.helperText,
        hintText: '#RRGGBB',
        border: const OutlineInputBorder(),
        prefixIcon: GestureDetector(
          onTap: widget.enabled ? _openDialog : null,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: color ?? Colors.grey.shade200,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: color == null
                  ? Icon(Icons.help_outline,
                      size: 14, color: Colors.grey.shade600)
                  : null,
            ),
          ),
        ),
        suffixIcon: IconButton(
          tooltip: 'Renk seç',
          icon: const Icon(Icons.palette_outlined),
          onPressed: widget.enabled ? _openDialog : null,
        ),
      ),
      inputFormatters: [
        // Allow #, 0-9, a-f, A-F only; cap to 7 chars (#RRGGBB)
        LengthLimitingTextInputFormatter(7),
        FilteringTextInputFormatter.allow(RegExp('[#0-9a-fA-F]')),
      ],
      onChanged: (value) {
        final normalized = _normalize(value);
        if (normalized != value) {
          _controller.value = TextEditingValue(
            text: normalized,
            selection: TextSelection.collapsed(offset: normalized.length),
          );
        }
        widget.onChanged(normalized);
      },
    );
  }
}

class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({required this.initialHex});

  final String initialHex;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late final TextEditingController _hexController;
  String _selected = '';

  @override
  void initState() {
    super.initState();
    _hexController = TextEditingController(text: widget.initialHex);
    _selected = widget.initialHex;
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  void _select(String hex) {
    setState(() {
      _selected = hex;
      _hexController.text = hex;
    });
  }

  Color? _parse(String value) {
    final cleaned = value.trim().replaceAll('#', '');
    if (cleaned.length != 6) return null;
    final v = int.tryParse(cleaned, radix: 16);
    if (v == null) return null;
    return Color(0xFF000000 | v);
  }

  @override
  Widget build(BuildContext context) {
    final preview = _parse(_selected);

    return AlertDialog(
      title: const Text('Renk Seç'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Palette grid
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final hex in _kPalette)
                  _Swatch(
                    hex: hex,
                    selected: _selected.toUpperCase() == hex,
                    onTap: () => _select(hex),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Hex input + live preview
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _hexController,
                    decoration: const InputDecoration(
                      labelText: 'Hex',
                      hintText: '#RRGGBB',
                      border: OutlineInputBorder(),
                    ),
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(7),
                      FilteringTextInputFormatter.allow(
                          RegExp('[#0-9a-fA-F]')),
                    ],
                    onChanged: (v) => setState(() => _selected = v.toUpperCase()),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: preview ?? Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: preview == null
                      ? Icon(Icons.help_outline,
                          color: Colors.grey.shade500)
                      : null,
                ),
              ],
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
          onPressed: preview == null
              ? null
              : () {
                  final cleaned = _selected.trim().replaceAll('#', '');
                  Navigator.of(context).pop('#${cleaned.toUpperCase()}');
                },
          child: const Text('Seç'),
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.hex,
    required this.selected,
    required this.onTap,
  });

  final String hex;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(0xFF000000 |
        int.parse(hex.replaceAll('#', ''), radix: 16));
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? Colors.black : Colors.grey.shade300,
            width: selected ? 2.5 : 1,
          ),
        ),
        child: selected
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : null,
      ),
    );
  }
}

/// Curated palette: Duolingo-leaning green-first set, plus the standard
/// admin accents already used across `lib/features/dashboard` and tile themes.
const List<String> _kPalette = [
  // Greens (Duolingo)
  '#58CC02', '#2FA827', '#88D43F', '#10B981', '#059669',
  // Blues
  '#1CB0F6', '#0891B2', '#4F46E5', '#3B82F6', '#1E40AF',
  // Purples / pinks
  '#7C3AED', '#A855F7', '#DB2777', '#E11D48', '#EC4899',
  // Oranges / reds
  '#FF9600', '#F97316', '#EA580C', '#F59E0B', '#DC2626',
  // Earth + neutral
  '#A52A2A', '#78350F', '#525252', '#1F2937', '#000000',
];
