import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/master_crud_screen.dart';

const _statusOptions = ['Active', 'Inactive'];

class ProductScreen extends StatelessWidget {
  const ProductScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MasterCrudScreen<Product>(
      resourcePath: '/api/products/',
      entityName: 'Product',
      fromJson: Product.fromJson,
      toJson: (p) => p.toJson(),
      idOf: (p) => p.id,
      titleOf: (p) => '${p.name}  [${p.productCode}]',
      subtitleOf: (p) => [
        if (p.barcode != null && p.barcode!.isNotEmpty) 'Barcode: ${p.barcode}',
        if (p.hsnSac != null && p.hsnSac!.isNotEmpty) 'HSN/SAC: ${p.hsnSac}',
        'Min stock: ${p.minimumStock.toStringAsFixed(0)} • Reorder: ${p.reorderLevel.toStringAsFixed(0)}',
      ].join(' • '),
      statusOf: (p) => p.status,
      openForm: _openForm,
    );
  }

  static Future<Product?> _openForm(BuildContext context, Product? existing) async {
    // Pull reference data for the dropdowns (spec sec 2: category/brand/
    // unit filtering, tax linkage). Loaded fresh each time the dialog
    // opens so newly-added categories/brands/etc. show up immediately.
    List<Category> categories = [];
    List<Brand> brands = [];
    List<Unit> units = [];
    List<Tax> taxes = [];
    try {
      final results = await Future.wait([
        ApiService.instance.list('/api/categories/'),
        ApiService.instance.list('/api/brands/'),
        ApiService.instance.list('/api/units/'),
        ApiService.instance.list('/api/taxes/'),
      ]);
      categories = results[0].map((e) => Category.fromJson(e)).toList();
      brands = results[1].map((e) => Brand.fromJson(e)).toList();
      units = results[2].map((e) => Unit.fromJson(e)).toList();
      taxes = results[3].map((e) => Tax.fromJson(e)).toList();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load reference data: $e'), backgroundColor: Colors.red),
        );
      }
      return null;
    }

    if (!context.mounted) return null;

    final code = TextEditingController(text: existing?.productCode ?? '');
    final name = TextEditingController(text: existing?.name ?? '');
    final hsn = TextEditingController(text: existing?.hsnSac ?? '');
    final barcode = TextEditingController(text: existing?.barcode ?? '');
    final description = TextEditingController(text: existing?.description ?? '');
    final minStock = TextEditingController(text: existing?.minimumStock.toString() ?? '0');
    final reorderLevel = TextEditingController(text: existing?.reorderLevel.toString() ?? '0');
    int? categoryId = existing?.categoryId;
    int? brandId = existing?.brandId;
    int? unitId = existing?.unitId;
    int? taxId = existing?.taxId;
    String status = existing?.status ?? 'Active';

    return showDialog<Product>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
        return AlertDialog(
          title: Text(existing == null ? 'New Product' : 'Edit Product'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Expanded(child: TextField(controller: code, decoration: const InputDecoration(labelText: 'Product Code / SKU'))),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: TextField(controller: name, decoration: const InputDecoration(labelText: 'Product Name'))),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: categoryId,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('— none —')),
                        ...categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                      ],
                      onChanged: (v) => setState(() => categoryId = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: brandId,
                      decoration: const InputDecoration(labelText: 'Brand'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('— none —')),
                        ...brands.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))),
                      ],
                      onChanged: (v) => setState(() => brandId = v),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: unitId,
                      decoration: const InputDecoration(labelText: 'Unit'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('— none —')),
                        ...units.map((u) => DropdownMenuItem(value: u.id, child: Text(u.name))),
                      ],
                      onChanged: (v) => setState(() => unitId = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: taxId,
                      decoration: const InputDecoration(labelText: 'Tax'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('— none —')),
                        ...taxes.map((t) => DropdownMenuItem(value: t.id, child: Text('${t.name} (${t.ratePercent}%)'))),
                      ],
                      onChanged: (v) => setState(() => taxId = v),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(controller: hsn, decoration: const InputDecoration(labelText: 'HSN/SAC'))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: barcode, decoration: const InputDecoration(labelText: 'Barcode'))),
                ]),
                const SizedBox(height: 12),
                TextField(controller: description, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: minStock,
                      decoration: const InputDecoration(labelText: 'Minimum Stock'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: reorderLevel,
                      decoration: const InputDecoration(labelText: 'Reorder Level'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ]),
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
                  Product(
                    id: existing?.id,
                    productCode: code.text.trim(),
                    name: name.text.trim(),
                    categoryId: categoryId,
                    brandId: brandId,
                    unitId: unitId,
                    taxId: taxId,
                    hsnSac: hsn.text.trim().isEmpty ? null : hsn.text.trim(),
                    barcode: barcode.text.trim().isEmpty ? null : barcode.text.trim(),
                    description: description.text.trim().isEmpty ? null : description.text.trim(),
                    minimumStock: double.tryParse(minStock.text.trim()) ?? 0,
                    reorderLevel: double.tryParse(reorderLevel.text.trim()) ?? 0,
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
