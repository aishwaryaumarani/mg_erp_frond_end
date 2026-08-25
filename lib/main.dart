import 'package:flutter/material.dart';
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
import 'screens/coming_soon_screen.dart';
import 'widgets/app_shell.dart';

void main() {
  runApp(const MiniErpApp());
}

class MiniErpApp extends StatelessWidget {
  const MiniErpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mini ERP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
      ),
      home: AppShell(
        title: 'Mini ERP',
        groups: [
          // Dashboard -- single-leaf group renders as a flat sidebar item.
          const NavGroup('Dashboard', Icons.dashboard_outlined, [
            NavLeaf('Dashboard', Icons.dashboard_outlined, _dashboard),
          ]),

          // Masters -- fully implemented in Phase 1.
          NavGroup('Masters', Icons.folder_outlined, [
            const NavLeaf('Products', Icons.inventory_2_outlined, _products),
            const NavLeaf('Categories', Icons.category_outlined, _categories),
            const NavLeaf('Brands', Icons.branding_watermark_outlined, _brands),
            const NavLeaf('Units', Icons.straighten_outlined, _units),
            const NavLeaf('Taxes', Icons.percent_outlined, _taxes),
            const NavLeaf('Price Lists', Icons.sell_outlined, _priceLists),
            const NavLeaf('Leads', Icons.person_search_outlined, _leads),
            const NavLeaf('Customers', Icons.people_outline, _customers),
            const NavLeaf('Suppliers', Icons.local_shipping_outlined, _suppliers),
          ]),

          // Sales -- Phase 2/3.
          NavGroup('Sales', Icons.point_of_sale_outlined, [
            const NavLeaf('Inquiries', Icons.help_outline, _inquiries),
            const NavLeaf('Quotations', Icons.request_quote_outlined, _quotations),
            const NavLeaf('Sales Orders', Icons.receipt_long_outlined, _salesOrders),
            const NavLeaf('Deliveries', Icons.local_shipping_outlined, _deliveries),
            const NavLeaf('Sales Invoices', Icons.description_outlined, _salesInvoices),
            const NavLeaf('Receipts', Icons.payments_outlined, _customerReceipts),
          ]),

          // Purchase -- Inquiry/Quotation/Order done (Phase 4); Goods Receipt/
          // Invoice/Payment still wait on Inventory (Phase 3/5) and
          // Accounts (Phase 6).
          NavGroup('Purchase', Icons.shopping_cart_outlined, [
            const NavLeaf('Inquiries', Icons.help_outline, _purchaseInquiries),
            const NavLeaf('Supplier Quotations', Icons.request_quote_outlined, _supplierQuotations),
            const NavLeaf('Purchase Orders', Icons.assignment_outlined, _purchaseOrders),
            const NavLeaf('Goods Receipts', Icons.move_to_inbox_outlined, _goodsReceipts),
            const NavLeaf('Purchase Invoices', Icons.description_outlined, _purchaseInvoices),
            const NavLeaf('Payments', Icons.payments_outlined, _supplierPayments),
          ]),

          // Inventory -- Phase 3/5.
          NavGroup('Inventory', Icons.warehouse_outlined, [
            NavLeaf('Stock', Icons.inventory_outlined,
                (ctx) => const ComingSoonScreen(moduleName: 'Stock Summary', phaseNote: 'Ships alongside Delivery (Phase 3) and Goods Receipt (Phase 5).')),
            NavLeaf('Stock Ledger', Icons.list_alt_outlined,
                (ctx) => const ComingSoonScreen(moduleName: 'Stock Ledger', phaseNote: 'Every stock movement will reference its source document (spec sec. 8).')),
            const NavLeaf('Warehouses', Icons.store_outlined, _warehouses),
            NavLeaf('Stock Transfer', Icons.compare_arrows_outlined,
                (ctx) => const ComingSoonScreen(moduleName: 'Stock Transfer', phaseNote: 'Ships in Phase 3.')),
            NavLeaf('Stock Adjustment', Icons.tune_outlined,
                (ctx) => const ComingSoonScreen(moduleName: 'Stock Adjustment', phaseNote: 'Ships in Phase 3.')),
          ]),

          // Accounts -- Phase 6.
          NavGroup('Accounts', Icons.account_balance_outlined, [
            NavLeaf('Chart of Accounts', Icons.list_outlined,
                (ctx) => const ComingSoonScreen(moduleName: 'Chart of Accounts', phaseNote: 'Ships in Phase 6 with the default accounts from spec sec. 10.')),
            NavLeaf('Journal', Icons.book_outlined,
                (ctx) => const ComingSoonScreen(moduleName: 'Journal Entries', phaseNote: 'Ships in Phase 6.')),
            NavLeaf('General Ledger', Icons.menu_book_outlined,
                (ctx) => const ComingSoonScreen(moduleName: 'General Ledger', phaseNote: 'Ships in Phase 6.')),
            NavLeaf('Receivables', Icons.arrow_downward,
                (ctx) => const ComingSoonScreen(moduleName: 'Accounts Receivable', phaseNote: 'Ships in Phase 6, driven by posted Sales Invoices.')),
            NavLeaf('Payables', Icons.arrow_upward,
                (ctx) => const ComingSoonScreen(moduleName: 'Accounts Payable', phaseNote: 'Ships in Phase 6, driven by posted Purchase Invoices.')),
            NavLeaf('Cash', Icons.payments_outlined,
                (ctx) => const ComingSoonScreen(moduleName: 'Cash', phaseNote: 'Ships in Phase 6.')),
            NavLeaf('Bank', Icons.account_balance_outlined,
                (ctx) => const ComingSoonScreen(moduleName: 'Bank', phaseNote: 'Ships in Phase 6.')),
            NavLeaf('Tax', Icons.percent_outlined,
                (ctx) => const ComingSoonScreen(moduleName: 'Tax', phaseNote: 'Ships in Phase 6.')),
          ]),

          // Reports -- Phase 7.
          NavGroup('Reports', Icons.bar_chart_outlined, [
            NavLeaf('Sales Report', Icons.show_chart,
                (ctx) => const ComingSoonScreen(moduleName: 'Sales Report', phaseNote: 'Ships in Phase 7, once Sales documents exist to report on.')),
            NavLeaf('Purchase Report', Icons.show_chart,
                (ctx) => const ComingSoonScreen(moduleName: 'Purchase Report', phaseNote: 'Ships in Phase 7.')),
            NavLeaf('Stock Report', Icons.show_chart,
                (ctx) => const ComingSoonScreen(moduleName: 'Stock Report', phaseNote: 'Ships in Phase 7.')),
            NavLeaf('Receivable Report', Icons.show_chart,
                (ctx) => const ComingSoonScreen(moduleName: 'Receivable Report', phaseNote: 'Ships in Phase 7.')),
            NavLeaf('Payable Report', Icons.show_chart,
                (ctx) => const ComingSoonScreen(moduleName: 'Payable Report', phaseNote: 'Ships in Phase 7.')),
            NavLeaf('Trial Balance', Icons.balance_outlined,
                (ctx) => const ComingSoonScreen(moduleName: 'Trial Balance', phaseNote: 'Ships in Phase 7.')),
            NavLeaf('Profit & Loss', Icons.trending_up,
                (ctx) => const ComingSoonScreen(moduleName: 'Profit & Loss', phaseNote: 'Ships in Phase 7.')),
            NavLeaf('Balance Sheet', Icons.account_balance_wallet_outlined,
                (ctx) => const ComingSoonScreen(moduleName: 'Balance Sheet', phaseNote: 'Ships in Phase 7.')),
          ]),

          // Settings -- single-leaf group.
          const NavGroup('Settings', Icons.settings_outlined, [
            NavLeaf('Settings', Icons.settings_outlined, _settings),
          ]),
        ],
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
  static Widget _settings(BuildContext ctx) => const ComingSoonScreen(
        moduleName: 'Settings',
        phaseNote: 'Company profile, users/roles, numbering sequences, and other config land here as later phases need them.',
      );
}
