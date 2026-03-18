import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

/// Result of a CSV import operation
class CsvImportResult {
  const CsvImportResult({
    required this.imported,
    required this.updated,
    required this.errors,
  });

  final int imported;
  final int updated;
  final List<String> errors;

  int get total => imported + updated;
  bool get hasErrors => errors.isNotEmpty;
}

/// Reusable CSV import dialog for Users and Vocabulary
class CsvImportDialog extends StatefulWidget {
  const CsvImportDialog({
    super.key,
    required this.title,
    required this.expectedHeaders,
    required this.requiredHeaders,
    required this.processRow,
    required this.onComplete,
  });

  final String title;
  final List<String> expectedHeaders;
  final List<String> requiredHeaders;

  /// Process a single row. Returns null on success, or an error message.
  final Future<String?> Function(Map<String, String> row) processRow;
  final VoidCallback onComplete;

  @override
  State<CsvImportDialog> createState() => _CsvImportDialogState();
}

class _CsvImportDialogState extends State<CsvImportDialog> {
  List<List<dynamic>>? _csvData;
  List<String>? _headers;
  String? _fileName;
  String? _validationError;
  bool _isImporting = false;
  CsvImportResult? _result;
  double _progress = 0;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) {
      setState(() => _validationError = 'Dosya okunamadı');
      return;
    }

    try {
      final content = utf8.decode(file.bytes!);
      final csvData = const CsvToListConverter().convert(content);

      if (csvData.isEmpty) {
        setState(() => _validationError = 'CSV dosyası boş');
        return;
      }

      final headers = csvData.first.map((e) => e.toString().toLowerCase().trim()).toList();

      // Validate required headers
      final missingHeaders = widget.requiredHeaders
          .where((h) => !headers.contains(h.toLowerCase()))
          .toList();

      if (missingHeaders.isNotEmpty) {
        setState(() {
          _validationError = 'Eksik zorunlu sütunlar: ${missingHeaders.join(', ')}\n\n'
              'Beklenen format: ${widget.expectedHeaders.join(',')}';
          _csvData = null;
          _headers = null;
          _fileName = null;
        });
        return;
      }

      setState(() {
        _csvData = csvData;
        _headers = headers.cast<String>();
        _fileName = file.name;
        _validationError = null;
        _result = null;
      });
    } catch (e) {
      setState(() => _validationError = 'CSV ayrıştırma hatası: $e');
    }
  }

  Future<void> _import() async {
    if (_csvData == null || _headers == null) return;

    setState(() {
      _isImporting = true;
      _progress = 0;
    });

    int imported = 0;
    int updated = 0;
    final errors = <String>[];

    // Skip header row
    final dataRows = _csvData!.skip(1).toList();
    final total = dataRows.length;

    for (var i = 0; i < dataRows.length; i++) {
      final row = dataRows[i];
      final rowMap = <String, String>{};

      for (var j = 0; j < _headers!.length && j < row.length; j++) {
        rowMap[_headers![j]] = row[j]?.toString().trim() ?? '';
      }

      try {
        final error = await widget.processRow(rowMap);
        if (error != null) {
          errors.add('Satır ${i + 2}: $error');
        } else {
          // Check if it was an update or insert based on error message
          // For simplicity, count all as imported
          imported++;
        }
      } catch (e) {
        errors.add('Satır ${i + 2}: $e');
      }

      setState(() => _progress = (i + 1) / total);
    }

    setState(() {
      _isImporting = false;
      _result = CsvImportResult(
        imported: imported,
        updated: updated,
        errors: errors,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Row(
              children: [
                const Icon(Icons.upload_file, size: 28),
                const SizedBox(width: 12),
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // File picker or result
            if (_result != null) ...[
              _buildResult(),
            ] else if (_isImporting) ...[
              _buildProgress(),
            ] else ...[
              _buildFilePicker(),
            ],

            const SizedBox(height: 24),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    if (_result != null) {
                      widget.onComplete();
                    }
                    Navigator.of(context).pop();
                  },
                  child: Text(_result != null ? 'Kapat' : 'İptal'),
                ),
                if (_csvData != null && _result == null && !_isImporting) ...[
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _import,
                    child: const Text('İçe Aktar'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Expected format
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Beklenen CSV formatı:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                widget.expectedHeaders.join(','),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Zorunlu: ${widget.requiredHeaders.join(', ')}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // File picker button
        InkWell(
          onTap: _pickFile,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    _fileName != null ? Icons.check_circle : Icons.cloud_upload,
                    size: 40,
                    color: _fileName != null ? Colors.green : Colors.grey.shade400,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _fileName ?? 'CSV dosyası seçmek için tıklayın',
                    style: TextStyle(
                      color: _fileName != null ? Colors.black : Colors.grey.shade600,
                    ),
                  ),
                  if (_csvData != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${_csvData!.length - 1} satır',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),

        // Validation error
        if (_validationError != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _validationError!,
                    style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProgress() {
    return Column(
      children: [
        const SizedBox(height: 20),
        LinearProgressIndicator(value: _progress),
        const SizedBox(height: 16),
        Text(
          'İçe aktarılıyor... ${(_progress * 100).toInt()}%',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildResult() {
    final result = _result!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Success summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: result.hasErrors ? Colors.orange.shade50 : Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                result.hasErrors ? Icons.warning_amber : Icons.check_circle,
                color: result.hasErrors ? Colors.orange.shade700 : Colors.green.shade700,
                size: 32,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'İçe Aktarma Tamamlandı',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: result.hasErrors
                            ? Colors.orange.shade900
                            : Colors.green.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${result.imported} başarıyla içe aktarıldı',
                      style: TextStyle(
                        color: result.hasErrors
                            ? Colors.orange.shade700
                            : Colors.green.shade700,
                      ),
                    ),
                    if (result.hasErrors)
                      Text(
                        '${result.errors.length} hata',
                        style: TextStyle(color: Colors.orange.shade700),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Error list
        if (result.hasErrors) ...[
          const SizedBox(height: 16),
          Text(
            'Hatalar:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.red.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: result.errors
                    .map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            e,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
