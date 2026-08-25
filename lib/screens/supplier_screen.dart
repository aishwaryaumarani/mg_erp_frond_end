import 'package:flutter/material.dart';
import '../models/models.dart';
import '../widgets/master_crud_screen.dart';

const _statusOptions = ['Active', 'Inactive'];

class SupplierScreen extends StatelessWidget {
  const SupplierScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MasterCrudScreen<Supplier>(
      resourcePath: '/api/suppliers/',
      entityName: 'Supplier',
      fromJson: Supplier.fromJson,
      toJson: (s) => s.toJson(),
      idOf: (s) => s.id,
      titleOf: (s) => '${s.name}  (${s.supplierCode})',
      subtitleOf: (s) => [
        if (s.companyName != null && s.companyName!.isNotEmpty) s.companyName,
        if (s.phone != null && s.phone!.isNotEmpty) s.phone,
        'Outstanding: reflects once Purchase module is live',
      ].whereType<String>().join(' • '),
      statusOf: (s) => s.status,
      openForm: _openForm,
    );
  }

  static Future<Supplier?> _openForm(BuildContext context, Supplier? existing) {
    final code = TextEditingController(text: existing?.supplierCode ?? '');
    final name = TextEditingController(text: existing?.name ?? '');
    final company = TextEditingController(text: existing?.companyName ?? '');
    final phone = TextEditingController(text: existing?.phone ?? '');
    final email = TextEditingController(text: existing?.email ?? '');
    final address = TextEditingController(text: existing?.address ?? '');
    final gstin = TextEditingController(text: existing?.gstin ?? '');
    final pan = TextEditingController(text: existing?.pan ?? '');
    final creditLimit = TextEditingController(text: existing?.creditLimit.toString() ?? '0');
    final paymentTerms = TextEditingController(text: existing?.paymentTerms ?? '');
    final openingBalance = TextEditingController(text: existing?.openingBalance.toString() ?? '0');
    String status = existing?.status ?? 'Active';

    return showDialog<Supplier>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
        return AlertDialog(
          title: Text(existing == null ? 'New Supplier' : 'Edit Supplier'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Expanded(child: TextField(controller: code, decoration: const InputDecoration(labelText: 'Supplier Code'))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: name, decoration: const InputDecoration(labelText: 'Supplier Name'))),
                ]),
                const SizedBox(height: 12),
                TextField(controller: company, decoration: const InputDecoration(labelText: 'Company Name')),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone'))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: email, decoration: const InputDecoration(labelText: 'Email'))),
                ]),
                const SizedBox(height: 12),
                TextField(controller: address, decoration: const InputDecoration(labelText: 'Address'), maxLines: 2),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(controller: gstin, decoration: const InputDecoration(labelText: 'GSTIN'))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: pan, decoration: const InputDecoration(labelText: 'PAN'))),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: creditLimit,
                      decoration: const InputDecoration(labelText: 'Credit Limit'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: openingBalance,
                      decoration: const InputDecoration(labelText: 'Opening Balance'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                TextField(controller: paymentTerms, decoration: const InputDecoration(labelText: 'Payment Terms')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: _statusOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => setState(() => status = v ?? 'Active'),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (code.text.trim().isEmpty || name.text.trim().isEmpty) return;
                Navigator.pop(
                  ctx,
                  Supplier(
                    id: existing?.id,
                    supplierCode: code.text.trim(),
                    name: name.text.trim(),
                    companyName: company.text.trim().isEmpty ? null : company.text.trim(),
                    phone: phone.text.trim().isEmpty ? null : phone.text.trim(),
                    email: email.text.trim().isEmpty ? null : email.text.trim(),
                    address: address.text.trim().isEmpty ? null : address.text.trim(),
                    gstin: gstin.text.trim().isEmpty ? null : gstin.text.trim(),
                    pan: pan.text.trim().isEmpty ? null : pan.text.trim(),
                    creditLimit: double.tryParse(creditLimit.text.trim()) ?? 0,
                    paymentTerms: paymentTerms.text.trim().isEmpty ? null : paymentTerms.text.trim(),
                    openingBalance: double.tryParse(openingBalance.text.trim()) ?? 0,
                    status: status,
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
}
