import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/doc_items_editor.dart';
import '../widgets/status_badge.dart';
import 'sales_order_screen.dart';

// Includes 'Converted' -- backend/app/routers/quotations.py sets this
// automatically when a Quotation is turned into a Sales Order. It has to
// be in this list or the status DropdownButton throws (its value must
// match one of its items).
const _quotationStatuses = ['Draft', 'Sent', 'Accepted', 'Rejected', 'Expired', 'Converted'];

/// Quotation screen -- sits between Inquiry and Sales Order. A Quotation
/// can be raised standalone ("New Quotation") or, more commonly, from an
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

  Future<void> _setStatus(Quotation q, String status) async {
    try {
      final updated = Quotation(
        id: q.id,
        quotationNo: q.quotationNo,
        inquiryId: q.inquiryId,
        customerId: q.customerId,
        quotationDate: q.quotationDate,
        validUntil: q.validUntil,
        status: status,
        notes: q.notes,
        items: q.items,
      );
      await ApiService.instance.update('/api/quotations/${q.id}', updated.toJson());
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

  void _showError(Object e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e is ApiException ? e.message : e.toString()), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_customers.isEmpty && !_loading) {
      return const Center(child: Text('Add a Customer first, then come back here to raise a Quotation.'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text('Quotations', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              FilledButton.icon(
                onPressed: _customers.isEmpty ? null : _create,
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
                  ? const Center(child: Text('No quotations yet.'))
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
                                if (q.status == 'Accepted' || q.status == 'Sent')
                                  IconButton(
                                    icon: const Icon(Icons.receipt_long_outlined),
                                    tooltip: 'Convert to Sales Order',
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

/// Public so inquiry_screen.dart can reuse it to build the "Create
/// Quotation from Inquiry" pre-filled dialog.
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
  final notes = TextEditingController(text: existing?.notes ?? '');
  // Backfill each line's tax rate (not a backend field) from the Tax list
  // so the live total preview is correct immediately, not just after the
  // user re-touches a row's Tax dropdown -- see models.dart withTaxRates().
  List<DocLineItem> items = existing == null ? [] : withTaxRates(existing.items, taxes);

  return showDialog<Quotation>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      return AlertDialog(
        title: Text(existing == null ? 'New Quotation' : 'Edit Quotation'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<int>(
                value: customerId,
                decoration: const InputDecoration(labelText: 'Customer'),
                items: customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                onChanged: (v) => setState(() => customerId = v),
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
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (customerId == null || quotationDate.text.trim().isEmpty || items.isEmpty) return;
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
