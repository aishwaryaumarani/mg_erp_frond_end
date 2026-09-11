import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// Sends posted sales and purchase invoices to Tally as XML import files
/// (backend: app/routers/tally.py; the file format is app/core/tally.py).
///
/// Two files, imported in order: the masters -- parties and the sales,
/// purchase and GST ledgers -- and then the vouchers. The summary is
/// read with exactly the filters the download buttons send, so what it
/// counts is what the file holds.
class TallyExportScreen extends StatefulWidget {
  const TallyExportScreen({super.key});

  @override
  State<TallyExportScreen> createState() => _TallyExportScreenState();
}

/// One of the Tally names the vouchers post to. [key] is the query
/// parameter, and [initial] the backend's own default (LedgerNames in
/// app/core/tally.py) -- kept identical so a blank field and an untouched
/// one mean the same thing.
class _LedgerField {
  final String key;
  final String label;
  final String initial;
  const _LedgerField(this.key, this.label, this.initial);
}

const _ledgerFields = [
  _LedgerField('sales_voucher_type', 'Sales voucher type', 'Sales'),
  _LedgerField('purchase_voucher_type', 'Purchase voucher type', 'Purchase'),
  _LedgerField('sales_ledger', 'Sales ledger', 'Sales @ {rate}%'),
  _LedgerField('purchase_ledger', 'Purchase ledger', 'Purchase @ {rate}%'),
  _LedgerField('output_cgst', 'Output CGST', 'Output CGST'),
  _LedgerField('output_sgst', 'Output SGST', 'Output SGST'),
  _LedgerField('output_igst', 'Output IGST', 'Output IGST'),
  _LedgerField('input_cgst', 'Input CGST', 'Input CGST'),
  _LedgerField('input_sgst', 'Input SGST', 'Input SGST'),
  _LedgerField('input_igst', 'Input IGST', 'Input IGST'),
  _LedgerField('sales_charges', 'Charges on sales', 'Freight & Other Charges'),
  _LedgerField('purchase_charges', 'Charges on purchases', 'Freight Inward'),
  _LedgerField('round_off', 'Round off', 'Round Off'),
];

class _TallyExportScreenState extends State<TallyExportScreen> {
  /// Ledger names are a property of the Tally company on the other end,
  /// which does not change between exports -- so they are remembered on
  /// this device rather than retyped every month.
  static const _prefsKey = 'tally_ledger_names';

  static final _inr =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  static final _ymd = DateFormat('yyyy-MM-dd');
  static final _display = DateFormat('d MMM y');

  late DateTimeRange _range = _month(DateTime.now());
  String _kind = 'all';
  bool _inventory = false;
  bool _editingNames = false;

  final Map<String, TextEditingController> _names = {
    for (final f in _ledgerFields)
      f.key: TextEditingController(text: f.initial),
  };

  Map<String, dynamic>? _summary;
  String? _error;
  bool _loading = false;
  String? _downloading; // 'masters' | 'vouchers'

