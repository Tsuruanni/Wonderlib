import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:universal_html/html.dart' as html;

/// Loads a static template file from `assets/import_templates/` and triggers
/// a browser download. Shared across vocabulary / users / book / wordlist
/// import screens so the operator gets a consistent "Şablon İndir" affordance.
class TemplateDownloadButton extends StatelessWidget {
  const TemplateDownloadButton({
    super.key,
    required this.assetPath,
    required this.downloadFilename,
    required this.contentType,
    this.label = 'Şablon İndir',
    this.icon = Icons.file_download_outlined,
    this.style,
  });

  /// Path to the template file (e.g. `assets/import_templates/users_template.csv`).
  /// Must be declared in `pubspec.yaml` `flutter.assets`.
  final String assetPath;

  /// What the file should be named when saved by the browser.
  final String downloadFilename;

  /// Mime type for the Blob (e.g. `text/csv;charset=utf-8;`,
  /// `application/json`).
  final String contentType;

  final String label;
  final IconData icon;
  final ButtonStyle? style;

  Future<void> _download(BuildContext context) async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      final blob = html.Blob([raw], contentType);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', downloadFilename)
        ..click();
      html.Url.revokeObjectUrl(url);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Şablon indirildi: $downloadFilename'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Şablon yüklenemedi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => _download(context),
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: style,
    );
  }
}
