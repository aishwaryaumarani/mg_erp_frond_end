import 'package:flutter/material.dart';
import '../models/models.dart';
import '../screens/customer_screen.dart';
import '../screens/product_screen.dart';
import '../screens/supplier_screen.dart';
import '../screens/warehouse_screen.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// Sentinel id for the "+ Add new ..." row in a [QuickAddDropdown].
/// Entity ids are always positive, so -1 can never collide with a real one.
const int kAddNewId = -1;

/// Opens the normal New Customer dialog, saves it, and returns the saved
/// record (with its server-assigned id) -- so a Customer can be created
/// without leaving the Inquiry/Quotation/Sales Order form.
Future<Customer?> quickAddCustomer(BuildContext context) async {
  final draft = await CustomerScreen.openForm(context, null);
  if (draft == null || !context.mounted) return null;
  try {
    final json = await ApiService.instance.create('/api/customers/', draft.toJson());
    return Customer.fromJson(json);
  } catch (e) {
    if (context.mounted) _showError(context, 'Could not save customer', e);
    return null;
  }
}

/// Same as [quickAddCustomer], for a Product created straight from a
/// document's line-item Product dropdown.
Future<Product?> quickAddProduct(BuildContext context) async {
  final draft = await ProductScreen.openForm(context, null);
  if (draft == null || !context.mounted) return null;
  try {
    final json = await ApiService.instance.create('/api/products/', draft.toJson());
    return Product.fromJson(json);
  } catch (e) {
    if (context.mounted) _showError(context, 'Could not save product', e);
    return null;
  }
}

/// Same as [quickAddCustomer], for a Supplier created from a Purchase
/// document's Supplier dropdown.
Future<Supplier?> quickAddSupplier(BuildContext context) async {
  final draft = await SupplierScreen.openForm(context, null);
  if (draft == null || !context.mounted) return null;
  try {
    final json = await ApiService.instance.create('/api/suppliers/', draft.toJson());
    return Supplier.fromJson(json);
  } catch (e) {
    if (context.mounted) _showError(context, 'Could not save supplier', e);
    return null;
  }
}

/// Same as [quickAddCustomer], for a Warehouse created from a Delivery or
/// Goods Receipt's Warehouse dropdown.
Future<Warehouse?> quickAddWarehouse(BuildContext context) async {
  final draft = await WarehouseScreen.openForm(context, null);
  if (draft == null || !context.mounted) return null;
  try {
    final json = await ApiService.instance.create('/api/warehouses/', draft.toJson());
    return Warehouse.fromJson(json);
  } catch (e) {
    if (context.mounted) _showError(context, 'Could not save warehouse', e);
    return null;
  }
}

void _showError(BuildContext context, String what, Object e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('$what: ${e is ApiException ? e.message : e}'),
      backgroundColor: AppColors.rose,
    ),
  );
}

/// Dropdown that always offers an "+ Add new ..." row under the real
/// options, so an empty master list is never a dead end -- picking it
/// opens that master's own create dialog ([onCreate]) and hands the saved
/// record back through [onCreated] for the caller to insert and select.
class QuickAddDropdown<T> extends StatefulWidget {
  final String label;
  final int? value;
  final List<T> options;
  final int? Function(T) idOf;
  final String Function(T) labelOf;
  final String addNewLabel;
  final ValueChanged<int?> onChanged;
  final Future<T?> Function(BuildContext context) onCreate;
  final ValueChanged<T> onCreated;
  final bool isDense;

  /// Label for a leading "no selection" row (e.g. 'Unassigned'). Omit for
  /// a dropdown where a choice is required.
  final String? noneLabel;

  /// When [value] refers to something missing from [options] (a deleted or
  /// not-yet-loaded record), render a placeholder row for it rather than
  /// letting DropdownButtonFormField assert on an unmatched value.
  final bool allowUnknownValue;

  const QuickAddDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.idOf,
    required this.labelOf,
    required this.addNewLabel,
    required this.onChanged,
    required this.onCreate,
    required this.onCreated,
    this.isDense = false,
    this.noneLabel,
    this.allowUnknownValue = false,
  });

  @override
  State<QuickAddDropdown<T>> createState() => _QuickAddDropdownState<T>();
}

class _QuickAddDropdownState<T> extends State<QuickAddDropdown<T>> {
  /// Bumped after the "+ Add new" row is picked. It feeds the field's key,
  /// which rebuilds the FormField from scratch -- otherwise the dropdown
  /// keeps displaying the sentinel row as if it were the selection.
  int _resetTick = 0;

  @override
  Widget build(BuildContext context) {
    final known = widget.options.where((o) => widget.idOf(o) != null).toList();
    final isKnown = widget.value != null && known.any((o) => widget.idOf(o) == widget.value);
    final showUnknown = widget.value != null && !isKnown && widget.allowUnknownValue;

    return DropdownButtonFormField<int>(
      key: ValueKey('quick-add-${widget.label}-$_resetTick-${widget.value}'),
      value: isKnown || showUnknown ? widget.value : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: widget.label, isDense: widget.isDense),
      items: [
        if (widget.noneLabel != null)
          DropdownMenuItem(value: null, child: Text(widget.noneLabel!)),
        ...known.map((o) => DropdownMenuItem(
              value: widget.idOf(o),
              child: Text(widget.labelOf(o), overflow: TextOverflow.ellipsis),
            )),
        if (showUnknown)
          DropdownMenuItem(
            value: widget.value,
            child: Text('${widget.label} #${widget.value} (not in list)'),
          ),
        DropdownMenuItem(
          value: kAddNewId,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_circle_outline, size: 18, color: AppColors.brand),
              const SizedBox(width: 8),
              Text(
                widget.addNewLabel,
                style: const TextStyle(color: AppColors.brand, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
      onChanged: (v) async {
        if (v == kAddNewId) {
          final created = await widget.onCreate(context);
          if (!mounted) return;
          // Drop the sentinel out of the field whether or not the create
          // dialog was cancelled.
          setState(() => _resetTick++);
          if (created != null) widget.onCreated(created);
          return;
        }
        widget.onChanged(v);
      },
    );
  }
}
