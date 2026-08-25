import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/status_badge.dart';

// Includes 'Confirmed' -- confirming a GRN is what actually posts the
// STOCK IN movement (backend/app/routers/goods_receipts.py). Must be in
// this list or the status display would fail to reflect the real value.
const _grnStatuses = ['Draft', 'Confirmed', 'Cancelled'];

/// Goods Receipt screen -- the ONLY place stock increases on the Purchase
/// side (spec sec. 8). A GRN is normally raised from a Purchase Order
/// (see purchase_order_screen.dart's "Create Goods Receipt" action, which
/// calls POST /api/purchase-orders/{id}/create-goods-receipt and copies
/// quantities only -- no pricing), but a standalone "New Receipt" is also
/// available for goods that arrive without a PO on file. Once a receipt
/// is Confirmed its stock movement is posted and it can no longer be
/// edited or deleted (backend enforces this too).
class GoodsReceiptScreen extends StatefulWidget {
  const GoodsReceiptScreen({super.key});

  @override
  State<GoodsReceiptScreen> createState() => _GoodsReceiptScreenState();
}

class _GoodsReceiptScreenState extends State<GoodsReceiptScreen> {
  List<GoodsReceipt> _receipts = [];
  List<Supplier> _suppliers = [];
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
        ApiService.instance.list('/api/goods-receipts/'),
        ApiService.instance.list('/api/suppliers/'),
        ApiService.instance.list('/api/products/'),
        ApiService.instance.list('/api/warehouses/'),
      ]);
      setState(() {
        _receipts = results[0].map((e) => GoodsReceipt.fromJson(e as Map<String, dynamic>)).toList();
        _suppliers = results[1].map((e) => Supplier.fromJson(e as Map<String, dynamic>)).toList();
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

  String _supplierName(int id) {
    final matches = _suppliers.where((s) => s.id == id);
    return matches.isEmpty ? 'Supplier #$id' : matches.first.name;
  }

  Future<void> _create() async {
    final result = await _openGoodsReceiptForm(context, null, _suppliers, _products, _warehouses);
    if (result == null) return;
    try {
      await ApiService.instance.create('/api/goods-receipts/', result.toJson());
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _edit(GoodsReceipt r) async {
    final result = await _openGoodsReceiptForm(context, r, _suppliers, _products, _warehouses);
    if (result == null) return;
    try {
      await ApiService.instance.update('/api/goods-receipts/${r.id}', result.toJson());
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _delete(GoodsReceipt r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Goods Receipt?'),
        content: Text('Delete receipt "${r.grnNo ?? '#${r.id}'}"?'),
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
      await ApiService.instance.delete('/api/goods-receipts/${r.id}');
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  /// Posts one STOCK IN StockLedger row per line (backend/app/routers/
  /// goods_receipts.py's confirm endpoint) and locks the receipt.
  Future<void> _confirm(GoodsReceipt r) async {
    try {
      await ApiService.instance.create('/api/goods-receipts/${r.id}/confirm', {});
      _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Goods receipt confirmed -- stock updated.')),
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
    if (_suppliers.isEmpty && !_loading) {
      return const Center(child: Text('Add a Supplier first, then come back here to record a Goods Receipt.'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text('Goods Receipts', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              FilledButton.icon(
                onPressed: _suppliers.isEmpty ? null : _create,
                icon: const Icon(Icons.add),
                label: const Text('New Receipt'),
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(_error!, style: const TextStyle(color: Colors.red))),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _receipts.isEmpty
                  ? const Center(child: Text('No goods receipts yet.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _receipts.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final r = _receipts[i];
                          return ListTile(
                            title: Text('${r.grnNo ?? '#${r.id}'} — ${_supplierName(r.supplierId)}'),
                            subtitle: Text('${r.receiptDate ?? 'no date'} • ${r.items.length} line(s)'
                                '${r.purchaseOrderId != null ? ' • from PO #${r.purchaseOrderId}' : ''}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                StatusBadge(status: r.status),
                                const SizedBox(width: 8),
                                if (r.status == 'Draft')
                                  OutlinedButton.icon(
                                    onPressed: () => _confirm(r),
                                    icon: const Icon(Icons.inventory_outlined, size: 18),
                                    label: const Text('Confirm'),
                                  ),
                                if (r.status != 'Confirmed') ...[
                                  IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _edit(r), tooltip: 'Edit'),
                                  IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(r), tooltip: 'Delete'),
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

Future<GoodsReceipt?> _openGoodsReceiptForm(
  BuildContext context,
  GoodsReceipt? existing,
  List<Supplier> suppliers,
  List<Product> products,
  List<Warehouse> warehouses,
) {
  int? supplierId = existing?.supplierId ?? (suppliers.isEmpty ? null : suppliers.first.id);
  int? warehouseId = existing?.warehouseId ?? (warehouses.isEmpty ? null : warehouses.first.id);
  final receiptDate = TextEditingController(text: existing?.receiptDate ?? DateTime.now().toIso8601String().substring(0, 10));
  final notes = TextEditingController(text: existing?.notes ?? '');
  List<InquiryItem> items = existing?.items.map((e) => InquiryItem(
        id: e.id,
        productId: e.productId,
        quantity: e.quantity,
        remarks: e.remarks,
      )).toList() ?? [];
  final qtyCtrls = items.map((e) => TextEditingController(text: e.quantity.toString())).toList();

  return showDialog<GoodsReceipt>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      return AlertDialog(
        title: Text(existing == null ? 'New Goods Receipt' : 'Edit Goods Receipt'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<int>(
                value: supplierId,
                decoration: const InputDecoration(labelText: 'Supplier'),
                items: suppliers.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                onChanged: (v) => setState(() => supplierId = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                value: warehouseId,
                decoration: const InputDecoration(labelText: 'Warehouse (optional)'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Unassigned')),
                  ...warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))),
                ],
                onChanged: (v) => setState(() => warehouseId = v),
              ),
              const SizedBox(height: 12),
              TextField(controller: receiptDate, decoration: const InputDecoration(labelText: 'Receipt Date (YYYY-MM-DD)')),
              const SizedBox(height: 12),
              TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes'), maxLines: 2),
              const SizedBox(height: 16),
              Row(children: [
                Text('What arrived?', style: Theme.of(ctx).textTheme.titleSmall),
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
                  child: Text('No lines yet. Add at least one product received.'),
                ),
              for (int i = 0; i < items.length; i++)
                Padding(
                  key: ValueKey('grn-line-$i-${items[i].hashCode}'),
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
              if (supplierId == null || receiptDate.text.trim().isEmpty || items.isEmpty) return;
              Navigator.pop(
                ctx,
                GoodsReceipt(
                  id: existing?.id,
                  grnNo: existing?.grnNo,
                  purchaseOrderId: existing?.purchaseOrderId,
                  supplierId: supplierId!,
                  warehouseId: warehouseId,
                  receiptDate: receiptDate.text.trim(),
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
