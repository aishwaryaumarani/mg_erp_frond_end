import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';

/// Extra charges on a Sales Order -- labour, parking, freight and so on.
///
/// Added one row at a time: what it is, the amount, and its own tax rate
/// (freight and goods are not always taxed alike). These never become
/// line items, so they don't touch quantities, stock or the delivery
/// note -- they only add to the money (backend/app/routers/sales_orders.py).
class OrderChargesEditor extends StatefulWidget {
  final List<OrderCharge> initialCharges;
  final ValueChanged<List<OrderCharge>> onChanged;

  const OrderChargesEditor({super.key, required this.initialCharges, required this.onChanged});

  @override
  State<OrderChargesEditor> createState() => _OrderChargesEditorState();
}

class _OrderChargesEditorState extends State<OrderChargesEditor> {
  late List<OrderCharge> _charges;
  // One controller per row, kept in lock-step with _charges by index --
  // the same reason doc_items_editor.dart keeps its own qty controllers.
  late List<TextEditingController> _labelCtrls;
  late List<TextEditingController> _amountCtrls;
  late List<TextEditingController> _taxCtrls;

  @override
  void initState() {
    super.initState();
    _charges = widget.initialCharges
        .map((c) => OrderCharge(id: c.id, label: c.label, amount: c.amount, taxPercent: c.taxPercent))
        .toList();
    _labelCtrls = _charges.map((c) => TextEditingController(text: c.label)).toList();
    _amountCtrls = _charges.map((c) => TextEditingController(text: _num(c.amount))).toList();
    _taxCtrls = _charges.map((c) => TextEditingController(text: _num(c.taxPercent))).toList();
  }

  @override
  void dispose() {
    for (final c in [..._labelCtrls, ..._amountCtrls, ..._taxCtrls]) {
      c.dispose();
    }
    super.dispose();
  }

  static String _num(double v) => v == 0 ? '' : (v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v');

  void _publish() => widget.onChanged(_charges);

  void _add() {
    setState(() {
      _charges.add(OrderCharge());
      _labelCtrls.add(TextEditingController());
      _amountCtrls.add(TextEditingController());
      _taxCtrls.add(TextEditingController());
    });
    _publish();
  }

  void _removeAt(int i) {
    setState(() {
      _charges.removeAt(i);
      _labelCtrls.removeAt(i).dispose();
      _amountCtrls.removeAt(i).dispose();
      _taxCtrls.removeAt(i).dispose();
    });
    _publish();
  }

  double get _amountTotal => _charges.fold(0.0, (sum, c) => sum + c.amount);
  double get _taxTotal => _charges.fold(0.0, (sum, c) => sum + c.taxAmount);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_charges.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('No extra charges. Add one for labour, parking, freight and the like.',
                style: TextStyle(color: AppColors.muted)),
          ),
        for (int i = 0; i < _charges.length; i++)
          Padding(
            key: ValueKey('charge-$i-${_charges[i].hashCode}'),
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _labelCtrls[i],
                    decoration: const InputDecoration(
                      labelText: 'Charge',
                      hintText: 'Labour / Parking / Freight',
                      isDense: true,
                    ),
                    onChanged: (v) {
                      _charges[i].label = v;
                      _publish();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _amountCtrls[i],
                    decoration: const InputDecoration(labelText: 'Amount', isDense: true),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) => setState(() {
                      _charges[i].amount = double.tryParse(v) ?? 0;
                      _publish();
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _taxCtrls[i],
                    decoration: const InputDecoration(labelText: 'Tax %', isDense: true),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) => setState(() {
                      _charges[i].taxPercent = double.tryParse(v) ?? 0;
                      _publish();
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 92,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      '₹${_charges[i].total.toStringAsFixed(2)}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Remove charge',
                  onPressed: () => _removeAt(i),
                ),
              ],
            ),
          ),
        Row(
          children: [
            TextButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: const Text('Add Charge'),
            ),
            const Spacer(),
            if (_charges.isNotEmpty)
              Text(
                'Charges ₹${_amountTotal.toStringAsFixed(2)}  +  tax ₹${_taxTotal.toStringAsFixed(2)}',
                style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600),
              ),
          ],
        ),
      ],
    );
  }
}
