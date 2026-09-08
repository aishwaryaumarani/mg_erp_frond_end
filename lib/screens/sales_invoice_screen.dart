import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../models/gst_models.dart';
import '../services/document_pdf.dart';
import '../widgets/doc_detail_page.dart';
import '../widgets/doc_items_editor.dart';
import '../widgets/pdf_preview_page.dart';
import '../widgets/gst_panel.dart';
import '../widgets/quick_add.dart';
import '../widgets/status_badge.dart';

// 'PartiallyPaid'/'Paid' are set automatically once Customer Receipts are
// recorded against this invoice (backend/app/routers/customer_receipts.py)
// -- must be in this list or the status display would break.
const _salesInvoiceStatuses = ['Draft', 'Posted', 'PartiallyPaid', 'Paid', 'Cancelled'];

/// Sales Invoice screen -- normally raised from a Sales Order (see
/// sales_order_screen.dart's "Create Invoice" action, which calls
/// POST /api/sales-orders/{id}/create-invoice and copies pricing as-is),
/// independent of Delivery since billing and shipping don't always land
/// together. A standalone "New Invoice" is also available. "Post" locks
/// the line items and posts AR Dr / Sales Cr / Output Tax Cr (spec sec.
/// 10). Once Posted, collect it from the Receipts screen.
class SalesInvoiceScreen extends StatefulWidget {
  const SalesInvoiceScreen({super.key});

  @override
  State<SalesInvoiceScreen> createState() => _SalesInvoiceScreenState();
}

