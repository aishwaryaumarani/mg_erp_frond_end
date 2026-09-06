import 'package:flutter/material.dart';
import '../services/document_pdf.dart';
import 'pdf_preview_page.dart';
import '../theme/app_theme.dart';
import 'status_badge.dart';

/// Read-only view of a sales document, and the only way to open one that
/// has left Draft: once it is Submitted or Approved its customer, lines
/// and pricing are fixed (backend/app/core/workflow.py enforces the same
/// rule), so there is nothing to edit -- only something to read, print or
/// send. Takes the same [DocumentView] the PDF is built from, so screen
/// and paper can never drift apart.
class DocDetailPage extends StatelessWidget {
  final DocumentView doc;
  const DocDetailPage({super.key, required this.doc});

  static Future<void> open(BuildContext context, DocumentView doc) {
    return Navigator.of(context).push(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => DocDetailPage(doc: doc)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.page,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(doc.docNo.isEmpty ? doc.docType : doc.docNo,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            Text(doc.docType, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(children: [
              StatusBadge(status: doc.status),
              if (doc.isLocked) ...[
                const SizedBox(width: 8),
                const Tooltip(
                  message: 'Moved on to the next document -- its status is now fixed',
                  child: Icon(Icons.lock_outline, size: 16, color: AppColors.muted),
                ),
              ],
            ]),
          ),
        ],
        shape: const Border(bottom: BorderSide(color: AppColors.line)),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _Section(title: 'Customer & details', children: [
                _field(doc.partyLabel, doc.customer),
                for (final e in doc.fields.entries) _field(e.key, e.value),
              ]),
              // A purchase invoice carries no ship-to, so the whole card
              // goes rather than showing a row of dashes.
              if (doc.billingLabel.isNotEmpty || doc.shippingLabel.isNotEmpty)
                _Section(title: 'Addresses', children: [
                  if (doc.billingLabel.isNotEmpty) _field(doc.billingLabel, doc.billingAddress),
                  if (doc.shippingLabel.isNotEmpty) _field(doc.shippingLabel, doc.shippingAddress),
                ]),
              _Section(
                title: 'Items',
                children: [
                  if (doc.lines.isEmpty)
                    const Text('No lines on this document.', style: TextStyle(color: AppColors.muted))
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columnSpacing: 28,
                        headingTextStyle: const TextStyle(
                            fontWeight: FontWeight.w700, color: AppColors.ink, fontSize: 13),
                        columns: [
                          const DataColumn(label: Text('Product')),
                          const DataColumn(label: Text('Qty'), numeric: true),
                          if (doc.hasPricing) const DataColumn(label: Text('Rate'), numeric: true),
                          if (doc.hasPricing) const DataColumn(label: Text('Disc %'), numeric: true),
                          if (doc.hasPricing) const DataColumn(label: Text('Tax')),
                          if (doc.hasPricing) const DataColumn(label: Text('Tax %'), numeric: true),
                          if (doc.hasPricing) const DataColumn(label: Text('Tax Amt'), numeric: true),
                          if (doc.hasPricing) const DataColumn(label: Text('Amount'), numeric: true),
                        ],
                        rows: [
                          for (final line in doc.lines)
                            DataRow(cells: [
                              DataCell(Text(line.product)),
                              DataCell(Text(_qty(line.quantity))),
                              if (doc.hasPricing) DataCell(Text(line.unitPrice.toStringAsFixed(2))),
                              if (doc.hasPricing) DataCell(Text(line.discountPercent.toStringAsFixed(2))),
                              if (doc.hasPricing) DataCell(Text(line.taxLabel ?? '--')),
                              if (doc.hasPricing) DataCell(Text(line.taxPercent.toStringAsFixed(2))),
                              if (doc.hasPricing) DataCell(Text(line.taxAmount.toStringAsFixed(2))),
                              if (doc.hasPricing) DataCell(Text(line.lineTotal.toStringAsFixed(2))),
                            ]),
                        ],
                      ),
                    ),
                  if (doc.charges.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const Text('Extra charges',
                        style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink)),
                    const SizedBox(height: 8),
                    for (final c in doc.charges)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(children: [
                          Expanded(child: Text(c.label)),
                          Text('₹${c.amount.toStringAsFixed(2)}',
                              style: const TextStyle(color: AppColors.muted)),
                          SizedBox(
                            width: 90,
                            child: Text('+ ${c.taxPercent.toStringAsFixed(2)}% tax',
                                textAlign: TextAlign.right,
                                style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                          ),
                          SizedBox(
                            width: 110,
                            child: Text('₹${c.total.toStringAsFixed(2)}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ]),
                      ),
                  ],
                  if (doc.hasPricing) ...[
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: 320,
                        child: Column(children: [
                          _total('Subtotal', doc.subtotal),
                          if (doc.chargesTotal != 0) _total('Extra charges', doc.chargesTotal),
                          _total('Tax', doc.taxAmount),
                          const Divider(),
                          _total('Total', doc.totalAmount, bold: true),
                        ]),
                      ),
                    ),
                  ],
                ],
              ),
              if (doc.notes != null && doc.notes!.trim().isNotEmpty)
                _Section(title: 'Notes', children: [Text(doc.notes!)]),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Close'),
                ),
                const SizedBox(width: 12),
                // Straight to a file, without opening the preview first.
                OutlinedButton.icon(
                  onPressed: () => downloadDocumentPdf(context, doc),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Download'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: () => PdfPreviewPage.open(context, doc),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('View PDF'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _qty(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  Widget _field(String label, String? value) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(),
                style: const TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(
              value == null || value.trim().isEmpty ? '--' : value,
              style: const TextStyle(color: AppColors.ink, fontSize: 14),
            ),
          ],
        ),
      );

  Widget _total(String label, double value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: bold ? AppColors.ink : AppColors.muted,
                      fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
            ),
            const SizedBox(width: 12),
            Text('₹${value.toStringAsFixed(2)}',
                style: TextStyle(
                    color: AppColors.ink, fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
          ],
        ),
      );
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, color: AppColors.ink, fontSize: 15)),
              const SizedBox(height: 14),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
