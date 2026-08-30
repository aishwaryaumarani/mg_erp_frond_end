import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// Stock Summary -- current on-hand per product, derived from the
/// append-only StockLedger (backend/app/routers/stock.py). Nothing on
/// this screen writes: stock only moves by confirming a Goods Receipt
/// (IN), confirming a Delivery (OUT), or posting an Adjustment
/// (see stock_adjustment_screen.dart).
///
/// The list is driven by the Product master, so a product that has never
/// moved still appears at 0 rather than silently missing from the report.
class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  List<StockBalance> _rows = [];
  List<Warehouse> _warehouses = [];
  bool _loading = true;
  String? _error;

  final _searchCtrl = TextEditingController();
  int? _warehouseId;
  String _filter = 'all'; // all | low | out

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiService.instance.list('/api/stock/', query: {
          'q': _searchCtrl.text.trim(),
          'warehouse_id': _warehouseId,
          'low_stock_only': _filter == 'low' ? 'true' : null,
          'out_of_stock_only': _filter == 'out' ? 'true' : null,
          'limit': 500,
        }),
        ApiService.instance.list('/api/warehouses/'),
      ]);
      setState(() {
        _rows = results[0].map((e) => StockBalance.fromJson(e as Map<String, dynamic>)).toList();
        _warehouses = results[1].map((e) => Warehouse.fromJson(e as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  double get _totalValue => _rows.fold(0.0, (sum, r) => sum + r.stockValue);

  Color _rowColor(StockBalance r) {
    if (r.isOutOfStock) return AppColors.rose;
    if (r.isLowStock) return AppColors.amber;
    return AppColors.teal;
  }

  Future<void> _openDetail(StockBalance row) async {
    try {
      final json = await ApiService.instance.getOne('/api/stock/product/${row.productId}');
      if (!mounted) return;
      final detail = StockBalance.fromJson(json);
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('${detail.productName} [${detail.productCode}]'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  _stat('On Hand', _qty(detail.onHand), _rowColor(detail)),
                  const SizedBox(width: 10),
                  _stat('Total In', _qty(detail.quantityIn), AppColors.green),
                  const SizedBox(width: 10),
                  _stat('Total Out', _qty(detail.quantityOut), AppColors.orange),
                ]),
                const SizedBox(height: 16),
                Text('Minimum stock ${_qty(detail.minimumStock)} • reorder level ${_qty(detail.reorderLevel)}',
                    style: const TextStyle(color: AppColors.slate, fontSize: 12)),
                Text('Valued at ${detail.stockValue.toStringAsFixed(2)} '
                    '(purchase price ${detail.purchasePrice.toStringAsFixed(2)})',
                    style: const TextStyle(color: AppColors.slate, fontSize: 12)),
                const SizedBox(height: 16),
                Text('Per warehouse', style: Theme.of(ctx).textTheme.titleSmall),
                const SizedBox(height: 6),
                if (detail.warehouses.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No movements recorded for this product yet.'),
                  ),
                for (final w in detail.warehouses)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.store_outlined, size: 20),
                    title: Text(w.displayName),
                    subtitle: Text('in ${_qty(w.quantityIn)} • out ${_qty(w.quantityOut)}'),
                    trailing: Text(_qty(w.onHand),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
              ]),
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is ApiException ? e.message : e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _stat(String label, String value, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: AppColors.tintedBox(color),
          child: Column(children: [
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: AppColors.slate, fontSize: 11)),
          ]),
        ),
      );

  /// Quantities are doubles server-side but almost always whole units, so
  /// trim a trailing ".0" rather than showing "12.0 pcs".
  static String _qty(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(children: [
              Text('Stock Summary', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              if (!_loading)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: AppColors.tintedBox(AppColors.teal),
                  child: Text('Total value ${_totalValue.toStringAsFixed(2)}',
                      style: const TextStyle(color: AppColors.teal, fontWeight: FontWeight.bold)),
                ),
              const SizedBox(width: 8),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Search product code or name',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _load(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<int?>(
                  value: _warehouseId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Warehouse', isDense: true),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('All warehouses')),
                    for (final w in _warehouses)
                      DropdownMenuItem<int?>(value: w.id, child: Text(w.name)),
                  ],
                  onChanged: (v) {
                    setState(() => _warehouseId = v);
                    _load();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _filter,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Show', isDense: true),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All products')),
                    DropdownMenuItem(value: 'low', child: Text('Low stock only')),
                    DropdownMenuItem(value: 'out', child: Text('Out of stock only')),
                  ],
                  onChanged: (v) {
                    setState(() => _filter = v ?? 'all');
                    _load();
                  },
                ),
              ),
            ]),
          ]),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _rows.isEmpty
                  ? const Center(child: Text('No products match these filters.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _rows.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final r = _rows[i];
                          final color = _rowColor(r);
                          return ListTile(
                            onTap: () => _openDetail(r),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: AppColors.tintedBox(color, radius: 10, border: false),
                              child: Icon(
                                r.isOutOfStock
                                    ? Icons.remove_shopping_cart_outlined
                                    : r.isLowStock
                                        ? Icons.warning_amber_outlined
                                        : Icons.inventory_2_outlined,
                                color: color,
                                size: 20,
                              ),
                            ),
                            title: Text('${r.productName} [${r.productCode}]'),
                            subtitle: Text('in ${_qty(r.quantityIn)} • out ${_qty(r.quantityOut)}'
                                '${r.minimumStock > 0 ? ' • min ${_qty(r.minimumStock)}' : ''}'
                                '${r.stockValue > 0 ? ' • value ${r.stockValue.toStringAsFixed(2)}' : ''}'),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(_qty(r.onHand),
                                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 17)),
                                Text(r.stockStatus, style: TextStyle(color: color, fontSize: 11)),
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
