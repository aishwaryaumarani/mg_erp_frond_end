import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/projection_charts.dart';
import '../widgets/status_badge.dart';

/// Sales Projection dashboard.
///
///     Projected Sales = Actual Sales + Confirmed Orders + Weighted Open Quotations
///
/// Every figure comes from the server (backend/app/routers/
/// sales_projection.py), including the *columns* of each table: the seven
/// breakdowns below all render through one table widget from the
/// `columns` the endpoint declares, so the screen, the Excel export and
/// the PDF cannot disagree about what a report shows.
///
/// The seven reports are fetched together on each refresh rather than one
/// per tab, because the charts across the top read from several of them
/// at once -- switching tabs then costs nothing.
class SalesProjectionScreen extends StatefulWidget {
  const SalesProjectionScreen({super.key});

  @override
  State<SalesProjectionScreen> createState() => _SalesProjectionScreenState();
}

/// One breakdown: its tab, the endpoint behind it and the chart, if any,
/// that reads from it.
class _Tab {
  final String key; // also the /export/{report} name
  final String label;
  final IconData icon;
  const _Tab(this.key, this.label, this.icon);
}

const List<_Tab> _tabs = [
  _Tab('summary', 'Summary', Icons.dashboard_outlined),
  _Tab('monthly', 'Monthly', Icons.calendar_month_outlined),
  _Tab('quarterly', 'Quarterly', Icons.calendar_view_month_outlined),
  _Tab('salesperson', 'Salesperson', Icons.person_outline),
  _Tab('product', 'Product', Icons.inventory_2_outlined),
  _Tab('category', 'Category', Icons.category_outlined),
  _Tab('pipeline', 'Pipeline', Icons.filter_alt_outlined),
];

class _SalesProjectionScreenState extends State<SalesProjectionScreen> {
  /// report key -> the {period, columns, rows, summary} envelope it returned.
  final Map<String, Map<String, dynamic>> _reports = {};
  Map<String, dynamic> _options = {};

  bool _loading = true;
  bool _exporting = false;
  String? _error;
  String _tab = 'summary';

  // --- the period being looked at ---------------------------------------
  String? _financialYear;
  String _periodKind = 'year'; // year | month | quarter | range
  int? _month;
  String? _quarter;
  DateTimeRange? _range;

