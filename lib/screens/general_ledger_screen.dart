import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// General Ledger -- one account's movements with a running balance.
///
/// Also serves the Cash, Bank and Tax screens: they are this ledger with
/// an account preselected, because "the cash book" is exactly the ledger
/// of the Cash account. The opening balance carries in everything before
/// the chosen start date, so the closing figure is the real one rather
/// than just this period's movement.
class GeneralLedgerScreen extends StatefulWidget {
  final String title;

  /// Preselects an account by code (CASH, BANK, OUTPUT_TAX...). The picker
  /// stays available so a Tax view can switch between input and output.
  final String? initialAccountCode;

  /// Narrows the picker, e.g. the two tax accounts.
  final List<String>? onlyCodes;

  const GeneralLedgerScreen({
    super.key,
    this.title = 'General Ledger',
    this.initialAccountCode,
    this.onlyCodes,
  });

  @override
  State<GeneralLedgerScreen> createState() => _GeneralLedgerScreenState();
}

class _GeneralLedgerScreenState extends State<GeneralLedgerScreen> {
  List<Map<String, dynamic>> _accounts = [];
  List<Map<String, dynamic>> _rows = [];
  Map<String, dynamic> _summary = {};
  int? _accountId;
  bool _loading = true;
  String? _error;
  DateTimeRange? _range;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  @override
  void didUpdateWidget(covariant GeneralLedgerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Cash -> Bank -> Tax all render this same widget in the same slot, so
    // without this the second one you open keeps the first one's account.
    if (oldWidget.initialAccountCode != widget.initialAccountCode ||
        oldWidget.title != widget.title) {
      setState(() {
        _rows = [];
        _summary = {};
        _accountId = null;
        _loading = true;
      });
      _loadAccounts();
    }
  }

  String _ymd(DateTime d) => d.toIso8601String().substring(0, 10);

  Future<void> _loadAccounts() async {
    try {
      final raw = await ApiService.instance.list('/api/accounts/');
      var accounts = raw.map((e) => (e as Map).cast<String, dynamic>()).toList();
      if (widget.onlyCodes != null) {
        accounts = accounts.where((a) => widget.onlyCodes!.contains('${a['code']}')).toList();
      }
      int? initial;
      if (widget.initialAccountCode != null) {
        final match = accounts.where((a) => '${a['code']}' == widget.initialAccountCode);
        if (match.isNotEmpty) initial = match.first['id'] as int;
      }
      initial ??= accounts.isEmpty ? null : accounts.first['id'] as int;
      setState(() {
        _accounts = accounts;
        _accountId = initial;
      });
      if (initial != null) {
        await _load();
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() {
        _error = e is ApiException ? e.message : e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _load() async {
    if (_accountId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.instance.getOne('/api/accounts/ledger', query: {
        'account_id': _accountId,
        if (_range != null) 'date_from': _ymd(_range!.start),
        if (_range != null) 'date_to': _ymd(_range!.end),
      });
      setState(() {
        _rows = ((data['rows'] as List<dynamic>?) ?? [])
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList();
        _summary = ((data['summary'] as Map?) ?? {}).cast<String, dynamic>();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e is ApiException ? e.message : e.toString();
        _loading = false;
      });
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

  static String _money(Object? v) {
    final n = v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    return '₹${n.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(widget.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800, color: AppColors.ink)),
              ),
              SizedBox(
                width: 300,
                child: DropdownButtonFormField<int>(
                  value: _accountId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Account', isDense: true),
                  items: [
                    for (final a in _accounts)
                      DropdownMenuItem<int>(
                        value: a['id'] as int,
                        child: Text('${a['code']} — ${a['name']}', overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) {
                    setState(() => _accountId = v);
                    _load();
                  },
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _pickRange,
                icon: const Icon(Icons.date_range_outlined, size: 18),
                label: Text(_range == null
                    ? 'All dates'
                    : '${_ymd(_range!.start)}  to  ${_ymd(_range!.end)}'),
              ),
              if (_range != null)
                IconButton(
                  tooltip: 'Clear dates',
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() => _range = null);
                    _load();
                  },
                ),
              IconButton(tooltip: 'Refresh', onPressed: _load, icon: const Icon(Icons.refresh)),
            ],
          ),
          const SizedBox(height: 16),
          if (_summary.isNotEmpty)
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final entry in _summary.entries)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.key.toUpperCase(),
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(_money(entry.value),
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink)),
                      ],
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(_error!, style: const TextStyle(color: AppColors.rose)),
                          ),
                        )
                      : _rows.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text('Nothing posted to this account in this period.',
                                    style: TextStyle(color: AppColors.muted)),
                              ),
                            )
                          : SingleChildScrollView(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columnSpacing: 26,
                                  headingTextStyle: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.ink,
                                      fontSize: 13),
                                  columns: const [
                                    DataColumn(label: Text('Date')),
                                    DataColumn(label: Text('Entry')),
                                    DataColumn(label: Text('Source')),
                                    DataColumn(label: Text('Narration')),
                                    DataColumn(label: Text('Debit'), numeric: true),
                                    DataColumn(label: Text('Credit'), numeric: true),
                                    DataColumn(label: Text('Balance'), numeric: true),
                                  ],
                                  rows: [
                                    for (final r in _rows)
                                      DataRow(cells: [
                                        DataCell(Text('${r['date']}')),
                                        DataCell(Text('${r['entry_no']}')),
                                        DataCell(Text('${r['source']}')),
                                        DataCell(SizedBox(
                                          width: 260,
                                          child: Text('${r['narration'] ?? ''}',
                                              maxLines: 1, overflow: TextOverflow.ellipsis),
                                        )),
                                        DataCell(Text(
                                            (r['debit'] as num) != 0 ? _money(r['debit']) : '')),
                                        DataCell(Text(
                                            (r['credit'] as num) != 0 ? _money(r['credit']) : '')),
                                        DataCell(Text(_money(r['balance']),
                                            style: const TextStyle(fontWeight: FontWeight.w700))),
                                      ]),
                                  ],
                                ),
                              ),
                            ),
            ),
          ),
        ],
      ),
    );
  }
}
