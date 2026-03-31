import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../presentation/widgets/common/game_button.dart';

extension BuildContextExtensions on BuildContext {
  // Theme shortcuts
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  // Media query shortcuts
  MediaQueryData get mediaQuery => MediaQuery.of(this);
  Size get screenSize => mediaQuery.size;
  double get screenWidth => screenSize.width;
  double get screenHeight => screenSize.height;
  EdgeInsets get padding => mediaQuery.padding;
  EdgeInsets get viewInsets => mediaQuery.viewInsets;
  bool get isKeyboardOpen => viewInsets.bottom > 0;

  // Responsive breakpoints
  bool get isMobile => screenWidth < 600;
  bool get isTablet => screenWidth >= 600 && screenWidth < 1200;
  bool get isDesktop => screenWidth >= 1200;

  // Localization
  AppLocalizations get l10n => AppLocalizations.of(this);

  // Navigation shortcuts
  NavigatorState get navigator => Navigator.of(this);

  // Note: pop() removed - use GoRouter's context.pop() instead

  Future<T?> pushPage<T>(Widget page) {
    return navigator.push<T>(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  // Snackbar helper
  void showSnackBar(
    String message, {
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
    Color? backgroundColor,
  }) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        action: action,
        backgroundColor: backgroundColor,
      ),
    );
  }

  void showErrorSnackBar(String message) {
    showSnackBar(
      message,
      backgroundColor: colorScheme.error,
    );
  }

  void showSuccessSnackBar(String message) {
    showSnackBar(
      message,
      backgroundColor: Colors.green,
    );
  }

  // Dialog helper
  Future<bool?> showConfirmDialog({
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: this,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: (isDestructive ? AppColors.danger : AppColors.secondary)
                        .withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isDestructive
                        ? Icons.warning_rounded
                        : Icons.help_outline_rounded,
                    color: isDestructive ? AppColors.danger : AppColors.secondary,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: GoogleFonts.nunito(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    color: AppColors.neutralText,
                  ),
                ),
                const SizedBox(height: 24),
                GameButton(
                  label: cancelText,
                  onPressed: () => Navigator.of(ctx).pop(false),
                  variant: GameButtonVariant.neutral,
                  fullWidth: true,
                ),
                const SizedBox(height: 8),
                GameButton(
                  label: confirmText,
                  onPressed: () => Navigator.of(ctx).pop(true),
                  variant: isDestructive
                      ? GameButtonVariant.danger
                      : GameButtonVariant.primary,
                  fullWidth: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Unfocus keyboard
  void unfocus() {
    FocusScope.of(this).unfocus();
  }
}
