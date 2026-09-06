import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/report_charts.dart';
import '../widgets/status_badge.dart';

/// One screen for every Phase-7 report (Sales, Purchase, Stock,
/// Receivables, Payables).
///
/// The backend returns the same {"rows": [...], "summary": {...}} shape
/// for all of them (backend/app/routers/reports.py), so the columns are
/// declared here per report and everything else -- filters, totals,
/// empty state, refresh -- is shared. Adding a sixth report is a column
/// list and a nav entry, not another screen.
class ReportColumn {
  final String key;
  final String label;

  /// Money and quantities are right-aligned and formatted; text is not.
  final bool numeric;
  final bool money;

  const ReportColumn(this.key, this.label, {this.numeric = false, this.money = false});
}

class ReportScreen extends StatefulWidget {
  final String title;
  final String path; // e.g. '/api/reports/sales'
  final List<ReportColumn> columns;

  /// Reports over a period take a date range; a stock snapshot doesn't.
  final bool dateFiltered;
  final String emptyMessage;

  /// Chart configuration. [chartLabelKey]/[chartValueKey] drive the
  /// magnitude bars; [chartStatusKey], when set, makes the pie a count by
  /// state in status colours instead of a share of the measure.
  final String? chartLabelKey;
  final String? chartValueKey;
  final String? chartStatusKey;

  /// Sums the measure per group for the pie (Income vs Expenses).
  final String? chartGroupKey;

  /// Rank bars by magnitude, keeping negative balances visible.
  final bool chartAbsolute;
  final String barTitle;
  final String pieTitle;

  /// Rows where this column is greater than zero are tinted, so invoices
  /// still owing stand out from settled ones at a glance. The amount is
  /// in the row too, so the tint is a second signal, never the only one.
  final String? highlightPositiveKey;

  const ReportScreen({
    super.key,
    required this.title,
    required this.path,
    required this.columns,
    this.dateFiltered = true,
    this.emptyMessage = 'Nothing to report for this period.',
    this.chartLabelKey,
    this.chartValueKey,
    this.chartStatusKey,
    this.chartGroupKey,
    this.chartAbsolute = false,
    this.barTitle = 'Top by value',
    this.pieTitle = 'Share',
    this.highlightPositiveKey,
  });

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  List<Map<String, dynamic>> _rows = [];
  Map<String, dynamic> _summary = {};
  bool _loading = true;
  String? _error;
  DateTimeRange? _range;

  @override
  void initState() {
    super.initState();
    _resetForReport();
  }

  @override
  void didUpdateWidget(covariant ReportScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Switching reports in the sidebar swaps the widget but keeps this
    // State -- same type, same slot in the tree -- so initState does not
    // run again. Without this, the Payable report kept showing whichever
    // report was opened first (its rows, its totals, under the new title).
    if (oldWidget.path != widget.path) {
      setState(_resetForReport);
    }
  }

  /// Clears the previous report's data and loads this one.
  void _resetForReport() {
    _rows = [];
    _summary = {};
    _error = null;
    _loading = true;
    if (widget.dateFiltered) {
      // Default to the current month -- the period people actually ask for.
      final now = DateTime.now();
      _range = DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
    } else {
      _range = null; // a snapshot report has no period
    }
    _load();
  }

  String _ymd(DateTime d) => d.toIso8601String().substring(0, 10);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final query = <String, dynamic>{};
      if (_range != null) {
        query['date_from'] = _ymd(_range!.start);
        query['date_to'] = _ymd(_range!.end);
      }
      final data = await ApiService.instance.getOne(widget.path, query: query);
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

  String _cell(Map<String, dynamic> row, ReportColumn col) {
    final v = row[col.key];
    if (v == null) return '--';
    if (col.money) return _money(v);
    if (col.numeric && v is num) {
      return v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';
    }
    return '$v';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _toolbar(),
          const SizedBox(height: 16),
          if (_summary.isNotEmpty) _summaryTiles(),
          const SizedBox(height: 16),
          if (!_loading && _error == null && _rows.isNotEmpty && widget.chartValueKey != null) ...[
            ReportCharts(
              rows: _rows,
              labelKey: widget.chartLabelKey!,
              valueKey: widget.chartValueKey!,
              statusKey: widget.chartStatusKey,
              groupKey: widget.chartGroupKey,
              absolute: widget.chartAbsolute,
              barTitle: widget.barTitle,
              pieTitle: widget.pieTitle,
            ),
            const SizedBox(height: 16),
          ],
          SizedBox(
            // The table gets a workable height of its own now that the
            // charts share the page.
            height: 420,
            child: Card(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _errorBox()
                      : _rows.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(widget.emptyMessage,
                                    style: const TextStyle(color: AppColors.muted)),
                              ),
                            )
                          : _table(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolbar() => Row(
        children: [
          Expanded(
            child: Text(widget.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    )),
          ),
          if (widget.dateFiltered && _range != null) ...[
            OutlinedButton.icon(
              onPressed: _pickRange,
              icon: const Icon(Icons.date_range_outlined, size: 18),
              label: Text('${_ymd(_range!.start)}  to  ${_ymd(_range!.end)}'),
            ),
            const SizedBox(width: 12),
          ],
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      );

  Widget _summaryTiles() => Wrap(
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
                  Text(
                    // Counts stay plain; money is formatted.
                    entry.value is int ? '${entry.value}' : _money(entry.value),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
                  ),
                ],
              ),
            ),
        ],
      );

  Widget _errorBox() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.rose, size: 32),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.rose)),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Try again')),
            ],
          ),
        ),
      );

  Widget _table() => SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 26,
            headingTextStyle: const TextStyle(
                fontWeight: FontWeight.w800, color: AppColors.ink, fontSize: 13),
            columns: [
              for (final col in widget.columns)
                DataColumn(label: Text(col.label), numeric: col.numeric || col.money),
            ],
            rows: [
              for (final row in _rows)
                DataRow(
                  color: _owing(row)
                      // Warning tint: this row needs chasing. Kept light so
                      // the ink text on top stays fully readable.
                      ? WidgetStateProperty.all(AppColors.amber.withValues(alpha: 0.10))
                      : null,
                  cells: [
                  for (final col in widget.columns)
                    DataCell(
                      col.key == 'status'
                          ? StatusBadge(status: '${row[col.key] ?? ''}')
                          : Text(_cell(row, col)),
                    ),
                  ],
                ),
            ],
          ),
        ),
      );

  /// True when the highlighted column carries a positive amount.
  bool _owing(Map<String, dynamic> row) {
    final key = widget.highlightPositiveKey;
    if (key == null) return false;
    final v = row[key];
    final n = v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    return n > 0;
  }
}
