import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/brand_logo.dart';

/// Dashboard (spec sec. 13).
///
/// Which sections appear is the *server's* answer, not this file's:
/// /api/dashboard/summary computes only the departments the signed-in
/// user was granted and names them in `sections`
/// (backend/app/routers/dashboard.py). Rendering from that list rather
/// than from a second copy of the permission rules here is what keeps
/// the two from drifting -- and means a section this user may not open
/// is absent rather than showing a misleading zero.
class DashboardScreen extends StatefulWidget {
  /// Skips the fetch and renders this summary instead. Only for widget
  /// tests -- the app always reads the real endpoint.
  @visibleForTesting
  final Map<String, dynamic>? initialSummary;

  const DashboardScreen({super.key, this.initialSummary});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

/// One KPI tile, described rather than built, so the section that owns it
/// can hand down its own accent colour.
class _Kpi {
  final String label;
  final dynamic value;
  final IconData icon;

  /// Overrides the section accent -- used where the number itself carries
  /// a warning (low stock, overdue) rather than just a count.
  final Color? color;

  /// Formats the value as rupees instead of a plain count.
  final bool money;

  /// The (sidebar group, sidebar leaf) pair this tile opens on tap.
  final (String, String)? to;

  const _Kpi(
    this.label,
    this.value,
    this.icon, {
    this.color,
    this.money = false,
    this.to,
  });
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _summary;
  String? _error;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialSummary != null) {
      _summary = widget.initialSummary;
      return;
    }
    _load();
  }

  Future<void> _load() async {
    setState(() => _refreshing = true);
    try {
      final data = await ApiService.instance.getOne('/api/dashboard/summary');
      if (!mounted) return;
      setState(() {
        _summary = data;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return _errorState();
    if (_summary == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final s = _summary!;
    // Older builds of the API sent every key and no `sections`; treat
    // that as "show everything" so a mismatched pair still renders.
    final sections =
        ((s['sections'] as List<dynamic>?)?.cast<String>().toSet()) ??
            const {
              'masters',
              'sales',
              'purchase',
              'inventory',
              'tasks',
              'accounts'
            };

    return LayoutBuilder(builder: (context, constraints) {
      // Phone widths get back the page gutter the desktop layout can
      // afford to spend -- at 420px a 28px margin costs a seventh of the
      // row the tiles have to share.
      final narrow = constraints.maxWidth < 560;
      final pad = narrow ? 16.0 : 28.0;
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.fromLTRB(pad, narrow ? 18 : 26, pad, 36),
          children: [
            _hero(narrow),
            const SizedBox(height: 26),
            if (sections.isEmpty) _noSections(),
            if (sections.contains('masters'))
              _section('Masters', 'Reference data every document draws on', [
                _Kpi('Total Products', s['total_products'],
                    Icons.inventory_2_outlined,
                    to: ('Masters', 'Products')),
                _Kpi('Categories', s['total_categories'],
                    Icons.category_outlined,
                    to: ('Masters', 'Categories')),
                _Kpi('Customers', s['total_customers'], Icons.people_outline,
                    to: ('Masters', 'Customers')),
                _Kpi('Suppliers', s['total_suppliers'],
                    Icons.local_shipping_outlined,
                    to: ('Masters', 'Suppliers')),
              ]),
            if (sections.contains('sales'))
              _section('Sales', 'Orders raised, delivered and collected', [
                _Kpi("Today's Sales", s['todays_sales'],
                    Icons.point_of_sale_outlined,
                    money: true, to: ('Sales', 'Sales Invoices')),
                _Kpi('Monthly Sales', s['monthly_sales'],
                    Icons.calendar_month_outlined,
                    money: true, to: ('Sales', 'Sales Invoices')),
                _Kpi('Pending Quotations', s['pending_quotations'],
                    Icons.request_quote_outlined,
                    to: ('Sales', 'Quotations / Proforma')),
                _Kpi('Pending Sales Orders', s['pending_sales_orders'],
                    Icons.receipt_long_outlined,
                    to: ('Sales', 'Sales Orders')),
                _Kpi('Pending Deliveries', s['pending_deliveries'],
                    Icons.local_shipping_outlined,
                    to: ('Sales', 'Deliveries')),
                // Customer outstanding is worked down by recording receipts,
                // so that is where the tile lands rather than on the invoices.
                _Kpi(
                    'Outstanding (Customers)',
                    s['outstanding_customer_amount'],
                    Icons.account_balance_wallet_outlined,
                    money: true,
                    color: AppColors.amber,
                    to: ('Sales', 'Receipts')),
              ]),
            if (sections.contains('purchase'))
              _section('Purchase', 'What is on order and what is owed', [
                _Kpi("Today's Purchase", s['todays_purchase'],
                    Icons.shopping_cart_outlined,
                    money: true, to: ('Purchase', 'Purchase Invoices')),
                _Kpi('Pending Purchase Orders', s['pending_purchase_orders'],
                    Icons.assignment_outlined,
                    to: ('Purchase', 'Purchase Orders')),
                _Kpi('Pending Goods Receipts', s['pending_goods_receipts'],
                    Icons.move_to_inbox_outlined,
                    to: ('Purchase', 'Goods Receipts')),
                _Kpi('Supplier Outstanding', s['supplier_outstanding'],
                    Icons.account_balance_wallet_outlined,
                    money: true,
                    color: AppColors.amber,
                    to: ('Purchase', 'Payments')),
              ]),
            if (sections.contains('inventory'))
              _section('Inventory', 'Position derived from the stock ledger', [
                _Kpi('Total Stock Value', s['total_stock_value'],
                    Icons.warehouse_outlined,
                    money: true, to: ('Inventory', 'Stock')),
                _Kpi('Low Stock Products', s['low_stock_products'],
                    Icons.warning_amber_outlined,
                    color: AppColors.amber, to: ('Inventory', 'Stock')),
                _Kpi('Out of Stock', s['out_of_stock_products'],
                    Icons.remove_shopping_cart_outlined,
                    color: AppColors.rose, to: ('Inventory', 'Stock')),
              ]),
            if (sections.contains('tasks'))
              _section('Tasks', 'Follow-ups and reminders waiting on someone', [
                _Kpi('Open Tasks', s['open_tasks'], Icons.task_alt_outlined,
                    to: ('Tasks', 'Tasks & Reminders')),
                _Kpi('Due Today', s['tasks_due_today'], Icons.today_outlined,
                    color: AppColors.amber, to: ('Tasks', 'Tasks & Reminders')),
                _Kpi(
                    'Overdue', s['overdue_tasks'], Icons.warning_amber_outlined,
                    color: AppColors.rose, to: ('Tasks', 'Tasks & Reminders')),
                _Kpi('Open Follow-ups', s['open_follow_ups'],
                    Icons.follow_the_signs_outlined,
                    to: ('Tasks', 'Tasks & Reminders')),
                _Kpi('Payment Reminders', s['open_payment_reminders'],
                    Icons.payments_outlined,
                    to: ('Tasks', 'Tasks & Reminders')),
              ]),
            // Accounts screens are still ComingSoonScreen placeholders; the
            // tiles navigate anyway so the destination explains itself.
            if (sections.contains('accounts'))
              _section('Accounts', 'Ledger positions as at today', [
                _Kpi('Receivable', s['receivable'], Icons.arrow_downward,
                    money: true,
                    color: AppColors.green,
                    to: ('Accounts', 'Receivables')),
                _Kpi('Payable', s['payable'], Icons.arrow_upward,
                    money: true,
                    color: AppColors.rose,
                    to: ('Accounts', 'Payables')),
                _Kpi('Cash Balance', s['cash_balance'], Icons.payments_outlined,
                    money: true,
                    color: AppColors.teal,
                    to: ('Accounts', 'Cash')),
                _Kpi('Bank Balance', s['bank_balance'],
                    Icons.account_balance_outlined,
                    money: true,
                    color: AppColors.indigo,
                    to: ('Accounts', 'Bank')),
              ]),
          ],
        ),
      );
    });
  }

  Widget _errorState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 540),
            padding: const EdgeInsets.all(26),
            decoration: AppColors.panel(radius: AppRadius.panel),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: AppColors.tintedBox(AppColors.rose,
                      radius: AppRadius.card, border: false),
                  child: const Icon(Icons.cloud_off_outlined,
                      size: 26, color: AppColors.rose),
                ),
                const SizedBox(height: 18),
                Text('Could not reach the backend',
                    style: AppText.serif(fontSize: 20)),
                const SizedBox(height: 10),
                Text(
                  '$_error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.rose, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 14),
                Text(
                  'Check that the FastAPI server is running and that '
                  'lib/config/api_config.dart points at the right host — the '
                  'comments in that file cover emulator and device setups.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      );

  /// The masthead. Navy, so the page opens on the brand and every white
  /// card below reads as content sitting under it.
  Widget _hero(bool narrow) {
    final today = DateFormat('EEEE, d MMMM y').format(DateTime.now());
    return Container(
      padding: EdgeInsets.fromLTRB(narrow ? 18 : 28, 22, narrow ? 14 : 24, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.panel),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brand, AppColors.brandDarker],
        ),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: narrow ? 46 : 58,
            height: narrow ? 46 : 58,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: BrandLogo(height: narrow ? 32 : 44),
          ),
          SizedBox(width: narrow ? 12 : 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(width: 16, height: 1.5, color: AppColors.gold),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        kCompanyName.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.goldLight,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  'Business overview',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.serif(
                    fontSize: narrow ? 21 : 26,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  today,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Tooltip(
            message: 'Refresh',
            child: Material(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.field),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.field),
                onTap: _refreshing ? null : _load,
                child: SizedBox(
                  width: 42,
                  height: 42,
                  child: _refreshing
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.refresh,
                          color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Shown when this login holds no departments at all. Without it the
  /// dashboard would be a logo and nothing else, which reads as a bug
  /// rather than as a permission that has not been granted yet.
  Widget _noSections() => Container(
        padding: const EdgeInsets.all(20),
        decoration:
            AppColors.tintedBox(AppColors.amber, radius: AppRadius.card),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: AppColors.tintedBox(AppColors.amber,
                radius: AppRadius.chip, border: false),
            child: const Icon(Icons.lock_outline, color: AppColors.amber),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('No departments granted yet',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                      fontSize: 14.5)),
              SizedBox(height: 4),
              Text(
                'Your admin decides which parts of the ERP you can open. '
                'Ask them to grant you a department and this page will fill in.',
                style: TextStyle(
                    color: AppColors.slate, fontSize: 13, height: 1.5),
              ),
            ]),
          ),
        ]),
      );

  /// A titled block of KPI tiles. Every tile takes the section's own
  /// module colour unless it names its own -- one hue per block reads as
  /// a considered scheme, where a per-tile rotation read as confetti.
  Widget _section(String title, String subtitle, List<_Kpi> tiles) {
    final color = AppColors.forModule(title);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeading(
                title: title,
                subtitle: subtitle,
                color: color,
              ),
              const SizedBox(height: 18),
              _KpiGrid(
                count: tiles.length,
                builder: (i) => _kpiTile(tiles[i], color),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Formats a KPI value: rupees for amounts, grouped digits for counts,
  /// and anything the server sends that is not a number verbatim.
  String _format(dynamic value, bool money) {
    final n = value is num ? value : num.tryParse('$value');
    if (n == null) return '$value';
    if (money) {
      return NumberFormat.currency(
        locale: 'en_IN',
        symbol: '₹',
        decimalDigits: 0,
      ).format(n);
    }
    return NumberFormat.decimalPattern('en_IN').format(n);
  }

  /// Tiles whose destination the signed-in user has no department
  /// permission for render as plain, non-tappable cards -- the shell drops
  /// those groups entirely (main.dart), so the KPI still reads but no
  /// longer leads anywhere.
  Widget _kpiTile(_Kpi kpi, Color sectionColor) {
    final accent = kpi.color ?? sectionColor;
    final radius = BorderRadius.circular(AppRadius.card);
    final nav = AppShellNav.maybeOf(context);
    final tappable =
        kpi.to != null && (nav?.has(kpi.to!.$1, kpi.to!.$2) ?? false);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
        borderRadius: radius,
        boxShadow: AppShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      // Transparent Material so the tap ripple paints over the card's
      // white background instead of behind it.
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: tappable ? () => nav!.goTo(kpi.to!.$1, kpi.to!.$2) : null,
          hoverColor: accent.withValues(alpha: 0.03),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // A hairline of the accent along the top edge: it colour-codes
              // the tile without tinting the surface the number sits on.
              Container(height: 3, color: accent.withValues(alpha: 0.85)),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: AppColors.tintedBox(accent,
                              radius: AppRadius.chip, border: false),
                          child: Icon(kpi.icon, color: accent, size: 20),
                        ),
                        const Spacer(),
                        // Quiet affordance -- without it a tappable tile
                        // looks identical to the static ones.
                        if (tappable)
                          Icon(Icons.arrow_forward,
                              size: 15, color: accent.withValues(alpha: 0.45)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _format(kpi.value, kpi.money),
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                          letterSpacing: -0.6,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Fixed two-line box: a label that wraps must not make
                    // its tile taller than the others, which Wrap would
                    // leave standing proud of the rest of the row.
                    SizedBox(
                      height: 29,
                      child: Text(
                        kpi.label.toUpperCase(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.overline
                            .copyWith(fontSize: 10.5, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lays KPI tiles out on an even grid.
///
/// A plain Wrap of fixed-width tiles leaves an orphan on the last row
/// whenever the count does not divide by the columns that happen to fit --
/// six tiles across five columns looks like a mistake. This picks the
/// column count that divides the tiles evenly where one exists, then
/// stretches every tile to share the row, so each block reads as a
/// deliberate grid at any window width.
class _KpiGrid extends StatelessWidget {
  final int count;
  final Widget Function(int index) builder;

  const _KpiGrid({required this.count, required this.builder});

  static const double _gap = 14;
  static const double _minTile = 150;

  int _columns(double width) {
    final maxCols =
        ((width + _gap) / (_minTile + _gap)).floor().clamp(1, count);
    // Best case: the whole section fits on one row.
    if (maxCols == count) return maxCols;
    // Otherwise take the widest layout that divides evenly, so the last
    // row is full rather than trailing a lone tile.
    for (int c = maxCols; c >= 2; c--) {
      if (count % c == 0) return c;
    }
    return maxCols;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final columns = _columns(constraints.maxWidth);
      final tile = (constraints.maxWidth - _gap * (columns - 1)) / columns;
      return Wrap(
        spacing: _gap,
        runSpacing: _gap,
        children: [
          for (int i = 0; i < count; i++)
            SizedBox(width: tile, child: builder(i)),
        ],
      );
    });
  }
}
