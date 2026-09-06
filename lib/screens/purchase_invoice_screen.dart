import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/document_pdf.dart';
import '../widgets/doc_detail_page.dart';
import 'invoice_import_screen.dart';
import '../widgets/doc_items_editor.dart';
import '../widgets/quick_add.dart';
import '../widgets/status_badge.dart';

// 'PartiallyPaid'/'Paid' are set automatically once Supplier Payments are
// recorded against this invoice (backend/app/routers/supplier_payments.py)
// -- must be in this list or the status display would break.
const _purchaseInvoiceStatuses = ['Draft', 'Posted', 'PartiallyPaid', 'Paid', 'Cancelled'];

/// Purchase Invoice screen -- normally raised from a Purchase Order (see
/// purchase_order_screen.dart's "Create Invoice" action, which calls
/// POST /api/purchase-orders/{id}/create-invoice and copies pricing
/// as-is), independent of Goods Receipt since the supplier's bill and
/// the physical delivery don't always land together. A standalone "New
/// Invoice" is also available. "Post" locks the line items and posts
/// Inventory Dr / Input Tax Dr / AP Cr (spec sec. 10). Once Posted, pay
/// it off from the Payments screen.
class PurchaseInvoiceScreen extends StatefulWidget {
  const PurchaseInvoiceScreen({super.key});

  @override
  State<PurchaseInvoiceScreen> createState() => _PurchaseInvoiceScreenState();
}

