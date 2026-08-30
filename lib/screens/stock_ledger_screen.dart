import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// Stock Ledger -- the raw movement log, newest first. Append-only: every
/// row names the document that caused it (spec sec. 8), so there is no
/// edit or delete here by design. A wrong movement is corrected by
/// posting the opposite Adjustment, never by rewriting history.
class StockLedgerScreen extends StatefulWidget {
  const StockLedgerScreen({super.key});

  @override
  State<StockLedgerScreen> createState() => _StockLedgerScreenState();
}

class _StockLedgerScreenState extends State<StockLedgerScreen> {
  List<StockLedgerEntry> _rows = [];
  List<Product> _products = [];
  List<Warehouse> _warehouses = [];
  bool _loading = true;
  String? _error;

  int? _productId;
  int? _warehouseId;
  String? _movementType;
  String? _referenceType;

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
        ApiService.instance.list('/api/stock/ledger', query: {
          'product_id': _productId,
          'warehouse_id': _warehouseId,
          'movement_type': _movementType,
          'reference_type': _referenceType,
          'limit': 300,
        }),
        ApiService.instance.list('/api/products/'),
        ApiService.instance.list('/api/warehouses/'),
      ]);
      setState(() {
        _rows = results[0].map((e) => StockLedgerEntry.fromJson(e as Map<String, dynamic>)).toList();
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

  static String _qty(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  /// Movement dates come back as full ISO timestamps; the date and
  /// minute are all that matter in a movement log.
  static String _when(String iso) => iso.length >= 16 ? iso.substring(0, 16).replaceFirst('T', ' ') : iso;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(children: [
              Text('Stock Ledger', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<int?>(
                  value: _productId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Product', isDense: true),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('All products')),
                    for (final p in _products)
                      DropdownMenuItem<int?>(value: p.id, child: Text('${p.name} [${p.productCode}]')),
                  ],
                  onChanged: (v) {
                    setState(() => _productId = v);
                    _load();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<int?>(
                  value: _warehouseId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Warehouse', isDense: true),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('All')),
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
                child: DropdownButtonFormField<String?>(
                  value: _movementType,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Direction', isDense: true),
                  items: const [
                    DropdownMenuItem<String?>(value: null, child: Text('In & Out')),
                    DropdownMenuItem<String?>(value: 'IN', child: Text('Stock In')),
                    DropdownMenuItem<String?>(value: 'OUT', child: Text('Stock Out')),
                  ],
                  onChanged: (v) {
                    setState(() => _movementType = v);
                    _load();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _referenceType,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Source', isDense: true),
                  items: const [
                    DropdownMenuItem<String?>(value: null, child: Text('All sources')),
                    DropdownMenuItem<String?>(value: 'GoodsReceipt', child: Text('Goods Receipt')),
                    DropdownMenuItem<String?>(value: 'Delivery', child: Text('Delivery')),
                    DropdownMenuItem<String?>(value: 'Adjustment', child: Text('Adjustment')),
                  ],
                  onChanged: (v) {
                    setState(() => _referenceType = v);
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
                  ? const Center(child: Text('No stock movements match these filters.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _rows.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final r = _rows[i];
                          final color = r.isIn ? AppColors.green : AppColors.orange;
                          return ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: AppColors.tintedBox(color, radius: 10, border: false),
                              child: Icon(
                                r.isIn ? Icons.arrow_downward : Icons.arrow_upward,
                                color: color,
                                size: 20,
                              ),
                            ),
                            title: Text(r.productName == null
                                ? 'Product #${r.productId}'
                                : '${r.productName} [${r.productCode}]'),
                            subtitle: Text(
                              '${_when(r.movementDate)} • ${r.referenceType}'
                              '${r.referenceId != null ? ' #${r.referenceId}' : ''}'
                              ' • ${r.warehouseName ?? 'Unassigned'}'
                              '${r.notes != null && r.notes!.isNotEmpty ? '\n${r.notes}' : ''}',
                            ),
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
