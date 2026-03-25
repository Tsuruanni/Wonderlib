import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/entities/teacher.dart';

/// Generates a PDF document with student login cards.
///
/// A4 format, 2 columns × 5 rows = 10 cards per page.
/// Each card shows: name, username, password, QR code, download URL.
Future<Uint8List> generateLoginCardsPdf({
  required List<StudentSummary> students,
  required String schoolName,
  required String className,
}) async {
  final pdf = pw.Document();
  const cardsPerPage = 10;
  const columns = 2;
  const downloadUrl = 'owlio.co/download';
  final now = DateTime.now();
  final dateStr = '${_monthName(now.month)} ${now.day}, ${now.year}';

  final totalPages = students.isEmpty ? 1 : (students.length / cardsPerPage).ceil();

  for (var page = 0; page < totalPages; page++) {
    final startIdx = page * cardsPerPage;
    final endIdx = (startIdx + cardsPerPage).clamp(0, students.length);
    final pageStudents = students.sublist(startIdx, endIdx);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(schoolName, className, dateStr),
              pw.SizedBox(height: 12),
              pw.Expanded(
                child: pw.Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: pageStudents.map((student) {
                    return _buildCard(
                      student: student,
                      downloadUrl: downloadUrl,
                      cardWidth: (PdfPageFormat.a4.width - 48 - 12) / columns,
                    );
                  }).toList(),
                ),
              ),
              _buildFooter(schoolName, page + 1, totalPages),
            ],
          );
        },
      ),
    );
  }

  return pdf.save();
}

pw.Widget _buildHeader(String schoolName, String className, String dateStr) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                schoolName,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#008080'),
                ),
              ),
              pw.Text(
                'Student Login Cards',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColor.fromHex('#008080'),
                ),
              ),
            ],
          ),
          pw.Text(dateStr, style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
      pw.SizedBox(height: 8),
      pw.Divider(color: PdfColor.fromHex('#008080'), thickness: 2),
      pw.SizedBox(height: 8),
      pw.Text(
        className,
        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
      ),
    ],
  );
}

pw.Widget _buildCard({
  required StudentSummary student,
  required String downloadUrl,
  required double cardWidth,
}) {
  final username = student.email ?? student.studentNumber ?? 'N/A';
  final password = student.passwordPlain ?? 'N/A';

  return pw.Container(
    width: cardWidth,
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey400),
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                student.fullName,
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                maxLines: 1,
              ),
              pw.SizedBox(height: 6),
              pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: 'Username:\n',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#008080'),
                      ),
                    ),
                    pw.TextSpan(text: username, style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
              pw.SizedBox(height: 4),
              pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: 'Password:\n',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#008080'),
                      ),
                    ),
                    pw.TextSpan(text: password, style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                downloadUrl,
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
              ),
            ],
          ),
        ),
        pw.SizedBox(width: 8),
        pw.BarcodeWidget(
          barcode: pw.Barcode.qrCode(),
          data: 'https://$downloadUrl',
          width: 50,
          height: 50,
        ),
      ],
    ),
  );
}

pw.Widget _buildFooter(String schoolName, int currentPage, int totalPages) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(schoolName, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
      pw.Text('Page $currentPage of $totalPages', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
    ],
  );
}

String _monthName(int month) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return months[month - 1];
}
