import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/status_badge.dart';
import 'quotation_screen.dart';

const _inquiryStatuses = ['Open', 'Quoted', 'Closed', 'Cancelled'];

/// Sales Inquiry screen -- first step after a Lead becomes a Customer
/// (spec: Lead -> Customer -> Inquiry -> Quotation -> Sales Order). Lines
/// here only capture what the customer is asking about (product +
/// quantity + remarks); pricing/tax/discount are added when "Quote" turns
/// this into a priced Quotation via the backend's
/// POST /api/inquiries/{id}/convert-to-quotation, which auto-suggests each
/// product's Retail price (backend/app/routers/inquiries.py).
class InquiryScreen extends StatefulWidget {
  const InquiryScreen({super.key});

  @override
  State<InquiryScreen> createState() => _InquiryScreenState();
}

class _InquiryScreenState extends State<InquiryScreen> {
  List<Inquiry> _inquiries = [];
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
        ApiService.instance.list('/api/inquiries/'),
        ApiService.instance.list('/api/customers/'),
        ApiService.instance.list('/api/products/'),
        ApiService.instance.list('/api/taxes/'),
      ]);
      setState(() {
        _inquiries = results[0].map((e) => Inquiry.fromJson(e as Map<String, dynamic>)).toList();
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

  String _customerName(int? id) {
    if (id == null) return 'No customer yet';
    final matches = _customers.where((c) => c.id == id);
    return matches.isEmpty ? 'Customer #$id' : matches.first.name;
  }

  Future<void> _create() async {
    final result = await _openInquiryForm(context, null, _customers, _products);
    if (result == null) return;
    try {
      await ApiService.instance.create('/api/inquiries/', result.toJson());
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _edit(Inquiry inquiry) async {
    final result = await _openInquiryForm(context, inquiry, _customers, _products);
    if (result == null) return;
    try {
      await ApiService.instance.update('/api/inquiries/${inquiry.id}', result.toJson());
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _delete(Inquiry inquiry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Inquiry?'),
        content: Text('Delete inquiry "${inquiry.inquiryNo ?? '#${inquiry.id}'}"?'),
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
      await ApiService.instance.delete('/api/inquiries/${inquiry.id}');
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  /// Calls the backend's convert-to-quotation endpoint (it looks up each
  /// line's Retail price itself and marks this inquiry Quoted), then opens
  /// the newly created Quotation for review/adjustment before the user
  /// moves on -- Cancel just leaves it as the Draft the backend already
  /// saved; edits are applied with Save (PUT).
  Future<void> _createQuotation(Inquiry inquiry) async {
    Map<String, dynamic> quotationJson;
    try {
      quotationJson = await ApiService.instance.create('/api/inquiries/${inquiry.id}/convert-to-quotation', {});
    } catch (e) {
      _showError(e);
      return;
    }
    _load();
    if (!mounted) return;
    final created = Quotation.fromJson(quotationJson);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Quotation ${created.quotationNo ?? ''} created -- review pricing below.')),
    );
    final result = await openQuotationForm(context, existing: created, customers: _customers, products: _products, taxes: _taxes);
    if (result == null) return;
    try {
      await ApiService.instance.update('/api/quotations/${created.id}', result.toJson());
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
      return const Center(child: Text('Add a Customer first (or convert a Lead), then come back here to raise an Inquiry.'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text('Sales Inquiries', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              FilledButton.icon(
                onPressed: _customers.isEmpty ? null : _create,
                icon: const Icon(Icons.add),
                label: const Text('New Inquiry'),
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(_error!, style: const TextStyle(color: Colors.red))),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _inquiries.isEmpty
                  ? const Center(child: Text('No inquiries yet.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _inquiries.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final inquiry = _inquiries[i];
                          return ListTile(
                            title: Text('${inquiry.inquiryNo ?? '#${inquiry.id}'} — ${_customerName(inquiry.customerId)}'),
                            subtitle: Text('${inquiry.inquiryDate ?? 'no date'} • ${inquiry.items.length} line(s)'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                StatusBadge(status: inquiry.status),
                                const SizedBox(width: 8),
                                if (inquiry.status == 'Open')
                                  OutlinedButton.icon(
                                    onPressed: () => _createQuotation(inquiry),
                                    icon: const Icon(Icons.request_quote_outlined, size: 18),
                                    label: const Text('Quote'),
                                  ),
                                IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _edit(inquiry), tooltip: 'Edit'),
                                IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(inquiry), tooltip: 'Delete'),
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

Future<Inquiry?> _openInquiryForm(
  BuildContext context,
  Inquiry? existing,
  List<Customer> customers,
  List<Product> products,
) {
  int? customerId = existing?.customerId ?? (customers.isEmpty ? null : customers.first.id);
  final inquiryDate = TextEditingController(text: existing?.inquiryDate ?? DateTime.now().toIso8601String().substring(0, 10));
  final notes = TextEditingController(text: existing?.notes ?? '');
  List<InquiryItem> items = existing?.items.map((e) => InquiryItem(
        id: e.id,
        productId: e.productId,
        quantity: e.quantity,
        remarks: e.remarks,
      )).toList() ?? [];
  // One qty controller per row, kept in lock-step with `items` by index --
  // see doc_items_editor.dart's class doc for why a bare
  // TextFormField(initialValue: ...) isn't safe once rows can be deleted.
  final qtyCtrls = items.map((e) => TextEditingController(text: e.quantity.toString())).toList();

  return showDialog<Inquiry>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      return AlertDialog(
        title: Text(existing == null ? 'New Inquiry' : 'Edit Inquiry'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<int>(
                value: customerId,
                decoration: const InputDecoration(labelText: 'Customer'),
                items: customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                onChanged: (v) => setState(() => customerId = v),
              ),
              const SizedBox(height: 12),
              TextField(controller: inquiryDate, decoration: const InputDecoration(labelText: 'Inquiry Date (YYYY-MM-DD)')),
              const SizedBox(height: 12),
              TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes'), maxLines: 2),
              const SizedBox(height: 16),
              Row(children: [
                Text('What are they asking about?', style: Theme.of(ctx).textTheme.titleSmall),
                const Spacer(),
                TextButton.icon(
                  onPressed: products.isEmpty
                      ? null
                      : () => setState(() {
                            final item = InquiryItem();
                            items.add(item);
                            qtyCtrls.add(TextEditingController(text: item.quantity.toString()));
                          }),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Line'),
                ),
              ]),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No lines yet. Add at least one product of interest.'),
                ),
              for (int i = 0; i < items.length; i++)
                Padding(
                  key: ValueKey('inq-line-$i-${items[i].hashCode}'),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<int>(
                          value: items[i].productId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Product', isDense: true),
                          items: [
                            ...products.map((p) => DropdownMenuItem(value: p.id, child: Text('${p.name} [${p.productCode}]', overflow: TextOverflow.ellipsis))),
                            if (items[i].productId != null && products.every((p) => p.id != items[i].productId))
                              DropdownMenuItem(value: items[i].productId, child: Text('Unknown product #${items[i].productId}')),
                          ],
                          onChanged: (v) => setState(() => items[i].productId = v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: qtyCtrls[i],
                          decoration: const InputDecoration(labelText: 'Qty', isDense: true),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (v) => items[i].quantity = double.tryParse(v) ?? 0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => setState(() {
                          items.removeAt(i);
                          qtyCtrls.removeAt(i).dispose();
                        }),
                      ),
                    ],
                  ),
                ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (customerId == null || inquiryDate.text.trim().isEmpty) return;
              Navigator.pop(
                ctx,
                Inquiry(
                  id: existing?.id,
                  inquiryNo: existing?.inquiryNo,
                  customerId: customerId,
                  leadId: existing?.leadId,
                  inquiryDate: inquiryDate.text.trim(),
                  status: existing?.status ?? 'Open',
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
