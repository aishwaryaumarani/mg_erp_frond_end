import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/grade_field.dart';
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
      gradeOf: (c) => c.grade,
      openForm: openForm,
    );
  }

  /// Public so quick_add.dart can reopen this same dialog inline from a
  /// Customer dropdown in the Sales forms.
  static Future<Customer?> openForm(BuildContext context, Customer? existing) {
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
    String? grade = existing?.grade;
    final stateCode = TextEditingController(text: existing?.stateCode ?? '');
    final placeOfSupply = TextEditingController(text: existing?.placeOfSupply ?? '');
    // Most customers take delivery where they are billed. Ticked by
    // default for a new customer, and for an existing one only when the
    // two addresses already match -- ticking it on save would otherwise
    // silently overwrite a shipping address someone entered deliberately.
    bool sameAsBilling = existing == null
        ? true
        : (existing.shippingAddress ?? '').trim() == (existing.billingAddress ?? '').trim();

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
                TextField(
                  controller: billing,
                  decoration: const InputDecoration(labelText: 'Billing Address'),
                  maxLines: 2,
                  // Keep the mirror live while the box is ticked, so what
                  // is shown is what will be saved.
                  onChanged: (v) {
                    if (sameAsBilling) setState(() => shipping.text = v);
                  },
                ),
                CheckboxListTile(
                  value: sameAsBilling,
                  onChanged: (v) => setState(() {
                    sameAsBilling = v ?? false;
                    if (sameAsBilling) shipping.text = billing.text;
                  }),
                  title: const Text('Shipping address same as billing'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                TextField(
                  controller: shipping,
                  decoration: InputDecoration(
                    labelText: 'Shipping Address',
                    // Untick to type a different delivery address.
                    fillColor: sameAsBilling ? AppColors.page : AppColors.surface,
                    helperText: sameAsBilling ? 'Copied from the billing address' : null,
                  ),
                  maxLines: 2,
                  readOnly: sameAsBilling,
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: gstin,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'GSTIN',
                        hintText: '27XXXXXXXXXXXZX',
                        helperText: 'Required to raise an e-invoice for this customer',
                      ),
                      // The state code is the GSTIN's first two digits, so
                      // filling one fills the other.
                      onChanged: (v) {
                        final code = v.trim().length >= 2 ? v.trim().substring(0, 2) : '';
                        if (code.length == 2 && int.tryParse(code) != null) {
                          if (stateCode.text.isEmpty) stateCode.text = code;
                          if (placeOfSupply.text.isEmpty) placeOfSupply.text = code;
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: pan, decoration: const InputDecoration(labelText: 'PAN'))),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: stateCode,
                      decoration: const InputDecoration(
                        labelText: 'State code',
                        hintText: '27 for Maharashtra',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: placeOfSupply,
                      decoration: const InputDecoration(
                        labelText: 'Place of supply',
                        helperText: 'Usually the same; decides CGST+SGST or IGST',
                      ),
                    ),
                  ),
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
                GradeDropdown(value: grade, onChanged: (v) => setState(() => grade = v)),
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
                    shippingAddress: sameAsBilling
                        ? (billing.text.trim().isEmpty ? null : billing.text.trim())
                        : (shipping.text.trim().isEmpty ? null : shipping.text.trim()),
                    gstin: gstin.text.trim().isEmpty ? null : gstin.text.trim(),
                    pan: pan.text.trim().isEmpty ? null : pan.text.trim(),
                    creditLimit: double.tryParse(creditLimit.text.trim()) ?? 0,
                    paymentTerms: paymentTerms.text.trim().isEmpty ? null : paymentTerms.text.trim(),
                    openingBalance: double.tryParse(openingBalance.text.trim()) ?? 0,
                    grade: grade,
                    stateCode: stateCode.text.trim().isEmpty ? null : stateCode.text.trim(),
                    placeOfSupply:
                        placeOfSupply.text.trim().isEmpty ? null : placeOfSupply.text.trim(),
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
