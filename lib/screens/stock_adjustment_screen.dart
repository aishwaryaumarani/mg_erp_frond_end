import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/quick_add.dart';

/// Stock Adjustment -- the one place a human moves stock directly
/// (opening balances, stock takes, damage, write-offs). Goods Receipt and
/// Delivery remain the only document-driven movements (spec sec. 8).
///
/// Adjustments are append-only like every other movement: this screen can
/// post one and list recent ones, but never edit or delete. A wrong
/// adjustment is corrected by posting the opposite one, which is exactly
/// what the ledger should show happened.
class StockAdjustmentScreen extends StatefulWidget {
  const StockAdjustmentScreen({super.key});

  @override
  State<StockAdjustmentScreen> createState() => _StockAdjustmentScreenState();
}

class _StockAdjustmentScreenState extends State<StockAdjustmentScreen> {
  List<StockLedgerEntry> _recent = [];
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
        ApiService.instance.list('/api/stock/ledger',
            query: {'reference_type': 'Adjustment', 'limit': 100}),
        ApiService.instance.list('/api/products/'),
        ApiService.instance.list('/api/warehouses/'),
      ]);
      setState(() {
        _recent = results[0].map((e) => StockLedgerEntry.fromJson(e as Map<String, dynamic>)).toList();
        _products = results[1].map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
        _warehouses = results[2].map((e) => Warehouse.fromJson(e as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _adjust() async {
    final payload = await _openAdjustmentForm(context, _products, _warehouses);
    if (payload == null) return;
    try {
      await ApiService.instance.create('/api/stock/adjustments', payload);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adjustment posted — stock updated.')),
      );
    } catch (e) {
      if (!mounted) return;
      // The backend refuses an OUT that would drive stock negative and
      // says how much is actually on hand -- surface that verbatim.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ApiException ? e.message : e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  static String _qty(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  static String _when(String iso) => iso.length >= 16 ? iso.substring(0, 16).replaceFirst('T', ' ') : iso;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Text('Stock Adjustments', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            FilledButton.icon(
              onPressed: _products.isEmpty ? null : _adjust,
              icon: const Icon(Icons.tune_outlined),
              label: const Text('New Adjustment'),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: AppColors.tintedBox(AppColors.teal),
            child: const Row(children: [
              Icon(Icons.info_outline, size: 18, color: AppColors.teal),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Adjustments are permanent. To undo one, post the opposite movement — '
                  'the ledger keeps both, which is what an audit trail is for.',
                  style: TextStyle(color: AppColors.teal, fontSize: 12),
                ),
              ),
            ]),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text('Recent adjustments', style: Theme.of(context).textTheme.titleSmall),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _recent.isEmpty
                  ? const Center(child: Text('No adjustments posted yet.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _recent.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final r = _recent[i];
                          final color = r.isIn ? AppColors.green : AppColors.orange;
                          return ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: AppColors.tintedBox(color, radius: 10, border: false),
                              child: Icon(r.isIn ? Icons.add : Icons.remove, color: color, size: 20),
                            ),
                            title: Text(r.productName == null
                                ? 'Product #${r.productId}'
                                : '${r.productName} [${r.productCode}]'),
                            subtitle: Text('${_when(r.movementDate)} • ${r.warehouseName ?? 'Unassigned'}'
                                '${r.notes != null && r.notes!.isNotEmpty ? '\n${r.notes}' : ''}'),
                            isThreeLine: r.notes != null && r.notes!.isNotEmpty,
                            trailing: Text(
                              '${r.isIn ? '+' : '−'}${_qty(r.quantity)}',
                              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
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

/// Returns the raw StockAdjustmentCreate body rather than a model --
/// an adjustment is a one-way command, not an entity the client owns.
Future<Map<String, dynamic>?> _openAdjustmentForm(
  BuildContext context,
  List<Product> products,
  List<Warehouse> warehouses,
) {
  int? productId = products.isEmpty ? null : products.first.id;
  int? warehouseId;
  String movementType = 'IN';
  final qtyCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  double? onHand;
  bool checking = false;

  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      // Show what's currently on hand for the chosen product/warehouse so
      // the user isn't guessing before an OUT the backend would refuse.
      Future<void> refreshOnHand() async {
        if (productId == null) return;
        setState(() => checking = true);
        try {
          final rows = await ApiService.instance.list('/api/stock/', query: {
            'warehouse_id': warehouseId,
            'limit': 500,
          });
          final match = rows
              .map((e) => StockBalance.fromJson(e as Map<String, dynamic>))
              .where((b) => b.productId == productId);
          setState(() {
            onHand = match.isEmpty ? 0 : match.first.onHand;
            checking = false;
          });
        } catch (_) {
          setState(() => checking = false);
        }
      }

      if (onHand == null && !checking && productId != null) refreshOnHand();

      return AlertDialog(
        title: const Text('New Stock Adjustment'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              QuickAddDropdown<Product>(
                label: 'Product',
                value: productId,
                options: products,
                idOf: (p) => p.id,
                labelOf: (p) => '${p.name} [${p.productCode}]',
                addNewLabel: 'Add New Product',
                allowUnknownValue: true,
                onCreate: quickAddProduct,
                onCreated: (p) => setState(() {
                  products.add(p);
                  productId = p.id;
                  onHand = null;
                }),
                onChanged: (v) => setState(() {
                  productId = v;
                  onHand = null;
                }),
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
                  onHand = null;
                }),
                onChanged: (v) => setState(() {
                  warehouseId = v;
                  onHand = null;
                }),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: AppColors.tintedBox(AppColors.slate),
                child: Text(
                  checking
                      ? 'Checking current stock…'
                      : onHand == null
                          ? 'Pick a product to see its current stock.'
                          : 'Currently on hand: ${_StockAdjustmentScreenState._qty(onHand!)}'
                              '${warehouseId == null ? ' (all warehouses)' : ' in this warehouse'}',
                  style: const TextStyle(color: AppColors.slate, fontSize: 12),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: movementType,
                decoration: const InputDecoration(labelText: 'Direction'),
                items: const [
                  DropdownMenuItem(value: 'IN', child: Text('Stock In (add)')),
                  DropdownMenuItem(value: 'OUT', child: Text('Stock Out (remove)')),
                ],
                onChanged: (v) => setState(() => movementType = v ?? 'IN'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyCtrl,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  helperText: 'Always positive — the direction above decides in or out',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  hintText: 'Opening balance / stock take / damaged / write-off',
                ),
                maxLines: 2,
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final qty = double.tryParse(qtyCtrl.text.trim()) ?? 0;
              if (productId == null || qty <= 0) return;
              Navigator.pop(ctx, {
                'product_id': productId,
                'warehouse_id': warehouseId,
                'movement_type': movementType,
                'quantity': qty,
                'notes': notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
              });
            },
            child: const Text('Post Adjustment'),
          ),
        ],
      );
    }),
  );
}
