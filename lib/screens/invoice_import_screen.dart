import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/doc_form_page.dart';

/// Import a supplier's tax invoice PDF into a Draft Purchase Invoice.
///
/// The PDF is read on the server and everything it found is shown here
/// for review before anything is created — a misread quantity would end
/// up in stock and in the books, so the numbers get a pair of human eyes
/// first. Lines the software could not match to an existing product, and
/// a supplier it has never seen, are flagged as NEW so it is obvious what
/// this import is about to add to your masters.
class InvoiceImportScreen extends StatefulWidget {
  /// Preview payload to start from, so the review layout can be rendered
  /// in a test without a server. Null in the app.
  @visibleForTesting
  final Map<String, dynamic>? initialPreview;

  const InvoiceImportScreen({super.key, this.initialPreview});

  /// Returns true when an invoice was created, so the caller can reload.
  static Future<bool?> open(BuildContext context) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => const InvoiceImportScreen()),
    );
  }

  @override
  State<InvoiceImportScreen> createState() => _InvoiceImportScreenState();
}

class _InvoiceImportScreenState extends State<InvoiceImportScreen> {
  Map<String, dynamic>? _preview;
  String? _fileName;
  bool _busy = false;
  String? _error;

  // Editable copies of what the parser read.
  final _invoiceNo = TextEditingController();
  final _invoiceDate = TextEditingController();
  final _supplierName = TextEditingController();
  final _gstin = TextEditingController();
  final _address = TextEditingController();
  final _email = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  // The goods arrived with the invoice, so receiving them is the default.
  bool _addToStock = true;
  int? _warehouseId;
  List<Map<String, dynamic>> _warehouses = [];
  final _qtyCtrls = <TextEditingController>[];
  final _rateCtrls = <TextEditingController>[];
  final _taxCtrls = <TextEditingController>[];

  @override
  void initState() {
    super.initState();
    if (widget.initialPreview != null) {
      _preview = widget.initialPreview;
      _fileName = 'sample.pdf';
      _fillFromPreview(_preview!);
    }
  }

  @override
  void dispose() {
    for (final c in [_invoiceNo, _invoiceDate, _supplierName, _gstin, _address, _email,
                     ..._qtyCtrls, ..._rateCtrls, ..._taxCtrls]) {
      c.dispose();
    }
    super.dispose();
  }

  double _num(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
  String _money(Object? v) => '₹${_num(v).toStringAsFixed(2)}';

  Future<void> _pickAndUpload() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Choose the supplier invoice PDF',
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (file == null) return;
    // Bytes rather than a path: on web there is no path to read from.
    final bytes = await file.readAsBytes();

    setState(() {
      _busy = true;
      _error = null;
      _preview = null;
    });
    try {
      final data = await ApiService.instance.uploadFile(
        '/api/purchase-invoices/import/preview', bytes, file.name);
      setState(() {
        _preview = data;
        _fileName = file.name;
        _busy = false;
        _fillFromPreview(data);
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _error = e is ApiException ? e.message : e.toString();
      });
    }
  }

