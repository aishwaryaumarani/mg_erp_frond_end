import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';

const _receiptModes = ['Cash', 'Bank', 'Cheque', 'UPI'];

/// Customer Receipt screen -- recording a receipt IS posting it (backend/
/// app/routers/customer_receipts.py has no draft/post split): it posts
/// Bank-Cash Dr / AR Cr immediately and updates the target Sales
/// Invoice's amount_paid/status. Only invoices that are Posted or
/// PartiallyPaid can be collected against. Deleting a receipt record
/// here only soft-deletes it -- it does NOT reverse the journal entry or
/// the invoice's amount_paid (documented backend limitation), so use
/// delete sparingly.
class CustomerReceiptScreen extends StatefulWidget {
  const CustomerReceiptScreen({super.key});

  @override
  State<CustomerReceiptScreen> createState() => _CustomerReceiptScreenState();
}

class _CustomerReceiptScreenState extends State<CustomerReceiptScreen> {
  List<CustomerReceipt> _receipts = [];
  List<Customer> _customers = [];
  List<SalesInvoice> _invoices = [];
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
        ApiService.instance.list('/api/customer-receipts/'),
        ApiService.instance.list('/api/customers/'),
        ApiService.instance.list('/api/sales-invoices/'),
      ]);
      setState(() {
        _receipts = results[0].map((e) => CustomerReceipt.fromJson(e as Map<String, dynamic>)).toList();
        _customers = results[1].map((e) => Customer.fromJson(e as Map<String, dynamic>)).toList();
        _invoices = results[2].map((e) => SalesInvoice.fromJson(e as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _customerName(int id) {
    final matches = _customers.where((c) => c.id == id);
    return matches.isEmpty ? 'Customer #$id' : matches.first.name;
  }

  String _invoiceLabel(int id) {
    final matches = _invoices.where((i) => i.id == id);
    return matches.isEmpty ? 'Invoice #$id' : (matches.first.invoiceNo ?? 'Invoice #$id');
  }

  List<SalesInvoice> get _receivableInvoices =>
      _invoices.where((i) => i.status == 'Posted' || i.status == 'PartiallyPaid').toList();

  Future<void> _create() async {
    if (_receivableInvoices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No posted invoices with an outstanding balance to collect.')),
      );
      return;
    }
    final result = await _openReceiptForm(context, _customers, _receivableInvoices);
    if (result == null) return;
    try {
      await ApiService.instance.create('/api/customer-receipts/', result.toJson());
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _delete(CustomerReceipt r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Receipt?'),
        content: Text('Delete receipt "${r.receiptNo ?? '#${r.id}'}"? This does NOT reverse the accounting entry or the invoice balance.'),
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
      await ApiService.instance.delete('/api/customer-receipts/${r.id}');
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text('Customer Receipts', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              FilledButton.icon(
                onPressed: _create,
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
                  ? const Center(child: Text('No receipts recorded yet.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _receipts.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final r = _receipts[i];
                          return ListTile(
                            title: Text('${r.receiptNo ?? '#${r.id}'} — ${_customerName(r.customerId)}'),
                            subtitle: Text('${r.receiptDate ?? 'no date'} • ${_invoiceLabel(r.salesInvoiceId)} • ${r.mode} • ₹${r.amount.toStringAsFixed(2)}'),
                            trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(r), tooltip: 'Delete'),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}

Future<CustomerReceipt?> _openReceiptForm(
  BuildContext context,
  List<Customer> customers,
  List<SalesInvoice> receivableInvoices,
) {
  SalesInvoice selectedInvoice = receivableInvoices.first;
  final receiptDate = TextEditingController(text: DateTime.now().toIso8601String().substring(0, 10));
  final amount = TextEditingController(text: selectedInvoice.outstanding.toStringAsFixed(2));
  String mode = 'Bank';
  final notes = TextEditingController();

  return showDialog<CustomerReceipt>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      String customerNameOf(int id) {
        final matches = customers.where((c) => c.id == id);
        return matches.isEmpty ? 'Customer #$id' : matches.first.name;
      }

      return AlertDialog(
        title: const Text('New Receipt'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<SalesInvoice>(
                value: selectedInvoice,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Sales Invoice'),
                items: receivableInvoices
                    .map((inv) => DropdownMenuItem(
                          value: inv,
                          child: Text(
                            '${inv.invoiceNo ?? '#${inv.id}'} — ${customerNameOf(inv.customerId)} (Outstanding ₹${inv.outstanding.toStringAsFixed(2)})',
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
              TextField(controller: receiptDate, decoration: const InputDecoration(labelText: 'Receipt Date (YYYY-MM-DD)')),
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
                items: _receiptModes.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
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
              if (amt <= 0 || receiptDate.text.trim().isEmpty) return;
              Navigator.pop(
                ctx,
                CustomerReceipt(
                  customerId: selectedInvoice.customerId,
                  salesInvoiceId: selectedInvoice.id!,
                  receiptDate: receiptDate.text.trim(),
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
