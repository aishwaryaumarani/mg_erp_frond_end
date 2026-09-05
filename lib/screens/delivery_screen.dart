import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/document_pdf.dart';
import '../widgets/doc_detail_page.dart';
import '../widgets/status_badge.dart';
import '../widgets/quick_add.dart';

/// Delivery screen -- the ONLY place stock decreases on the Sales side
/// (spec sec. 8). A delivery is normally raised from a Sales Order (see
/// sales_order_screen.dart's "Create Delivery" action, which calls
/// POST /api/sales-orders/{id}/create-delivery and copies quantities
/// only -- no pricing), but a standalone "New Delivery" is also available.
/// Deliveries are raised from a Sales Order and are never edited here:
/// the document mirrors its order, and confirming one posts the stock
/// movement. The screen only creates, views (with a printable Delivery
/// Note), confirms and deletes -- the backend refuses edits to anything
/// that isn't a Draft, and refuses to touch a Confirmed one at all.
class DeliveryScreen extends StatefulWidget {
  const DeliveryScreen({super.key});

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  List<Delivery> _deliveries = [];
  List<Customer> _customers = [];
  List<Product> _products = [];
  List<Warehouse> _warehouses = [];
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
        ApiService.instance.list('/api/deliveries/'),
        ApiService.instance.list('/api/customers/'),
        ApiService.instance.list('/api/products/'),
        ApiService.instance.list('/api/warehouses/'),
      ]);
      setState(() {
        _deliveries = results[0].map((e) => Delivery.fromJson(e as Map<String, dynamic>)).toList();
        _customers = results[1].map((e) => Customer.fromJson(e as Map<String, dynamic>)).toList();
        _products = results[2].map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
        _warehouses = results[3].map((e) => Warehouse.fromJson(e as Map<String, dynamic>)).toList();
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
    return matches.isEmpty ? 'Product #$id' : '${matches.first.name} [${matches.first.productCode}]';
  }

  String _warehouseName(int? id) {
    if (id == null) return '--';
    final matches = _warehouses.where((w) => w.id == id);
    return matches.isEmpty ? 'Warehouse #$id' : matches.first.name;
  }

  /// Deliveries are raised from a Sales Order and confirming one posts a
  /// stock movement, so this screen only ever shows them -- read-only,
  /// printable, never editable.
  DocumentView _viewOf(Delivery d) => DocumentView(
        docType: 'Delivery Note',
        docNo: d.deliveryNo ?? '#${d.id}',
        status: d.status,
        isLocked: d.status == 'Confirmed', // stock already posted
        customer: _customerName(d.customerId),
        fields: {
          'Delivery date': d.deliveryDate ?? '--',
          'Warehouse': _warehouseName(d.warehouseId),
          if (d.salesOrderId != null) 'From sales order': '#${d.salesOrderId}',
        },
        hasPricing: false, // quantities only -- valuation lives on the invoice
        lines: d.items
            .map((e) => DocLineView(product: _productName(e.productId), quantity: e.quantity))
            .toList(),
        notes: d.notes,
      );

  String _customerName(int id) {
    final matches = _customers.where((c) => c.id == id);
    return matches.isEmpty ? 'Customer #$id' : matches.first.name;
  }

  Future<void> _create() async {
    final result = await _openDeliveryForm(context, null, _customers, _products, _warehouses);
    if (result == null) return;
    try {
      await ApiService.instance.create('/api/deliveries/', result.toJson());
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _delete(Delivery d) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Delivery?'),
        content: Text('Delete delivery "${d.deliveryNo ?? '#${d.id}'}"?'),
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
      await ApiService.instance.delete('/api/deliveries/${d.id}');
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  /// Posts one STOCK OUT StockLedger row per line (backend/app/routers/
  /// deliveries.py's confirm endpoint) and locks the delivery.
  Future<void> _confirm(Delivery d) async {
    try {
      await ApiService.instance.create('/api/deliveries/${d.id}/confirm', {});
      _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery confirmed -- stock updated.')),
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
              Text('Deliveries', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.add),
                label: const Text('New Delivery'),
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(_error!, style: const TextStyle(color: Colors.red))),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _deliveries.isEmpty
                  ? const Center(child: Text('No deliveries yet.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _deliveries.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final d = _deliveries[i];
                          return ListTile(
                            title: Text('${d.deliveryNo ?? '#${d.id}'} — ${_customerName(d.customerId)}'),
                            subtitle: Text('${d.deliveryDate ?? 'no date'} • ${d.items.length} line(s)'
                                '${d.salesOrderId != null ? ' • from Sales Order #${d.salesOrderId}' : ''}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                StatusBadge(status: d.status),
                                const SizedBox(width: 8),
                                if (d.status == 'Draft')
                                  OutlinedButton.icon(
                                    onPressed: () => _confirm(d),
                                    icon: const Icon(Icons.local_shipping_outlined, size: 18),
                                    label: const Text('Confirm'),
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.visibility_outlined),
                                  tooltip: 'View details / PDF',
                                  onPressed: () => DocDetailPage.open(context, _viewOf(d)),
                                ),
                                // No Edit here by design: a delivery mirrors
                                // its Sales Order, and confirming it posts
                                // stock.
                                if (d.status != 'Confirmed')
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => _delete(d),
                                    tooltip: 'Delete',
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

Future<Delivery?> _openDeliveryForm(
  BuildContext context,
  Delivery? existing,
  List<Customer> customers,
  List<Product> products,
  List<Warehouse> warehouses,
) {
  int? customerId = existing?.customerId ?? (customers.isEmpty ? null : customers.first.id);
  int? warehouseId = existing?.warehouseId ?? (warehouses.isEmpty ? null : warehouses.first.id);
  final deliveryDate = TextEditingController(text: existing?.deliveryDate ?? DateTime.now().toIso8601String().substring(0, 10));
  final notes = TextEditingController(text: existing?.notes ?? '');
  List<InquiryItem> items = existing?.items.map((e) => InquiryItem(
        id: e.id,
        productId: e.productId,
        quantity: e.quantity,
        remarks: e.remarks,
      )).toList() ?? [];
  final qtyCtrls = items.map((e) => TextEditingController(text: e.quantity.toString())).toList();

  return showDialog<Delivery>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      return AlertDialog(
        title: Text(existing == null ? 'New Delivery' : 'Edit Delivery'),
        content: SizedBox(
          width: 520,
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
              QuickAddDropdown<Warehouse>(
                label: 'Warehouse (optional)',
                value: warehouseId,
                options: warehouses,
                idOf: (w) => w.id,
                labelOf: (w) => w.code == null || w.code!.isEmpty ? w.name : '${w.name} (${w.code})',
                addNewLabel: 'Add New Warehouse',
                noneLabel: 'Unassigned',
                allowUnknownValue: true,
                onCreate: quickAddWarehouse,
                onCreated: (w) => setState(() {
                  warehouses.add(w);
                  warehouseId = w.id;
                }),
                onChanged: (v) => setState(() => warehouseId = v),
              ),
              const SizedBox(height: 12),
              TextField(controller: deliveryDate, decoration: const InputDecoration(labelText: 'Delivery Date (YYYY-MM-DD)')),
              const SizedBox(height: 12),
              TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes'), maxLines: 2),
              const SizedBox(height: 16),
              Row(children: [
                Text('What is going out?', style: Theme.of(ctx).textTheme.titleSmall),
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
                  child: Text('No lines yet. Add at least one product being delivered.'),
                ),
              for (int i = 0; i < items.length; i++)
                Padding(
                  key: ValueKey('dlv-line-$i-${items[i].hashCode}'),
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
              if (customerId == null || deliveryDate.text.trim().isEmpty || items.isEmpty) return;
              Navigator.pop(
                ctx,
                Delivery(
                  id: existing?.id,
                  deliveryNo: existing?.deliveryNo,
                  salesOrderId: existing?.salesOrderId,
                  customerId: customerId!,
                  warehouseId: warehouseId,
                  deliveryDate: deliveryDate.text.trim(),
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
