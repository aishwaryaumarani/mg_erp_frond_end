import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/companies_screen.dart';
import 'screens/users_screen.dart';
import 'services/auth_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/simple_master_screens.dart';
import 'screens/product_screen.dart';
import 'screens/price_list_screen.dart';
import 'screens/customer_screen.dart';
import 'screens/supplier_screen.dart';
import 'screens/lead_screen.dart';
import 'screens/inquiry_screen.dart';
import 'screens/quotation_screen.dart';
import 'screens/sales_order_screen.dart';
import 'screens/purchase_inquiry_screen.dart';
import 'screens/supplier_quotation_screen.dart';
import 'screens/purchase_order_screen.dart';
import 'screens/goods_receipt_screen.dart';
import 'screens/purchase_invoice_screen.dart';
import 'screens/supplier_payment_screen.dart';
import 'screens/delivery_screen.dart';
import 'screens/sales_invoice_screen.dart';
import 'screens/customer_receipt_screen.dart';
import 'screens/warehouse_screen.dart';
import 'screens/stock_screen.dart';
import 'screens/stock_ledger_screen.dart';
import 'screens/stock_adjustment_screen.dart';
import 'screens/task_screen.dart';
import 'screens/coming_soon_screen.dart';
import 'screens/report_screen.dart';
import 'widgets/app_shell.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.instance.loadSession();
  // Fire-and-forget: picks up permission changes an admin made while this
  // device was signed in, and reshapes the sidebar when it lands.
  AuthService.instance.refreshPermissions();
  runApp(const MiniErpApp());
}

