import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../widgets/brand_logo.dart';

/// One line of a printed document. Inquiries carry no pricing, so the
/// money columns are dropped when [DocumentView.hasPricing] is false.
class DocLineView {
  final String product;
  final double quantity;
  final double unitPrice;
  final double discountPercent;

  /// Which tax applies, named as it is in the Tax master (e.g. "GST 18%"),
  /// and its rate. Null/0 when the line carries no tax.
  final String? taxLabel;
  final double taxPercent;

  /// Pre-tax line amount: qty x rate less discount. Tax lands once in the
  /// totals block, so these add up to the subtotal.
  final double lineTotal;

  const DocLineView({
    required this.product,
    required this.quantity,
    this.unitPrice = 0,
    this.discountPercent = 0,
    this.taxLabel,
    this.taxPercent = 0,
    this.lineTotal = 0,
  });

  double get taxAmount => lineTotal * taxPercent / 100;
}

/// An extra charge on the document (labour, parking, freight...), printed
/// under the item table rather than in it -- it is money, not goods.
class DocChargeView {
  final String label;
  final double amount;
  final double taxPercent;

  const DocChargeView({required this.label, this.amount = 0, this.taxPercent = 0});

  double get taxAmount => amount * taxPercent / 100;
  double get total => amount + taxAmount;
}

/// Everything needed to render a sales document, on screen (read-only
/// view) or on paper (PDF). Built by the list screens, which already hold
/// the customer/product/tax lists needed to turn ids into names.
class DocumentView {
  final String docType; // 'Sales Inquiry' | 'Quotation' | 'Sales Order'
  final String docNo;
  final String status;
  final bool isLocked;
  final String customer;
  final Map<String, String> fields; // date, valid until, source document...
  final String? billingAddress;
  final String? shippingAddress;
  final List<DocLineView> lines;
  final List<DocChargeView> charges;
  final bool hasPricing;
  final double subtotal;
  final double chargesTotal;
  final double taxAmount;
  final double totalAmount;
  final String? notes;

  const DocumentView({
    required this.docType,
    required this.docNo,
    required this.status,
    required this.isLocked,
    required this.customer,
    required this.fields,
    this.billingAddress,
    this.shippingAddress,
    required this.lines,
    this.charges = const [],
    required this.hasPricing,
    this.subtotal = 0,
    this.chargesTotal = 0,
    this.taxAmount = 0,
    this.totalAmount = 0,
    this.notes,
  });
}