  /// Bumped per request, so a slow summary for an old selection cannot
  /// land on top of a newer one.
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _restoreNames().whenComplete(_load);
  }

  @override
  void dispose() {
    for (final c in _names.values) {
      c.dispose();
    }
    super.dispose();
  }

  static DateTimeRange _month(DateTime anyDay) => DateTimeRange(
        start: DateTime(anyDay.year, anyDay.month, 1),
        // Day 0 of next month is the last day of this one.
        end: DateTime(anyDay.year, anyDay.month + 1, 0),
      );

  Map<String, dynamic> get _query => {
        'date_from': _ymd.format(_range.start),
        'date_to': _ymd.format(_range.end),
        'kind': _kind,
        'inventory': '$_inventory',
        for (final f in _ledgerFields) f.key: _names[f.key]!.text.trim(),
      };

  // --- persistence ----------------------------------------------------------

  Future<void> _restoreNames() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      final saved = (jsonDecode(raw) as Map).cast<String, dynamic>();
      for (final f in _ledgerFields) {
        final value = saved[f.key];
        if (value is String && value.trim().isNotEmpty) {
          _names[f.key]!.text = value;
        }
      }
    } catch (_) {
      // Unreadable prefs just mean the defaults stand.
    }
  }

  Future<void> _saveNames() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _prefsKey,
        jsonEncode({
          for (final f in _ledgerFields) f.key: _names[f.key]!.text.trim()
        }));
    setState(() => _editingNames = false);
    _load();
  }

  void _resetNames() {
    for (final f in _ledgerFields) {
      _names[f.key]!.text = f.initial;
    }
    setState(() {});
  }

  // --- data -----------------------------------------------------------------

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data =
          await ApiService.instance.getOne('/api/tally/summary', query: _query);
      if (!mounted || request != _request) return;
      setState(() => _summary = data);
    } catch (e) {
      if (!mounted || request != _request) return;
      setState(() => _error = e is ApiException ? e.message : '$e');
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _download(String part) async {
    setState(() => _downloading = part);
    try {
      await ApiService.instance.download(
        '/api/tally/export',
        query: {..._query, 'part': part},
        fallbackName: 'tally-$part-$_kind-${_ymd.format(_range.start)}'
            '-to-${_ymd.format(_range.end)}.xml',
        mimeType: 'application/xml',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e is ApiException ? e.message : '$e'),
          backgroundColor: AppColors.rose,
        ));
      }
    } finally {
      if (mounted) setState(() => _downloading = null);
    }
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _range,
    );
    if (picked == null) return;
    setState(() => _range = picked);
    _load();
  }

  void _setRange(DateTimeRange range) {
    setState(() => _range = range);
    _load();
  }

  int _count(String kind) =>
      ((_summary?[kind] as Map?)?['count'] as num?)?.toInt() ?? 0;

  int get _total => _count('sales') + _count('purchase');

  // --- layout ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final pad = constraints.maxWidth < 600 ? 16.0 : 24.0;
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: ListView(
            padding: EdgeInsets.fromLTRB(pad, pad, pad, 40),
            children: [
              _options(),
              _gap,
              _summaryCard(),
              _gap,
              _ledgersCard(),
              _gap,
              _downloadCard(),
              _gap,
              _howToCard(),
            ],
          ),
        ),
      );
    });
  }

  static const _gap = SizedBox(height: 16);

  Widget _card({required Widget heading, required List<Widget> children}) =>
      Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: AppColors.surfaceAlt,
              padding: const EdgeInsets.fromLTRB(18, 15, 18, 15),
              child: heading,
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ],
        ),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text.toUpperCase(), style: AppText.overline),
      );

  // --- 1. what to export ----------------------------------------------------

  Widget _options() {
    final now = DateTime.now();
    final thisMonth = _month(now);
    final lastMonth = _month(DateTime(now.year, now.month - 1, 1));
    return _card(
      heading: const SectionHeading(
        title: 'What to export',
        subtitle: 'Posted, part-paid and paid invoices. Drafts and cancelled '
            'invoices are never sent to Tally.',
      ),
      children: [
        _label('Period'),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _pickRange,
              icon: const Icon(Icons.date_range_outlined, size: 18),
              label: Text(
                  '${_display.format(_range.start)}  –  ${_display.format(_range.end)}'),
            ),
            ChoiceChip(
              label: Text('This month (${DateFormat('MMM').format(now)})'),
              selected: _range == thisMonth,
              onSelected: (_) => _setRange(thisMonth),
            ),
            ChoiceChip(
              label: Text(
                  'Last month (${DateFormat('MMM').format(lastMonth.start)})'),
              selected: _range == lastMonth,
              onSelected: (_) => _setRange(lastMonth),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 32,
          runSpacing: 20,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _label('Invoices'),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                        value: 'all', label: Text('Sales + Purchase')),
                    ButtonSegment(value: 'sales', label: Text('Sales')),
                    ButtonSegment(value: 'purchase', label: Text('Purchase')),
                  ],
                  selected: {_kind},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) {
                    setState(() => _kind = s.first);
                    _load();
                  },
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _label('Voucher format'),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Ledgers only')),
                    ButtonSegment(value: true, label: Text('With stock items')),
                  ],
                  selected: {_inventory},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) {
                    setState(() => _inventory = s.first);
                    _load();
                  },
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          _inventory
              ? 'Item invoices: every line goes to Tally with its stock item, '
                  'quantity and rate, so Tally keeps stock too. Products are created '
                  'as stock items by the masters file.'
              : 'Accounting invoices: party, sales/purchase and GST ledgers only. '
                  'Stock stays in this ERP -- the simplest setup if Tally is used '
                  'for accounts and GST returns.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  // --- 2. what is in it -----------------------------------------------------

  Widget _summaryCard() {
    final warnings = ((_summary?['warnings'] as List?) ?? []).cast<String>();
    return _card(
      heading: SectionHeading(
        title: 'In this export',
        subtitle:
            '${_display.format(_range.start)} to ${_display.format(_range.end)}',
        trailing: _loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : IconButton(
                tooltip: 'Refresh',
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 19),
              ),
      ),
      children: [
        if (_error != null)
          _banner(_error!, AppColors.rose, Icons.error_outline)
        else if (_summary == null)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              if (_kind != 'purchase')
                _totals('Sales', 'sales', AppColors.green),
              if (_kind != 'sales')
                _totals('Purchase', 'purchase', AppColors.orange),
            ],
          ),
          if (_total == 0) ...[
            const SizedBox(height: 14),
            _banner(
                'No posted invoices in this period, so there is nothing to export yet.',
                AppColors.slate,
                Icons.inbox_outlined),
          ],
          for (final w in warnings) ...[
            const SizedBox(height: 10),
            _banner(w, AppColors.amber, Icons.warning_amber_outlined),
          ],
        ],
      ],
    );
  }

  Widget _totals(String title, String key, Color color) {
    final data = ((_summary?[key] as Map?) ?? {}).cast<String, dynamic>();
    Widget figure(String label, String value) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(children: [
            Expanded(
                child: Text(label,
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 13))),
            Text(value,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                  fontFeatures: [FontFeature.tabularFigures()],
                )),
          ]),
        );
    return Container(
      width: 320,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: AppColors.panel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 3, height: 16, color: color),
            const SizedBox(width: 10),
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, color: AppColors.ink)),
            const Spacer(),
            Text('${data['count'] ?? 0} invoice(s)',
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w700, fontSize: 12.5)),
          ]),
          figure('Taxable value', _inr.format(data['taxable'] ?? 0)),
          figure('GST', _inr.format(data['tax'] ?? 0)),
          const Padding(padding: EdgeInsets.only(top: 10), child: Divider()),
          figure('Invoice total', _inr.format(data['total'] ?? 0)),
        ],
      ),
    );
  }

  Widget _banner(String text, Color color, IconData icon) => Container(
        padding: const EdgeInsets.all(12),
        decoration: AppColors.tintedBox(color, radius: AppRadius.field),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text,
                  style: const TextStyle(
                      color: AppColors.ink, fontSize: 13, height: 1.45)),
            ),
          ],
        ),
      );

  // --- 3. the ledgers Tally needs --------------------------------------------

  Widget _ledgersCard() {
    final ledgers = ((_summary?['ledgers'] as List?) ?? [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
    final parties =
        ((_summary?['parties'] as Map?) ?? {}).cast<String, dynamic>();
    final stockItems = (_summary?['stock_items'] as num?)?.toInt() ?? 0;
    return _card(
      heading: SectionHeading(
        title: 'Ledgers Tally needs',
        subtitle: 'Tally matches by exact name. The masters file creates any '
            'ledger that is missing and leaves existing ones untouched.',
        trailing: TextButton.icon(
          onPressed: () => setState(() => _editingNames = !_editingNames),
          icon:
              Icon(_editingNames ? Icons.close : Icons.edit_outlined, size: 17),
          label: Text(_editingNames ? 'Close' : 'Match my Tally names'),
        ),
      ),
      children: [
        if (_editingNames) ...[
          _namesEditor(),
          const SizedBox(height: 18),
          const Divider(),
          const SizedBox(height: 14),
        ],
        if (ledgers.isEmpty)
          Text('Ledgers appear here once the period has invoices.',
              style: Theme.of(context).textTheme.bodySmall)
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final l in ledgers)
                Tooltip(
                  message: 'Under ${l['group']}',
                  child: Chip(
                    avatar: const Icon(Icons.account_balance_wallet_outlined,
                        size: 15, color: AppColors.brand),
                    label: Text('${l['name']}'),
                  ),
                ),
            ],
          ),
        if ((parties['customers'] ?? 0) + (parties['suppliers'] ?? 0) > 0) ...[
          const SizedBox(height: 12),
          Text(
            'Plus ${parties['customers'] ?? 0} customer ledger(s) under Sundry Debtors '
            'and ${parties['suppliers'] ?? 0} supplier ledger(s) under Sundry Creditors'
            '${_inventory ? ', and $stockItems stock item(s)' : ''}.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  Widget _namesEditor() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _banner(
            'Type the names exactly as they are in your Tally company. Leave '
            '{rate} in a name to get one ledger per GST rate -- "Sales @ {rate}%" '
            'becomes "Sales @ 18%"; for CGST and SGST it is half the rate.',
            AppColors.brand,
            Icons.info_outline,
          ),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, c) {
            final columns = c.maxWidth >= 900 ? 3 : (c.maxWidth >= 560 ? 2 : 1);
            final width = (c.maxWidth - 14 * (columns - 1)) / columns;
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final f in _ledgerFields)
                  SizedBox(
                    width: width,
                    child: TextField(
                      controller: _names[f.key],
                      decoration: InputDecoration(
                        labelText: f.label,
                        hintText: f.initial,
                        isDense: true,
                      ),
                    ),
                  ),
              ],
            );
          }),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                  onPressed: _resetNames,
                  child: const Text('Reset to defaults')),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _saveNames,
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Save names'),
              ),
            ],
          ),
        ],
      );

  // --- 4. download -----------------------------------------------------------

  Widget _downloadCard() {
    final ready = !_loading && _error == null && _total > 0;
    return _card(
      heading: const SectionHeading(
        title: 'Download',
        subtitle:
            'Import the masters file first -- Tally refuses a voucher that '
            'names a ledger it does not have.',
      ),
      children: [
        _step(
          number: 1,
          title: 'Masters',
          detail: _inventory
              ? 'Party ledgers, sales/purchase/GST ledgers, units and stock items.'
              : 'Party ledgers and the sales, purchase and GST ledgers.',
          button: OutlinedButton.icon(
            onPressed: ready && _downloading == null
                ? () => _download('masters')
                : null,
            icon: _spinnerOr('masters', Icons.download_outlined),
            label: const Text('Masters XML'),
          ),
        ),
        const SizedBox(height: 12),
        _step(
          number: 2,
          title: 'Vouchers',
          detail: ready
              ? '$_total invoice(s) as Tally ${_inventory ? 'item' : 'accounting'} vouchers.'
              : 'One voucher per invoice.',
          button: FilledButton.icon(
            onPressed: ready && _downloading == null
                ? () => _download('vouchers')
                : null,
            icon: _spinnerOr('vouchers', Icons.download_outlined, light: true),
            label: const Text('Vouchers XML'),
          ),
        ),
      ],
    );
  }

  Widget _spinnerOr(String part, IconData icon, {bool light = false}) =>
      _downloading == part
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: light ? Colors.white : AppColors.brand),
            )
          : Icon(icon, size: 18);

  Widget _step({
    required int number,
    required String title,
    required String detail,
    required Widget button,
  }) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: AppColors.panel(color: AppColors.surfaceAlt),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 14,
          runSpacing: 12,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                      color: AppColors.brand, shape: BoxShape.circle),
                  child: Text('$number',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink)),
                      const SizedBox(height: 2),
                      Text(detail,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ]),
            ),
            button,
          ],
        ),
      );

  // --- 5. how to import ------------------------------------------------------

  Widget _howToCard() {
    const steps = [
      (
        'Back up your Tally company first',
        'Or try the files on a test copy of the company the first time.'
      ),
      (
        'Keep the ERP invoice numbers',
        'Alter the Sales and Purchase voucher types and set numbering to Manual, or '
            'Automatic (Manual Override). Otherwise Tally renumbers the invoices and '
            'GSTR-1 will not match the bills your customers hold.'
      ),
      (
        'Import the masters file',
        'TallyPrime: Gateway of Tally > Import > Masters. Tally.ERP 9: Gateway of Tally > '
            'Import Data > Masters. Choose the XML, and set "if a master already exists" '
            'to Ignore Duplicates so your existing ledgers are left alone.'
      ),
      (
        'Import the vouchers file',
        'TallyPrime: Import > Transactions. Tally.ERP 9: Import Data > Vouchers. '
            'Re-importing the same file does not double-book -- each voucher carries '
            'this ERP\'s invoice ID.'
      ),
      (
        'Check the import result',
        'Tally reports how many were created and any errors. Open the Day Book for '
            'the period and compare the totals with the figures above.'
      ),
      (
        'One-time GST setup in Tally',
        'On each sales and purchase ledger (Sales @ 18% and so on) set GST applicable '
            'and its rate, so Tally\'s GSTR-1 and GSTR-3B classify the vouchers.'
      ),
    ];
    return _card(
      heading: const SectionHeading(title: 'How to import into Tally'),
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: AppColors.tintedBox(AppColors.gold,
                      radius: AppRadius.pill, border: false),
                  child: Text('${i + 1}',
                      style: const TextStyle(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w800,
                          fontSize: 12)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(steps[i].$1,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink)),
                      const SizedBox(height: 3),
                      Text(steps[i].$2,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