  void _fillFromPreview(Map<String, dynamic> data) {
    final supplier = (data['supplier'] as Map).cast<String, dynamic>();
    final invoice = (data['invoice'] as Map).cast<String, dynamic>();
    _supplierName.text = '${supplier['name'] ?? ''}';
    _gstin.text = '${supplier['gstin'] ?? ''}';
    _address.text = '${supplier['address'] ?? ''}';
    _email.text = '${supplier['email'] ?? ''}';
    _invoiceNo.text = '${invoice['invoice_no'] ?? ''}';
    _invoiceDate.text = '${invoice['invoice_date'] ?? ''}';

    _warehouses = ((data['warehouses'] as List<dynamic>?) ?? [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
    // With a single warehouse there is nothing to choose.
    _warehouseId = _warehouses.length == 1 ? _warehouses.first['id'] as int : null;

    _items = ((data['items'] as List<dynamic>?) ?? [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
    for (final c in [..._qtyCtrls, ..._rateCtrls, ..._taxCtrls]) {
      c.dispose();
    }
    _qtyCtrls
      ..clear()
      ..addAll(_items.map((i) => TextEditingController(text: '${_num(i['quantity'])}')));
    _rateCtrls
      ..clear()
      ..addAll(_items.map((i) => TextEditingController(text: '${_num(i['rate'])}')));
    _taxCtrls
      ..clear()
      ..addAll(_items.map((i) => TextEditingController(text: '${_num(i['tax_percent'])}')));
  }

  double get _linesTotal {
    var total = 0.0;
    for (var i = 0; i < _items.length; i++) {
      final qty = double.tryParse(_qtyCtrls[i].text) ?? 0;
      final rate = double.tryParse(_rateCtrls[i].text) ?? 0;
      final tax = double.tryParse(_taxCtrls[i].text) ?? 0;
      final amount = qty * rate;
      total += amount + amount * tax / 100;
    }
    return total;
  }

  Future<void> _confirm() async {
    if (_supplierName.text.trim().isEmpty) {
      showFormError(context, 'The supplier needs a name.');
      return;
    }
    if (_items.isEmpty) {
      showFormError(context, 'There are no line items to import.');
      return;
    }
    if (_addToStock && _warehouses.length > 1 && _warehouseId == null) {
      showFormError(context, 'Choose which warehouse the goods came into.');
      return;
    }
    final supplier = (_preview!['supplier'] as Map).cast<String, dynamic>();
    setState(() => _busy = true);
    try {
      final created = await ApiService.instance.create(
        '/api/purchase-invoices/import/confirm',
        {
          'supplier_id': supplier['matched_id'],
          'supplier': {
            'name': _supplierName.text.trim(),
            'gstin': _gstin.text.trim().isEmpty ? null : _gstin.text.trim(),
            'address': _address.text.trim().isEmpty ? null : _address.text.trim(),
            'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
          },
          'invoice_no': _invoiceNo.text.trim().isEmpty ? null : _invoiceNo.text.trim(),
          'invoice_date': _invoiceDate.text.trim().isEmpty ? null : _invoiceDate.text.trim(),
          'notes': _importNote(),
          'add_to_stock': _addToStock,
          'warehouse_id': _warehouseId,
          'items': [
            for (var i = 0; i < _items.length; i++)
              {
                'description': _items[i]['description'],
                'hsn': _items[i]['hsn'],
                'quantity': double.tryParse(_qtyCtrls[i].text) ?? 0,
                'unit': _items[i]['unit'],
                'rate': double.tryParse(_rateCtrls[i].text) ?? 0,
                'tax_percent': double.tryParse(_taxCtrls[i].text) ?? 0,
                'product_id': _items[i]['product_id'],
                'kind': _items[i]['kind'] ?? 'goods',
              },
          ],
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_addToStock
              ? '${created['invoice_no']} created as a Draft, and the quantities are in stock.'
              : '${created['invoice_no']} created as a Draft — review and post it.'),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _busy = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.message : e.toString()),
          backgroundColor: AppColors.rose,
        ),
      );
    }
  }

  /// Keeps the transport details from the PDF on the invoice, since the
  /// ERP has no fields of its own for an e-way bill or a vehicle number.
  String _importNote() {
    final invoice = (_preview!['invoice'] as Map).cast<String, dynamic>();
    final bits = <String>[
      if ('${invoice['eway_bill_no'] ?? ''}'.isNotEmpty) 'e-Way ${invoice['eway_bill_no']}',
      if ('${invoice['vehicle_no'] ?? ''}'.isNotEmpty) 'vehicle ${invoice['vehicle_no']}',
      if ('${invoice['dispatched_from'] ?? ''}'.isNotEmpty) 'from ${invoice['dispatched_from']}',
      if (_fileName != null) 'imported from $_fileName',
    ];
    return bits.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final hasPreview = _preview != null;
    return Scaffold(
      backgroundColor: AppColors.page,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Cancel',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Import Supplier Invoice',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            Text(_fileName ?? 'Read a PDF into a Draft purchase invoice',
                style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ],
        ),
        shape: const Border(bottom: BorderSide(color: AppColors.line)),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: _busy
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    if (_error != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: AppColors.tintedBox(AppColors.rose, radius: 8),
                        child: Row(children: [
                          const Icon(Icons.error_outline, color: AppColors.rose),
                          const SizedBox(width: 10),
                          Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.rose))),
                        ]),
                      ),
                    if (!hasPreview) _picker() else ..._reviewSections(),
                  ],
                ),
        ),
      ),
      bottomNavigationBar: !hasPreview
          ? null
          : Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.line)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Text('Lines total  ${_money(_linesTotal)}',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _busy ? null : _confirm,
                        icon: const Icon(Icons.check),
                        label: const Text('Create Draft Invoice'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _picker() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: AppColors.tintedBox(AppColors.brand, radius: 20, border: false),
              child: const Icon(Icons.upload_file_outlined, size: 44, color: AppColors.brand),
            ),
            const SizedBox(height: 20),
            Text('Choose the supplier\'s invoice PDF',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 470),
              child: Text(
                'The invoice your supplier generated from their software. Nothing is saved until '
                'you have checked the figures on the next screen.\n\n'
                'A scan or photograph of a bill has no text in it and cannot be read.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted),
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _pickAndUpload,
              icon: const Icon(Icons.folder_open_outlined),
              label: const Text('Choose PDF'),
            ),
          ],
        ),
      );

  List<Widget> _reviewSections() {
    final supplier = (_preview!['supplier'] as Map).cast<String, dynamic>();
    final invoice = (_preview!['invoice'] as Map).cast<String, dynamic>();
    final totals = (_preview!['totals'] as Map).cast<String, dynamic>();
    final warnings = ((_preview!['warnings'] as List<dynamic>?) ?? []).map((e) => '$e').toList();
    final newSupplier = supplier['will_create'] == true;
    final newProducts = _items.where((i) => i['will_create_product'] == true).length;

    return [
      if (warnings.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(14),
          decoration: AppColors.tintedBox(AppColors.amber, radius: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Check these before importing',
                  style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.amber)),
              const SizedBox(height: 6),
              for (final w in warnings)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('• $w', style: const TextStyle(color: AppColors.amber)),
                ),
            ],
          ),
        ),
      DocFormSection(
        title: 'Supplier',
        hint: newSupplier
            ? 'Not in your supplier list — it will be created with these details.'
            : 'Matched to ${supplier['matched_code']} in your supplier list.',
        children: [
          if (newSupplier) _newBadge('New supplier will be created'),
          TextField(controller: _supplierName, decoration: const InputDecoration(labelText: 'Supplier name')),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(controller: _gstin, decoration: const InputDecoration(labelText: 'GSTIN'))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email'))),
          ]),
          const SizedBox(height: 12),
          TextField(controller: _address, decoration: const InputDecoration(labelText: 'Address'), maxLines: 2),
        ],
      ),
      DocFormSection(
        title: 'Invoice',
        hint: 'The supplier\'s own number and date. Your internal PINV number is assigned on save.',
        children: [
          Row(children: [
            Expanded(child: TextField(controller: _invoiceNo, decoration: const InputDecoration(labelText: 'Supplier invoice no.'))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: _invoiceDate, decoration: const InputDecoration(labelText: 'Invoice date (YYYY-MM-DD)'))),
          ]),
          const SizedBox(height: 12),
          _readOnlyRow('e-Way bill', '${invoice['eway_bill_no'] ?? '--'}'),
          _readOnlyRow('Vehicle', '${invoice['vehicle_no'] ?? '--'}'),
          _readOnlyRow('Dispatched from / to',
              '${invoice['dispatched_from'] ?? '--'} → ${invoice['destination'] ?? '--'}'),
          const SizedBox(height: 4),
          const Text('These are kept in the invoice notes — the ERP has no fields of its own for them.',
              style: TextStyle(color: AppColors.muted, fontSize: 12)),
        ],
      ),
      DocFormSection(
        title: 'Items',
        hint: newProducts == 0
            ? 'Every line matched a product you already have.'
            : '$newProducts line(s) are not in your product list and will be created.',
        children: [
          for (int i = 0; i < _items.length; i++) _itemRow(i),
        ],
      ),
      DocFormSection(
        title: 'Stock',
        hint: 'An invoice records what the goods cost; stock moves on a Goods Receipt. '
            'Leave this ticked and the import raises a confirmed receipt for the same '
            'quantities, so the godown figures are right straight away.',
        children: [
          CheckboxListTile(
            value: _addToStock,
            onChanged: (v) => setState(() => _addToStock = v ?? false),
            title: const Text('Add these quantities to stock'),
            subtitle: const Text(
                'Creates a confirmed Goods Receipt against this supplier for the lines '
                'marked Goods. Charge lines are never stocked.'),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
          if (_addToStock && _warehouses.length > 1) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: _warehouseId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Received into warehouse'),
              items: [
                for (final w in _warehouses)
                  DropdownMenuItem<int>(value: w['id'] as int, child: Text('${w['name']}')),
              ],
              onChanged: (v) => setState(() => _warehouseId = v),
            ),
          ],
          if (_addToStock && _warehouses.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('No warehouses set up — the receipt will not be tied to one.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12)),
            ),
        ],
      ),
      DocFormSection(
        title: 'Totals on the PDF',
        children: [
          _readOnlyRow('Taxable value', _money(totals['taxable_value'])),
          _readOnlyRow('Tax', _money(totals['tax_amount'])),
          _readOnlyRow('Invoice total', _money(totals['total_amount'])),
          const SizedBox(height: 8),
          Text('Your edited lines add up to ${_money(_linesTotal)}.',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: (_linesTotal - _num(totals['total_amount'])).abs() < 1
                      ? AppColors.green
                      : AppColors.amber)),
        ],
      ),
    ];
  }

  Widget _newBadge(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: AppColors.tintedBox(AppColors.brand, radius: 6),
            child: Text(text,
                style: const TextStyle(
                    color: AppColors.brand, fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ),
      );

  Widget _readOnlyRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          SizedBox(width: 180, child: Text(label, style: const TextStyle(color: AppColors.muted))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );

  Widget _itemRow(int i) {
    final item = _items[i];
    final isNew = item['will_create_product'] == true;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text('${item['description']}',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
            ),
            if (isNew)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: AppColors.tintedBox(AppColors.brand, radius: 6),
                child: const Text('NEW PRODUCT',
                    style: TextStyle(color: AppColors.brand, fontWeight: FontWeight.w700, fontSize: 11)),
              )
            else
              Text('matches ${item['product_code']}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            SizedBox(
              width: 130,
              child: Text('HSN ${item['hsn'] ?? '--'}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ),
            Expanded(
              child: TextFormField(
                controller: _qtyCtrls[i],
                decoration: InputDecoration(labelText: 'Qty${item['unit'] != null ? ' (${item['unit']})' : ''}', isDense: true),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _rateCtrls[i],
                decoration: const InputDecoration(labelText: 'Rate', isDense: true),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _taxCtrls[i],
                decoration: const InputDecoration(labelText: 'Tax %', isDense: true),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 120,
              child: Text(
                _money((double.tryParse(_qtyCtrls[i].text) ?? 0) * (double.tryParse(_rateCtrls[i].text) ?? 0)),
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ]),
          Row(children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'goods', label: Text('Goods'), icon: Icon(Icons.inventory_2_outlined, size: 15)),
                ButtonSegment(value: 'charge', label: Text('Charge'), icon: Icon(Icons.local_shipping_outlined, size: 15)),
              ],
              selected: {'${item['kind'] ?? 'goods'}'},
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              onSelectionChanged: (v) => setState(() => item['kind'] = v.first),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item['kind'] == 'charge'
                    // Freight and labour belong on the bill, not in the godown.
                    ? 'Freight/labour: kept on the invoice as a charge. No product is created and nothing is added to stock.'
                    : 'A product line: received into stock and added to your product list.',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
          ]),
          const Divider(height: 20),
        ],
      ),
    );
  }
}
