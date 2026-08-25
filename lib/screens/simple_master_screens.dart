import 'package:flutter/material.dart';
import '../models/models.dart';
import '../widgets/master_crud_screen.dart';

const _statusOptions = ['Active', 'Inactive'];

// ---------------------------------------------------------------- Category
class CategoryScreen extends StatelessWidget {
  const CategoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MasterCrudScreen<Category>(
      resourcePath: '/api/categories/',
      entityName: 'Category',
      fromJson: Category.fromJson,
      toJson: (c) => c.toJson(),
      idOf: (c) => c.id,
      titleOf: (c) => c.name,
      subtitleOf: (c) => c.parentId != null ? 'Sub-category of #${c.parentId}' : 'Top-level category',
      statusOf: (c) => c.status,
      openForm: _openForm,
    );
  }

  static Future<Category?> _openForm(BuildContext context, Category? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final parentCtrl = TextEditingController(text: existing?.parentId?.toString() ?? '');
    String status = existing?.status ?? 'Active';

    return showDialog<Category>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
        return AlertDialog(
          title: Text(existing == null ? 'New Category' : 'Edit Category'),
          content: SizedBox(
            width: 400,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Category Name')),
              const SizedBox(height: 12),
              TextField(
                controller: parentCtrl,
                decoration: const InputDecoration(
                  labelText: 'Parent Category ID (optional, for Sub Category)',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: _statusOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
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
                  Category(
                    id: existing?.id,
                    name: nameCtrl.text.trim(),
                    parentId: int.tryParse(parentCtrl.text.trim()),
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

// ------------------------------------------------------------------- Brand
class BrandScreen extends StatelessWidget {
  const BrandScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MasterCrudScreen<Brand>(
      resourcePath: '/api/brands/',
      entityName: 'Brand',
      fromJson: Brand.fromJson,
      toJson: (b) => b.toJson(),
      idOf: (b) => b.id,
      titleOf: (b) => b.name,
      statusOf: (b) => b.status,
      openForm: _openForm,
    );
  }

  static Future<Brand?> _openForm(BuildContext context, Brand? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    String status = existing?.status ?? 'Active';

    return showDialog<Brand>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
        return AlertDialog(
          title: Text(existing == null ? 'New Brand' : 'Edit Brand'),
          content: SizedBox(
            width: 400,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Brand Name')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: _statusOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => status = v ?? 'Active'),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, Brand(id: existing?.id, name: nameCtrl.text.trim(), status: status));
              },
              child: const Text('Save'),
            ),
          ],
        );
      }),
    );
  }
}

// -------------------------------------------------------------------- Unit
class UnitScreen extends StatelessWidget {
  const UnitScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MasterCrudScreen<Unit>(
      resourcePath: '/api/units/',
      entityName: 'Unit',
      fromJson: Unit.fromJson,
      toJson: (u) => u.toJson(),
      idOf: (u) => u.id,
      titleOf: (u) => u.name,
      statusOf: (u) => u.status,
      openForm: _openForm,
    );
  }

  static Future<Unit?> _openForm(BuildContext context, Unit? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    String status = existing?.status ?? 'Active';

    return showDialog<Unit>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
        return AlertDialog(
          title: Text(existing == null ? 'New Unit' : 'Edit Unit'),
          content: SizedBox(
            width: 400,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Unit Name (e.g. PCS, KG, BOX)'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: _statusOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => status = v ?? 'Active'),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, Unit(id: existing?.id, name: nameCtrl.text.trim(), status: status));
              },
              child: const Text('Save'),
            ),
          ],
        );
      }),
    );
  }
}

// --------------------------------------------------------------------- Tax
class TaxScreen extends StatelessWidget {
  const TaxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MasterCrudScreen<Tax>(
      resourcePath: '/api/taxes/',
      entityName: 'Tax',
      fromJson: Tax.fromJson,
      toJson: (t) => t.toJson(),
      idOf: (t) => t.id,
      titleOf: (t) => t.name,
      subtitleOf: (t) => '${t.ratePercent}%',
      statusOf: (t) => t.status,
      openForm: _openForm,
    );
  }

  static Future<Tax?> _openForm(BuildContext context, Tax? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final rateCtrl = TextEditingController(text: existing?.ratePercent.toString() ?? '0');
    String status = existing?.status ?? 'Active';

    return showDialog<Tax>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
        return AlertDialog(
          title: Text(existing == null ? 'New Tax' : 'Edit Tax'),
          content: SizedBox(
            width: 400,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Tax Name (e.g. GST 18%)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: rateCtrl,
                decoration: const InputDecoration(labelText: 'Rate (%)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: _statusOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
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
                  Tax(
                    id: existing?.id,
                    name: nameCtrl.text.trim(),
                    ratePercent: double.tryParse(rateCtrl.text.trim()) ?? 0,
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