  // --- slices ------------------------------------------------------------
  int? _salespersonId;
  int? _customerId;
  int? _productId;
  int? _categoryId;
  String? _region;
  int? _warehouseId;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      final options = await ApiService.instance.getOne('/api/sales-projection/filters');
      setState(() {
        _options = options;
        _financialYear = '${options['current_financial_year']}';
      });
    } catch (e) {
      setState(() {
        _error = e is ApiException ? e.message : e.toString();
        _loading = false;
      });
      return;
    }
    await _load();
  }

  Map<String, dynamic> get _query {
    String? ymd(DateTime? d) => d?.toIso8601String().substring(0, 10);
    return {
      'financial_year': _financialYear,
      if (_periodKind == 'month') 'month': _month,
      if (_periodKind == 'quarter') 'quarter': _quarter,
      if (_periodKind == 'range' && _range != null) 'date_from': ymd(_range!.start),
      if (_periodKind == 'range' && _range != null) 'date_to': ymd(_range!.end),
      'salesperson_id': _salespersonId,
      'customer_id': _customerId,
      'product_id': _productId,
      'category_id': _categoryId,
      'region': _region,
      'warehouse_id': _warehouseId,
    };
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final query = _query;
      final results = await Future.wait([
        for (final tab in _tabs)
          ApiService.instance.getOne('/api/sales-projection/${tab.key}', query: query),
      ]);
      setState(() {
        for (var i = 0; i < _tabs.length; i++) {
          _reports[_tabs[i].key] = results[i];
        }
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e is ApiException ? e.message : e.toString();
        _loading = false;
      });
    }
  }

  // --- helpers -----------------------------------------------------------

  Map<String, dynamic>? get _summary => _reports['summary'];

  List<Map<String, dynamic>> _rows(String report) =>
      ((_reports[report]?['rows'] as List<dynamic>?) ?? [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();

  List<Map<String, dynamic>> _columns(String report) =>
      ((_reports[report]?['columns'] as List<dynamic>?) ?? [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();

  static double _num(Object? v) =>
      v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

  List<ProjectionPoint> _points(String report) =>
      _rows(report).map(ProjectionPoint.fromRow).toList();

  int get _activeFilterCount => [
        _salespersonId,
        _customerId,
        _productId,
        _categoryId,
        _region,
        _warehouseId,
      ].where((f) => f != null).length;

  // --- build -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_error != null && _reports.isEmpty) return _errorBox();

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _toolbar(),
            const SizedBox(height: 14),
            _periodBar(),
            if (_activeFilterCount > 0) ...[
              const SizedBox(height: 10),
              _activeFilterChips(),
            ],
            const SizedBox(height: 18),
            if (_loading && _reports.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              if (_error != null) ...[_errorBanner(), const SizedBox(height: 14)],
              _summaryCards(),
              const SizedBox(height: 18),
              _standingPeriods(),
              const SizedBox(height: 18),
              _charts(),
              const SizedBox(height: 18),
              _breakdown(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _toolbar() => Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 10,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Sales Projection',
                  style: AppText.serif(fontSize: 22, color: AppColors.ink)),
              Text(
                _summary?['period']?['label'] == null
                    ? 'Actual sales + confirmed orders + weighted pipeline'
                    : '${_summary!['period']['label']}  ·  '
                        'actual + confirmed orders + weighted pipeline',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _openFilters,
                icon: const Icon(Icons.tune, size: 18),
                label: Text(_activeFilterCount == 0
                    ? 'Filters'
                    : 'Filters ($_activeFilterCount)'),
              ),
              OutlinedButton.icon(
                onPressed: _openTargets,
                icon: const Icon(Icons.flag_outlined, size: 18),
                label: const Text('Targets'),
              ),
              _exportButton(),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _loading ? null : _load,
                icon: _loading
                    ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh),
              ),
            ],
          ),
        ],
      );

  Widget _exportButton() => PopupMenuButton<String>(
        enabled: !_exporting && !_loading,
        tooltip: 'Export this view',
        onSelected: (choice) {
          final parts = choice.split(':');
          _export(parts[0], parts[1]);
        },
        itemBuilder: (context) => [
          for (final report in _tabs)
            PopupMenuItem(
              value: '${report.key}:xlsx',
              child: Text('${report.label} — Excel'),
            ),
          const PopupMenuDivider(),
          for (final report in _tabs)
            PopupMenuItem(
              value: '${report.key}:pdf',
              child: Text('${report.label} — PDF'),
            ),
        ],
        child: OutlinedButton.icon(
          // The button is decorative here: the PopupMenuButton around it
          // takes the tap, so onPressed must stay null or it would eat it.
          onPressed: null,
          icon: _exporting
              ? const SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.download_outlined, size: 18),
          label: const Text('Export'),
        ),
      );

  // --- period ------------------------------------------------------------

  Widget _periodBar() {
    final years = ((_options['financial_years'] as List<dynamic>?) ?? [])
        .map((e) => '$e')
        .toList();
    final months = ((_options['months'] as List<dynamic>?) ?? [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
    final quarters = ((_options['quarters'] as List<dynamic>?) ?? [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (years.isNotEmpty)
          _shelf(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: years.contains(_financialYear) ? _financialYear : years.first,
                isDense: true,
                items: [
                  for (final year in years)
                    DropdownMenuItem(value: year, child: Text('FY $year')),
                ],
                onChanged: (value) {
                  setState(() => _financialYear = value);
                  _load();
                },
              ),
            ),
          ),
        SegmentedButton<String>(
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: const [
            ButtonSegment(value: 'year', label: Text('Year')),
            ButtonSegment(value: 'quarter', label: Text('Quarter')),
            ButtonSegment(value: 'month', label: Text('Month')),
            ButtonSegment(value: 'range', label: Text('Range')),
          ],
          selected: {_periodKind},
          onSelectionChanged: (choice) => _pickPeriodKind(choice.first, months, quarters),
        ),
        if (_periodKind == 'month' && months.isNotEmpty)
          _shelf(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _month,
                isDense: true,
                items: [
                  for (final month in months)
                    DropdownMenuItem(
                        value: month['value'] as int, child: Text('${month['label']}')),
                ],
                onChanged: (value) {
                  setState(() => _month = value);
                  _load();
                },
              ),
            ),
          ),
        if (_periodKind == 'quarter' && quarters.isNotEmpty)
          _shelf(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _quarter,
                isDense: true,
                items: [
                  for (final quarter in quarters)
                    DropdownMenuItem(
                        value: '${quarter['value']}', child: Text('${quarter['label']}')),
                ],
                onChanged: (value) {
                  setState(() => _quarter = value);
                  _load();
                },
              ),
            ),
          ),
        if (_periodKind == 'range')
          OutlinedButton.icon(
            onPressed: _pickRange,
            icon: const Icon(Icons.date_range_outlined, size: 18),
            label: Text(_range == null
                ? 'Pick dates'
                : '${_ymd(_range!.start)}  to  ${_ymd(_range!.end)}'),
          ),
      ],
    );
  }

  void _pickPeriodKind(String kind, List<Map<String, dynamic>> months,
      List<Map<String, dynamic>> quarters) {
    setState(() {
      _periodKind = kind;
      // Default each mode to something real, so switching to it never
      // shows an empty control or an unchanged page.
      if (kind == 'month' && _month == null && months.isNotEmpty) {
        _month = DateTime.now().month;
      }
      if (kind == 'quarter' && _quarter == null && quarters.isNotEmpty) {
        _quarter = '${quarters.first['value']}';
      }
    });
    if (kind == 'range' && _range == null) {
      _pickRange();
      return;
    }
    _load();
  }

  static String _ymd(DateTime d) => d.toIso8601String().substring(0, 10);

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      initialDateRange: _range,
    );
    if (picked == null) {
      if (_range == null) setState(() => _periodKind = 'year');
      return;
    }
    setState(() => _range = picked);
    _load();
  }

  Widget _shelf({required Widget child}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(8),
        ),
        child: child,
      );

  // --- summary cards -----------------------------------------------------

  static const List<({String key, IconData icon, Color color, bool money})> _cardSpecs = [
    (key: 'Total target', icon: Icons.flag_outlined, color: AppColors.brand, money: true),
    (key: 'Actual sales', icon: Icons.receipt_long_outlined, color: kActualColor, money: true),
    (key: 'Confirmed orders', icon: Icons.assignment_turned_in_outlined, color: kOrderColor, money: true),
    (key: 'Open pipeline', icon: Icons.request_quote_outlined, color: AppColors.violet, money: true),
    (key: 'Weighted pipeline', icon: Icons.balance_outlined, color: kPipelineColor, money: true),
    (key: 'Projected sales', icon: Icons.trending_up, color: AppColors.teal, money: true),
    (key: 'Target achievement', icon: Icons.speed_outlined, color: AppColors.green, money: false),
    (key: 'Target gap', icon: Icons.trending_down, color: AppColors.amber, money: true),
  ];

  Widget _summaryCards() {
    final figures = ((_summary?['summary'] as Map?) ?? {}).cast<String, dynamic>();
    if (figures.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        // Tiles fill the row rather than sitting at a fixed width: on a
        // phone that means one full-width card instead of a narrow one
        // with dead space beside it, and on a desktop it lines the two
        // rows of four up in a grid instead of leaving a ragged tail.
        const gap = 12.0;
        final columns = (constraints.maxWidth / 224).floor().clamp(1, 4);
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final spec in _cardSpecs)
              _card(
                label: spec.key,
                value: figures[spec.key],
                icon: spec.icon,
                accent: _cardAccent(spec, figures),
                money: spec.money,
                width: width,
              ),
          ],
        );
      },
    );
  }

  /// A gap and an achievement figure carry their own verdict, so they take
  /// their colour from the number rather than from the tile's slot.
  Color _cardAccent(({String key, IconData icon, Color color, bool money}) spec,
      Map<String, dynamic> figures) {
    if (spec.key == 'Target gap') {
      final gap = figures['Target gap'];
      if (gap == null) return spec.color;
      return _num(gap) <= 0 ? AppColors.green : AppColors.rose;
    }
    if (spec.key == 'Target achievement') {
      final percent = figures['Target achievement'];
      if (percent == null) return AppColors.muted;
      final value = _num(percent);
      return value >= 100 ? AppColors.green : (value >= 80 ? AppColors.amber : AppColors.rose);
    }
    return spec.color;
  }

  Widget _card({
    required String label,
    required Object? value,
    required IconData icon,
    required Color accent,
    required bool money,
    required double width,
  }) {
    final text = value == null
        ? '--'
        : money
            ? shortMoney(_num(value))
            : '${_num(value).toStringAsFixed(0)}%';
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: accent),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 10.5,
                          letterSpacing: 0.4,
                          color: AppColors.muted,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800, color: accent)),
            if (value != null && money)
              Text('₹${_num(value).toStringAsFixed(2)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.5, color: AppColors.faint)),
          ],
        ),
      ),
    );
  }

  // --- current month / quarter / year -----------------------------------

  Widget _standingPeriods() {
    final blocks = [
      for (final key in ['current_month', 'current_quarter', 'current_year'])
        if (_summary?[key] != null) (_summary![key] as Map).cast<String, dynamic>(),
    ];
    if (blocks.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxWidth >= 820;
        final cards = [
          for (final block in blocks) _standingCard(block),
        ];
        if (!side) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                cards[i],
              ],
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: cards[i]),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _standingCard(Map<String, dynamic> block) {
    final target = _num(block['target']);
    final projected = _num(block['projected']);
    final ratio = target > 0 ? projected / target : null;
    final color = ratio == null
        ? AppColors.muted
        : (ratio >= 1 ? AppColors.green : (ratio >= 0.8 ? AppColors.amber : AppColors.rose));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${block['label']}'.toUpperCase(),
                style: const TextStyle(
                    fontSize: 10.5,
                    letterSpacing: 0.4,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(shortMoney(projected),
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink)),
                const SizedBox(width: 8),
                if (ratio != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('${(ratio * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w800, color: color)),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              target > 0
                  ? 'against a target of ${shortMoney(target)}'
                  : 'no target set for this period',
              style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            _miniSplit('Actual', _num(block['actual']), kActualColor),
            _miniSplit('Confirmed orders', _num(block['confirmed_orders']), kOrderColor),
            _miniSplit('Weighted pipeline', _num(block['weighted_quotations']), kPipelineColor),
          ],
        ),
      ),
    );
  }

  Widget _miniSplit(String label, double value, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(label,
                  style: const TextStyle(fontSize: 11.5, color: AppColors.slate)),
            ),
            Text(shortMoney(value),
                style: const TextStyle(
                    fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
          ],
        ),
      );

  // --- charts ------------------------------------------------------------

  Widget _charts() {
    final monthly = _points('monthly');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChartCard(
          title: 'Monthly actual vs target vs projection',
          hint: 'Each bar stacks what is invoiced, ordered and weighted-pipeline; '
              'the thin bar beside it is the target. Tap a month to drill in.',
          child: ProjectionBars(
            points: monthly,
            onTap: (point) => _openDrillDownChooser(point.label),
          ),
        ),
        const SizedBox(height: 16),
        ChartGrid(children: [
          ChartCard(
            title: 'Monthly sales trend — projected vs actual',
            hint: 'Where the projection runs above actual, the gap is order book and pipeline.',
            child: TrendLine(points: monthly),
          ),
          ChartCard(
            title: 'Sales target achievement',
            hint: 'Projection as a share of each month\'s target.',
            child: AchievementBars(points: monthly),
          ),
        ]),
        const SizedBox(height: 16),
        ChartGrid(children: [
          ChartCard(
            title: 'Salesperson-wise projection',
            hint: 'Tap a name to see the documents behind it.',
            child: MagnitudeBars(
              slices: [
                for (final row in _rows('salesperson'))
                  MagnitudeSlice(
                    '${row['salesperson']}',
                    _num(row['projected']),
                    note: _num(row['target']) > 0
                        ? 'target ${shortMoney(_num(row['target']))}'
                        : null,
                  ),
              ],
              emptyMessage: 'No sales, orders or quotations in this period.',
              onTap: (slice) => _openDrillDownChooser(slice.label),
            ),
          ),
          ChartCard(
            title: 'Category-wise projection',
            hint: 'Product totals rolled up. The Product tab has the per-item detail.',
            child: MagnitudeBars(
              slices: [
                for (final row in _rows('category'))
                  MagnitudeSlice(
                    '${row['category']}',
                    _num(row['projected']),
                    note: 'actual ${shortMoney(_num(row['actual']))}',
                  ),
              ],
              emptyMessage: 'No line items in this period.',
            ),
          ),
        ]),
        const SizedBox(height: 16),
        ChartGrid(children: [
          ChartCard(
            title: 'Quotation pipeline by probability',
            hint: 'Only the weighted part of each band reaches the projection.',
            child: PipelineByProbability(rows: _rows('pipeline')),
          ),
          ChartCard(
            title: 'Product-wise projection',
            hint: 'Top products by projected value.',
            child: MagnitudeBars(
              slices: [
                for (final row in _rows('product'))
                  MagnitudeSlice(
                    '${row['product']}',
                    _num(row['projected']),
                    note: '${row['category']}',
                  ),
              ],
              emptyMessage: 'No line items in this period.',
            ),
          ),
        ]),
      ],
    );
  }

  // --- the breakdown tables ----------------------------------------------

  Widget _breakdown() {
    final report = _reports[_tab];
    final columns = _columns(_tab);
    final rows = _rows(_tab);

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final tab in _tabs)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: Icon(tab.icon,
                            size: 16,
                            color: _tab == tab.key ? AppColors.brand : AppColors.muted),
                        label: Text(tab.label),
                        selected: _tab == tab.key,
                        onSelected: (_) => setState(() => _tab = tab.key),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const Divider(height: 22),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text('${report?['title'] ?? ''}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                          fontSize: 13.5)),
                ),
                TextButton.icon(
                  onPressed: _exporting ? null : () => _export(_tab, 'xlsx'),
                  icon: const Icon(Icons.table_view_outlined, size: 17),
                  label: const Text('Excel'),
                ),
                TextButton.icon(
                  onPressed: _exporting ? null : () => _export(_tab, 'pdf'),
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 17),
                  label: const Text('PDF'),
                ),
              ],
            ),
          ),
          if (_tab == 'summary') _drillDownButtons(),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 42),
              child: Center(
                child: Text('Nothing to report for this period.',
                    style: TextStyle(color: AppColors.muted)),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: _table(columns, rows),
            ),
          if (report?['summary'] != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
              child: _totalsStrip((report!['summary'] as Map).cast<String, dynamic>()),
            ),
        ],
      ),
    );
  }

  Widget _drillDownButtons() => Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 8, right: 4),
              child: Text('Drill down to:',
                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
            ),
            for (final source in const [
              ('actual', 'Invoices', Icons.description_outlined),
              ('order', 'Orders', Icons.receipt_long_outlined),
              ('quotation', 'Quotations', Icons.request_quote_outlined),
            ])
              OutlinedButton.icon(
                onPressed: () => _openDrillDown(source.$1),
                icon: Icon(source.$3, size: 16),
                label: Text(source.$2),
              ),
          ],
        ),
      );

  Widget _table(List<Map<String, dynamic>> columns, List<Map<String, dynamic>> rows) {
    bool numeric(Map<String, dynamic> c) =>
        c['money'] == true || c['numeric'] == true || c['percent'] == true;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 22,
        headingRowHeight: 42,
        dataRowMinHeight: 40,
        dataRowMaxHeight: 46,
        headingTextStyle: const TextStyle(
            fontWeight: FontWeight.w800, color: AppColors.ink, fontSize: 12.5),
        columns: [
          for (final column in columns)
            DataColumn(label: Text('${column['label']}'), numeric: numeric(column)),
        ],
        rows: [
          for (final row in rows)
            DataRow(
              cells: [
                for (final column in columns)
                  DataCell(_cell(row, column)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _cell(Map<String, dynamic> row, Map<String, dynamic> column) {
    final key = '${column['key']}';
    final value = row[key];
    if (key == 'status') return StatusBadge(status: '$value');
    if (value == null) {
      return const Text('--', style: TextStyle(color: AppColors.faint));
    }
    if (column['percent'] == true) {
      // Achievement colours the number, because "130%" and "40%" mean very
      // different things and the table is where they are compared.
      final percent = _num(value);
      final colour = key.contains('achievement')
          ? (percent >= 100
              ? AppColors.green
              : (percent >= 80 ? AppColors.amber : AppColors.rose))
          : AppColors.ink;
      return Text('${percent.toStringAsFixed(1)}%',
          style: TextStyle(color: colour, fontWeight: FontWeight.w700, fontSize: 12.5));
    }
    if (column['money'] == true) {
      final amount = _num(value);
      final isGap = key == 'gap' || key == 'actual_gap';
      return Tooltip(
        message: '₹${amount.toStringAsFixed(2)}',
        child: Text(shortMoney(amount),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: isGap
                  ? (amount <= 0 ? AppColors.green : AppColors.rose)
                  : AppColors.ink,
            )),
      );
    }
    if (column['numeric'] == true) {
      return Text(shortNumber(_num(value)), style: const TextStyle(fontSize: 12.5));
    }
    return Text('$value', style: const TextStyle(fontSize: 12.5));
  }

  Widget _totalsStrip(Map<String, dynamic> summary) => Wrap(
        spacing: 20,
        runSpacing: 8,
        children: [
          for (final entry in summary.entries)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${entry.key}: ',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                Text(
                  formatSummaryValue(entry.key, entry.value),
                  style: const TextStyle(
                      fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.ink),
                ),
              ],
            ),
        ],
      );

  // --- drill-down ---------------------------------------------------------

  void _openDrillDownChooser(String what) {
    showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Drill into $what'),
        children: [
          for (final source in const [
            ('actual', 'Invoices behind the actual sales'),
            ('order', 'Confirmed orders not yet invoiced'),
            ('quotation', 'Open quotations in the pipeline'),
          ])
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(ctx);
                _openDrillDown(source.$1);
              },
              child: Text(source.$2),
            ),
        ],
      ),
    );
  }

  /// Lists the documents behind a figure, under exactly the filters the
  /// dashboard is showing -- so the total in the dialog is the total on
  /// the card.
  Future<void> _openDrillDown(String source) async {
    // Read the shell's navigation here, not inside the dialog: a dialog is
    // pushed on the root Navigator, whose context sits *above* the
    // AppShell that provides AppShellNav, so looking it up in there always
    // finds nothing and the "open the documents" link never appears.
    final nav = AppShellNav.maybeOf(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => _DrillDownDialog(
        source: source,
        query: {..._query, 'source': source},
        nav: nav,
      ),
    );
  }

  // --- filters ------------------------------------------------------------

  Widget _activeFilterChips() {
    List<Map<String, dynamic>> options(String key) =>
        ((_options[key] as List<dynamic>?) ?? [])
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList();

    String nameOf(String key, int? id) {
      final match = options(key).where((o) => o['id'] == id);
      return match.isEmpty ? '#$id' : '${match.first['name']}';
    }

    final chips = <(String, VoidCallback)>[
      if (_salespersonId != null)
        ('Salesperson: ${nameOf('salespeople', _salespersonId)}',
            () => setState(() => _salespersonId = null)),
      if (_customerId != null)
        ('Customer: ${nameOf('customers', _customerId)}',
            () => setState(() => _customerId = null)),
      if (_productId != null)
        ('Product: ${nameOf('products', _productId)}', () => setState(() => _productId = null)),
      if (_categoryId != null)
        ('Category: ${nameOf('categories', _categoryId)}',
            () => setState(() => _categoryId = null)),
      if (_region != null) ('Region: $_region', () => setState(() => _region = null)),
      if (_warehouseId != null)
        ('Branch: ${nameOf('warehouses', _warehouseId)}',
            () => setState(() => _warehouseId = null)),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final chip in chips)
          InputChip(
            label: Text(chip.$1, style: const TextStyle(fontSize: 11.5)),
            onDeleted: () {
              chip.$2();
              _load();
            },
          ),
        TextButton(
          onPressed: () {
            setState(() {
              _salespersonId = null;
              _customerId = null;
              _productId = null;
              _categoryId = null;
              _region = null;
              _warehouseId = null;
            });
            _load();
          },
          child: const Text('Clear all'),
        ),
      ],
    );
  }

  Future<void> _openFilters() async {
    final applied = await showDialog<bool>(
      context: context,
      builder: (ctx) => _FilterDialog(
        options: _options,
        salespersonId: _salespersonId,
        customerId: _customerId,
        productId: _productId,
        categoryId: _categoryId,
        region: _region,
        warehouseId: _warehouseId,
        onApply: (values) => setState(() {
          _salespersonId = values.salespersonId;
          _customerId = values.customerId;
          _productId = values.productId;
          _categoryId = values.categoryId;
          _region = values.region;
          _warehouseId = values.warehouseId;
        }),
      ),
    );
    if (applied == true) _load();
  }

  // --- targets ------------------------------------------------------------

  Future<void> _openTargets() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => _TargetsDialog(
        financialYear: _financialYear ?? '',
        salespeople: ((_options['salespeople'] as List<dynamic>?) ?? [])
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList(),
      ),
    );
    if (saved == true) _load();
  }

  // --- export -------------------------------------------------------------

  Future<void> _export(String report, String format) async {
    setState(() => _exporting = true);
    try {
      await ApiService.instance.download(
        '/api/sales-projection/export/$report',
        query: {..._query, 'format': format},
        fallbackName: 'sales-projection-$report.$format',
        mimeType: format == 'pdf'
            ? 'application/pdf'
            : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is ApiException ? e.message : '$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // --- errors -------------------------------------------------------------

  Widget _errorBanner() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.rose.withValues(alpha: 0.08),
          border: Border.all(color: AppColors.rose.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.rose, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.rose))),
            TextButton(onPressed: _load, child: const Text('Try again')),
          ],
        ),
      );

  Widget _errorBox() => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.rose, size: 32),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.rose)),
              const SizedBox(height: 14),
              FilledButton(onPressed: _boot, child: const Text('Try again')),
            ],
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Drill-down
// ---------------------------------------------------------------------------

