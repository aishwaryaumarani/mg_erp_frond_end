import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/doc_items_editor.dart';
import '../widgets/quick_add.dart';
import '../widgets/status_badge.dart';
import 'purchase_order_screen.dart';

// Includes 'Converted' -- backend/app/routers/supplier_quotations.py sets
// this automatically when a Supplier Quotation is turned into a Purchase
// Order. Must be in this list or the status DropdownButton throws.
const _quotationStatuses = ['Draft', 'Received', 'Accepted', 'Rejected', 'Expired', 'Converted'];

/// Supplier Quotation screen -- sits between Purchase Inquiry and Purchase
/// Order. Can be raised standalone ("New Quotation", e.g. recording a
/// quote a supplier emailed over) or, more commonly, from a Purchase
/// Inquiry via [openSupplierQuotationForm] (see purchase_inquiry_screen.
/// dart), which pre-fills the supplier and copies the inquiry's product
/// lines. Accepting a Supplier Quotation offers "Convert to Purchase
/// Order".
class SupplierQuotationScreen extends StatefulWidget {
  const SupplierQuotationScreen({super.key});

  @override
  State<SupplierQuotationScreen> createState() => _SupplierQuotationScreenState();
}

class _SupplierQuotationScreenState extends State<SupplierQuotationScreen> {
  List<SupplierQuotation> _quotations = [];
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
        ApiService.instance.list('/api/supplier-quotations/'),
        ApiService.instance.list('/api/suppliers/'),
        ApiService.instance.list('/api/products/'),
        ApiService.instance.list('/api/taxes/'),
      ]);
      setState(() {
        _quotations = results[0].map((e) => SupplierQuotation.fromJson(e as Map<String, dynamic>)).toList();
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

  String _supplierName(int id) {
    final matches = _suppliers.where((s) => s.id == id);
    return matches.isEmpty ? 'Supplier #$id' : matches.first.name;
  }

  Future<void> _create() async {
    final result = await openSupplierQuotationForm(context, existing: null, suppliers: _suppliers, products: _products, taxes: _taxes);
    if (result == null) return;
    try {
      await ApiService.instance.create('/api/supplier-quotations/', result.toJson());
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _edit(SupplierQuotation q) async {
    final result = await openSupplierQuotationForm(context, existing: q, suppliers: _suppliers, products: _products, taxes: _taxes);
    if (result == null) return;
    try {
      await ApiService.instance.update('/api/supplier-quotations/${q.id}', result.toJson());
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _setStatus(SupplierQuotation q, String status) async {
    try {
      final updated = SupplierQuotation(
        id: q.id,
        quotationNo: q.quotationNo,
        inquiryId: q.inquiryId,
        supplierId: q.supplierId,
        quotationDate: q.quotationDate,
        validUntil: q.validUntil,
        status: status,
        notes: q.notes,
        items: q.items,
      );
      await ApiService.instance.update('/api/supplier-quotations/${q.id}', updated.toJson());
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _delete(SupplierQuotation q) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Supplier Quotation?'),
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
      await ApiService.instance.delete('/api/supplier-quotations/${q.id}');
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  /// Calls the backend's convert-to-order endpoint (it copies line items
  /// as-is and marks this quotation Converted -- backend/app/routers/
  /// supplier_quotations.py), then just reloads. Creating the Purchase
  /// Order does NOT move inventory (spec sec. 8) -- only a future Goods
  /// Receipt does.
  Future<void> _convertToOrder(SupplierQuotation q) async {
    try {
      final orderJson = await ApiService.instance.create('/api/supplier-quotations/${q.id}/convert-to-order', {});
      _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Purchase Order ${orderJson['order_no'] ?? ''} created.')),
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
              Text('Supplier Quotations', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.add),
                label: const Text('New Quotation'),
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
                  ? const Center(child: Text('No supplier quotations yet.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _quotations.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final q = _quotations[i];
                          return ListTile(
                            title: Text('${q.quotationNo ?? '#${q.id}'} — ${_supplierName(q.supplierId)}'),
                            subtitle: Text('${q.quotationDate ?? 'no date'} • ${q.items.length} line(s) • Total ₹${q.totalAmount.toStringAsFixed(2)}'
                                '${q.inquiryId != null ? ' • from Inquiry #${q.inquiryId}' : ''}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                DropdownButton<String>(
                                  value: q.status,
                                  underline: const SizedBox(),
                                  items: _quotationStatuses
                                      .map((s) => DropdownMenuItem(value: s, child: StatusBadge(status: s)))
                                      .toList(),
                                  onChanged: q.status == 'Converted'
                                      ? null // already turned into an order -- don't let the status be edited back
                                      : (v) {
                                          if (v != null && v != q.status) _setStatus(q, v);
                                        },
                                ),
                                if (q.status == 'Accepted' || q.status == 'Received')
                                  IconButton(
                                    icon: const Icon(Icons.assignment_outlined),
                                    tooltip: 'Convert to Purchase Order',
                                    onPressed: () => _convertToOrder(q),
                                  ),
                                IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _edit(q), tooltip: 'Edit'),
                                IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(q), tooltip: 'Delete'),
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

/// Public so purchase_inquiry_screen.dart can reuse it to build the
/// "Create Quotation from Purchase Inquiry" pre-filled dialog.
Future<SupplierQuotation?> openSupplierQuotationForm(
  BuildContext context, {
  required SupplierQuotation? existing,
  required List<Supplier> suppliers,
  required List<Product> products,
  required List<Tax> taxes,
}) {
  int? supplierId = existing?.supplierId ?? (suppliers.isEmpty ? null : suppliers.first.id);
  final quotationDate = TextEditingController(text: existing?.quotationDate ?? DateTime.now().toIso8601String().substring(0, 10));
  final validUntil = TextEditingController(text: existing?.validUntil ?? '');
  final notes = TextEditingController(text: existing?.notes ?? '');
  // Backfill each line's tax rate (not a backend field) from the Tax list
  // so the live total preview is correct immediately -- see
  // models.dart withTaxRates().
  List<DocLineItem> items = existing == null ? [] : withTaxRates(existing.items, taxes);

  return showDialog<SupplierQuotation>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      return AlertDialog(
        title: Text(existing == null ? 'New Supplier Quotation' : 'Edit Supplier Quotation'),
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
                Expanded(child: TextField(controller: quotationDate, decoration: const InputDecoration(labelText: 'Quotation Date (YYYY-MM-DD)'))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: validUntil, decoration: const InputDecoration(labelText: 'Valid Until (YYYY-MM-DD)'))),
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
              if (supplierId == null || quotationDate.text.trim().isEmpty || items.isEmpty) return;
              Navigator.pop(
                ctx,
                SupplierQuotation(
                  id: existing?.id,
                  quotationNo: existing?.quotationNo,
                  inquiryId: existing?.inquiryId,
                  supplierId: supplierId!,
                  quotationDate: quotationDate.text.trim(),
                  validUntil: validUntil.text.trim().isEmpty ? null : validUntil.text.trim(),
                  status: existing?.status ?? 'Draft',
                  notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
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
