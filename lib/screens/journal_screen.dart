import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/doc_form_page.dart';

/// Journal Entries -- every posting in the books, in date order.
///
/// Most entries are written automatically when a document is posted (a
/// Sales Invoice, a Supplier Payment); this screen shows those and lets
/// you record the ones no document produces: an expense, an opening
/// balance, a correction. Double entry is enforced by the server, and
/// mirrored here so the Save button can say why it is disabled.
class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  List<Map<String, dynamic>> _entries = [];
  List<Map<String, dynamic>> _accounts = [];
  bool _loading = true;
  String? _error;
  DateTimeRange? _range;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
    _load();
  }

  String _ymd(DateTime d) => d.toIso8601String().substring(0, 10);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiService.instance.list('/api/accounts/journal', query: {
          if (_range != null) 'date_from': _ymd(_range!.start),
          if (_range != null) 'date_to': _ymd(_range!.end),
        }),
        ApiService.instance.list('/api/accounts/', query: {'status': 'Active'}),
      ]);
      setState(() {
        _entries = results[0].map((e) => (e as Map).cast<String, dynamic>()).toList();
        _accounts = results[1].map((e) => (e as Map).cast<String, dynamic>()).toList();
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

  Future<void> _newEntry() async {
    final payload = await openJournalEntryForm(context, _accounts);
    if (payload == null) return;
    try {
      await ApiService.instance.create('/api/accounts/journal', payload);
      _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Journal entry recorded.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.message : e.toString()),
          backgroundColor: AppColors.rose,
        ),
      );
    }
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
                child: Text('Journal Entries',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800, color: AppColors.ink)),
              ),
              if (_range != null)
                OutlinedButton.icon(
                  onPressed: _pickRange,
                  icon: const Icon(Icons.date_range_outlined, size: 18),
                  label: Text('${_ymd(_range!.start)}  to  ${_ymd(_range!.end)}'),
                ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _accounts.isEmpty ? null : _newEntry,
                icon: const Icon(Icons.add),
                label: const Text('New Entry'),
              ),
              IconButton(tooltip: 'Refresh', onPressed: _load, icon: const Icon(Icons.refresh)),
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
                      : _entries.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text('No entries in this period.',
                                    style: TextStyle(color: AppColors.muted)),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: _entries.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final e = _entries[i];
                                final lines = ((e['lines'] as List<dynamic>?) ?? [])
                                    .map((l) => (l as Map).cast<String, dynamic>())
                                    .toList();
                                return ExpansionTile(
                                  title: Text('${e['entry_no']}  ·  ${'${e['entry_date']}'.substring(0, 10)}',
                                      style: const TextStyle(fontWeight: FontWeight.w700)),
                                  subtitle: Text(
                                    '${e['narration'] ?? ''}   ·   ${e['reference_type'] ?? 'Manual'}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: AppColors.muted),
                                  ),
                                  trailing: Text(_money(e['total']),
                                      style: const TextStyle(fontWeight: FontWeight.w800)),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                                      child: Column(
                                        children: [
                                          for (final l in lines)
                                            Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 4),
                                              child: Row(children: [
                                                SizedBox(
                                                  width: 150,
                                                  child: Text('${l['account_code']}',
                                                      style: const TextStyle(
                                                          fontWeight: FontWeight.w600)),
                                                ),
                                                Expanded(
                                                    child: Text('${l['account_name']}',
                                                        style: const TextStyle(
                                                            color: AppColors.muted))),
                                                SizedBox(
                                                  width: 130,
                                                  child: Text(
                                                    (l['debit'] as num) != 0 ? _money(l['debit']) : '',
                                                    textAlign: TextAlign.right,
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: 130,
                                                  child: Text(
                                                    (l['credit'] as num) != 0 ? _money(l['credit']) : '',
                                                    textAlign: TextAlign.right,
                                                  ),
                                                ),
                                              ]),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One line being typed into a new entry.
class _EntryLine {
  int? accountId;
  double debit = 0;
  double credit = 0;
}

/// The manual-entry form. Returns the POST body, or null if cancelled.
Future<Map<String, dynamic>?> openJournalEntryForm(
  BuildContext context,
  List<Map<String, dynamic>> accounts,
) {
  final narration = TextEditingController();
  final dateCtrl = TextEditingController(text: DateTime.now().toIso8601String().substring(0, 10));
  final lines = <_EntryLine>[_EntryLine(), _EntryLine()];
  final debitCtrls = <TextEditingController>[TextEditingController(), TextEditingController()];
  final creditCtrls = <TextEditingController>[TextEditingController(), TextEditingController()];

  String money(double v) => '₹${v.toStringAsFixed(2)}';

  return openDocFormPage<Map<String, dynamic>>(context, (ctx) {
    return StatefulBuilder(builder: (ctx, setState) {
      final debitTotal = lines.fold<double>(0, (s, l) => s + l.debit);
      final creditTotal = lines.fold<double>(0, (s, l) => s + l.credit);
      final difference = double.parse((debitTotal - creditTotal).toStringAsFixed(2));
      final balanced = difference == 0 && debitTotal > 0;

      return DocFormPage(
        title: 'New Journal Entry',
        subtitle: balanced
            ? 'Balanced · ${money(debitTotal)}'
            : 'Out of balance by ${money(difference.abs())}',
        saveLabel: 'Post Entry',
        onSave: () {
          if (narration.text.trim().isEmpty) {
            showFormError(ctx, 'Give the entry a narration -- what is it for?');
            return;
          }
          final used = lines.where((l) => l.accountId != null && (l.debit > 0 || l.credit > 0)).toList();
          if (used.length < 2) {
            showFormError(ctx, 'A journal entry needs at least two lines with an account and an amount.');
            return;
          }
          if (!balanced) {
            showFormError(ctx,
                'Debits and credits must match. Currently out by ${money(difference.abs())}.');
            return;
          }
          Navigator.pop(ctx, {
            'entry_date': dateCtrl.text.trim().isEmpty ? null : dateCtrl.text.trim(),
            'narration': narration.text.trim(),
            'lines': [
              for (final l in used)
                {'account_id': l.accountId, 'debit': l.debit, 'credit': l.credit},
            ],
          });
        },
        children: [
          DocFormSection(
            title: 'Entry',
            children: [
              TextField(
                controller: narration,
                decoration: const InputDecoration(
                    labelText: 'Narration', hintText: 'What is this entry for?'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dateCtrl,
                decoration: const InputDecoration(labelText: 'Entry Date (YYYY-MM-DD)'),
              ),
            ],
          ),
          DocFormSection(
            title: 'Lines',
            hint: 'Every entry has two sides: what was received (debit) and where it came '
                'from (credit). The two totals must match.',
            children: [
              for (int i = 0; i < lines.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<int>(
                          value: lines[i].accountId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Account', isDense: true),
                          items: [
                            for (final a in accounts)
                              DropdownMenuItem<int>(
                                value: a['id'] as int,
                                child: Text('${a['code']} — ${a['name']}',
                                    overflow: TextOverflow.ellipsis),
                              ),
                          ],
                          onChanged: (v) => setState(() => lines[i].accountId = v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: debitCtrls[i],
                          decoration: const InputDecoration(labelText: 'Debit', isDense: true),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (v) => setState(() {
                            lines[i].debit = double.tryParse(v) ?? 0;
                            // A line is one side or the other, never both.
                            if (lines[i].debit > 0) {
                              lines[i].credit = 0;
                              creditCtrls[i].clear();
                            }
                          }),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: creditCtrls[i],
                          decoration: const InputDecoration(labelText: 'Credit', isDense: true),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (v) => setState(() {
                            lines[i].credit = double.tryParse(v) ?? 0;
                            if (lines[i].credit > 0) {
                              lines[i].debit = 0;
                              debitCtrls[i].clear();
                            }
                          }),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Remove line',
                        onPressed: lines.length <= 2
                            ? null // two lines is the minimum a journal can have
                            : () => setState(() {
                                  lines.removeAt(i);
                                  debitCtrls.removeAt(i).dispose();
                                  creditCtrls.removeAt(i).dispose();
                                }),
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => setState(() {
                      lines.add(_EntryLine());
                      debitCtrls.add(TextEditingController());
                      creditCtrls.add(TextEditingController());
                    }),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Line'),
                  ),
                  const Spacer(),
                  Text('Debit ${money(debitTotal)}    Credit ${money(creditTotal)}',
                      style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: AppColors.tintedBox(
                        balanced ? AppColors.green : AppColors.amber,
                        radius: 6),
                    child: Text(
                      balanced ? 'Balanced' : 'Out by ${money(difference.abs())}',
                      style: TextStyle(
                        color: balanced ? AppColors.green : AppColors.amber,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
    });
  });
}
