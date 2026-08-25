import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';

const _paymentModes = ['Cash', 'Bank', 'Cheque', 'UPI'];

/// Supplier Payment screen -- recording a payment IS posting it (backend/
/// app/routers/supplier_payments.py has no draft/post split): it posts
/// AP Dr / Bank-Cash Cr immediately and updates the target Purchase
/// Invoice's amount_paid/status. Only invoices that are Posted or
/// PartiallyPaid can be paid against. Deleting a payment record here only
/// soft-deletes it -- it does NOT reverse the journal entry or the
/// invoice's amount_paid (documented backend limitation), so use delete
/// sparingly.
class SupplierPaymentScreen extends StatefulWidget {
  const SupplierPaymentScreen({super.key});

  @override
  State<SupplierPaymentScreen> createState() => _SupplierPaymentScreenState();
}

class _SupplierPaymentScreenState extends State<SupplierPaymentScreen> {
  List<SupplierPayment> _payments = [];
  List<Supplier> _suppliers = [];
  List<PurchaseInvoice> _invoices = [];
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
        ApiService.instance.list('/api/supplier-payments/'),
        ApiService.instance.list('/api/suppliers/'),
        ApiService.instance.list('/api/purchase-invoices/'),
      ]);
      setState(() {
        _payments = results[0].map((e) => SupplierPayment.fromJson(e as Map<String, dynamic>)).toList();
        _suppliers = results[1].map((e) => Supplier.fromJson(e as Map<String, dynamic>)).toList();
        _invoices = results[2].map((e) => PurchaseInvoice.fromJson(e as Map<String, dynamic>)).toList();
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

  String _invoiceLabel(int id) {
    final matches = _invoices.where((i) => i.id == id);
    return matches.isEmpty ? 'Invoice #$id' : (matches.first.invoiceNo ?? 'Invoice #$id');
  }

  List<PurchaseInvoice> get _payableInvoices =>
      _invoices.where((i) => i.status == 'Posted' || i.status == 'PartiallyPaid').toList();

  Future<void> _create() async {
    if (_payableInvoices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No posted invoices with an outstanding balance to pay.')),
      );
      return;
    }
    final result = await _openPaymentForm(context, _suppliers, _payableInvoices);
    if (result == null) return;
    try {
      await ApiService.instance.create('/api/supplier-payments/', result.toJson());
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _delete(SupplierPayment p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Payment?'),
        content: Text('Delete payment "${p.paymentNo ?? '#${p.id}'}"? This does NOT reverse the accounting entry or the invoice balance.'),
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
      await ApiService.instance.delete('/api/supplier-payments/${p.id}');
      _load();
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
      return const Center(child: Text('Add a Supplier first, then come back here to record a Payment.'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text('Supplier Payments', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              FilledButton.icon(
                onPressed: _suppliers.isEmpty ? null : _create,
                icon: const Icon(Icons.add),
                label: const Text('New Payment'),
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(_error!, style: const TextStyle(color: Colors.red))),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _payments.isEmpty
                  ? const Center(child: Text('No payments recorded yet.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _payments.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final p = _payments[i];
                          return ListTile(
                            title: Text('${p.paymentNo ?? '#${p.id}'} — ${_supplierName(p.supplierId)}'),
                            subtitle: Text('${p.paymentDate ?? 'no date'} • ${_invoiceLabel(p.purchaseInvoiceId)} • ${p.mode} • ₹${p.amount.toStringAsFixed(2)}'),
                            trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(p), tooltip: 'Delete'),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}

Future<SupplierPayment?> _openPaymentForm(
  BuildContext context,
  List<Supplier> suppliers,
  List<PurchaseInvoice> payableInvoices,
) {
  PurchaseInvoice selectedInvoice = payableInvoices.first;
  final paymentDate = TextEditingController(text: DateTime.now().toIso8601String().substring(0, 10));
  final amount = TextEditingController(text: selectedInvoice.outstanding.toStringAsFixed(2));
  String mode = 'Bank';
  final notes = TextEditingController();

  return showDialog<SupplierPayment>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      String supplierNameOf(int id) {
        final matches = suppliers.where((s) => s.id == id);
        return matches.isEmpty ? 'Supplier #$id' : matches.first.name;
      }

      return AlertDialog(
        title: const Text('New Payment'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<PurchaseInvoice>(
                value: selectedInvoice,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Purchase Invoice'),
                items: payableInvoices
                    .map((inv) => DropdownMenuItem(
                          value: inv,
                          child: Text(
                            '${inv.invoiceNo ?? '#${inv.id}'} — ${supplierNameOf(inv.supplierId)} (Outstanding ₹${inv.outstanding.toStringAsFixed(2)})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    selectedInvoice = v;
                    amount.text = v.outstanding.toStringAsFixed(2);
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(controller: paymentDate, decoration: const InputDecoration(labelText: 'Payment Date (YYYY-MM-DD)')),
              const SizedBox(height: 12),
              TextField(
                controller: amount,
                decoration: const InputDecoration(labelText: 'Amount (₹)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: mode,
                decoration: const InputDecoration(labelText: 'Mode'),
                items: _paymentModes.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (v) => setState(() => mode = v ?? 'Bank'),
              ),
              const SizedBox(height: 12),
              TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes'), maxLines: 2),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final amt = double.tryParse(amount.text.trim()) ?? 0;
              if (amt <= 0 || paymentDate.text.trim().isEmpty) return;
              Navigator.pop(
                ctx,
                SupplierPayment(
                  supplierId: selectedInvoice.supplierId,
                  purchaseInvoiceId: selectedInvoice.id!,
                  paymentDate: paymentDate.text.trim(),
                  amount: amt,
                  mode: mode,
                  notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
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