class _DrillDownDialog extends StatefulWidget {
  final String source;
  final Map<String, dynamic> query;

  /// The shell's navigation, handed down from the screen -- see
  /// _openDrillDown for why it cannot be looked up in here.
  final AppShellNav? nav;

  const _DrillDownDialog({required this.source, required this.query, this.nav});

  @override
  State<_DrillDownDialog> createState() => _DrillDownDialogState();
}

class _DrillDownDialogState extends State<_DrillDownDialog> {
  Map<String, dynamic>? _data;
  String? _error;

  static const Map<String, (String, String)> _destinations = {
    'actual': ('Sales', 'Sales Invoices'),
    'order': ('Sales', 'Sales Orders'),
    'quotation': ('Sales', 'Quotations / Proforma'),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.instance
          .getOne('/api/sales-projection/drill-down', query: widget.query);
      setState(() => _data = data);
    } catch (e) {
      setState(() => _error = e is ApiException ? e.message : e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = ((_data?['rows'] as List<dynamic>?) ?? [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
    final columns = ((_data?['columns'] as List<dynamic>?) ?? [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
    final destination = _destinations[widget.source];
    final nav = widget.nav;
    final canOpen = destination != null && (nav?.has(destination.$1, destination.$2) ?? false);

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${_data?['title'] ?? 'Documents'}',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink)),
                        Text('${_data?['period']?['label'] ?? ''}',
                            style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                      ],
                    ),
                  ),
                  if (canOpen)
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        nav!.goTo(destination.$1, destination.$2);
                      },
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: Text('Open ${destination.$2}'),
                    ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(height: 20),
              Flexible(
                child: _error != null
                    ? Center(
                        child: Text(_error!, style: const TextStyle(color: AppColors.rose)))
                    : _data == null
                        ? const Center(child: Padding(
                            padding: EdgeInsets.all(40),
                            child: CircularProgressIndicator()))
                        : rows.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(40),
                                  child: Text('No documents behind this figure.',
                                      style: TextStyle(color: AppColors.muted)),
                                ),
                              )
                            : SingleChildScrollView(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    columnSpacing: 22,
                                    columns: [
                                      for (final column in columns)
                                        DataColumn(
                                          label: Text('${column['label']}'),
                                          numeric: column['money'] == true ||
                                              column['numeric'] == true ||
                                              column['percent'] == true,
                                        ),
                                    ],
                                    rows: [
                                      for (final row in rows)
                                        DataRow(cells: [
                                          for (final column in columns)
                                            DataCell(_cell(row, column)),
                                        ]),
                                    ],
                                  ),
                                ),
                              ),
              ),
              if (_data?['summary'] != null) ...[
                const Divider(height: 20),
                Wrap(
                  spacing: 20,
                  runSpacing: 6,
                  children: [
                    for (final entry
                        in (_data!['summary'] as Map).cast<String, dynamic>().entries)
                      Text(
                        '${entry.key}: ${formatSummaryValue(entry.key, entry.value)}',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _cell(Map<String, dynamic> row, Map<String, dynamic> column) {
    final key = '${column['key']}';
    final value = row[key];
    if (key == 'status') return StatusBadge(status: '$value');
    if (value == null) return const Text('--', style: TextStyle(color: AppColors.faint));
    final number = value is num ? value.toDouble() : double.tryParse('$value');
    if (column['percent'] == true && number != null) {
      return Text('${number.toStringAsFixed(0)}%');
    }
    if (column['money'] == true && number != null) {
      return Tooltip(
        message: '₹${number.toStringAsFixed(2)}',
        child: Text(shortMoney(number),
            style: const TextStyle(fontWeight: FontWeight.w600)),
      );
    }
    return Text('$value');
  }
}

// ---------------------------------------------------------------------------
// Filters
// ---------------------------------------------------------------------------

typedef _FilterValues = ({
  int? salespersonId,
  int? customerId,
  int? productId,
  int? categoryId,
  String? region,
  int? warehouseId,
});

class _FilterDialog extends StatefulWidget {
  final Map<String, dynamic> options;
  final int? salespersonId;
  final int? customerId;
  final int? productId;
  final int? categoryId;
  final String? region;
  final int? warehouseId;
  final void Function(_FilterValues values) onApply;

  const _FilterDialog({
    required this.options,
    required this.salespersonId,
    required this.customerId,
    required this.productId,
    required this.categoryId,
    required this.region,
    required this.warehouseId,
    required this.onApply,
  });

  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
  late int? _salespersonId = widget.salespersonId;
  late int? _customerId = widget.customerId;
  late int? _productId = widget.productId;
  late int? _categoryId = widget.categoryId;
  late String? _region = widget.region;
  late int? _warehouseId = widget.warehouseId;

  List<Map<String, dynamic>> _list(String key) =>
      ((widget.options[key] as List<dynamic>?) ?? [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Filter the projection'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _idField('Salesperson', 'salespeople', _salespersonId,
                    (v) => setState(() => _salespersonId = v)),
                _idField('Customer', 'customers', _customerId,
                    (v) => setState(() => _customerId = v)),
                _idField('Product', 'products', _productId,
                    (v) => setState(() => _productId = v),
                    helper: 'Product and category slices are built from line items, '
                        'so they carry no share of freight or other document charges.'),
                _idField('Category', 'categories', _categoryId,
                    (v) => setState(() => _categoryId = v)),
                _regionField(),
                _idField('Branch / store', 'warehouses', _warehouseId,
                    (v) => setState(() => _warehouseId = v)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              widget.onApply((
                salespersonId: null,
                customerId: null,
                productId: null,
                categoryId: null,
                region: null,
                warehouseId: null,
              ));
              Navigator.pop(context, true);
            },
            child: const Text('Clear all'),
          ),
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              widget.onApply((
                salespersonId: _salespersonId,
                customerId: _customerId,
                productId: _productId,
                categoryId: _categoryId,
                region: _region,
                warehouseId: _warehouseId,
              ));
              Navigator.pop(context, true);
            },
            child: const Text('Apply'),
          ),
        ],
      );

  Widget _idField(String label, String key, int? value, ValueChanged<int?> onChanged,
      {String? helper}) {
    final options = _list(key);
    if (options.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: DropdownButtonFormField<int?>(
        initialValue: options.any((o) => o['id'] == value) ? value : null,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, helperText: helper, helperMaxLines: 3),
        items: [
          const DropdownMenuItem<int?>(value: null, child: Text('All')),
          for (final option in options)
            DropdownMenuItem<int?>(
              value: option['id'] as int,
              child: Text(
                option['code'] == null
                    ? '${option['name']}'
                    : '${option['name']} (${option['code']})',
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }

  Widget _regionField() {
    final regions =
        ((widget.options['regions'] as List<dynamic>?) ?? []).map((e) => '$e').toList();
    if (regions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: DropdownButtonFormField<String?>(
        initialValue: regions.contains(_region) ? _region : null,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Region',
          helperText: "The customer's state -- this ERP's geography",
        ),
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('All')),
          for (final region in regions)
            DropdownMenuItem<String?>(value: region, child: Text(region)),
        ],
        onChanged: (value) => setState(() => _region = value),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Targets
// ---------------------------------------------------------------------------

/// A financial year's twelve monthly targets, set in one save.
///
/// Company-wide by default; picking a salesperson edits their own
/// apportionment instead. Where both exist the company figure is the
/// total and the per-person rows divide it up -- adding them together
/// would count the same money twice (backend/app/core/projection.py).
class _TargetsDialog extends StatefulWidget {
  final String financialYear;
  final List<Map<String, dynamic>> salespeople;

  const _TargetsDialog({required this.financialYear, required this.salespeople});

  @override
  State<_TargetsDialog> createState() => _TargetsDialogState();
}

class _TargetsDialogState extends State<_TargetsDialog> {
  final Map<int, TextEditingController> _controllers = {};
  List<Map<String, dynamic>> _rows = [];
  int? _salespersonId;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.instance.getOne(
        '/api/sales-projection/targets/grid',
        query: {
          'financial_year': widget.financialYear,
          if (_salespersonId != null) 'salesperson_id': _salespersonId,
        },
      );
      final rows = ((data['rows'] as List<dynamic>?) ?? [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
      for (final row in rows) {
        final month = row['month'] as int;
        final amount = (row['target_amount'] as num?)?.toDouble() ?? 0;
        _controllers
            .putIfAbsent(month, () => TextEditingController())
            .text = amount == 0 ? '' : amount.toStringAsFixed(0);
      }
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e is ApiException ? e.message : e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ApiService.instance.update('/api/sales-projection/targets/bulk', {
        'financial_year': widget.financialYear,
        'salesperson_id': _salespersonId,
        'months': {
          for (final entry in _controllers.entries)
            '${entry.key}': double.tryParse(entry.value.text.trim()) ?? 0,
        },
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _error = e is ApiException ? e.message : e.toString();
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Sales targets — FY ${widget.financialYear}'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.salespeople.isNotEmpty)
                DropdownButtonFormField<int?>(
                  initialValue: _salespersonId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Whose target',
                    helperText: 'Per-person targets divide the company figure up; '
                        'they are not extra targets on top of it.',
                    helperMaxLines: 3,
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                        value: null, child: Text('Company-wide')),
                    for (final person in widget.salespeople)
                      DropdownMenuItem<int?>(
                          value: person['id'] as int, child: Text('${person['name']}')),
                  ],
                  onChanged: (value) {
                    setState(() => _salespersonId = value);
                    _load();
                  },
                ),
              const SizedBox(height: 12),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(_error!, style: const TextStyle(color: AppColors.rose)),
                ),
              Flexible(
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(30),
                        child: Center(child: CircularProgressIndicator()))
                    : SingleChildScrollView(
                        child: Column(
                          children: [
                            for (final row in _rows)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 5),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 130,
                                      child: Text('${row['label']}',
                                          style: const TextStyle(
                                              fontSize: 12.5, color: AppColors.slate)),
                                    ),
                                    Expanded(
                                      child: TextField(
                                        controller: _controllers[row['month'] as int],
                                        keyboardType:
                                            const TextInputType.numberWithOptions(decimal: true),
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          prefixText: '₹ ',
                                          hintText: '0',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _saving || _loading ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save targets'),
          ),
        ],
      );
}
