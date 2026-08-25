import 'package:flutter/material.dart';
import '../models/models.dart';

/// Editable line-items table shared by the Quotation and Sales Order forms.
/// Each row picks a Product (which seeds unit price from the product's
/// Retail price list entry when available, editable after), a quantity,
/// a discount %, and a Tax -- then shows the computed line total live.
/// Owns its own list of rows internally and reports every change back via
/// [onChanged] so the enclosing form dialog can read the latest items (and
/// totals) at Save time.
///
/// Each row keeps its own TextEditingControllers (qty/price/discount) kept
/// in lock-step with [_items] by index. This matters: a bare
/// `TextFormField(initialValue: ...)` only applies that value on first
/// build. When a row above is deleted, Flutter reuses the row's Element at
/// the same list position, and a keyless TextFormField keeps its OLD text
/// instead of picking up the value of the item now at that index -- so
/// deleting line 1 could silently leave line 2's qty/price showing line 1's
/// stale numbers. Explicit controllers (updated in code, not via
/// initialValue) avoid that.
class DocLineItemsEditor extends StatefulWidget {
  final List<Product> products;
  final List<Tax> taxes;
  final List<DocLineItem> initialItems;
  final ValueChanged<List<DocLineItem>> onChanged;

  const DocLineItemsEditor({
    super.key,
    required this.products,
    required this.taxes,
    required this.initialItems,
    required this.onChanged,
  });

  @override
  State<DocLineItemsEditor> createState() => _DocLineItemsEditorState();
}

class _DocLineItemsEditorState extends State<DocLineItemsEditor> {
  late List<DocLineItem> _items;
  final List<TextEditingController> _qtyCtrls = [];
  final List<TextEditingController> _priceCtrls = [];
  final List<TextEditingController> _discountCtrls = [];

  @override
  void initState() {
    super.initState();
    _items = widget.initialItems.map((e) => DocLineItem(
          id: e.id,
          productId: e.productId,
          quantity: e.quantity,
          unitPrice: e.unitPrice,
          discountPercent: e.discountPercent,
          taxId: e.taxId,
          taxRatePercent: e.taxRatePercent,
        )).toList();
    for (final item in _items) {
      _addControllersFor(item);
    }
  }

  @override
  void dispose() {
    for (final c in [..._qtyCtrls, ..._priceCtrls, ..._discountCtrls]) {
      c.dispose();
    }
    super.dispose();
  }

  void _addControllersFor(DocLineItem item) {
    _qtyCtrls.add(TextEditingController(text: item.quantity.toString()));
    _priceCtrls.add(TextEditingController(text: item.unitPrice.toString()));
    _discountCtrls.add(TextEditingController(text: item.discountPercent.toString()));
  }

  void _notify() => widget.onChanged(_items);

  Tax? _taxOf(int? id) {
    if (id == null) return null;
    final matches = widget.taxes.where((t) => t.id == id);
    return matches.isEmpty ? null : matches.first;
  }

  void _addRow() {
    final item = DocLineItem();
    setState(() {
      _items.add(item);
      _addControllersFor(item);
    });
    _notify();
  }

  void _removeRow(int index) {
    setState(() {
      _items.removeAt(index);
      _qtyCtrls.removeAt(index).dispose();
      _priceCtrls.removeAt(index).dispose();
      _discountCtrls.removeAt(index).dispose();
    });
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = _items.fold(0.0, (sum, i) => sum + i.lineSubtotal);
    final tax = _items.fold(0.0, (sum, i) => sum + i.lineTax);
    final total = _items.fold(0.0, (sum, i) => sum + i.lineTotal);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Line Items', style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            TextButton.icon(
              onPressed: widget.products.isEmpty ? null : _addRow,
              icon: const Icon(Icons.add),
              label: const Text('Add Line'),
            ),
          ],
        ),
        if (_items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('No lines yet. Add at least one product line.'),
          ),
        for (int i = 0; i < _items.length; i++) _row(i),
        const Divider(height: 24),
        Align(
          alignment: Alignment.centerRight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Subtotal: ₹${subtotal.toStringAsFixed(2)}'),
              Text('Tax: ₹${tax.toStringAsFixed(2)}'),
              Text('Total: ₹${total.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(int i) {
    final item = _items[i];
    return Padding(
      key: ValueKey('line-$i-${item.hashCode}'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<int>(
                  value: item.productId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Product', isDense: true),
                  items: [
                    ...widget.products.map((p) => DropdownMenuItem(value: p.id, child: Text('${p.name} [${p.productCode}]', overflow: TextOverflow.ellipsis))),
                    // Guards against a DropdownButtonFormField assertion crash: if this
                    // line references a product not in the loaded list (e.g. deleted,
                    // or not yet fetched), the dropdown's value wouldn't match any item.
                    if (item.productId != null && widget.products.every((p) => p.id != item.productId))
                      DropdownMenuItem(value: item.productId, child: Text('Unknown product #${item.productId}')),
                  ],
                  onChanged: (v) {
                    setState(() => item.productId = v);
                    _notify();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _qtyCtrls[i],
                  decoration: const InputDecoration(labelText: 'Qty', isDense: true),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) {
                    item.quantity = double.tryParse(v) ?? 0;
                    setState(() {});
                    _notify();
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Remove line',
                onPressed: () => _removeRow(i),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _priceCtrls[i],
                  decoration: const InputDecoration(labelText: 'Unit Price (₹)', isDense: true),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) {
                    item.unitPrice = double.tryParse(v) ?? 0;
                    setState(() {});
                    _notify();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _discountCtrls[i],
                  decoration: const InputDecoration(labelText: 'Discount %', isDense: true),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) {
                    item.discountPercent = double.tryParse(v) ?? 0;
                    setState(() {});
                    _notify();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<int?>(
                  value: item.taxId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Tax', isDense: true),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    ...widget.taxes.map((t) => DropdownMenuItem(
                          value: t.id,
                          child: Text('${t.name} (${t.ratePercent.toStringAsFixed(0)}%)', overflow: TextOverflow.ellipsis),
                        )),
                  ],
                  onChanged: (v) {
                    final t = _taxOf(v);
                    item.taxId = v;
                    item.taxRatePercent = t?.ratePercent ?? 0;
                    setState(() {});
                    _notify();
                  },
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text('Line total: ₹${item.lineTotal.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          const Divider(height: 16),
        ],
      ),
    );
  }
}