class _PurchaseInvoiceScreenState extends State<PurchaseInvoiceScreen> {
  List<PurchaseInvoice> _invoices = [];
  List<Supplier> _suppliers = [];
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
        ApiService.instance.list('/api/purchase-invoices/'),
        ApiService.instance.list('/api/suppliers/'),
        ApiService.instance.list('/api/products/'),
        ApiService.instance.list('/api/taxes/'),
      ]);
      setState(() {
        _invoices = results[0].map((e) => PurchaseInvoice.fromJson(e as Map<String, dynamic>)).toList();
        _suppliers = results[1].map((e) => Supplier.fromJson(e as Map<String, dynamic>)).toList();
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

  String _productName(int? id) {
    final matches = _products.where((p) => p.id == id);
    return matches.isEmpty ? 'Product #\$id' : '\${matches.first.name} [\${matches.first.productCode}]';
  }

  Tax? _taxOf(int? id) {
    if (id == null) return null;
    final matches = _taxes.where((t) => t.id == id);
    return matches.isEmpty ? null : matches.first;
  }

  /// The read-only view of a supplier bill: who it is from, their own
  /// invoice number, the goods, the freight/labour charges and what is
  /// still owed. Same shape the PDF is built from, so the two agree.
  DocumentView _viewOf(PurchaseInvoice inv) => DocumentView(
        docType: 'Purchase Invoice',
        docNo: inv.invoiceNo ?? '#\${inv.id}',
        status: inv.status,
        isLocked: inv.status != 'Draft', // posted bills are read-only
        customer: _supplierName(inv.supplierId),
        partyLabel: 'SUPPLIER',
        billingLabel: '',
        shippingLabel: '',
        fields: {
          'Invoice date': inv.invoiceDate ?? '--',
          if ((inv.dueDate ?? '').isNotEmpty) 'Due date': inv.dueDate!,
          if (inv.purchaseOrderId != null) 'From purchase order': '#\${inv.purchaseOrderId}',
          'Paid': '₹\${inv.amountPaid.toStringAsFixed(2)}',
          'Outstanding': '₹\${inv.outstanding.toStringAsFixed(2)}',
        },
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
        charges: inv.charges
            .map((c) => DocChargeView(
                  label: c.label, amount: c.amount, taxPercent: c.taxPercent))
            .toList(),
        subtotal: inv.subtotal,
        chargesTotal: inv.chargesTotal,
        taxAmount: inv.taxAmount,
        totalAmount: inv.totalAmount,
        notes: inv.notes,
      );

  String _supplierName(int id) {
    final matches = _suppliers.where((s) => s.id == id);
    return matches.isEmpty ? 'Supplier #$id' : matches.first.name;
  }

  Future<void> _create() async {
    final result = await openPurchaseInvoiceForm(context, existing: null, suppliers: _suppliers, products: _products, taxes: _taxes);
    if (result == null) return;
    try {
      await ApiService.instance.create('/api/purchase-invoices/', result.toJson());
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _edit(PurchaseInvoice inv) async {
    final result = await openPurchaseInvoiceForm(context, existing: inv, suppliers: _suppliers, products: _products, taxes: _taxes);
    if (result == null) return;
    try {
      await ApiService.instance.update('/api/purchase-invoices/${inv.id}', result.toJson());
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _delete(PurchaseInvoice inv) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Purchase Invoice?'),
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
      await ApiService.instance.delete('/api/purchase-invoices/${inv.id}');
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  /// Posts Inventory Dr / Input Tax Dr / AP Cr and locks the invoice
  /// (backend/app/routers/purchase_invoices.py's post endpoint).
  Future<void> _post(PurchaseInvoice inv) async {
    try {
      await ApiService.instance.create('/api/purchase-invoices/${inv.id}/post', {});
      _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Purchase invoice posted.')),
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
              Text('Purchase Invoices', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              // Reading the supplier's own PDF beats retyping it.
              OutlinedButton.icon(
                onPressed: () async {
                  final created = await InvoiceImportScreen.open(context);
                  if (created == true) _load();
                },
                icon: const Icon(Icons.upload_file_outlined, size: 18),
                label: const Text('Import from PDF'),
              ),
              const SizedBox(width: 12),
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
                  ? const Center(child: Text('No purchase invoices yet.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _invoices.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final inv = _invoices[i];
                          return ListTile(
                            title: Text('${inv.invoiceNo ?? '#${inv.id}'} — ${_supplierName(inv.supplierId)}'),
                            subtitle: Text('${inv.invoiceDate ?? 'no date'} • ${inv.items.length} line(s) • Total ₹${inv.totalAmount.toStringAsFixed(2)}'
                                ' • Outstanding ₹${inv.outstanding.toStringAsFixed(2)}'
                                '${inv.purchaseOrderId != null ? ' • from PO #${inv.purchaseOrderId}' : ''}'),
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
                                IconButton(
                                  icon: const Icon(Icons.visibility_outlined),
                                  tooltip: 'View details / PDF',
                                  onPressed: () => DocDetailPage.open(context, _viewOf(inv)),
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

/// Public so purchase_order_screen.dart can reuse it to build the
/// "Create Invoice from Purchase Order" flow.
Future<PurchaseInvoice?> openPurchaseInvoiceForm(
  BuildContext context, {
  required PurchaseInvoice? existing,
  required List<Supplier> suppliers,
  required List<Product> products,
  required List<Tax> taxes,
}) {
  int? supplierId = existing?.supplierId ?? (suppliers.isEmpty ? null : suppliers.first.id);
  final invoiceDate = TextEditingController(text: existing?.invoiceDate ?? DateTime.now().toIso8601String().substring(0, 10));
  final dueDate = TextEditingController(text: existing?.dueDate ?? '');
  final notes = TextEditingController(text: existing?.notes ?? '');
  List<DocLineItem> items = existing == null ? [] : withTaxRates(existing.items, taxes);

  return showDialog<PurchaseInvoice>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      return AlertDialog(
        title: Text(existing == null ? 'New Purchase Invoice' : 'Edit Purchase Invoice'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              QuickAddDropdown<Supplier>(
                label: 'Supplier',
                value: supplierId,
                options: suppliers,
                idOf: (s) => s.id,
                labelOf: (s) => '${s.name} (${s.supplierCode})',
                addNewLabel: 'Add New Supplier',
                allowUnknownValue: true,
                onCreate: quickAddSupplier,
                // `suppliers` is the calling screen's own list, so a
                // supplier added here survives cancelling this dialog.
                onCreated: (s) => setState(() {
                  suppliers.add(s);
                  supplierId = s.id;
                }),
                onChanged: (v) => setState(() => supplierId = v),
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
              if (supplierId == null || invoiceDate.text.trim().isEmpty || items.isEmpty) return;
              Navigator.pop(
                ctx,
                PurchaseInvoice(
                  id: existing?.id,
                  invoiceNo: existing?.invoiceNo,
                  purchaseOrderId: existing?.purchaseOrderId,
                  supplierId: supplierId!,
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
