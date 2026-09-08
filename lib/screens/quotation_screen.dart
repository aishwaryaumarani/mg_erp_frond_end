import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/document_pdf.dart';
import '../widgets/doc_detail_page.dart';
import '../widgets/doc_address_fields.dart';
import '../widgets/doc_form_page.dart';
import '../widgets/doc_items_editor.dart';
import '../widgets/quick_add.dart';
import '../widgets/status_badge.dart';
import '../widgets/workflow_actions.dart';

/// Quotation / Proforma Invoice screen.
///
/// One document, two names, because it is used two ways here:
///  * as a **quotation** on the long path -- Inquiry -> Quotation ->
///    Sales Order -> Delivery -> Invoice;
///  * as a **proforma invoice** on the short path the client actually
///    works -- the proforma is sent, the customer accepts it as the
///    order, the tax invoice is raised straight off it, and the goods
///    follow the invoice.
///
/// Approving it offers both "Convert to Sales Order" and "Create Sales
/// Invoice"; taking either locks the document, so the same goods can
/// never travel down both paths.
///
/// It can be raised standalone ("New Quotation") or, more commonly, from an
/// Inquiry via [openQuotationForm] (see inquiry_screen.dart), which
/// pre-fills the customer and copies the inquiry's product lines so
/// pricing/tax/discount only need to be added, not re-entered (spec:
/// "Auto-copies customer, products, price, tax, discount from the
/// Inquiry"). Accepting a Quotation offers "Convert to Sales Order".
class QuotationScreen extends StatefulWidget {
  const QuotationScreen({super.key});

  @override
  State<QuotationScreen> createState() => _QuotationScreenState();
}

