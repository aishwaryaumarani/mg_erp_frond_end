import 'package:flutter/material.dart';
import '../models/models.dart';
import '../widgets/master_crud_screen.dart';

/// Warehouse master -- plain CRUD, same pattern as Category/Brand/Unit
/// (see simple_master_screens.dart). Goods Receipt and Delivery both
/// reference a Warehouse; StockLedger rows are scoped per warehouse too.
class WarehouseScreen extends StatelessWidget {
  const WarehouseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MasterCrudScreen<Warehouse>(
      resourcePath: '/api/warehouses/',
      entityName: 'Warehouse',
      fromJson: Warehouse.fromJson,
      toJson: (w) => w.toJson(),
      idOf: (w) => w.id,
      titleOf: (w) => w.name,
      subtitleOf: (w) => w.code != null ? 'Code: ${w.code}' : (w.address ?? ''),
      statusOf: (w) => w.status,
      openForm: openForm,
    );
  }

  /// Public so quick_add.dart can reopen this same dialog inline from a
  /// Warehouse dropdown in Delivery / Goods Receipt.
  static Future<Warehouse?> openForm(BuildContext context, Warehouse? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final codeCtrl = TextEditingController(text: existing?.code ?? '');
    final addressCtrl = TextEditingController(text: existing?.address ?? '');
    String status = existing?.status ?? 'Active';

    return showDialog<Warehouse>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
        return AlertDialog(
          title: Text(existing == null ? 'New Warehouse' : 'Edit Warehouse'),
          content: SizedBox(
            width: 400,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Warehouse Name')),
              const SizedBox(height: 12),
              TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Code (optional)')),
              const SizedBox(height: 12),
              TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Address (optional)'), maxLines: 2),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(value: 'Active', child: Text('Active')),
                  DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
                ],
                onChanged: (v) => setState(() => status = v ?? 'Active'),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(
                  ctx,
                  Warehouse(
                    id: existing?.id,
                    name: nameCtrl.text.trim(),
                    code: codeCtrl.text.trim().isEmpty ? null : codeCtrl.text.trim(),
                    address: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
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
