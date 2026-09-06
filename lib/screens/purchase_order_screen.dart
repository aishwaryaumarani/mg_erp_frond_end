import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/document_pdf.dart';
import '../widgets/doc_detail_page.dart';
import '../widgets/doc_form_page.dart';
import '../widgets/doc_items_editor.dart';
import '../widgets/quick_add.dart';
import '../widgets/status_badge.dart';

const _orderStatuses = ['Draft', 'Sent', 'Confirmed', 'Cancelled'];

/// Purchase Order screen -- the last stop of the Purchase flow implemented
/// so far (Supplier -> Purchase Inquiry -> Supplier Quotation -> Purchase
/// Order). Orders are normally created by accepting a Supplier Quotation
/// (see [openPurchaseOrderForm]'s use from supplier_quotation_screen.dart),
/// but a standalone "New Order" is also available. Creating a PO does NOT
/// move inventory -- only a future Goods Receipt (Phase 5) does.
class PurchaseOrderScreen extends StatefulWidget {
  const PurchaseOrderScreen({super.key});

  @override
  State<PurchaseOrderScreen> createState() => _PurchaseOrderScreenState();
}

class _PurchaseOrderScreenState extends State<PurchaseOrderScreen> {
  List<PurchaseOrder> _orders = [];
  List<Supplier> _suppliers = [];
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
        ApiService.instance.list('/api/purchase-orders/'),
        ApiService.instance.list('/api/suppliers/'),
        ApiService.instance.list('/api/products/'),
        ApiService.instance.list('/api/taxes/'),
      ]);
      setState(() {
        _orders = results[0].map((e) => PurchaseOrder.fromJson(e as Map<String, dynamic>)).toList();
        _suppliers = results[1].map((e) => Supplier.fromJson(e as Map<String, dynamic>)).toList();
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
    return matches.isEmpty ? 'Product #\$id' : '\${matches.first.name} [\${matches.first.productCode}]';
  }

  Tax? _taxOf(int? id) {
    if (id == null) return null;
    final matches = _taxes.where((t) => t.id == id);
    return matches.isEmpty ? null : matches.first;
  }

  /// The printed purchase order: everything the supplier's copy carries,
  /// shared by the on-screen view and the PDF.
  DocumentView _viewOf(PurchaseOrder o) => DocumentView(
        docType: 'Purchase Order',
        docNo: o.orderNo ?? '#\${o.id}',
        status: o.status,
        isLocked: false,
        customer: _supplierName(o.supplierId),
        partyLabel: 'SUPPLIER (BILL FROM)',
        fields: {
          'Order date': o.orderDate ?? '--',
          if ((o.dueDate ?? '').isNotEmpty) 'Due on': o.dueDate!,
          if ((o.referenceNo ?? '').isNotEmpty) 'Reference no.': o.referenceNo!,
          if ((o.otherReferences ?? '').isNotEmpty) 'Other references': o.otherReferences!,
          if ((o.paymentTerms ?? '').isNotEmpty) 'Mode/terms of payment': o.paymentTerms!,
          if ((o.dispatchedThrough ?? '').isNotEmpty) 'Dispatched through': o.dispatchedThrough!,
          if ((o.destination ?? '').isNotEmpty) 'Destination': o.destination!,
          if ((o.termsOfDelivery ?? '').isNotEmpty) 'Terms of delivery': o.termsOfDelivery!,
        },
        billingAddress: o.consigneeName == null && o.consigneeAddress == null
            ? null
            : [o.consigneeName, o.consigneeAddress].whereType<String>().join('\n'),
        billingLabel: 'CONSIGNEE (SHIP TO)',
        shippingLabel: '',
        hasPricing: true,
        lines: o.items.map((e) {
          final tax = _taxOf(e.taxId);
          return DocLineView(
            product: _productName(e.productId),
            quantity: e.quantity,
            unitPrice: e.unitPrice,
            discountPercent: e.discountPercent,
            taxLabel: tax?.name,
            taxPercent: tax?.ratePercent ?? 0,
            lineTotal: e.lineSubtotal,
          );
        }).toList(),
        subtotal: o.subtotal,
        taxAmount: o.taxAmount,
        totalAmount: o.totalAmount,
        notes: o.notes,
      );

  String _supplierName(int id) {
    final matches = _suppliers.where((s) => s.id == id);
    return matches.isEmpty ? 'Supplier #$id' : matches.first.name;
  }

  Future<void> _create() async {
    final result = await openPurchaseOrderForm(context, existing: null, suppliers: _suppliers, products: _products, taxes: _taxes);
    if (result == null) return;
    try {
      await ApiService.instance.create('/api/purchase-orders/', result.toJson());
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _edit(PurchaseOrder order) async {
    final result = await openPurchaseOrderForm(context, existing: order, suppliers: _suppliers, products: _products, taxes: _taxes);
    if (result == null) return;
    try {
      await ApiService.instance.update('/api/purchase-orders/${order.id}', result.toJson());
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _setStatus(PurchaseOrder order, String status) async {
    try {
      final updated = PurchaseOrder(
        id: order.id,
        orderNo: order.orderNo,
        quotationId: order.quotationId,
        supplierId: order.supplierId,
        orderDate: order.orderDate,
        status: status,
        notes: order.notes,
        items: order.items,
      );
      await ApiService.instance.update('/api/purchase-orders/${order.id}', updated.toJson());
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _delete(PurchaseOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Purchase Order?'),
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
      await ApiService.instance.delete('/api/purchase-orders/${order.id}');
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  /// Calls POST /api/purchase-orders/{id}/create-goods-receipt (backend/
  /// app/routers/purchase_orders.py) -- raises a Draft Goods Receipt with
  /// this order's quantities. Confirming that receipt (on the Goods
  /// Receipts screen) is what actually moves stock (spec sec. 8).
  Future<void> _createGoodsReceipt(PurchaseOrder order) async {
    try {
      final grnJson = await ApiService.instance.create('/api/purchase-orders/${order.id}/create-goods-receipt', {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Goods Receipt ${grnJson['grn_no'] ?? ''} created -- confirm it on the Goods Receipts screen to update stock.')),
      );
    } catch (e) {
      _showError(e);
    }
  }

  /// Calls POST /api/purchase-orders/{id}/create-invoice (backend/app/
  /// routers/purchase_orders.py) -- raises a Draft Purchase Invoice with
  /// this order's pricing, independent of Goods Receipt.
  Future<void> _createInvoice(PurchaseOrder order) async {
    try {
      final invJson = await ApiService.instance.create('/api/purchase-orders/${order.id}/create-invoice', {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Purchase Invoice ${invJson['invoice_no'] ?? ''} created -- post it on the Purchase Invoices screen.')),
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
              Text('Purchase Orders', style: Theme.of(context).textTheme.titleMedium),
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
                  ? const Center(child: Text('No purchase orders yet.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _orders.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final o = _orders[i];
                          return ListTile(
                            title: Text('${o.orderNo ?? '#${o.id}'} — ${_supplierName(o.supplierId)}'),
                            subtitle: Text('${o.orderDate ?? 'no date'} • ${o.items.length} line(s) • Total ₹${o.totalAmount.toStringAsFixed(2)}'
                                '${o.quotationId != null ? ' • from Supplier Quotation #${o.quotationId}' : ''}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                DropdownButton<String>(
                                  value: o.status,
                                  underline: const SizedBox(),
                                  items: _orderStatuses
                                      .map((s) => DropdownMenuItem(value: s, child: StatusBadge(status: s)))
                                      .toList(),
                                  onChanged: (v) {
                                    if (v != null && v != o.status) _setStatus(o, v);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.move_to_inbox_outlined),
                                  tooltip: 'Create Goods Receipt',
                                  onPressed: () => _createGoodsReceipt(o),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.description_outlined),
                                  tooltip: 'Create Invoice',
                                  onPressed: () => _createInvoice(o),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.visibility_outlined),
                                  tooltip: 'View details / PDF',
                                  onPressed: () => DocDetailPage.open(context, _viewOf(o)),
                                ),
                                IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _edit(o), tooltip: 'Edit'),
                                IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(o), tooltip: 'Delete'),
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

/// Public so supplier_quotation_screen.dart can reuse it to build the
/// "Convert to Purchase Order" pre-filled dialog.
Future<PurchaseOrder?> openPurchaseOrderForm(
  BuildContext context, {
  required PurchaseOrder? existing,
  required List<Supplier> suppliers,
  required List<Product> products,
  required List<Tax> taxes,
}) {
  int? supplierId = existing?.supplierId ?? (suppliers.isEmpty ? null : suppliers.first.id);
  final orderDate = TextEditingController(
      text: existing?.orderDate ?? DateTime.now().toIso8601String().substring(0, 10));
  final dueDate = TextEditingController(text: existing?.dueDate ?? '');
  final referenceNo = TextEditingController(text: existing?.referenceNo ?? '');
  final otherReferences = TextEditingController(text: existing?.otherReferences ?? '');
  final paymentTerms = TextEditingController(text: existing?.paymentTerms ?? '');
  final dispatchedThrough = TextEditingController(text: existing?.dispatchedThrough ?? '');
  final destination = TextEditingController(text: existing?.destination ?? '');
  final termsOfDelivery = TextEditingController(text: existing?.termsOfDelivery ?? '');
  final consigneeName = TextEditingController(text: existing?.consigneeName ?? '');
  final consigneeAddress = TextEditingController(text: existing?.consigneeAddress ?? '');
  final notes = TextEditingController(text: existing?.notes ?? '');
  // Backfill each line's tax rate (not a backend field) from the Tax list
  // so the live total preview is correct immediately -- see
  // models.dart withTaxRates().
  List<DocLineItem> items = existing == null ? [] : withTaxRates(existing.items, taxes);

  return openDocFormPage<PurchaseOrder>(context, (ctx) {
    return StatefulBuilder(builder: (ctx, setState) {
      return DocFormPage(
        title: existing == null ? 'New Purchase Order' : 'Edit Purchase Order',
        subtitle: existing?.orderNo,
        onSave: () {
          if (supplierId == null) {
            showFormError(ctx, 'Pick the supplier this order goes to.');
            return;
          }
          if (orderDate.text.trim().isEmpty) {
            showFormError(ctx, 'Order date is required (YYYY-MM-DD).');
            return;
          }
          if (items.isEmpty) {
            showFormError(ctx, 'A purchase order needs at least one line item.');
            return;
          }
          String? clean(TextEditingController c) =>
              c.text.trim().isEmpty ? null : c.text.trim();
          Navigator.pop(
            ctx,
            PurchaseOrder(
              id: existing?.id,
              orderNo: existing?.orderNo,
              quotationId: existing?.quotationId,
              supplierId: supplierId!,
              orderDate: orderDate.text.trim(),
              status: existing?.status ?? 'Draft',
              dueDate: clean(dueDate),
              referenceNo: clean(referenceNo),
              otherReferences: clean(otherReferences),
              paymentTerms: clean(paymentTerms),
              dispatchedThrough: clean(dispatchedThrough),
              destination: clean(destination),
              termsOfDelivery: clean(termsOfDelivery),
              consigneeName: clean(consigneeName),
              consigneeAddress: clean(consigneeAddress),
              notes: clean(notes),
              items: items,
            ),
          );
        },
        children: [
          DocFormSection(
            title: 'Supplier & dates',
            children: [
              QuickAddDropdown<Supplier>(
                label: 'Supplier (bill from)',
                value: supplierId,
                options: suppliers,
                idOf: (s) => s.id,
                labelOf: (s) => '${s.name} (${s.supplierCode})',
                addNewLabel: 'Add New Supplier',
                allowUnknownValue: true,
                onCreate: quickAddSupplier,
                // `suppliers` is the calling screen's own list, so a
                // supplier added here survives cancelling this form.
                onCreated: (s) => setState(() {
                  suppliers.add(s);
                  supplierId = s.id;
                }),
                onChanged: (v) => setState(() => supplierId = v),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: orderDate, decoration: const InputDecoration(labelText: 'Order Date (YYYY-MM-DD)'))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: dueDate, decoration: const InputDecoration(labelText: 'Due on (YYYY-MM-DD)'))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: referenceNo, decoration: const InputDecoration(labelText: 'Reference no. & date'))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: otherReferences, decoration: const InputDecoration(labelText: 'Other references'))),
              ]),
            ],
          ),
          DocFormSection(
            title: 'Consignee (ship to)',
            hint: 'Where the goods are to be delivered, if that is not your own office.',
            children: [
              TextField(controller: consigneeName, decoration: const InputDecoration(labelText: 'Consignee name')),
              const SizedBox(height: 12),
              TextField(controller: consigneeAddress, decoration: const InputDecoration(labelText: 'Consignee address'), maxLines: 3),
            ],
          ),
          DocFormSection(
            title: 'Dispatch & terms',
            hint: 'Printed on the order the supplier receives.',
            children: [
              Row(children: [
                Expanded(child: TextField(controller: dispatchedThrough, decoration: const InputDecoration(labelText: 'Dispatched through'))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: destination, decoration: const InputDecoration(labelText: 'Destination'))),
              ]),
              const SizedBox(height: 12),
              TextField(controller: paymentTerms, decoration: const InputDecoration(labelText: 'Mode / terms of payment')),
              const SizedBox(height: 12),
              TextField(
                controller: termsOfDelivery,
                decoration: const InputDecoration(
                    labelText: 'Terms of delivery', hintText: 'e.g. TILL 13 AUGUST'),
              ),
            ],
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
