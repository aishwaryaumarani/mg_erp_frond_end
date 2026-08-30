import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/status_badge.dart';
import '../widgets/quick_add.dart';
import 'supplier_quotation_screen.dart';

const _inquiryStatuses = ['Open', 'Quoted', 'Closed', 'Cancelled'];

/// Purchase Inquiry screen -- first step of the Purchase flow (Supplier ->
/// Purchase Inquiry -> Supplier Quotation -> Purchase Order). Lines here
/// only capture what you're asking a supplier to price (product +
/// quantity + remarks); pricing comes back on the Supplier Quotation. The
/// "Quote" button calls the backend's
/// POST /api/purchase-inquiries/{id}/convert-to-quotation, which
/// auto-suggests each product's Purchase price (backend/app/routers/
/// purchase_inquiries.py) -- same pattern as Sales Inquiry -> Quotation.
class PurchaseInquiryScreen extends StatefulWidget {
  const PurchaseInquiryScreen({super.key});

  @override
  State<PurchaseInquiryScreen> createState() => _PurchaseInquiryScreenState();
}

class _PurchaseInquiryScreenState extends State<PurchaseInquiryScreen> {
  List<PurchaseInquiry> _inquiries = [];
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
        ApiService.instance.list('/api/purchase-inquiries/'),
        ApiService.instance.list('/api/suppliers/'),
        ApiService.instance.list('/api/products/'),
        ApiService.instance.list('/api/taxes/'),
      ]);
      setState(() {
        _inquiries = results[0].map((e) => PurchaseInquiry.fromJson(e as Map<String, dynamic>)).toList();
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
    final result = await _openPurchaseInquiryForm(context, null, _suppliers, _products);
    if (result == null) return;
    try {
      await ApiService.instance.create('/api/purchase-inquiries/', result.toJson());
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _edit(PurchaseInquiry inquiry) async {
    final result = await _openPurchaseInquiryForm(context, inquiry, _suppliers, _products);
    if (result == null) return;
    try {
      await ApiService.instance.update('/api/purchase-inquiries/${inquiry.id}', result.toJson());
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _delete(PurchaseInquiry inquiry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Purchase Inquiry?'),
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
      await ApiService.instance.delete('/api/purchase-inquiries/${inquiry.id}');
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  /// Calls the backend's convert-to-quotation endpoint (it looks up each
  /// line's Purchase price itself and marks this inquiry Quoted), then
  /// opens the newly created Supplier Quotation for review/adjustment --
  /// Cancel just leaves it as the Draft the backend already saved; edits
  /// are applied with Save (PUT).
  Future<void> _createQuotation(PurchaseInquiry inquiry) async {
    Map<String, dynamic> quotationJson;
    try {
      quotationJson = await ApiService.instance.create('/api/purchase-inquiries/${inquiry.id}/convert-to-quotation', {});
    } catch (e) {
      _showError(e);
      return;
    }
    _load();
    if (!mounted) return;
    final created = SupplierQuotation.fromJson(quotationJson);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Supplier Quotation ${created.quotationNo ?? ''} created -- review pricing below.')),
    );
    final result = await openSupplierQuotationForm(context, existing: created, suppliers: _suppliers, products: _products, taxes: _taxes);
    if (result == null) return;
    try {
      await ApiService.instance.update('/api/supplier-quotations/${created.id}', result.toJson());
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
              Text('Purchase Inquiries', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              FilledButton.icon(
                onPressed: _create,
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
                  ? const Center(child: Text('No purchase inquiries yet.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _inquiries.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final inquiry = _inquiries[i];
                          return ListTile(
                            title: Text('${inquiry.inquiryNo ?? '#${inquiry.id}'} — ${_supplierName(inquiry.supplierId)}'),
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

Future<PurchaseInquiry?> _openPurchaseInquiryForm(
  BuildContext context,
  PurchaseInquiry? existing,
  List<Supplier> suppliers,
  List<Product> products,
) {
  int? supplierId = existing?.supplierId ?? (suppliers.isEmpty ? null : suppliers.first.id);
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

  return showDialog<PurchaseInquiry>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      return AlertDialog(
        title: Text(existing == null ? 'New Purchase Inquiry' : 'Edit Purchase Inquiry'),
        content: SizedBox(
          width: 520,
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
              TextField(controller: inquiryDate, decoration: const InputDecoration(labelText: 'Inquiry Date (YYYY-MM-DD)')),
              const SizedBox(height: 12),
              TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes'), maxLines: 2),
              const SizedBox(height: 16),
              Row(children: [
                Text('What are you asking the supplier to price?', style: Theme.of(ctx).textTheme.titleSmall),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => setState(() {
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
                  child: Text('No lines yet. Add at least one product to ask about.'),
                ),
              for (int i = 0; i < items.length; i++)
                Padding(
                  key: ValueKey('pinq-line-$i-${items[i].hashCode}'),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: QuickAddDropdown<Product>(
                          label: 'Product',
                          value: items[i].productId,
                          options: products,
                          idOf: (p) => p.id,
                          labelOf: (p) => '${p.name} [${p.productCode}]',
                          addNewLabel: 'Add New Product',
                          isDense: true,
                          allowUnknownValue: true,
                          onCreate: quickAddProduct,
                          onCreated: (p) => setState(() {
                            products.add(p);
                            items[i].productId = p.id;
                          }),
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
              if (supplierId == null || inquiryDate.text.trim().isEmpty) return;
              Navigator.pop(
                ctx,
                PurchaseInquiry(
                  id: existing?.id,
                  inquiryNo: existing?.inquiryNo,
                  supplierId: supplierId!,
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
