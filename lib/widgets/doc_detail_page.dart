import 'package:flutter/material.dart';
import '../services/document_pdf.dart';
import 'doc_form_page.dart';
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
      MaterialPageRoute(
          fullscreenDialog: true, builder: (_) => DocDetailPage(doc: doc)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.page,
      appBar: AppBar(
        leadingWidth: 56,
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              doc.docNo.isEmpty ? doc.docType : doc.docNo,
              style: AppText.serif(fontSize: 18),
            ),
            Text(
              doc.docType.toUpperCase(),
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.9,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(children: [
              StatusBadge(status: doc.status),
              if (doc.isLocked) ...[
                const SizedBox(width: 10),
                const Tooltip(
                  message:
                      'Moved on to the next document -- its status is now fixed',
                  child: Icon(Icons.lock_outline,
                      size: 16, color: AppColors.muted),
                ),
              ],
            ]),
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
            children: [
              _Section(
                title: 'Customer & details',
                children: [
                  _FieldGrid(fields: [
                    (doc.partyLabel, doc.customer),
                    for (final e in doc.fields.entries) (e.key, e.value),
                  ]),
                ],
              ),
              // A purchase invoice carries no ship-to, so the whole card
              // goes rather than showing a row of dashes.
              if (doc.billingLabel.isNotEmpty || doc.shippingLabel.isNotEmpty)
                _Section(
                  title: 'Addresses',
                  children: [
                    _FieldGrid(
                      minColumnWidth: 320,
                      fields: [
                        if (doc.billingLabel.isNotEmpty)
                          (doc.billingLabel, doc.billingAddress),
                        if (doc.shippingLabel.isNotEmpty)
                          (doc.shippingLabel, doc.shippingAddress),
                      ],
                    ),
                  ],
                ),
              _Section(
                title: 'Items',
                padded: false,
                children: [
                  if (doc.lines.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(18),
                      child: Text('No lines on this document.',
                          style: TextStyle(color: AppColors.muted)),
                    )
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 640),
                        child: DataTable(
                          columns: [
                            const DataColumn(label: Text('PRODUCT')),
                            const DataColumn(label: Text('QTY'), numeric: true),
                            if (doc.hasPricing)
                              const DataColumn(
                                  label: Text('RATE'), numeric: true),
                            if (doc.hasPricing)
                              const DataColumn(
                                  label: Text('DISC %'), numeric: true),
                            if (doc.hasPricing)
                              const DataColumn(label: Text('TAX')),
                            if (doc.hasPricing)
                              const DataColumn(
                                  label: Text('TAX %'), numeric: true),
                            if (doc.hasPricing)
                              const DataColumn(
                                  label: Text('TAX AMT'), numeric: true),
                            if (doc.hasPricing)
                              const DataColumn(
                                  label: Text('AMOUNT'), numeric: true),
                          ],
                          rows: [
                            for (final line in doc.lines)
                              DataRow(cells: [
                                DataCell(Text(
                                  line.product,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                )),
                                DataCell(_num(_qty(line.quantity))),
                                if (doc.hasPricing)
                                  DataCell(
                                      _num(line.unitPrice.toStringAsFixed(2))),
                                if (doc.hasPricing)
                                  DataCell(_num(
                                      line.discountPercent.toStringAsFixed(2))),
                                if (doc.hasPricing)
                                  DataCell(Text(line.taxLabel ?? '--')),
                                if (doc.hasPricing)
                                  DataCell(
                                      _num(line.taxPercent.toStringAsFixed(2))),
                                if (doc.hasPricing)
                                  DataCell(
                                      _num(line.taxAmount.toStringAsFixed(2))),
                                if (doc.hasPricing)
                                  DataCell(_num(
                                      line.lineTotal.toStringAsFixed(2),
                                      bold: true)),
                              ]),
                          ],
                        ),
                      ),
                    ),
                  if (doc.charges.isNotEmpty) ...[
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Extra charges',
                              style: AppText.overline
                                  .copyWith(color: AppColors.slate)),
                          const SizedBox(height: 10),
                          for (final c in doc.charges)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(children: [
                                Expanded(
                                  child: Text(c.label,
                                      style: const TextStyle(
                                          fontSize: 13.5,
                                          color: AppColors.ink)),
                                ),
                                Text('₹${c.amount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        color: AppColors.muted, fontSize: 13)),
                                SizedBox(
                                  width: 96,
                                  child: Text(
                                    '+ ${c.taxPercent.toStringAsFixed(2)}% tax',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                        color: AppColors.muted, fontSize: 12),
                                  ),
                                ),
                                SizedBox(
                                  width: 110,
                                  child: Text(
                                    '₹${c.total.toStringAsFixed(2)}',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                ),
                              ]),
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (doc.hasPricing) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: SizedBox(
                          width: 320,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceAlt,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.field),
                              border: Border.all(color: AppColors.line),
                            ),
                            child: Column(children: [
                              _total('Subtotal', doc.subtotal),
                              if (doc.chargesTotal != 0)
                                _total('Extra charges', doc.chargesTotal),
                              _total('Tax', doc.taxAmount),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Divider(),
                              ),
                              _total('Total', doc.totalAmount, bold: true),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (doc.notes != null && doc.notes!.trim().isNotEmpty)
                _Section(
                  title: 'Notes',
                  children: [
                    Text(
                      doc.notes!,
                      style: const TextStyle(
                          color: AppColors.slate, fontSize: 13.5, height: 1.55),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: DocActionBar(
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('Close'),
          ),
          const SizedBox(width: 12),
          // Straight to a file, without opening the preview first.
          OutlinedButton.icon(
            onPressed: () => downloadDocumentPdf(context, doc),
            icon: const Icon(Icons.download_outlined, size: 19),
            label: const Text('Download'),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: () => PdfPreviewPage.open(context, doc),
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 19),
            label: const Text('View PDF'),
          ),
        ],
      ),
    );
  }

  static String _qty(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  /// Figures in the line grid, kept on tabular digits so the columns line
  /// up the way they do on the printed document.
  static Widget _num(String text, {bool bold = false}) => Text(
        text,
        style: TextStyle(
          fontSize: 13.5,
          color: AppColors.ink,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );

  Widget _total(String label, double value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: bold ? AppColors.ink : AppColors.muted,
                  fontSize: bold ? 14 : 13,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '₹${value.toStringAsFixed(2)}',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: bold ? 16 : 13.5,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      );
}

/// Label-over-value pairs laid out in as many columns as the width
/// allows. A document header is a set of short facts, and reading them
/// across is far quicker than scrolling one per line.
class _FieldGrid extends StatelessWidget {
  final List<(String, String?)> fields;
  final double minColumnWidth;

  const _FieldGrid({required this.fields, this.minColumnWidth = 220});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final columns =
          (constraints.maxWidth / minColumnWidth).floor().clamp(1, 4);
      const gap = 20.0;
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: 18,
        children: [
          for (final f in fields)
            SizedBox(
              width: columns == 1 ? constraints.maxWidth : width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f.$1.toUpperCase(), style: AppText.overline),
                  const SizedBox(height: 4),
                  Text(
                    f.$2 == null || f.$2!.trim().isEmpty ? '--' : f.$2!,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    });
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  /// The Items card holds a full-bleed table, so it opts out of the
  /// card's own padding and pads its own parts instead.
  final bool padded;

  const _Section({
    required this.title,
    required this.children,
    this.padded = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: AppColors.surfaceAlt,
              padding: const EdgeInsets.fromLTRB(18, 15, 18, 15),
              child: SectionHeading(title: title),
            ),
            const Divider(),
            if (padded)
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              )
            else
              ...children,
          ],
        ),
      ),
    );
  }
}
