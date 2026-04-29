import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Wraps an edit screen with two universal keyboard shortcuts:
/// - `Cmd/Ctrl+S` triggers [onSave]
/// - `Esc` triggers [onEscape] (defaults to popping the current route)
///
/// Use by wrapping the whole `Scaffold` returned from `build`:
///
/// ```dart
/// return EditScreenShortcuts(
///   onSave: _isSaving ? null : _save,
///   child: Scaffold(...),
/// );
/// ```
///
/// Pass `null` for [onSave] while saving is in progress to prevent re-entry.
class EditScreenShortcuts extends StatelessWidget {
  const EditScreenShortcuts({
    super.key,
    required this.child,
    this.onSave,
    this.onEscape,
  });

  final Widget child;
  final VoidCallback? onSave;
  final VoidCallback? onEscape;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        if (onSave != null) ...{
          const SingleActivator(LogicalKeyboardKey.keyS, meta: true): onSave!,
          const SingleActivator(LogicalKeyboardKey.keyS, control: true):
              onSave!,
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (onEscape != null) {
            onEscape!();
            return;
          }
          final nav = Navigator.of(context);
          if (nav.canPop()) nav.pop();
        },
      },
      child: Focus(
        autofocus: true,
        child: child,
      ),
    );
  }
}
