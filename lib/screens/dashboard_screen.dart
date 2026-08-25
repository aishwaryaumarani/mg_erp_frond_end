import 'package:flutter/material.dart';
import '../services/api_service.dart';

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
          child: Text(
            'Could not reach the backend at the configured API URL.\n\n$_error\n\n'
            'Check that the FastAPI server is running and that lib/config/api_config.dart '
            'points at the right host (see the comments in that file for emulator/device setups).',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_summary == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final s = _summary!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _sectionTitle('Masters'),
          _tileGrid([
            _kpi('Total Products', s['total_products'], Icons.inventory_2_outlined),
            _kpi('Categories', s['total_categories'], Icons.category_outlined),
            _kpi('Customers', s['total_customers'], Icons.people_outline),
            _kpi('Suppliers', s['total_suppliers'], Icons.local_shipping_outlined),
          ]),
          const SizedBox(height: 24),
          _sectionTitle('Sales (Phase 2/3)'),
          _tileGrid([
            _kpi("Today's Sales", s['todays_sales'], Icons.point_of_sale_outlined),
            _kpi('Monthly Sales', s['monthly_sales'], Icons.calendar_month_outlined),
            _kpi('Pending Quotations', s['pending_quotations'], Icons.request_quote_outlined),
            _kpi('Pending Sales Orders', s['pending_sales_orders'], Icons.receipt_long_outlined),
            _kpi('Pending Deliveries', s['pending_deliveries'], Icons.local_shipping_outlined),
            _kpi('Outstanding (Customers)', s['outstanding_customer_amount'], Icons.account_balance_wallet_outlined),
          ]),
          const SizedBox(height: 24),
          _sectionTitle('Purchase (Phase 4/5)'),
          _tileGrid([
            _kpi("Today's Purchase", s['todays_purchase'], Icons.shopping_cart_outlined),
            _kpi('Pending Purchase Orders', s['pending_purchase_orders'], Icons.assignment_outlined),
            _kpi('Pending Goods Receipts', s['pending_goods_receipts'], Icons.move_to_inbox_outlined),
            _kpi('Supplier Outstanding', s['supplier_outstanding'], Icons.account_balance_wallet_outlined),
          ]),
          const SizedBox(height: 24),
          _sectionTitle('Inventory (Phase 3/5)'),
          _tileGrid([
            _kpi('Total Stock Value', s['total_stock_value'], Icons.warehouse_outlined),
            _kpi('Low Stock Products', s['low_stock_products'], Icons.warning_amber_outlined),
            _kpi('Out of Stock', s['out_of_stock_products'], Icons.remove_shopping_cart_outlined),
          ]),
          const SizedBox(height: 24),
          _sectionTitle('Accounts (Phase 6)'),
          _tileGrid([
            _kpi('Receivable', s['receivable'], Icons.arrow_downward),
            _kpi('Payable', s['payable'], Icons.arrow_upward),
            _kpi('Cash Balance', s['cash_balance'], Icons.payments_outlined),
            _kpi('Bank Balance', s['bank_balance'], Icons.account_balance_outlined),
          ]),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      );

  Widget _tileGrid(List<Widget> tiles) => Wrap(spacing: 16, runSpacing: 16, children: tiles);

  Widget _kpi(String label, dynamic value, IconData icon) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text('$value', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