String _money(double v) => v.toStringAsFixed(2);
String _qty(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

/// Builds the printable document. Kept deliberately plain -- black text,
/// one accent rule -- so it prints legibly on any office printer.
Future<Uint8List> buildDocumentPdf(DocumentView doc) async {
  final pdf = pw.Document(title: '${doc.docType} ${doc.docNo}');
  // Company mark, shared with the dashboard (widgets/brand_logo.dart).
  // Null if the asset can't be read -- the document still prints.
  final logoBytes = await loadLogoBytes();
  final logo = logoBytes == null ? null : pw.MemoryImage(logoBytes);
  const accent = PdfColor.fromInt(0xFF1D4ED8);
  const muted = PdfColor.fromInt(0xFF64748B);

  pw.Widget label(String text) =>
      pw.Text(text, style: const pw.TextStyle(fontSize: 8, color: muted));

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (context) => context.pageNumber == 1
          ? pw.SizedBox()
          : pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 12),
              child: pw.Text('${doc.docType} ${doc.docNo} (continued)',
                  style: const pw.TextStyle(fontSize: 9, color: muted)),
            ),
      footer: (context) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(kCompanyName, style: const pw.TextStyle(fontSize: 8, color: muted)),
          pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: muted)),
        ],
      ),
      build: (context) => [
        // ---- title block -------------------------------------------------
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              if (logo != null) ...[
                pw.Image(logo, height: 52),
                pw.SizedBox(width: 12),
              ],
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(kCompanyName,
                    style: const pw.TextStyle(
                        fontSize: 15, fontWeight: pw.FontWeight.bold, color: accent)),
                pw.SizedBox(height: 2),
                pw.Text(doc.docType, style: const pw.TextStyle(fontSize: 12, color: muted)),
              ]),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text(doc.docNo,
                  style: const pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: muted, width: 0.5),
                  borderRadius: pw.BorderRadius.circular(3),
                ),
                child: pw.Text(doc.status, style: const pw.TextStyle(fontSize: 9)),
              ),
            ]),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Divider(color: accent, thickness: 1),
        pw.SizedBox(height: 12),

        // ---- customer + dates -------------------------------------------
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(
            flex: 3,
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              label('CUSTOMER'),
              pw.Text(doc.customer,
                  style: const pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ]),
          ),
          pw.Expanded(
            flex: 2,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: doc.fields.entries
                  .map((e) => pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 4),
                        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                          label(e.key.toUpperCase()),
                          pw.Text(e.value, style: const pw.TextStyle(fontSize: 10)),
                        ]),
                      ))
                  .toList(),
            ),
          ),
        ]),
        pw.SizedBox(height: 14),

        // ---- addresses ---------------------------------------------------
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              label('BILL TO'),
              pw.Text(doc.billingAddress?.trim().isNotEmpty == true ? doc.billingAddress! : '--',
                  style: const pw.TextStyle(fontSize: 10)),
            ]),
          ),
          pw.SizedBox(width: 24),
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              label('SHIP TO'),
              pw.Text(doc.shippingAddress?.trim().isNotEmpty == true ? doc.shippingAddress! : '--',
                  style: const pw.TextStyle(fontSize: 10)),
            ]),
          ),
        ]),
        pw.SizedBox(height: 16),

        // ---- line items --------------------------------------------------
        pw.TableHelper.fromTextArray(
          headers: doc.hasPricing
              ? ['#', 'Product', 'Qty', 'Rate', 'Disc %', 'Tax', 'Tax %', 'Tax Amt', 'Amount']
              : ['#', 'Product', 'Qty'],
          data: [
            for (var i = 0; i < doc.lines.length; i++)
              doc.hasPricing
                  ? [
                      '${i + 1}',
                      doc.lines[i].product,
                      _qty(doc.lines[i].quantity),
                      _money(doc.lines[i].unitPrice),
                      _money(doc.lines[i].discountPercent),
                      doc.lines[i].taxLabel ?? '--',
                      _money(doc.lines[i].taxPercent),
                      _money(doc.lines[i].taxAmount),
                      _money(doc.lines[i].lineTotal),
                    ]
                  : ['${i + 1}', doc.lines[i].product, _qty(doc.lines[i].quantity)],
          ],
          headerStyle: const pw.TextStyle(
              fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: accent),
          cellStyle: const pw.TextStyle(fontSize: 8),
          cellHeight: 20,
          columnWidths: doc.hasPricing
              ? {
                  0: const pw.FixedColumnWidth(18),
                  1: const pw.FlexColumnWidth(3),
                  5: const pw.FlexColumnWidth(1.4),
                }
              : null,
          cellAlignments: {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.centerLeft,
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight,
            4: pw.Alignment.centerRight,
            5: pw.Alignment.centerLeft, // tax name
            6: pw.Alignment.centerRight,
            7: pw.Alignment.centerRight,
            8: pw.Alignment.centerRight,
          },
        ),

        // ---- extra charges -----------------------------------------------
        if (doc.charges.isNotEmpty) ...[
          pw.SizedBox(height: 12),
          label('EXTRA CHARGES'),
          pw.SizedBox(height: 4),
          pw.TableHelper.fromTextArray(
            headers: ['Charge', 'Amount', 'Tax %', 'Tax Amt', 'Total'],
            data: [
              for (final c in doc.charges)
                [
                  c.label,
                  _money(c.amount),
                  _money(c.taxPercent),
                  _money(c.taxAmount),
                  _money(c.total),
                ],
            ],
            headerStyle: const pw.TextStyle(
                fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: muted),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellHeight: 18,
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
            },
          ),
        ],

        // ---- totals ------------------------------------------------------
        if (doc.hasPricing) ...[
          pw.SizedBox(height: 10),
          // The PDF's built-in Helvetica has no rupee glyph, so the
          // currency is stated once here instead of per amount.
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('All amounts in INR',
                style: const pw.TextStyle(fontSize: 8, color: muted)),
          ),
          pw.SizedBox(height: 4),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
            pw.SizedBox(
              width: 200,
              child: pw.Column(children: [
                _totalRow('Subtotal', _money(doc.subtotal)),
                if (doc.chargesTotal != 0) _totalRow('Extra charges', _money(doc.chargesTotal)),
                _totalRow('Tax', _money(doc.taxAmount)),
                pw.Divider(color: muted, thickness: 0.5),
                _totalRow('Total', _money(doc.totalAmount), bold: true),
              ]),
            ),
          ]),
        ],

        if (doc.notes != null && doc.notes!.trim().isNotEmpty) ...[
          pw.SizedBox(height: 18),
          label('NOTES'),
          pw.Text(doc.notes!, style: const pw.TextStyle(fontSize: 9)),
        ],
      ],
    ),
  );

  return pdf.save();
}

pw.Widget _totalRow(String label, String value, {bool bold = false}) {
  final style = pw.TextStyle(fontSize: bold ? 11 : 10, fontWeight: bold ? pw.FontWeight.bold : null);
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text(label, style: style),
      pw.Text(value, style: style),
    ]),
  );
}