class _SalesInvoiceScreenState extends State<SalesInvoiceScreen> {
  List<SalesInvoice> _invoices = [];
  List<Customer> _customers = [];
  List<Product> _products = [];
  List<Tax> _taxes = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiService.instance.list('/api/sales-invoices/'),
        ApiService.instance.list('/api/customers/'),
        ApiService.instance.list('/api/products/'),
        ApiService.instance.list('/api/taxes/'),
      ]);
      setState(() {
        _invoices = results[0].map((e) => SalesInvoice.fromJson(e as Map<String, dynamic>)).toList();
        _customers = results[1].map((e) => Customer.fromJson(e as Map<String, dynamic>)).toList();
        _products = results[2].map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
        _taxes = results[3].map((e) => Tax.fromJson(e as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _customerName(int id) {
    final matches = _customers.where((c) => c.id == id);
    return matches.isEmpty ? 'Customer #$id' : matches.first.name;
  }

  Tax? _taxOf(int? id) {
    if (id == null) return null;
    final matches = _taxes.where((t) => t.id == id);
    return matches.isEmpty ? null : matches.first;
  }

  String _productName(int? id) {
    final matches = _products.where((p) => p.id == id);
    return matches.isEmpty ? 'Product #$id' : '${matches.first.name} [${matches.first.productCode}]';
  }

  Customer? _customerOf(int id) {
    final matches = _customers.where((c) => c.id == id);
    return matches.isEmpty ? null : matches.first;
  }

  /// The read-only shape shared by the detail screen and the PDF.
  DocumentView _viewOf(SalesInvoice inv, {DocGstView? gst}) {
    final customer = _customerOf(inv.customerId);
    return DocumentView(
      docType: 'Tax Invoice',
      docNo: inv.invoiceNo ?? '#${inv.id}',
      status: inv.status,
      // Only a Draft is editable; anything posted onward is frozen, and a
      // filed e-invoice can never be edited at all.
      isLocked: inv.status != 'Draft',
      customer: _customerName(inv.customerId),
      fields: {
        'Invoice date': inv.invoiceDate ?? '--',
        if (inv.dueDate != null && inv.dueDate!.isNotEmpty) 'Due date': inv.dueDate!,
        if ((customer?.gstin ?? '').isNotEmpty) 'Customer GSTIN': customer!.gstin!,
        if ((customer?.placeOfSupply ?? '').isNotEmpty)
          'Place of supply': customer!.placeOfSupply!,
        if (inv.salesOrderId != null) 'From sales order': '#${inv.salesOrderId}',
        if (inv.quotationId != null) 'From proforma': '#${inv.quotationId}',
      },
      billingAddress: customer?.billingAddress,
      shippingAddress: customer?.shippingAddress,
      hasPricing: true,
      lines: inv.items.map((e) {
        final tax = _taxOf(e.taxId);
        return DocLineView(
          product: _productName(e.productId),
          quantity: e.quantity,
          unitPrice: e.unitPrice,
          discountPercent: e.discountPercent,
          taxLabel: tax?.name,
          taxPercent: tax?.ratePercent ?? 0,
          lineTotal: e.lineSubtotal,
        );
      }).toList(),
      subtotal: inv.subtotal,
      taxAmount: inv.taxAmount,
      totalAmount: inv.totalAmount,
      notes: inv.notes,
      gst: gst,
    );
  }

  /// Fetches the filing details before rendering, so the IRN, acknowledgement
  /// and signed QR on the printed invoice are always what the portal holds
  /// right now -- not a stale copy cached in the list.
  Future<DocGstView?> _gstStampFor(SalesInvoice inv) async {
    try {
      final status = GstStatus.fromJson(await ApiService.instance
          .getOne('/api/sales-invoices/${inv.id}/gst-status'));
      if (!status.gstEnabled) return null;
      final ei = status.eInvoice;
      final ewb = status.eWayBill;
      if (ei == null && ewb == null) return null;
      return DocGstView(
        irn: ei?.irn,
        ackNumber: ei?.ackNumber,
        ackDate: ei?.ackDate,
        signedQrCode: ei?.signedQrCode,
        eInvoiceCancelled: ei?.cancelled ?? false,
        ewbNumber: ewb?.ewbNumber,
        ewbDate: ewb?.ewbDate,
        ewbValidUntil: ewb?.validUntil,
        vehicleNumber: ewb?.vehicleNumber,
        transportMode: ewb?.transportMode,
        ewbCancelled: ewb?.cancelled ?? false,
        sandbox: (ei?.environment ?? '').toLowerCase() != 'production',
      );
    } catch (_) {
      // A document with no filing, or GST switched off entirely: print the
      // plain invoice rather than failing the whole PDF.
      return null;
    }
  }

  Future<void> _openDetail(SalesInvoice inv) async {
    final gst = await _gstStampFor(inv);
    if (!mounted) return;
    DocDetailPage.open(context, _viewOf(inv, gst: gst));
  }

  Future<void> _openPdf(SalesInvoice inv) async {
    final gst = await _gstStampFor(inv);
    if (!mounted) return;
    PdfPreviewPage.open(context, _viewOf(inv, gst: gst));
  }

  Future<void> _create() async {
    final result = await openSalesInvoiceForm(context, existing: null, customers: _customers, products: _products, taxes: _taxes);
    if (result == null) return;
    try {
      await ApiService.instance.create('/api/sales-invoices/', result.toJson());
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _edit(SalesInvoice inv) async {
    final result = await openSalesInvoiceForm(context, existing: inv, customers: _customers, products: _products, taxes: _taxes);
    if (result == null) return;
    try {
      await ApiService.instance.update('/api/sales-invoices/${inv.id}', result.toJson());
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _delete(SalesInvoice inv) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Sales Invoice?'),
        content: Text('Delete invoice "${inv.invoiceNo ?? '#${inv.id}'}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService.instance.delete('/api/sales-invoices/${inv.id}');
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  /// The short path's last step: the goods follow the invoice, because
  /// there is no sales order to hang the delivery off. Confirming the
  /// Delivery is still the only thing that moves stock.
  Future<void> _sendToDelivery(SalesInvoice inv) async {
    try {
      final json = await ApiService.instance
          .create('/api/sales-invoices/${inv.id}/create-delivery', {});
      _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
            'Delivery ${json['delivery_no'] ?? ''} created — confirm it in Deliveries to move the stock.')),
      );
    } catch (e) {
      _showError(e);
    }
  }

  /// Posts AR Dr / Sales Cr / Output Tax Cr and locks the invoice
  /// (backend/app/routers/sales_invoices.py's post endpoint).
  Future<void> _post(SalesInvoice inv) async {
    try {
      await ApiService.instance.create('/api/sales-invoices/${inv.id}/post', {});
      _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sales invoice posted.')),
      );
    } catch (e) {
      _showError(e);
    }
  }

  void _showError(Object e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e is ApiException ? e.message : e.toString()), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text('Sales Invoices', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.add),
                label: const Text('New Invoice'),
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(_error!, style: const TextStyle(color: Colors.red))),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _invoices.isEmpty
                  ? const Center(child: Text('No sales invoices yet.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _invoices.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final inv = _invoices[i];
                          return ListTile(
                            title: Text('${inv.invoiceNo ?? '#${inv.id}'} — ${_customerName(inv.customerId)}'),
                            subtitle: Text('${inv.invoiceDate ?? 'no date'} • ${inv.items.length} line(s) • Total ₹${inv.totalAmount.toStringAsFixed(2)}'
                                ' • Outstanding ₹${inv.outstanding.toStringAsFixed(2)}'
                                '${inv.salesOrderId != null ? ' • from Sales Order #${inv.salesOrderId}' : ''}'
                                '${inv.quotationId != null ? ' • from Proforma #${inv.quotationId}' : ''}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                StatusBadge(status: inv.status),
                                const SizedBox(width: 8),
                                if (inv.status == 'Draft')
                                  OutlinedButton.icon(
                                    onPressed: () => _post(inv),
                                    icon: const Icon(Icons.check_circle_outline, size: 18),
                                    label: const Text('Post'),
                                  ),
                                // Posted and not yet shipped: offer it
                                // once. A Draft invoice is refused by the
                                // server -- stock should not leave against
                                // a document that is not in the books.
                                if (inv.status != 'Draft' &&
                                    inv.status != 'Cancelled' &&
                                    !inv.hasDelivery)
                                  OutlinedButton.icon(
                                    onPressed: () => _sendToDelivery(inv),
                                    icon: const Icon(Icons.local_shipping_outlined, size: 18),
                                    label: const Text('Send to Delivery'),
                                  ),
                                if (inv.hasDelivery)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 4),
                                    child: Chip(
                                      visualDensity: VisualDensity.compact,
                                      label: Text('Sent to Delivery',
                                          style: TextStyle(fontSize: 11)),
                                    ),
                                  ),
                                // E-invoice and e-way bill live behind this
                                // button: explicit actions, never automatic.
                                IconButton(
                                  icon: const Icon(Icons.visibility_outlined),
                                  tooltip: 'View',
                                  onPressed: () => _openDetail(inv),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.picture_as_pdf_outlined),
                                  tooltip: 'PDF',
                                  onPressed: () => _openPdf(inv),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.qr_code_2_outlined),
                                  tooltip: 'GST: e-invoice & e-way bill',
                                  onPressed: () => GstPanel.open(
                                    context, inv.id!, inv.invoiceNo ?? '#${inv.id}',
                                  ).then((_) => _load()),
                                ),
                                if (inv.status == 'Draft') ...[
                                  IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _edit(inv), tooltip: 'Edit'),
                                  IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(inv), tooltip: 'Delete'),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}

/// Public so sales_order_screen.dart can reuse it to build the "Create
/// Invoice from Sales Order" flow.
Future<SalesInvoice?> openSalesInvoiceForm(
  BuildContext context, {
  required SalesInvoice? existing,
  required List<Customer> customers,
  required List<Product> products,
  required List<Tax> taxes,
}) {
  int? customerId = existing?.customerId ?? (customers.isEmpty ? null : customers.first.id);
  final invoiceDate = TextEditingController(text: existing?.invoiceDate ?? DateTime.now().toIso8601String().substring(0, 10));
  final dueDate = TextEditingController(text: existing?.dueDate ?? '');
  final notes = TextEditingController(text: existing?.notes ?? '');
  List<DocLineItem> items = existing == null ? [] : withTaxRates(existing.items, taxes);

  return showDialog<SalesInvoice>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      return AlertDialog(
        title: Text(existing == null ? 'New Sales Invoice' : 'Edit Sales Invoice'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              QuickAddDropdown<Customer>(
                label: 'Customer',
                value: customerId,
                options: customers,
                idOf: (c) => c.id,
                labelOf: (c) => '${c.name} (${c.customerCode})',
                addNewLabel: 'Add New Customer',
                allowUnknownValue: true,
                onCreate: quickAddCustomer,
                // `customers` is the calling screen's own list, so a
                // customer added here survives cancelling this dialog.
                onCreated: (c) => setState(() {
                  customers.add(c);
                  customerId = c.id;
                }),
                onChanged: (v) => setState(() => customerId = v),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: invoiceDate, decoration: const InputDecoration(labelText: 'Invoice Date (YYYY-MM-DD)'))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: dueDate, decoration: const InputDecoration(labelText: 'Due Date (YYYY-MM-DD)'))),
              ]),
              const SizedBox(height: 12),
              TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes'), maxLines: 2),
              const SizedBox(height: 16),
              DocLineItemsEditor(
                products: products,
                taxes: taxes,
                initialItems: items,
                onChanged: (updated) => items = updated,
                onProductCreated: products.add,
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (customerId == null || invoiceDate.text.trim().isEmpty || items.isEmpty) return;
              Navigator.pop(
                ctx,
                SalesInvoice(
                  id: existing?.id,
                  invoiceNo: existing?.invoiceNo,
                  salesOrderId: existing?.salesOrderId,
                  customerId: customerId!,
                  invoiceDate: invoiceDate.text.trim(),
                  dueDate: dueDate.text.trim().isEmpty ? null : dueDate.text.trim(),
                  status: existing?.status ?? 'Draft',
                  notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
                  amountPaid: existing?.amountPaid ?? 0,
                  items: items,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      );
    }),
  );
}