class _QuotationScreenState extends State<QuotationScreen> {
  List<Quotation> _quotations = [];
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
        ApiService.instance.list('/api/quotations/'),
        ApiService.instance.list('/api/customers/'),
        ApiService.instance.list('/api/products/'),
        ApiService.instance.list('/api/taxes/'),
      ]);
      setState(() {
        _quotations = results[0].map((e) => Quotation.fromJson(e as Map<String, dynamic>)).toList();
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

  /// The Tax master row behind a line, so the document can print the tax
  /// type by name as well as its rate.
  Tax? _taxOf(int? id) {
    if (id == null) return null;
    final matches = _taxes.where((t) => t.id == id);
    return matches.isEmpty ? null : matches.first;
  }

  String _productName(int? id) {
    final matches = _products.where((p) => p.id == id);
    return matches.isEmpty ? 'Product #$id' : '${matches.first.name} [${matches.first.productCode}]';
  }

  /// The read-only shape shared by the detail screen and the PDF. Line
  /// amounts are shown pre-tax so they add up to the server's subtotal;
  /// tax lands once in the totals block.
  DocumentView _viewOf(Quotation q) => DocumentView(
        docType: 'Quotation / Proforma Invoice',
        docNo: q.quotationNo ?? '#${q.id}',
        status: q.status,
        isLocked: q.isLocked,
        customer: _customerName(q.customerId),
        fields: {
          'Quotation date': q.quotationDate ?? '--',
          if (q.validUntil != null && q.validUntil!.isNotEmpty) 'Valid until': q.validUntil!,
          if (q.inquiryId != null) 'From inquiry': '#${q.inquiryId}',
        },
        billingAddress: q.billingAddress,
        shippingAddress: q.shippingAddress,
        hasPricing: true,
        lines: q.items.map((e) {
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
        subtotal: q.subtotal,
        taxAmount: q.taxAmount,
        totalAmount: q.totalAmount,
        notes: q.notes,
      );

  String _customerName(int id) {
    final matches = _customers.where((c) => c.id == id);
    return matches.isEmpty ? 'Customer #$id' : matches.first.name;
  }

  Future<void> _create() async {
    final result = await openQuotationForm(context, existing: null, customers: _customers, products: _products, taxes: _taxes);
    if (result == null) return;
    try {
      await ApiService.instance.create('/api/quotations/', result.toJson());
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _edit(Quotation q) async {
    final result = await openQuotationForm(context, existing: q, customers: _customers, products: _products, taxes: _taxes);
    if (result == null) return;
    try {
      await ApiService.instance.update('/api/quotations/${q.id}', result.toJson());
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _delete(Quotation q) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Quotation?'),
        content: Text('Delete quotation "${q.quotationNo ?? '#${q.id}'}"?'),
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
      await ApiService.instance.delete('/api/quotations/${q.id}');
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  /// Calls the backend's convert-to-order endpoint (it copies line items
  /// as-is and marks this quotation Converted -- backend/app/routers/
  /// quotations.py), then just reloads; no client-side status write-back
  /// needed since the server already did it.
  Future<void> _convertToOrder(Quotation q) async {
    try {
      final orderJson = await ApiService.instance.create('/api/quotations/${q.id}/convert-to-order', {});
      _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sales Order ${orderJson['order_no'] ?? ''} created.')),
      );
    } catch (e) {
      _showError(e);
    }
  }

  /// The short path: bill the proforma directly, no sales order in
  /// between (POST /api/quotations/{id}/create-invoice). Locks the
  /// proforma, so "Convert to Sales Order" disappears with it.
  Future<void> _createInvoice(Quotation q) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Sales Invoice?'),
        content: Text(
          'Bills ${q.quotationNo ?? '#${q.id}'} directly, with no sales order in between.\n\n'
          'This closes the sales-order route for this proforma -- it can only go one way.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create Invoice')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final json = await ApiService.instance.create('/api/quotations/${q.id}/create-invoice', {});
      _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sales Invoice ${json['invoice_no'] ?? ''} created — open Sales Invoices to post it.')),
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
              Text('Quotations / Proforma Invoices',
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.add),
                label: const Text('New Quotation / Proforma'),
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(_error!, style: const TextStyle(color: Colors.red))),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _quotations.isEmpty
                  ? const Center(child: Text('No quotations or proforma invoices yet.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _quotations.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final q = _quotations[i];
                          return ListTile(
                            title: Text('${q.quotationNo ?? '#${q.id}'} — ${_customerName(q.customerId)}'),
                            subtitle: Text('${q.quotationDate ?? 'no date'} • ${q.items.length} line(s) • Total ₹${q.totalAmount.toStringAsFixed(2)}'
                                '${q.inquiryId != null ? ' • from Inquiry #${q.inquiryId}' : ''}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                StatusBadge(status: q.status),
                                const SizedBox(width: 8),
                                WorkflowActions(
                                  resourcePath: '/api/quotations/',
                                  id: q.id,
                                  status: q.status,
                                  isLocked: q.isLocked,
                                  onChanged: _load,
                                  onError: _showError,
                                ),
                                const SizedBox(width: 8),
                                // Approved and not yet converted: both
                                // paths are open. The short one (straight
                                // to an invoice) is what the client uses,
                                // so it leads.
                                if (canMoveOn(q.status) && !q.isLocked) ...[
                                  IconButton(
                                    icon: const Icon(Icons.request_quote_outlined),
                                    tooltip: 'Create Sales Invoice (no sales order)',
                                    onPressed: () => _createInvoice(q),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.receipt_long_outlined),
                                    tooltip: 'Convert to Sales Order',
                                    onPressed: () => _convertToOrder(q),
                                  ),
                                ],
                                // Converted: say which way it went instead
                                // of leaving a locked row with no
                                // explanation.
                                if (q.convertedTo != null)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: Chip(
                                      visualDensity: VisualDensity.compact,
                                      label: Text('→ ${q.convertedTo}',
                                          style: const TextStyle(fontSize: 11)),
                                    ),
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.visibility_outlined),
                                  tooltip: 'View details / PDF',
                                  onPressed: () => DocDetailPage.open(context, _viewOf(q)),
                                ),
                                if (canEditDocument(q.status, q.isLocked))
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined),
                                    tooltip: 'Edit',
                                    onPressed: () => _edit(q),
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  tooltip: q.isLocked ? 'Already ordered -- cannot be deleted' : 'Delete',
                                  onPressed: q.isLocked ? null : () => _delete(q),
                                ),
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

/// Public so inquiry_screen.dart can reuse it to build the "Create
/// Quotation from Inquiry" pre-filled form.
Future<Quotation?> openQuotationForm(
  BuildContext context, {
  required Quotation? existing,
  required List<Customer> customers,
  required List<Product> products,
  required List<Tax> taxes,
}) {
  int? customerId = existing?.customerId ?? (customers.isEmpty ? null : customers.first.id);
  final quotationDate = TextEditingController(text: existing?.quotationDate ?? DateTime.now().toIso8601String().substring(0, 10));
  final validUntil = TextEditingController(text: existing?.validUntil ?? '');
  final billing = TextEditingController(text: existing?.billingAddress ?? '');
  final shipping = TextEditingController(text: existing?.shippingAddress ?? '');
  final notes = TextEditingController(text: existing?.notes ?? '');
  // Backfill each line's tax rate (not a backend field) from the Tax list
  // so the live total preview is correct immediately, not just after the
  // user re-touches a row's Tax dropdown -- see models.dart withTaxRates().
  List<DocLineItem> items = existing == null ? [] : withTaxRates(existing.items, taxes);

  // New quotation -> start from the customer master. An existing one
  // (including one just converted from an Inquiry, which carries the
  // inquiry's addresses) keeps what's on the document.
  if (existing == null) {
    syncAddressesToCustomer(
      previous: null,
      next: customerById(customers, customerId),
      billing: billing,
      shipping: shipping,
    );
  }

  return openDocFormPage<Quotation>(context, (ctx) {
    return StatefulBuilder(builder: (ctx, setState) {
      void pickCustomer(int? id) {
        final previous = customerById(customers, customerId);
        setState(() {
          customerId = id;
          syncAddressesToCustomer(
            previous: previous,
            next: customerById(customers, id),
            billing: billing,
            shipping: shipping,
          );
        });
      }

      return DocFormPage(
        title: existing == null ? 'New Quotation' : 'Edit Quotation',
        subtitle: existing?.quotationNo,
        onSave: () {
          if (customerId == null) {
            showFormError(ctx, 'Pick a customer for this quotation.');
            return;
          }
          if (quotationDate.text.trim().isEmpty) {
            showFormError(ctx, 'Quotation date is required (YYYY-MM-DD).');
            return;
          }
          if (items.isEmpty) {
            showFormError(ctx, 'A quotation needs at least one line item.');
            return;
          }
          Navigator.pop(
            ctx,
            Quotation(
              id: existing?.id,
              quotationNo: existing?.quotationNo,
              inquiryId: existing?.inquiryId,
              customerId: customerId!,
              quotationDate: quotationDate.text.trim(),
              validUntil: validUntil.text.trim().isEmpty ? null : validUntil.text.trim(),
              status: existing?.status ?? 'Draft',
              billingAddress: billing.text.trim().isEmpty ? null : billing.text.trim(),
              shippingAddress: shipping.text.trim().isEmpty ? null : shipping.text.trim(),
              notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
              items: items,
            ),
          );
        },
        children: [
          DocFormSection(
            title: 'Customer & dates',
            children: [
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
                // customer added here survives cancelling this form.
                onCreated: (c) {
                  customers.add(c);
                  pickCustomer(c.id);
                },
                onChanged: pickCustomer,
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: quotationDate, decoration: const InputDecoration(labelText: 'Quotation Date (YYYY-MM-DD)'))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: validUntil, decoration: const InputDecoration(labelText: 'Valid Until (YYYY-MM-DD)'))),
              ]),
            ],
          ),
          DocFormSection(
            title: 'Addresses',
            hint: "Filled in from the customer master -- edit here for a one-off billing or delivery address.",
            children: [DocAddressFields(billing: billing, shipping: shipping)],
          ),
          DocFormSection(
            title: 'Items',
            children: [
              DocLineItemsEditor(
                products: products,
                taxes: taxes,
                initialItems: items,
                onChanged: (updated) => items = updated,
                onProductCreated: products.add,
              ),
            ],
          ),
          DocFormSection(
            title: 'Notes',
            children: [
              TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes'), maxLines: 3),
            ],
          ),
        ],
      );
    });
  });
}
