import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';

const _priceTypes = ['Purchase', 'Retail', 'Wholesale', 'Dealer', 'Customer-specific'];

/// Price Management module (spec sec. 3). Prices are scoped to a
/// product (and optionally a specific customer), never hard-coded
/// into Sales -- this screen manages that table directly, and
/// includes a small "Suggested Price" tester so you can see the
/// `/api/price-lists/suggest` auto-suggest endpoint working the same
/// way a Quotation/Sales Order screen would call it later.
class PriceListScreen extends StatefulWidget {
  const PriceListScreen({super.key});

  @override
  State<PriceListScreen> createState() => _PriceListScreenState();
}

class _PriceListScreenState extends State<PriceListScreen> {
  List<Product> _products = [];
  List<Customer> _customers = [];
  Product? _selectedProduct;
  List<PriceListEntry> _entries = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.instance.list('/api/products/'),
        ApiService.instance.list('/api/customers/'),
      ]);
      _products = results[0].map((e) => Product.fromJson(e)).toList();
      _customers = results[1].map((e) => Customer.fromJson(e)).toList();
      if (_products.isNotEmpty) {
        _selectedProduct = _products.first;
        await _loadEntries();
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadEntries() async {
    if (_selectedProduct == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await ApiService.instance
          .list('/api/price-lists/', query: {'product_id': _selectedProduct!.id});
      setState(() {
        _entries = raw.map((e) => PriceListEntry.fromJson(e)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _customerLabel(int? id) {
    if (id == null) return 'All customers';
    final c = _customers.where((c) => c.id == id).toList();
    return c.isEmpty ? 'Customer #$id' : c.first.name;
  }

  Future<void> _createOrEdit([PriceListEntry? existing]) async {
    if (_selectedProduct == null) return;
    final result = await _openForm(context, _selectedProduct!.id??0, existing, _customers);
    if (result == null) return;
    try {
      if (existing == null) {
        await ApiService.instance.create('/api/price-lists/', result.toJson());
      } else {
        await ApiService.instance.update('/api/price-lists/${existing.id}', result.toJson());
      }
      _loadEntries();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _delete(PriceListEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete price entry?'),
        content: Text('Remove the ${entry.priceType} price of ₹${entry.price.toStringAsFixed(2)}?'),
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
      await ApiService.instance.delete('/api/price-lists/${entry.id}');
      _loadEntries();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _testSuggest() async {
    if (_selectedProduct == null) return;
    String priceType = 'Retail';
    final qtyCtrl = TextEditingController(text: '1');

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
        Map<String, dynamic>? result;
        String? error;
        return AlertDialog(
          title: const Text('Suggest Applicable Price'),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Product: ${_selectedProduct!.name}'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: priceType,
                decoration: const InputDecoration(labelText: 'Price Type'),
                items: _priceTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setState(() => priceType = v ?? 'Retail'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyCtrl,
                decoration: const InputDecoration(labelText: 'Quantity'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  try {
                    final data = await ApiService.instance.getOne(
                      '/api/price-lists/suggest?product_id=${_selectedProduct!.id}'
                      '&price_type=$priceType&quantity=${qtyCtrl.text}',
                    );
                    setState(() {
                      result = data;
                      error = null;
                    });
                  } catch (e) {
                    setState(() {
                      error = e.toString();
                      result = null;
                    });
                  }
                },
                child: const Text('Get Suggested Price'),
              ),
              const SizedBox(height: 12),
              if (result != null)
                Text('Suggested price: ₹${result!['price']}\n(min qty ${result!['min_quantity']}, discount ${result!['discount_percent']}%)'),
              if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ],
        );
      }),
    );
  }

  void _showError(Object e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e is ApiException ? e.message : e.toString()), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_products.isEmpty && !_loading) {
      return const Center(
        child: Text('Add a Product first, then come back here to set its prices.'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<Product>(
                  value: _selectedProduct,
                  decoration: const InputDecoration(labelText: 'Product'),
                  items: _products
                      .map((p) => DropdownMenuItem(value: p, child: Text('${p.name} [${p.productCode}]')))
                      .toList(),
                  onChanged: (p) {
                    setState(() => _selectedProduct = p);
                    _loadEntries();
                  },
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _selectedProduct == null ? null : _testSuggest,
                icon: const Icon(Icons.calculate_outlined),
                label: const Text('Suggest Price'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _selectedProduct == null ? null : () => _createOrEdit(),
                icon: const Icon(Icons.add),
                label: const Text('New Price'),
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(_error!, style: const TextStyle(color: Colors.red))),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _entries.isEmpty
                  ? const Center(child: Text('No prices set for this product yet.'))
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _entries.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final e = _entries[i];
                        return ListTile(
                          title: Text('${e.priceType} — ₹${e.price.toStringAsFixed(2)}'),
                          subtitle: Text(
                            '${_customerLabel(e.customerId)} • Min Qty ${e.minQuantity.toStringAsFixed(0)} • '
                            'Discount ${e.discountPercent.toStringAsFixed(0)}%'
                            '${e.effectiveFrom != null ? ' • From ${e.effectiveFrom}' : ''}'
                            '${e.effectiveTo != null ? ' to ${e.effectiveTo}' : ''}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _createOrEdit(e)),
                              IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(e)),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

Future<PriceListEntry?> _openForm(
  BuildContext context,
  int productId,
  PriceListEntry? existing,
  List<Customer> customers,
) {
  String priceType = existing?.priceType ?? 'Retail';
  int? customerId = existing?.customerId;
  final price = TextEditingController(text: existing?.price.toString() ?? '0');
  final minQty = TextEditingController(text: existing?.minQuantity.toString() ?? '1');
  final discount = TextEditingController(text: existing?.discountPercent.toString() ?? '0');
  final effectiveFrom = TextEditingController(text: existing?.effectiveFrom ?? '');
  final effectiveTo = TextEditingController(text: existing?.effectiveTo ?? '');

  return showDialog<PriceListEntry>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      return AlertDialog(
        title: Text(existing == null ? 'New Price' : 'Edit Price'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                value: priceType,
                decoration: const InputDecoration(labelText: 'Price Type'),
                items: _priceTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setState(() => priceType = v ?? 'Retail'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                value: customerId,
                decoration: const InputDecoration(labelText: 'Customer (optional -- for customer-specific pricing)'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('— applies to all customers —')),
                  ...customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                ],
                onChanged: (v) => setState(() => customerId = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: price,
                decoration: const InputDecoration(labelText: 'Price (₹)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: minQty,
                    decoration: const InputDecoration(labelText: 'Minimum Quantity'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: discount,
                    decoration: const InputDecoration(labelText: 'Discount %'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: effectiveFrom,
                    decoration: const InputDecoration(labelText: 'Effective From (YYYY-MM-DD)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: effectiveTo,
                    decoration: const InputDecoration(labelText: 'Effective To (YYYY-MM-DD)'),
                  ),
                ),
              ]),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(
                ctx,
                PriceListEntry(
                  id: existing?.id,
                  productId: productId,
                  priceType: priceType,
                  customerId: customerId,
                  price: double.tryParse(price.text.trim()) ?? 0,
                  minQuantity: double.tryParse(minQty.text.trim()) ?? 1,
                  discountPercent: double.tryParse(discount.text.trim()) ?? 0,
                  effectiveFrom: effectiveFrom.text.trim().isEmpty ? null : effectiveFrom.text.trim(),
                  effectiveTo: effectiveTo.text.trim().isEmpty ? null : effectiveTo.text.trim(),
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
