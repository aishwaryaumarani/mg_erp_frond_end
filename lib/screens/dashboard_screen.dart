import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// Dashboard (spec sec. 13). Phase 1 only has master-data KPIs to show
/// for real; the Sales/Purchase/Inventory/Accounts tiles are wired up
/// and rendered now so the layout won't need to change later -- they
/// just read 0 from the backend until those modules exist (see
/// backend/app/routers/dashboard.py).
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _summary;
  String? _error;

  /// Incremented by every [_kpi] call so tiles cycle through the accent
  /// palette; reset at the top of build() to keep colours stable across
  /// rebuilds.
  int _tileIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.instance.getOne('/api/dashboard/summary');
      setState(() => _summary = data);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520),
            padding: const EdgeInsets.all(20),
            decoration: AppColors.tintedBox(AppColors.rose, radius: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 40, color: AppColors.rose),
                const SizedBox(height: 12),
                Text(
                  'Could not reach the backend',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.rose,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$_error\n\n'
                  'Check that the FastAPI server is running and that lib/config/api_config.dart '
                  'points at the right host (see the comments in that file for emulator/device setups).',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.slate),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_summary == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final s = _summary!;
    _tileIndex = 0;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _section('Masters', [
            _kpi('Total Products', s['total_products'], Icons.inventory_2_outlined),
            _kpi('Categories', s['total_categories'], Icons.category_outlined),
            _kpi('Customers', s['total_customers'], Icons.people_outline),
            _kpi('Suppliers', s['total_suppliers'], Icons.local_shipping_outlined),
          ]),
          _section('Sales (Phase 2/3)', [
            _kpi("Today's Sales", s['todays_sales'], Icons.point_of_sale_outlined),
            _kpi('Monthly Sales', s['monthly_sales'], Icons.calendar_month_outlined),
            _kpi('Pending Quotations', s['pending_quotations'], Icons.request_quote_outlined),
            _kpi('Pending Sales Orders', s['pending_sales_orders'], Icons.receipt_long_outlined),
            _kpi('Pending Deliveries', s['pending_deliveries'], Icons.local_shipping_outlined),
            _kpi('Outstanding (Customers)', s['outstanding_customer_amount'], Icons.account_balance_wallet_outlined),
          ]),
          _section('Purchase (Phase 4/5)', [
            _kpi("Today's Purchase", s['todays_purchase'], Icons.shopping_cart_outlined),
            _kpi('Pending Purchase Orders', s['pending_purchase_orders'], Icons.assignment_outlined),
            _kpi('Pending Goods Receipts', s['pending_goods_receipts'], Icons.move_to_inbox_outlined),
            _kpi('Supplier Outstanding', s['supplier_outstanding'], Icons.account_balance_wallet_outlined),
          ]),
          _section('Inventory (Phase 3/5)', [
            _kpi('Total Stock Value', s['total_stock_value'], Icons.warehouse_outlined),
            _kpi('Low Stock Products', s['low_stock_products'], Icons.warning_amber_outlined, color: AppColors.amber),
            _kpi('Out of Stock', s['out_of_stock_products'], Icons.remove_shopping_cart_outlined, color: AppColors.rose),
          ]),
          _section('Tasks (Reminders)', [
            _kpi('Open Tasks', s['open_tasks'], Icons.task_alt_outlined, color: AppColors.brand),
            _kpi('Due Today', s['tasks_due_today'], Icons.today_outlined, color: AppColors.amber),
            _kpi('Overdue', s['overdue_tasks'], Icons.warning_amber_outlined, color: AppColors.rose),
            _kpi('Open Follow-ups', s['open_follow_ups'], Icons.follow_the_signs_outlined, color: AppColors.violet),
            _kpi('Payment Reminders', s['open_payment_reminders'], Icons.payments_outlined, color: AppColors.green),
          ]),
          _section('Accounts (Phase 6)', [
            _kpi('Receivable', s['receivable'], Icons.arrow_downward, color: AppColors.green),
            _kpi('Payable', s['payable'], Icons.arrow_upward, color: AppColors.rose),
            _kpi('Cash Balance', s['cash_balance'], Icons.payments_outlined, color: AppColors.teal),
            _kpi('Bank Balance', s['bank_balance'], Icons.account_balance_outlined, color: AppColors.indigo),
          ]),
        ],
      ),
    );
  }

  /// A titled block of KPI tiles. Tiles with no explicit colour take
  /// their accent from the section's module colour, cycled through
  /// [AppColors.accents] so adjacent tiles stay distinguishable.
  Widget _section(String title, List<Widget> tiles) {
    final color = AppColors.forModule(title);
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(title, color),
          const SizedBox(height: 14),
          Wrap(spacing: 16, runSpacing: 16, children: tiles),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text, Color color) => Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            text,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
        ],
      );

  Widget _kpi(String label, dynamic value, IconData icon, {Color? color}) {
    final accent = color ?? AppColors.accentAt(_tileIndex++);
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: accent.withOpacity(0.25)),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: AppColors.tintedBox(accent, radius: 10, border: false),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(height: 14),
          Text(
            '$value',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: accent,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.slate),
          ),
        ],
      ),
    );
  }
}
