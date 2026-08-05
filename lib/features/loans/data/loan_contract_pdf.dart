import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// RN `createPDF` / contract download for My Loans history rows.
class LoanContractPdfService {
  LoanContractPdfService._();

  /// Prefer remote `PublicURL`/`DownloadURL` (current backend); else generate PDF.
  static Future<void> downloadOrShare({
    required Map<String, dynamic> offer,
    required int index,
    String? borrowerName,
  }) async {
    final payload = offer['data'] is Map
        ? Map<String, dynamic>.from(offer['data'] as Map)
        : offer;

    final remote = (payload['PublicURL'] ??
            payload['DownloadURL'] ??
            payload['public_url'] ??
            payload['download_url'])
        ?.toString();
    if (remote != null && remote.isNotEmpty) {
      final uri = Uri.tryParse(remote);
      if (uri != null) {
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (ok) return;
      }
    }

    await generateAndShare(
      offer: payload,
      index: index,
      borrowerName: borrowerName,
    );
  }

  static Future<File> generateAndShare({
    required Map<String, dynamic> offer,
    required int index,
    String? borrowerName,
  }) async {
    final bytes = await buildPdfBytes(offer);
    final name = _fileName(offer, index, borrowerName);
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'Loan Contract',
        text: 'Zap Money loan contract',
      ),
    );
    return file;
  }

  static Future<void> preview(Map<String, dynamic> offer) async {
    await Printing.layoutPdf(
      onLayout: (_) async => Uint8List.fromList(await buildPdfBytes(offer)),
      name: 'Loan Contract',
    );
  }

  static Future<Uint8List> buildPdfBytes(Map<String, dynamic> offer) async {
    final pdf = pw.Document();
    final disbursement = offer['disbursement'] is Map
        ? Map<String, dynamic>.from(offer['disbursement'] as Map)
        : <String, dynamic>{};
    final pd = offer['pd'] is Map
        ? Map<String, dynamic>.from(offer['pd'] as Map)
        : <String, dynamic>{};
    final lenders = offer['lenderAnnexure'] is List
        ? (offer['lenderAnnexure'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : const <Map<String, dynamic>>[];

    final lai = _s(offer['lai'] ?? disbursement['lai']);
    final amount = _s(
      offer['offeredLoanAmt'] ??
          disbursement['loanAmt'] ??
          offer['loanAmt'] ??
          offer['DocumentName'],
    );
    final tenure = _s(
      offer['offeredLoanTenure'] ??
          disbursement['tenure'] ??
          offer['loanTenure'],
    );
    final rate = _s(offer['interestRate'] ?? disbursement['interestRate']);
    final dt = _s(offer['dt'] ?? disbursement['dt']);
    final ip = _s(offer['ipAddress'] ?? disbursement['ipAddress']);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Zap Money — Loan Contract',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromInt(0xFF3A2165),
              ),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Loan offer acceptance and disbursement summary.',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 20),
          _sectionTitle('Offer Acceptance'),
          _kvTable([
            ['LAI / Contract', lai],
            ['Amount (₹)', amount],
            ['Tenure (Months)', tenure],
            ['Interest Rate (p.a.)', rate],
            ['Date', dt],
            ['IP Address', ip],
          ]),
          pw.SizedBox(height: 16),
          _sectionTitle('Borrower Acceptance'),
          _kvTable([
            ['Date and Time', _s(pd['dateAndTime'] ?? pd['dt'])],
            ['IP Address', _s(pd['ipAddress'])],
            ['Name', _s(pd['name'] ?? pd['customerName'])],
          ]),
          pw.SizedBox(height: 16),
          _sectionTitle('Loan Disbursement'),
          _kvTable([
            ['LAI', lai],
            ['Disbursed Loan Amount (₹)', amount],
            ['Loan Tenor (Months)', tenure],
            ['Interest Rate (p.a.)', rate],
            ['Date', dt],
          ]),
          if (lenders.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _sectionTitle('Lender Annexure'),
            pw.TableHelper.fromTextArray(
              headers: const [
                'Customer ID',
                'Investment Order',
                'Booking Order',
                'Amount (₹)',
                'IP Address',
              ],
              data: lenders
                  .map(
                    (i) => [
                      _s(i['customerId']),
                      _s(i['investmtOrder'] ?? i['investmentOrder']),
                      _s(i['bookingOrder']),
                      _s(i['amt'] ?? i['amount']),
                      _s(i['ipAddress']),
                    ],
                  )
                  .toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
                fontSize: 9,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF577736),
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellAlignment: pw.Alignment.centerLeft,
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.3),
            ),
          ],
          pw.SizedBox(height: 24),
          pw.Text(
            'Generated from Zap Money. Full facility terms are as accepted '
            'during loan origination.',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _sectionTitle(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 13,
          fontWeight: pw.FontWeight.bold,
          color: PdfColor.fromInt(0xFF539515),
        ),
      ),
    );
  }

  static pw.Widget _kvTable(List<List<String>> rows) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
      children: rows.map((r) {
        return pw.TableRow(
          children: [
            pw.Container(
              color: PdfColor.fromInt(0xFF577736),
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(
                r[0],
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Container(
              color: PdfColor.fromInt(0xFFEBF3E0),
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(
                r[1].isEmpty ? '—' : r[1],
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  static String _fileName(
    Map<String, dynamic> offer,
    int index,
    String? borrowerName,
  ) {
    final stamp = DateFormat('d MMM').format(DateTime.now());
    if (index == 0) return 'Loan Contract_$stamp.pdf';
    final safe = (borrowerName ?? offer['lai'] ?? 'loan')
        .toString()
        .replaceAll(RegExp(r'[^\w\- ]'), '')
        .trim();
    return 'Loan Contract_$safe($index).pdf';
  }

  static String _s(dynamic v) {
    if (v == null) return '';
    return v.toString().trim();
  }
}
