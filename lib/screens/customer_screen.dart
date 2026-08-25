import 'package:flutter/material.dart';
import '../models/models.dart';
import '../widgets/master_crud_screen.dart';

const _statusOptions = ['Active', 'Inactive'];

class CustomerScreen extends StatelessWidget {
  const CustomerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MasterCrudScreen<Customer>(
      resourcePath: '/api/customers/',
      entityName: 'Customer',
      fromJson: Customer.fromJson,
      toJson: (c) => c.toJson(),
      idOf: (c) => c.id,
      titleOf: (c) => '${c.name}  (${c.customerCode})',
      subtitleOf: (c) => [
        if (c.companyName != null && c.companyName!.isNotEmpty) c.companyName,
        if (c.phone != null && c.phone!.isNotEmpty) c.phone,
        'Outstanding: reflects once Sales module is live',
      ].whereType<String>().join(' • '),
      statusOf: (c) => c.status,
      openForm: _openForm,
    );
  }

  static Future<Customer?> _openForm(BuildContext context, Customer? existing) {
    final code = TextEditingController(text: existing?.customerCode ?? '');
    final name = TextEditingController(text: existing?.name ?? '');
    final company = TextEditingController(text: existing?.companyName ?? '');
    final phone = TextEditingController(text: existing?.phone ?? '');
    final email = TextEditingController(text: existing?.email ?? '');
    final billing = TextEditingController(text: existing?.billingAddress ?? '');
    final shipping = TextEditingController(text: existing?.shippingAddress ?? '');
    final gstin = TextEditingController(text: existing?.gstin ?? '');
    final pan = TextEditingController(text: existing?.pan ?? '');
    final creditLimit = TextEditingController(text: existing?.creditLimit.toString() ?? '0');
    final paymentTerms = TextEditingController(text: existing?.paymentTerms ?? '');
    final openingBalance = TextEditingController(text: existing?.openingBalance.toString() ?? '0');
    String status = existing?.status ?? 'Active';

    return showDialog<Customer>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
        return AlertDialog(
          title: Text(existing == null ? 'New Customer' : 'Edit Customer'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Expanded(child: TextField(controller: code, decoration: const InputDecoration(labelText: 'Customer Code'))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: name, decoration: const InputDecoration(labelText: 'Customer Name'))),
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
                TextField(controller: billing, decoration: const InputDecoration(labelText: 'Billing Address'), maxLines: 2),
                const SizedBox(height: 12),
                TextField(controller: shipping, decoration: const InputDecoration(labelText: 'Shipping Address'), maxLines: 2),
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
                  Customer(
                    id: existing?.id,
                    customerCode: code.text.trim(),
                    name: name.text.trim(),
                    companyName: company.text.trim().isEmpty ? null : company.text.trim(),
                    phone: phone.text.trim().isEmpty ? null : phone.text.trim(),
                    email: email.text.trim().isEmpty ? null : email.text.trim(),
                    billingAddress: billing.text.trim().isEmpty ? null : billing.text.trim(),
                    shippingAddress: shipping.text.trim().isEmpty ? null : shipping.text.trim(),
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
