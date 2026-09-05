import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/document_pdf.dart';
import '../widgets/doc_detail_page.dart';
import '../widgets/doc_address_fields.dart';
import '../widgets/doc_form_page.dart';
import '../widgets/doc_items_editor.dart';
import '../widgets/quick_add.dart';
import '../widgets/status_badge.dart';
import '../widgets/workflow_actions.dart';

/// Sales Order screen -- the last stop of the Sales flow implemented so
/// far (Lead -> Customer -> Inquiry -> Quotation -> Sales Order). Orders
/// are normally created by accepting a Quotation (see
/// [openSalesOrderForm]'s use from quotation_screen.dart), but a
/// standalone "New Order" is also available for a walk-in/direct sale.
class SalesOrderScreen extends StatefulWidget {
  const SalesOrderScreen({super.key});

  @override
  State<SalesOrderScreen> createState() => _SalesOrderScreenState();
}

class _SalesOrderScreenState extends State<SalesOrderScreen> {
  List<SalesOrder> _orders = [];
  List<Customer> _customers = [];
  List<Product> _products = [];
  List<Tax> _taxes = [];
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
        ApiService.instance.list('/api/sales-orders/'),
        ApiService.instance.list('/api/customers/'),
        ApiService.instance.list('/api/products/'),
        ApiService.instance.list('/api/taxes/'),
      ]);
      setState(() {
        _orders = results[0].map((e) => SalesOrder.fromJson(e as Map<String, dynamic>)).toList();
        _customers = results[1].map((e) => Customer.fromJson(e as Map<String, dynamic>)).toList();
        _products = results[2].map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
        _taxes = results[3].map((e) => Tax.fromJson(e as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _productName(int? id) {
    final matches = _products.where((p) => p.id == id);
    return matches.isEmpty ? 'Product #$id' : '${matches.first.name} [${matches.first.productCode}]';
  }

  /// The read-only shape shared by the detail screen and the PDF.
  DocumentView _viewOf(SalesOrder o) => DocumentView(
        docType: 'Sales Order',
        docNo: o.orderNo ?? '#${o.id}',
        status: o.status,
        isLocked: o.isLocked,
        customer: _customerName(o.customerId),
        fields: {
          'Order date': o.orderDate ?? '--',
          if (o.quotationId != null) 'From quotation': '#${o.quotationId}',
        },
        billingAddress: o.billingAddress,
        shippingAddress: o.shippingAddress,
        hasPricing: true,
        lines: o.items
            .map((e) => DocLineView(
                  product: _productName(e.productId),
                  quantity: e.quantity,
                  unitPrice: e.unitPrice,
                  discountPercent: e.discountPercent,
                  lineTotal: e.lineSubtotal,
                ))
            .toList(),
        subtotal: o.subtotal,
        taxAmount: o.taxAmount,
        totalAmount: o.totalAmount,
        notes: o.notes,
      );

  String _customerName(int id) {
    final matches = _customers.where((c) => c.id == id);
    return matches.isEmpty ? 'Customer #$id' : matches.first.name;
  }

  Future<void> _create() async {
    final result = await openSalesOrderForm(context, existing: null, customers: _customers, products: _products, taxes: _taxes);
    if (result == null) return;
    try {
      await ApiService.instance.create('/api/sales-orders/', result.toJson());
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _edit(SalesOrder order) async {
    final result = await openSalesOrderForm(context, existing: order, customers: _customers, products: _products, taxes: _taxes);
    if (result == null) return;
    try {
      await ApiService.instance.update('/api/sales-orders/${order.id}', result.toJson());
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _delete(SalesOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Sales Order?'),
        content: Text('Delete order "${order.orderNo ?? '#${order.id}'}"?'),
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
      await ApiService.instance.delete('/api/sales-orders/${order.id}');
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  /// Calls POST /api/sales-orders/{id}/create-delivery (backend/app/
  /// routers/sales_orders.py) -- raises a Draft Delivery with this
  /// order's quantities. Confirming that delivery (on the Deliveries
  /// screen) is what actually moves stock (spec sec. 8).
  Future<void> _createDelivery(SalesOrder order) async {
    try {
      final dlvJson = await ApiService.instance.create('/api/sales-orders/${order.id}/create-delivery', {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delivery ${dlvJson['delivery_no'] ?? ''} created -- confirm it on the Deliveries screen to update stock.')),
      );
    } catch (e) {
      _showError(e);
    }
  }

  /// Calls POST /api/sales-orders/{id}/create-invoice (backend/app/
  /// routers/sales_orders.py) -- raises a Draft Sales Invoice with this
  /// order's pricing, independent of Delivery.
  Future<void> _createInvoice(SalesOrder order) async {
    try {
      final invJson = await ApiService.instance.create('/api/sales-orders/${order.id}/create-invoice', {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sales Invoice ${invJson['invoice_no'] ?? ''} created -- post it on the Sales Invoices screen.')),
      );
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
              Text('Sales Orders', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.add),
                label: const Text('New Order'),
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(_error!, style: const TextStyle(color: Colors.red))),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _orders.isEmpty
                  ? const Center(child: Text('No sales orders yet.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _orders.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final o = _orders[i];
                          return ListTile(
                            title: Text('${o.orderNo ?? '#${o.id}'} — ${_customerName(o.customerId)}'),
                            subtitle: Text('${o.orderDate ?? 'no date'} • ${o.items.length} line(s) • Total ₹${o.totalAmount.toStringAsFixed(2)}'
                                '${o.quotationId != null ? ' • from Quotation #${o.quotationId}' : ''}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                StatusBadge(status: o.status),
                                const SizedBox(width: 8),
                                WorkflowActions(
                                  resourcePath: '/api/sales-orders/',
                                  id: o.id,
                                  status: o.status,
                                  isLocked: o.isLocked,
                                  onChanged: _load,
                                  onError: _showError,
                                ),
                                const SizedBox(width: 8),
                                // Deliveries and invoices only come off an
                                // approved order -- and unlike the earlier
                                // steps, an order can raise several of them.
                                if (canMoveOn(o.status)) ...[
                                  IconButton(
                                    icon: const Icon(Icons.local_shipping_outlined),
                                    tooltip: 'Create Delivery',
                                    onPressed: () => _createDelivery(o),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.description_outlined),
                                    tooltip: 'Create Invoice',
                                    onPressed: () => _createInvoice(o),
                                  ),
                                ],
                                IconButton(
                                  icon: const Icon(Icons.visibility_outlined),
                                  tooltip: 'View details / PDF',
                                  onPressed: () => DocDetailPage.open(context, _viewOf(o)),
                                ),
                                if (canEditDocument(o.status, o.isLocked))
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined),
                                    tooltip: 'Edit',
                                    onPressed: () => _edit(o),
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  tooltip: o.isLocked ? 'Has a delivery or invoice -- cannot be deleted' : 'Delete',
                                  onPressed: o.isLocked ? null : () => _delete(o),
                                ),
                              ],
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

/// Public so quotation_screen.dart can reuse it to build the "Convert to
/// Sales Order" pre-filled form.
Future<SalesOrder?> openSalesOrderForm(
  BuildContext context, {
  required SalesOrder? existing,
  required List<Customer> customers,
  required List<Product> products,
  required List<Tax> taxes,
}) {
  int? customerId = existing?.customerId ?? (customers.isEmpty ? null : customers.first.id);
  final orderDate = TextEditingController(text: existing?.orderDate ?? DateTime.now().toIso8601String().substring(0, 10));
  final billing = TextEditingController(text: existing?.billingAddress ?? '');
  final shipping = TextEditingController(text: existing?.shippingAddress ?? '');
  final notes = TextEditingController(text: existing?.notes ?? '');
  // Backfill each line's tax rate (not a backend field) from the Tax list
  // so the live total preview is correct immediately -- see
  // models.dart withTaxRates().
  List<DocLineItem> items = existing == null ? [] : withTaxRates(existing.items, taxes);

  if (existing == null) {
    syncAddressesToCustomer(
      previous: null,
      next: customerById(customers, customerId),
      billing: billing,
      shipping: shipping,
    );
  }

  return openDocFormPage<SalesOrder>(context, (ctx) {
    return StatefulBuilder(builder: (ctx, setState) {
      void pickCustomer(int? id) {
        final previous = customerById(customers, customerId);
        setState(() {
          customerId = id;
          syncAddressesToCustomer(
            previous: previous,
            next: customerById(customers, id),
            billing: billing,
            shipping: shipping,
          );
        });
      }

      return DocFormPage(
        title: existing == null ? 'New Sales Order' : 'Edit Sales Order',
        subtitle: existing?.orderNo,
        onSave: () {
          if (customerId == null) {
            showFormError(ctx, 'Pick a customer for this order.');
            return;
          }
          if (orderDate.text.trim().isEmpty) {
            showFormError(ctx, 'Order date is required (YYYY-MM-DD).');
            return;
          }
          if (items.isEmpty) {
            showFormError(ctx, 'A sales order needs at least one line item.');
            return;
          }
          Navigator.pop(
            ctx,
            SalesOrder(
              id: existing?.id,
              orderNo: existing?.orderNo,
              quotationId: existing?.quotationId,
              customerId: customerId!,
              orderDate: orderDate.text.trim(),
              status: existing?.status ?? 'Pending',
              billingAddress: billing.text.trim().isEmpty ? null : billing.text.trim(),
              shippingAddress: shipping.text.trim().isEmpty ? null : shipping.text.trim(),
              notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
              items: items,
            ),
          );
        },
        children: [
          DocFormSection(
            title: 'Customer & date',
            children: [
              QuickAddDropdown<Customer>(
                label: 'Customer',
                value: customerId,
                options: customers,
                idOf: (c) => c.id,
                labelOf: (c) => '${c.name} (${c.customerCode})',
                addNewLabel: 'Add New Customer',
                allowUnknownValue: true,
                onCreate: quickAddCustomer,
                // `customers` is the calling screen's own list, so a
                // customer added here survives cancelling this form.
                onCreated: (c) {
                  customers.add(c);
                  pickCustomer(c.id);
                },
                onChanged: pickCustomer,
              ),
              const SizedBox(height: 12),
              TextField(controller: orderDate, decoration: const InputDecoration(labelText: 'Order Date (YYYY-MM-DD)')),
            ],
          ),
          DocFormSection(
            title: 'Addresses',
            hint: "Filled in from the customer master -- edit here for a one-off billing or delivery address.",
            children: [DocAddressFields(billing: billing, shipping: shipping)],
          ),
          DocFormSection(
            title: 'Items',
            children: [
              DocLineItemsEditor(
                products: products,
                taxes: taxes,
                initialItems: items,
                onChanged: (updated) => items = updated,
                onProductCreated: products.add,
              ),
            ],
          ),
          DocFormSection(
            title: 'Notes',
            children: [
              TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes'), maxLines: 3),
            ],
          ),
        ],
      );
    });
  });
}
