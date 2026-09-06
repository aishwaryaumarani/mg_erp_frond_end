import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/status_badge.dart';

const _accountTypes = ['Asset', 'Liability', 'Income', 'Expense', 'Equity'];

/// Chart of Accounts -- the list of buckets every posting lands in.
///
/// Balances are shown on the account's normal side (assets and expenses
/// debit-normal, the rest credit-normal), so a healthy figure is positive
/// on every row rather than a mix of signs to interpret. Accounts are
/// deactivated rather than deleted: the journal entries pointing at them
/// have to keep resolving.
class ChartOfAccountsScreen extends StatefulWidget {
  const ChartOfAccountsScreen({super.key});

  @override
  State<ChartOfAccountsScreen> createState() => _ChartOfAccountsScreenState();
}

class _ChartOfAccountsScreenState extends State<ChartOfAccountsScreen> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _accounts = [];
  bool _loading = true;
  String? _error;
  String? _type;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await ApiService.instance.list('/api/accounts/', query: {
        if (_searchCtrl.text.isNotEmpty) 'q': _searchCtrl.text,
        if (_type != null) 'type': _type,
      });
      setState(() {
        _accounts = raw.map((e) => (e as Map).cast<String, dynamic>()).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e is ApiException ? e.message : e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _save(Map<String, dynamic>? existing) async {
    final result = await _openForm(context, existing);
    if (result == null) return;
    try {
      if (existing == null) {
        await ApiService.instance.create('/api/accounts/', result);
      } else {
        await ApiService.instance.update('/api/accounts/${existing['id']}', result);
      }
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _deactivate(Map<String, dynamic> account) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate account?'),
        content: Text('"${account['name']}" stays in the books and keeps its history, '
            'but will not be offered for new entries.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.rose),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.instance.delete('/api/accounts/${account['id']}');
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  void _showError(Object e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(e is ApiException ? e.message : e.toString()),
        backgroundColor: AppColors.rose,
      ),
    );
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
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Search code or name...',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _load(),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<String?>(
                  value: _type,
                  isDense: true,
                  // Without this the dropdown sizes to its widest item and
                  // overflows the toolbar instead of ellipsizing.
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Type', isDense: true),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('All types')),
                    ..._accountTypes.map((t) => DropdownMenuItem<String?>(value: t, child: Text(t))),
                  ],
                  onChanged: (v) {
                    setState(() => _type = v);
                    _load();
                  },
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _save(null),
                icon: const Icon(Icons.add),
                label: const Text('New Account'),
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
                      : _accounts.isEmpty
                          ? const Center(child: Text('No accounts yet.'))
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
                                    DataColumn(label: Text('Code')),
                                    DataColumn(label: Text('Account')),
                                    DataColumn(label: Text('Type')),
                                    DataColumn(label: Text('Debit'), numeric: true),
                                    DataColumn(label: Text('Credit'), numeric: true),
                                    DataColumn(label: Text('Balance'), numeric: true),
                                    DataColumn(label: Text('Status')),
                                    DataColumn(label: Text('')),
                                  ],
                                  rows: [
                                    for (final a in _accounts)
                                      DataRow(cells: [
                                        DataCell(Text('${a['code']}')),
                                        DataCell(Text('${a['name']}')),
                                        DataCell(Text('${a['type']}')),
                                        DataCell(Text(_money(a['debit_total']))),
                                        DataCell(Text(_money(a['credit_total']))),
                                        DataCell(Text(_money(a['balance']),
                                            style: const TextStyle(fontWeight: FontWeight.w700))),
                                        DataCell(StatusBadge(status: '${a['status']}')),
                                        DataCell(Row(children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit_outlined),
                                            tooltip: 'Edit',
                                            onPressed: () => _save(a),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.block_outlined),
                                            tooltip: 'Deactivate',
                                            onPressed: '${a['status']}' == 'Active'
                                                ? () => _deactivate(a)
                                                : null,
                                          ),
                                        ])),
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

Future<Map<String, dynamic>?> _openForm(BuildContext context, Map<String, dynamic>? existing) {
  final code = TextEditingController(text: existing?['code']?.toString() ?? '');
  final name = TextEditingController(text: existing?['name']?.toString() ?? '');
  String type = existing?['type']?.toString() ?? 'Asset';
  String status = existing?['status']?.toString() ?? 'Active';
  final posted = ((existing?['debit_total'] ?? 0) as num) != 0 ||
      ((existing?['credit_total'] ?? 0) as num) != 0;

  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      return AlertDialog(
        title: Text(existing == null ? 'New Account' : 'Edit Account'),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: code,
              readOnly: existing != null, // the code is what postings refer to
              decoration: InputDecoration(
                labelText: 'Code',
                hintText: 'e.g. FREIGHT_OUT',
                helperText: existing != null ? 'A code cannot be changed once created' : null,
              ),
            ),
            const SizedBox(height: 12),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Account name')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: type,
              decoration: InputDecoration(
                labelText: 'Type',
                helperText: posted ? 'Locked: this account already has entries' : null,
              ),
              items: _accountTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: posted ? null : (v) => setState(() => type = v ?? 'Asset'),
            ),
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
              if (code.text.trim().isEmpty || name.text.trim().isEmpty) return;
              Navigator.pop(ctx, {
                'code': code.text.trim(),
                'name': name.text.trim(),
                'type': type,
                'status': status,
              });
            },
            child: const Text('Save'),
          ),
        ],
      );
    }),
  );
}