class MiniErpApp extends StatelessWidget {
  const MiniErpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MG Chemicals',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: AnimatedBuilder(
        animation: AuthService.instance,
        builder: (context, _) {
          final auth = AuthService.instance;
          if (!auth.isLoggedIn) return const LoginScreen();
          if (auth.isSuperAdmin) return _superAdminShell();
          return _erpShell(auth);
        },
      ),
    );
  }

  /// Super Admin has no company_id, so none of the business-data screens
  /// below (Products, Sales, ...) apply to them -- they only manage
  /// Companies (backend/app/routers/companies.py).
  static Widget _superAdminShell() {
    return AppShell(
      title: 'Companies',
      actions: [_logoutButton()],
      groups: [
        NavGroup('Companies', Icons.business_outlined, [
          NavLeaf('Companies', Icons.business_outlined, (ctx) => const CompaniesScreen()),
        ]),
      ],
    );
  }

  /// Builds the sidebar from the departments this login was granted
  /// (backend/app/core/permissions.py -- the group labels below match its
  /// MODULES keys one-for-one). Groups whose leaves are all hidden drop
  /// out entirely, so a Sales-only user sees Dashboard, Sales and
  /// Settings and nothing else.
  ///
  /// This is menu shaping, not security: every endpoint re-checks the
  /// same permission server-side, so hiding a group and blocking the data
  /// are independent.
  static Widget _erpShell(AuthService auth) {
    final isCompanyAdmin = auth.isCompanyAdmin;
    bool can(String module) => auth.can(module);

    final groups = <NavGroup>[
      // Dashboard -- single-leaf group renders as a flat sidebar item.
      const NavGroup('Dashboard', Icons.dashboard_outlined, [
        NavLeaf('Dashboard', Icons.dashboard_outlined, _dashboard),
      ]),

      // Masters -- fully implemented in Phase 1.
      NavGroup('Masters', Icons.folder_outlined, [
        if (can('masters')) ...[
          const NavLeaf('Products', Icons.inventory_2_outlined, _products),
          const NavLeaf('Categories', Icons.category_outlined, _categories),
          const NavLeaf('Brands', Icons.branding_watermark_outlined, _brands),
          const NavLeaf('Units', Icons.straighten_outlined, _units),
          const NavLeaf('Taxes', Icons.percent_outlined, _taxes),
          const NavLeaf('Price Lists', Icons.sell_outlined, _priceLists),
        ],
        // Leads are a Sales document that happens to sit in this
        // group, so they follow the Sales permission, not Masters
        // (backend mounts /api/leads behind "sales").
        if (can('sales')) const NavLeaf('Leads', Icons.person_search_outlined, _leads),
        if (can('masters')) ...[
          const NavLeaf('Customers', Icons.people_outline, _customers),
          const NavLeaf('Suppliers', Icons.local_shipping_outlined, _suppliers),
        ],
      ]),

      // Sales -- Phase 2/3.
      if (can('sales'))
        const NavGroup('Sales', Icons.point_of_sale_outlined, [
          NavLeaf('Inquiries', Icons.help_outline, _inquiries),
          NavLeaf('Quotations', Icons.request_quote_outlined, _quotations),
          NavLeaf('Sales Orders', Icons.receipt_long_outlined, _salesOrders),
          NavLeaf('Deliveries', Icons.local_shipping_outlined, _deliveries),
          NavLeaf('Sales Invoices', Icons.description_outlined, _salesInvoices),
          NavLeaf('Receipts', Icons.payments_outlined, _customerReceipts),
        ]),

      // Purchase -- Inquiry/Quotation/Order done (Phase 4); Goods Receipt/
      // Invoice/Payment still wait on Inventory (Phase 3/5) and
      // Accounts (Phase 6).
      if (can('purchase'))
        const NavGroup('Purchase', Icons.shopping_cart_outlined, [
          NavLeaf('Inquiries', Icons.help_outline, _purchaseInquiries),
          NavLeaf('Supplier Quotations', Icons.request_quote_outlined, _supplierQuotations),
          NavLeaf('Purchase Orders', Icons.assignment_outlined, _purchaseOrders),
          NavLeaf('Goods Receipts', Icons.move_to_inbox_outlined, _goodsReceipts),
          NavLeaf('Purchase Invoices', Icons.description_outlined, _purchaseInvoices),
          NavLeaf('Payments', Icons.payments_outlined, _supplierPayments),
        ]),

      // Inventory -- Phase 3/5. Stock is derived from the append-only
      // StockLedger; Goods Receipt (IN), Delivery (OUT) and Stock
      // Adjustment are the only things that move it (spec sec. 8).
      if (can('inventory'))
        NavGroup('Inventory', Icons.warehouse_outlined, [
          const NavLeaf('Stock', Icons.inventory_outlined, _stock),
          const NavLeaf('Stock Ledger', Icons.list_alt_outlined, _stockLedger),
          const NavLeaf('Warehouses', Icons.store_outlined, _warehouses),
          const NavLeaf('Stock Adjustment', Icons.tune_outlined, _stockAdjustment),
          // Still a placeholder -- there is no transfer endpoint yet;
          // moving stock between warehouses would need a paired
          // OUT/IN posting the backend doesn't expose.
          NavLeaf(
              'Stock Transfer',
              Icons.compare_arrows_outlined,
              (ctx) => const ComingSoonScreen(
                  moduleName: 'Stock Transfer',
                  phaseNote:
                      'Not yet available in the API — needs a paired OUT/IN movement endpoint.')),
        ]),

      // Tasks & Reminders -- follow-up calls, payment reminders and
      // to-do checklists. Reminders are polled, not pushed: the
      // backend exposes due-today/overdue/upcoming windows and this
      // screen reads them (backend/app/routers/tasks.py).
      if (can('tasks'))
        const NavGroup('Tasks', Icons.task_alt_outlined, [
          NavLeaf('Tasks & Reminders', Icons.task_alt_outlined, _tasks),
        ]),

      // Accounts -- Phase 6.
      if (can('accounts'))
        NavGroup('Accounts', Icons.account_balance_outlined, [
          NavLeaf(
              'Chart of Accounts',
              Icons.list_outlined,
              (ctx) => const ComingSoonScreen(
                  moduleName: 'Chart of Accounts',
                  phaseNote: 'Ships in Phase 6 with the default accounts from spec sec. 10.')),
          NavLeaf(
              'Journal',
              Icons.book_outlined,
              (ctx) => const ComingSoonScreen(
                  moduleName: 'Journal Entries', phaseNote: 'Ships in Phase 6.')),
          NavLeaf(
              'General Ledger',
              Icons.menu_book_outlined,
              (ctx) => const ComingSoonScreen(
                  moduleName: 'General Ledger', phaseNote: 'Ships in Phase 6.')),
          NavLeaf(
              'Receivables',
              Icons.arrow_downward,
              (ctx) => const ComingSoonScreen(
                  moduleName: 'Accounts Receivable',
                  phaseNote: 'Ships in Phase 6, driven by posted Sales Invoices.')),
          NavLeaf(
              'Payables',
              Icons.arrow_upward,
              (ctx) => const ComingSoonScreen(
                  moduleName: 'Accounts Payable',
                  phaseNote: 'Ships in Phase 6, driven by posted Purchase Invoices.')),
          NavLeaf('Cash', Icons.payments_outlined,
              (ctx) => const ComingSoonScreen(moduleName: 'Cash', phaseNote: 'Ships in Phase 6.')),
          NavLeaf('Bank', Icons.account_balance_outlined,
              (ctx) => const ComingSoonScreen(moduleName: 'Bank', phaseNote: 'Ships in Phase 6.')),
          NavLeaf('Tax', Icons.percent_outlined,
              (ctx) => const ComingSoonScreen(moduleName: 'Tax', phaseNote: 'Ships in Phase 6.')),
        ]),

      // Reports -- Phase 7.
      if (can('reports'))
        NavGroup('Reports', Icons.bar_chart_outlined, [
          NavLeaf(
              'Sales Report',
              Icons.show_chart,
              (ctx) => const ReportScreen(
                    title: 'Sales Report',
                    path: '/api/reports/sales',
                    chartLabelKey: 'party',
                    chartValueKey: 'total',
                    barTitle: 'Top customers by sales',
                    pieTitle: 'Share of sales',
                    emptyMessage: 'No invoices were issued in this period.',
                    columns: [
                      ReportColumn('date', 'Date'),
                      ReportColumn('document', 'Invoice'),
                      ReportColumn('party', 'Customer'),
                      ReportColumn('status', 'Status'),
                      ReportColumn('taxable', 'Taxable', money: true),
                      ReportColumn('tax', 'Tax', money: true),
                      ReportColumn('total', 'Total', money: true),
                      ReportColumn('paid', 'Received', money: true),
                      ReportColumn('outstanding', 'Outstanding', money: true),
                    ],
                  )),
          NavLeaf(
              'Purchase Report',
              Icons.show_chart,
              (ctx) => const ReportScreen(
                    title: 'Purchase Report',
                    path: '/api/reports/purchase',
                    chartLabelKey: 'party',
                    chartValueKey: 'total',
                    barTitle: 'Top suppliers by purchases',
                    pieTitle: 'Share of purchases',
                    emptyMessage: 'No supplier invoices in this period.',
                    columns: [
                      ReportColumn('date', 'Date'),
                      ReportColumn('document', 'Invoice'),
                      ReportColumn('party', 'Supplier'),
                      ReportColumn('status', 'Status'),
                      ReportColumn('taxable', 'Taxable', money: true),
                      ReportColumn('tax', 'Tax', money: true),
                      ReportColumn('total', 'Total', money: true),
                      ReportColumn('paid', 'Paid', money: true),
                      ReportColumn('outstanding', 'Outstanding', money: true),
                    ],
                  )),
          NavLeaf(
              'Stock Report',
              Icons.show_chart,
              (ctx) => const ReportScreen(
                    title: 'Stock Report',
                    path: '/api/reports/stock',
                    chartLabelKey: 'product',
                    chartValueKey: 'value',
                    chartStatusKey: 'status',
                    barTitle: 'Highest stock value',
                    pieTitle: 'Stock health',
                    // A stock position is "now", not a period.
                    dateFiltered: false,
                    emptyMessage: 'No products yet.',
                    columns: [
                      ReportColumn('product_code', 'Code'),
                      ReportColumn('product', 'Product'),
                      ReportColumn('on_hand', 'On hand', numeric: true),
                      ReportColumn('minimum', 'Minimum', numeric: true),
                      ReportColumn('rate', 'Rate', money: true),
                      ReportColumn('value', 'Value', money: true),
                      ReportColumn('status', 'Status'),
                    ],
                  )),
          NavLeaf(
              'Receivable Report',
              Icons.show_chart,
              (ctx) => const ReportScreen(
                    title: 'Receivable Report',
                    path: '/api/reports/receivables',
                    chartLabelKey: 'party',
                    chartValueKey: 'outstanding',
                    barTitle: 'Who owes the most',
                    pieTitle: 'Share of outstanding',
                    // Outstanding is a running position, not a date range.
                    dateFiltered: false,
                    emptyMessage: 'Nothing outstanding -- every invoice is settled.',
                    columns: [
                      ReportColumn('party_code', 'Code'),
                      ReportColumn('party', 'Customer'),
                      ReportColumn('invoices', 'Open invoices', numeric: true),
                      ReportColumn('billed', 'Billed', money: true),
                      ReportColumn('paid', 'Received', money: true),
                      ReportColumn('outstanding', 'Outstanding', money: true),
                      ReportColumn('oldest_invoice', 'Oldest'),
                      ReportColumn('days_overdue', 'Days', numeric: true),
                    ],
                  )),
          NavLeaf(
              'Payable Report',
              Icons.show_chart,
              (ctx) => const ReportScreen(
                    title: 'Payable Report',
                    path: '/api/reports/payables',
                    chartLabelKey: 'party',
                    chartValueKey: 'outstanding',
                    barTitle: 'Who we owe the most',
                    pieTitle: 'Share of outstanding',
                    dateFiltered: false,
                    emptyMessage: 'Nothing outstanding -- every supplier invoice is settled.',
                    columns: [
                      ReportColumn('party_code', 'Code'),
                      ReportColumn('party', 'Supplier'),
                      ReportColumn('invoices', 'Open invoices', numeric: true),
                      ReportColumn('billed', 'Billed', money: true),
                      ReportColumn('paid', 'Paid', money: true),
                      ReportColumn('outstanding', 'Outstanding', money: true),
                      ReportColumn('oldest_invoice', 'Oldest'),
                      ReportColumn('days_overdue', 'Days', numeric: true),
                    ],
                  )),
          NavLeaf(
              'Trial Balance',
              Icons.balance_outlined,
              (ctx) => const ComingSoonScreen(
                  moduleName: 'Trial Balance', phaseNote: 'Ships in Phase 7.')),
          NavLeaf(
              'Profit & Loss',
              Icons.trending_up,
              (ctx) => const ComingSoonScreen(
                  moduleName: 'Profit & Loss', phaseNote: 'Ships in Phase 7.')),
          NavLeaf(
              'Balance Sheet',
              Icons.account_balance_wallet_outlined,
              (ctx) => const ComingSoonScreen(
                  moduleName: 'Balance Sheet', phaseNote: 'Ships in Phase 7.')),
        ]),

      // Settings -- single-leaf group.
      const NavGroup('Settings', Icons.settings_outlined, [
        NavLeaf('Settings', Icons.settings_outlined, _settings),
      ]),

      // Team -- Company Admin only (backend/app/routers/users.py
      // restricts POST/GET /api/users to role=company_admin).
      if (isCompanyAdmin)
        NavGroup('Team', Icons.group_outlined, [
          NavLeaf('Team', Icons.group_outlined, (ctx) => const UsersScreen()),
        ]),
    ];

    return AppShell(
      title: 'Dashboard',
      actions: [_logoutButton()],
      // A group whose every leaf was filtered out would render as an
      // empty, unopenable row -- drop it instead.
      groups: groups.where((g) => g.children.isNotEmpty).toList(),
    );
  }

  static Widget _logoutButton() {
    return Builder(
      builder: (context) => IconButton(
        icon: const Icon(Icons.logout),
        tooltip:
            'Sign out${AuthService.instance.fullName != null ? ' (${AuthService.instance.fullName})' : ''}',
        onPressed: () => AuthService.instance.logout(),
      ),
    );
  }

  static Widget _dashboard(BuildContext ctx) => const DashboardScreen();
  static Widget _products(BuildContext ctx) => const ProductScreen();
  static Widget _categories(BuildContext ctx) => const CategoryScreen();
  static Widget _brands(BuildContext ctx) => const BrandScreen();
  static Widget _units(BuildContext ctx) => const UnitScreen();
  static Widget _taxes(BuildContext ctx) => const TaxScreen();
  static Widget _priceLists(BuildContext ctx) => const PriceListScreen();
  static Widget _customers(BuildContext ctx) => const CustomerScreen();
  static Widget _suppliers(BuildContext ctx) => const SupplierScreen();
  static Widget _leads(BuildContext ctx) => const LeadScreen();
  static Widget _inquiries(BuildContext ctx) => const InquiryScreen();
  static Widget _quotations(BuildContext ctx) => const QuotationScreen();
  static Widget _salesOrders(BuildContext ctx) => const SalesOrderScreen();
  static Widget _purchaseInquiries(BuildContext ctx) => const PurchaseInquiryScreen();
  static Widget _supplierQuotations(BuildContext ctx) => const SupplierQuotationScreen();
  static Widget _purchaseOrders(BuildContext ctx) => const PurchaseOrderScreen();
  static Widget _goodsReceipts(BuildContext ctx) => const GoodsReceiptScreen();
  static Widget _purchaseInvoices(BuildContext ctx) => const PurchaseInvoiceScreen();
  static Widget _supplierPayments(BuildContext ctx) => const SupplierPaymentScreen();
  static Widget _deliveries(BuildContext ctx) => const DeliveryScreen();
  static Widget _salesInvoices(BuildContext ctx) => const SalesInvoiceScreen();
  static Widget _customerReceipts(BuildContext ctx) => const CustomerReceiptScreen();
  static Widget _warehouses(BuildContext ctx) => const WarehouseScreen();
  static Widget _stock(BuildContext ctx) => const StockScreen();
  static Widget _stockLedger(BuildContext ctx) => const StockLedgerScreen();
  static Widget _stockAdjustment(BuildContext ctx) => const StockAdjustmentScreen();
  static Widget _tasks(BuildContext ctx) => const TaskScreen();
  static Widget _settings(BuildContext ctx) => const ComingSoonScreen(
        moduleName: 'Settings',
        phaseNote:
            'Company profile, users/roles, numbering sequences, and other config land here as later phases need them.',
      );
}
