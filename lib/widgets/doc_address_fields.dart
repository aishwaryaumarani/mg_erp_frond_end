import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

/// Billing / shipping address on a sales document (Inquiry, Quotation,
/// Sales Order). The document keeps its own copy -- taken from the
/// Customer master when the customer is picked -- so a quote or order
/// stays addressed to the site it was raised for even if the master is
/// edited later (backend/app/core/addresses.py does the same defaulting
/// for anything posting straight to the API).
class DocAddressFields extends StatelessWidget {
  final TextEditingController billing;
  final TextEditingController shipping;

  const DocAddressFields({super.key, required this.billing, required this.shipping});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: billing,
          decoration: const InputDecoration(labelText: 'Billing Address'),
          maxLines: 3,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => shipping.text = billing.text,
            icon: const Icon(Icons.south, size: 16),
            label: const Text('Ship to the billing address'),
            style: TextButton.styleFrom(foregroundColor: AppColors.muted),
          ),
        ),
        TextField(
          controller: shipping,
          decoration: const InputDecoration(labelText: 'Shipping Address'),
          maxLines: 3,
        ),
      ],
    );
  }
}

/// Re-fills the address boxes when the picked customer changes.
///
/// Anything the user typed themselves is left alone: a box is only
/// rewritten while it still holds what [previous] auto-filled (or is
/// empty), so switching customer by mistake doesn't destroy a hand-typed
/// one-off delivery address.
void syncAddressesToCustomer({
  required Customer? previous,
  required Customer? next,
  required TextEditingController billing,
  required TextEditingController shipping,
}) {
  void fill(TextEditingController ctrl, String? previousValue, String? nextValue) {
    final current = ctrl.text.trim();
    final wasAutoFilled = current.isEmpty || current == (previousValue ?? '').trim();
    if (!wasAutoFilled) return;
    ctrl.text = nextValue ?? '';
  }

  // Most customers ship where they bill, so a blank shipping address on
  // the master falls back to the billing one rather than leaving the
  // document with no ship-to at all.
  fill(billing, previous?.billingAddress, next?.billingAddress);
  fill(
    shipping,
    previous?.shippingAddress ?? previous?.billingAddress,
    next?.shippingAddress ?? next?.billingAddress,
  );
}

/// The customer in [customers] with this id, or null (the id can point at
/// a customer outside the loaded page -- see QuickAddDropdown's
/// allowUnknownValue).
Customer? customerById(List<Customer> customers, int? id) {
  if (id == null) return null;
  final matches = customers.where((c) => c.id == id);
  return matches.isEmpty ? null : matches.first;
}
