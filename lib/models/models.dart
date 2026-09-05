// ---------------------------------------------------------------------------
// Auth / tenancy: Company (Super Admin's onboarding list) and AppUser
// (a Company Admin's own-company user list). Mirrors
// backend/app/schemas/auth.py's CompanyOut/UserOut 1:1. Named AppUser to
// avoid clashing with Flutter/other packages' own `User` types.
// ---------------------------------------------------------------------------

class CompanyModel {
  final int id;
  String name;
  String status; // Active | Suspended
  final String createdAt;

  CompanyModel(
      {required this.id, required this.name, required this.status, required this.createdAt});

  factory CompanyModel.fromJson(Map<String, dynamic> j) => CompanyModel(
        id: j['id'],
        name: j['name'],
        status: j['status'] ?? 'Active',
        createdAt: j['created_at'] ?? '',
      );
}

class AppUser {
  final int id;
  final int? companyId;
  String fullName;
  String email;
  String role; // super_admin | company_admin | user
  String status; // Active | Suspended
  // Departments this user may open (backend/app/core/permissions.py).
  // Always empty for a company_admin -- they are never gated, so the
  // backend stores no rows for them.
  List<String> modules;

  AppUser({
    required this.id,
    this.companyId,
    required this.fullName,
    required this.email,
    required this.role,
    required this.status,
    this.modules = const [],
  });

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'],
        companyId: j['company_id'],
        fullName: j['full_name'],
        email: j['email'],
        role: j['role'],
        status: j['status'] ?? 'Active',
        modules: ((j['modules'] as List<dynamic>?) ?? const []).cast<String>(),
      );
}

/// One tickable department from GET /api/users/modules. Fetched rather
/// than hard-coded so the Team screen can never offer a permission the
/// backend does not actually enforce.
class AppModule {
  final String key;
  final String label;
  const AppModule({required this.key, required this.label});

  factory AppModule.fromJson(Map<String, dynamic> j) => AppModule(key: j['key'], label: j['label']);
}

// Data models for Phase 1: Category, Brand, Unit, Tax, Product,
// PriceList, Customer, Supplier. Each mirrors the corresponding
// Pydantic schema in the backend 1:1 so `fromJson`/`toJson` stay a
// direct field-for-field mapping.

class Category {
  final int? id;
  String name;
  int? parentId;
  String status;

  Category({this.id, required this.name, this.parentId, this.status = 'Active'});

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: j['id'],
        name: j['name'],
        parentId: j['parent_id'],
        status: j['status'] ?? 'Active',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'parent_id': parentId,
        'status': status,
      };
}

class Brand {
  final int? id;
  String name;
  String status;

  Brand({this.id, required this.name, this.status = 'Active'});

  factory Brand.fromJson(Map<String, dynamic> j) =>
      Brand(id: j['id'], name: j['name'], status: j['status'] ?? 'Active');

  Map<String, dynamic> toJson() => {'name': name, 'status': status};
}

class Unit {
  final int? id;
  String name;
  String status;

  Unit({this.id, required this.name, this.status = 'Active'});

  factory Unit.fromJson(Map<String, dynamic> j) =>
      Unit(id: j['id'], name: j['name'], status: j['status'] ?? 'Active');

  Map<String, dynamic> toJson() => {'name': name, 'status': status};
}

class Tax {
  final int? id;
  String name;
  double ratePercent;
  String status;

  Tax({this.id, required this.name, this.ratePercent = 0, this.status = 'Active'});

  factory Tax.fromJson(Map<String, dynamic> j) => Tax(
        id: j['id'],
        name: j['name'],
        ratePercent: (j['rate_percent'] ?? 0).toDouble(),
        status: j['status'] ?? 'Active',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'rate_percent': ratePercent,
        'status': status,
      };
}

class Product {
  final int? id;
  String productCode;
  String name;
  int? categoryId;
  int? subCategoryId;
  int? brandId;
  int? unitId;
  String? hsnSac;
  int? taxId;
  String? barcode;
  String? description;
  double minimumStock;
  double reorderLevel;
  String status;

  Product({
    this.id,
    required this.productCode,
    required this.name,
    this.categoryId,
    this.subCategoryId,
    this.brandId,
    this.unitId,
    this.hsnSac,
    this.taxId,
    this.barcode,
    this.description,
    this.minimumStock = 0,
    this.reorderLevel = 0,
    this.status = 'Active',
  });

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: j['id'],
        productCode: j['product_code'],
        name: j['name'],
        categoryId: j['category_id'],
        subCategoryId: j['sub_category_id'],
        brandId: j['brand_id'],
        unitId: j['unit_id'],
        hsnSac: j['hsn_sac'],
        taxId: j['tax_id'],
        barcode: j['barcode'],
        description: j['description'],
        minimumStock: (j['minimum_stock'] ?? 0).toDouble(),
        reorderLevel: (j['reorder_level'] ?? 0).toDouble(),
        status: j['status'] ?? 'Active',
      );

  Map<String, dynamic> toJson() => {
        'product_code': productCode,
        'name': name,
        'category_id': categoryId,
        'sub_category_id': subCategoryId,
        'brand_id': brandId,
        'unit_id': unitId,
        'hsn_sac': hsnSac,
        'tax_id': taxId,
        'barcode': barcode,
        'description': description,
        'minimum_stock': minimumStock,
        'reorder_level': reorderLevel,
        'status': status,
      };
}

class PriceListEntry {
  final int? id;
  int productId;
  String priceType; // Purchase | Retail | Wholesale | Dealer | Customer-specific
  int? customerId;
  double price;
  double minQuantity;
  double discountPercent;
  int? taxId;
  String? effectiveFrom; // yyyy-MM-dd
  String? effectiveTo;

  PriceListEntry({
    this.id,
    required this.productId,
    required this.priceType,
    this.customerId,
    this.price = 0,
    this.minQuantity = 1,
    this.discountPercent = 0,
    this.taxId,
    this.effectiveFrom,
    this.effectiveTo,
  });

  factory PriceListEntry.fromJson(Map<String, dynamic> j) => PriceListEntry(
        id: j['id'],
        productId: j['product_id'],
        priceType: j['price_type'],
        customerId: j['customer_id'],
        price: (j['price'] ?? 0).toDouble(),
        minQuantity: (j['min_quantity'] ?? 1).toDouble(),
        discountPercent: (j['discount_percent'] ?? 0).toDouble(),
        taxId: j['tax_id'],
        effectiveFrom: j['effective_from'],
        effectiveTo: j['effective_to'],
      );

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'price_type': priceType,
        'customer_id': customerId,
        'price': price,
        'min_quantity': minQuantity,
        'discount_percent': discountPercent,
        'tax_id': taxId,
        'effective_from': effectiveFrom,
        'effective_to': effectiveTo,
      };
}

class Customer {
  final int? id;
  String customerCode;
  String name;
  String? companyName;
  String? phone;
  String? email;
  String? billingAddress;
  String? shippingAddress;
  String? gstin;
  String? pan;
  double creditLimit;
  String? paymentTerms;
  double openingBalance;
  String? grade; // Platinum | Diamond | Gold | Silver -- see widgets/grade_field.dart
  String status;

  Customer({
    this.id,
    required this.customerCode,
    required this.name,
    this.companyName,
    this.phone,
    this.email,
    this.billingAddress,
    this.shippingAddress,
    this.gstin,
    this.pan,
    this.creditLimit = 0,
    this.paymentTerms,
    this.openingBalance = 0,
    this.grade,
    this.status = 'Active',
  });

  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
        id: j['id'],
        customerCode: j['customer_code'],
        name: j['name'],
        companyName: j['company_name'],
        phone: j['phone'],
        email: j['email'],
        billingAddress: j['billing_address'],
        shippingAddress: j['shipping_address'],
        gstin: j['gstin'],
        pan: j['pan'],
        creditLimit: (j['credit_limit'] ?? 0).toDouble(),
        paymentTerms: j['payment_terms'],
        openingBalance: (j['opening_balance'] ?? 0).toDouble(),
        grade: j['grade'],
        status: j['status'] ?? 'Active',
      );

  Map<String, dynamic> toJson() => {
        'customer_code': customerCode,
        'name': name,
        'company_name': companyName,
        'phone': phone,
        'email': email,
        'billing_address': billingAddress,
        'shipping_address': shippingAddress,
        'gstin': gstin,
        'pan': pan,
        'credit_limit': creditLimit,
        'payment_terms': paymentTerms,
        'opening_balance': openingBalance,
        'grade': grade,
        'status': status,
      };
}

class Supplier {
  final int? id;
  String supplierCode;
  String name;
  String? companyName;
  String? phone;
  String? email;
  String? address;
  String? gstin;
  String? pan;
  String? paymentTerms;
  double creditLimit;
  double openingBalance;
  String status;

  Supplier({
    this.id,
    required this.supplierCode,
    required this.name,
    this.companyName,
    this.phone,
    this.email,
    this.address,
    this.gstin,
    this.pan,
    this.paymentTerms,
    this.creditLimit = 0,
    this.openingBalance = 0,
    this.status = 'Active',
  });

  factory Supplier.fromJson(Map<String, dynamic> j) => Supplier(
        id: j['id'],
        supplierCode: j['supplier_code'],
        name: j['name'],
        companyName: j['company_name'],
        phone: j['phone'],
        email: j['email'],
        address: j['address'],
        gstin: j['gstin'],
        pan: j['pan'],
        paymentTerms: j['payment_terms'],
        creditLimit: (j['credit_limit'] ?? 0).toDouble(),
        openingBalance: (j['opening_balance'] ?? 0).toDouble(),
        status: j['status'] ?? 'Active',
      );

  Map<String, dynamic> toJson() => {
        'supplier_code': supplierCode,
        'name': name,
        'company_name': companyName,
        'phone': phone,
        'email': email,
        'address': address,
        'gstin': gstin,
        'pan': pan,
        'payment_terms': paymentTerms,
        'credit_limit': creditLimit,
        'opening_balance': openingBalance,
        'status': status,
      };
}

// ---------------------------------------------------------------------------
// Phase 2: CRM + Sales flow -- Lead -> Customer, Sales Inquiry -> Quotation
// -> Sales Order. Field names below are a deliberate 1:1 mirror of
// backend/app/schemas/sales.py -- e.g. `quotation_no` (not
// `quotation_number`), item `remarks` (not `description`), Quotation/
// SalesOrder `notes` (not `terms`). Document numbers (LEAD-0001, INQ-0001,
// QTN-0001, SO-0001) are assigned by the backend's next_doc_no() -- leave
// the *No fields null/empty on create and the server fills them in.
// ---------------------------------------------------------------------------

class Lead {
  final int? id;
  String? leadCode; // server-assigned (LEAD-0001) if left blank on create
  String name;
  String? companyName;
  String? phone;
  String? email;
  String? source; // e.g. Website, Referral, Cold Call, Advertisement, Other
  String status; // New | Contacted | Qualified | Converted | Lost
  String? grade; // Platinum | Diamond | Gold | Silver -- see widgets/grade_field.dart
  String? notes;
  int? convertedCustomerId;

  Lead({
    this.id,
    this.leadCode,
    required this.name,
    this.companyName,
    this.phone,
    this.email,
    this.source,
    this.status = 'New',
    this.grade,
    this.notes,
    this.convertedCustomerId,
  });

  factory Lead.fromJson(Map<String, dynamic> j) => Lead(
        id: j['id'],
        leadCode: j['lead_code'],
        name: j['name'],
        companyName: j['company_name'],
        phone: j['phone'],
        email: j['email'],
        source: j['source'],
        status: j['status'] ?? 'New',
        grade: j['grade'],
        notes: j['notes'],
        convertedCustomerId: j['converted_customer_id'],
      );

  Map<String, dynamic> toJson() => {
        'lead_code': (leadCode == null || leadCode!.isEmpty) ? null : leadCode,
        'name': name,
        'company_name': companyName,
        'phone': phone,
        'email': email,
        'source': source,
        'status': status,
        'grade': grade,
        'notes': notes,
      };
}

/// One line of a Sales Inquiry -- just what the customer is asking about,
/// no pricing yet (pricing is decided when the Inquiry is converted to a
/// priced Quotation).
class InquiryItem {
  final int? id;
  int? productId;
  double quantity;
  String? remarks;

  InquiryItem({this.id, this.productId, this.quantity = 1, this.remarks});

  factory InquiryItem.fromJson(Map<String, dynamic> j) => InquiryItem(
        id: j['id'],
        productId: j['product_id'],
        quantity: (j['quantity'] ?? 1).toDouble(),
        remarks: j['remarks'],
      );

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'quantity': quantity,
        'remarks': remarks,
      };
}

class Inquiry {
  final int? id;
  String? inquiryNo; // server-assigned (INQ-0001) if left blank on create
  int? customerId; // backend requires customerId OR leadId, not both null
  int? leadId;
  String? inquiryDate; // yyyy-MM-dd
  String status; // Draft | Submitted | Approved | Cancelled
  /// Server-set: the document has been moved on to the next step, so
  /// its status is frozen (backend/app/core/workflow.py).
  final bool isLocked;
  /// Snapshot of the customer's addresses taken when the document is
  /// raised -- edited per document, never written back to the master.
  String? billingAddress;
  String? shippingAddress;
  String? notes;
  List<InquiryItem> items;

  Inquiry({
    this.id,
    this.inquiryNo,
    this.customerId,
    this.leadId,
    this.inquiryDate,
    this.status = 'Draft',
    this.isLocked = false,
    this.billingAddress,
    this.shippingAddress,
    this.notes,
    List<InquiryItem>? items,
  }) : items = items ?? [];

  factory Inquiry.fromJson(Map<String, dynamic> j) => Inquiry(
        id: j['id'],
        inquiryNo: j['inquiry_no'],
        customerId: j['customer_id'],
        leadId: j['lead_id'],
        inquiryDate: j['inquiry_date'],
        status: j['status'] ?? 'Draft',
        isLocked: j['is_locked'] ?? false,
        billingAddress: j['billing_address'],
        shippingAddress: j['shipping_address'],
        notes: j['notes'],
        items: ((j['items'] as List<dynamic>?) ?? [])
            .map((e) => InquiryItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'inquiry_no': (inquiryNo == null || inquiryNo!.isEmpty) ? null : inquiryNo,
        'customer_id': customerId,
        'lead_id': leadId,
        'inquiry_date': inquiryDate,
        'status': status,
        'billing_address': billingAddress,
        'shipping_address': shippingAddress,
        'notes': notes,
        'items': items.map((e) => e.toJson()).toList(),
      };
}

/// One priced line, shared shape between Quotation and Sales Order items
/// (backend: QuotationItemBase / SalesOrderItemBase are identical). Money
/// totals here (lineSubtotal/lineTax/lineTotal) are a CLIENT-SIDE PREVIEW
/// only, used while editing in DocLineItemsEditor before Save -- the
/// authoritative subtotal/tax/total live on the parent Quotation/SalesOrder
/// once the backend computes and returns them.
class DocLineItem {
  final int? id;
  int? productId;
  double quantity;
  double unitPrice;
  double discountPercent;
  int? taxId;
  double taxRatePercent; // client-only, looked up from the Tax list for live preview

  DocLineItem({
    this.id,
    this.productId,
    this.quantity = 1,
    this.unitPrice = 0,
    this.discountPercent = 0,
    this.taxId,
    this.taxRatePercent = 0,
  });

  double get discountedUnitPrice => unitPrice * (1 - (discountPercent / 100));
  double get lineSubtotal => discountedUnitPrice * quantity;
  double get lineTax => lineSubtotal * (taxRatePercent / 100);
  double get lineTotal => lineSubtotal + lineTax;

  factory DocLineItem.fromJson(Map<String, dynamic> j) => DocLineItem(
        id: j['id'],
        productId: j['product_id'],
        quantity: (j['quantity'] ?? 1).toDouble(),
        unitPrice: (j['unit_price'] ?? 0).toDouble(),
        discountPercent: (j['discount_percent'] ?? 0).toDouble(),
        taxId: j['tax_id'],
        // tax_rate_percent isn't a backend field -- callers that have the
        // Tax list (quotation/sales-order screens) backfill this via
        // withTaxRates() below so the editor's live preview has a rate.
      );

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'quantity': quantity,
        'unit_price': unitPrice,
        'discount_percent': discountPercent,
        'tax_id': taxId,
      };
}

/// Rebuilds [items] with `taxRatePercent` filled in from [taxes] (matched by
/// `taxId`), so re-opening an existing Quotation/Sales Order for editing
/// shows correct tax/total figures in the live preview immediately, not
/// just after the user re-touches each row's Tax dropdown.
List<DocLineItem> withTaxRates(List<DocLineItem> items, List<Tax> taxes) {
  return items.map((e) {
    double rate = 0;
    if (e.taxId != null) {
      final matches = taxes.where((t) => t.id == e.taxId);
      if (matches.isNotEmpty) rate = matches.first.ratePercent;
    }
    return DocLineItem(
      id: e.id,
      productId: e.productId,
      quantity: e.quantity,
      unitPrice: e.unitPrice,
      discountPercent: e.discountPercent,
      taxId: e.taxId,
      taxRatePercent: rate,
    );
  }).toList();
}

class Quotation {
  final int? id;
  String? quotationNo; // server-assigned (QTN-0001) if left blank on create
  int? inquiryId;
  int customerId;
  String? quotationDate;
  String? validUntil;
  String status; // Draft | Submitted | Approved | Cancelled
  /// Server-set: the document has been moved on to the next step, so
  /// its status is frozen (backend/app/core/workflow.py).
  final bool isLocked;
  /// Snapshot of the customer's addresses taken when the document is
  /// raised -- edited per document, never written back to the master.
  String? billingAddress;
  String? shippingAddress;
  String? notes;
  double subtotal;
  double discountAmount;
  double taxAmount;
  double totalAmount;
  List<DocLineItem> items;

  Quotation({
    this.id,
    this.quotationNo,
    this.inquiryId,
    required this.customerId,
    this.quotationDate,
    this.validUntil,
    this.status = 'Draft',
    this.isLocked = false,
    this.billingAddress,
    this.shippingAddress,
    this.notes,
    this.subtotal = 0,
    this.discountAmount = 0,
    this.taxAmount = 0,
    this.totalAmount = 0,
    List<DocLineItem>? items,
  }) : items = items ?? [];

  factory Quotation.fromJson(Map<String, dynamic> j) => Quotation(
        id: j['id'],
        quotationNo: j['quotation_no'],
        inquiryId: j['inquiry_id'],
        customerId: j['customer_id'],
        quotationDate: j['quotation_date'],
        validUntil: j['valid_until'],
        status: j['status'] ?? 'Draft',
        isLocked: j['is_locked'] ?? false,
        billingAddress: j['billing_address'],
        shippingAddress: j['shipping_address'],
        notes: j['notes'],
        subtotal: (j['subtotal'] ?? 0).toDouble(),
        discountAmount: (j['discount_amount'] ?? 0).toDouble(),
        taxAmount: (j['tax_amount'] ?? 0).toDouble(),
        totalAmount: (j['total_amount'] ?? 0).toDouble(),
        items: ((j['items'] as List<dynamic>?) ?? [])
            .map((e) => DocLineItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'quotation_no': (quotationNo == null || quotationNo!.isEmpty) ? null : quotationNo,
        'inquiry_id': inquiryId,
        'customer_id': customerId,
        'quotation_date': quotationDate,
        'valid_until': validUntil,
        'status': status,
        'billing_address': billingAddress,
        'shipping_address': shippingAddress,
        'notes': notes,
        'items': items.map((e) => e.toJson()).toList(),
      };
}

class SalesOrder {
  final int? id;
  String? orderNo; // server-assigned (SO-0001) if left blank on create
  int? quotationId;
  int customerId;
  String? orderDate;
  String status; // Draft | Submitted | Approved | Cancelled
  /// Server-set: the document has been moved on to the next step, so
  /// its status is frozen (backend/app/core/workflow.py).
  final bool isLocked;
  /// Snapshot of the customer's addresses taken when the document is
  /// raised -- edited per document, never written back to the master.
  String? billingAddress;
  String? shippingAddress;
  String? notes;
  double subtotal;
  double discountAmount;
  double taxAmount;
  double totalAmount;
  List<DocLineItem> items;

  SalesOrder({
    this.id,
    this.orderNo,
    this.quotationId,
    required this.customerId,
    this.orderDate,
    this.status = 'Draft',
    this.isLocked = false,
    this.billingAddress,
    this.shippingAddress,
    this.notes,
    this.subtotal = 0,
    this.discountAmount = 0,
    this.taxAmount = 0,
    this.totalAmount = 0,
    List<DocLineItem>? items,
  }) : items = items ?? [];

  factory SalesOrder.fromJson(Map<String, dynamic> j) => SalesOrder(
        id: j['id'],
        orderNo: j['order_no'],
        quotationId: j['quotation_id'],
        customerId: j['customer_id'],
        orderDate: j['order_date'],
        status: j['status'] ?? 'Draft',
        isLocked: j['is_locked'] ?? false,
        billingAddress: j['billing_address'],
        shippingAddress: j['shipping_address'],
        notes: j['notes'],
        subtotal: (j['subtotal'] ?? 0).toDouble(),
        discountAmount: (j['discount_amount'] ?? 0).toDouble(),
        taxAmount: (j['tax_amount'] ?? 0).toDouble(),
        totalAmount: (j['total_amount'] ?? 0).toDouble(),
        items: ((j['items'] as List<dynamic>?) ?? [])
            .map((e) => DocLineItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'order_no': (orderNo == null || orderNo!.isEmpty) ? null : orderNo,
        'quotation_id': quotationId,
        'customer_id': customerId,
        'order_date': orderDate,
        'status': status,
        'billing_address': billingAddress,
        'shipping_address': shippingAddress,
        'notes': notes,
        'items': items.map((e) => e.toJson()).toList(),
      };
}

// ---------------------------------------------------------------------------
// Phase 4: Purchase pipeline -- the supplier-facing mirror of Phase 2's
// Sales pipeline. Mirrors backend/app/schemas/purchase.py 1:1. No Lead-
// equivalent step here: Suppliers are already onboarded as masters, so the
// flow starts directly at Purchase Inquiry. Item shapes are identical to
// the Sales side, so this reuses InquiryItem (product_id/quantity/remarks)
// and DocLineItem (priced line) rather than duplicating them.
// ---------------------------------------------------------------------------

class PurchaseInquiry {
  final int? id;
  String? inquiryNo; // server-assigned (PINQ-0001) if left blank on create
  int supplierId;
  String? inquiryDate;
  String status; // Open | Quoted | Closed | Cancelled
  String? notes;
  List<InquiryItem> items;

  PurchaseInquiry({
    this.id,
    this.inquiryNo,
    required this.supplierId,
    this.inquiryDate,
    this.status = 'Open',
    this.notes,
    List<InquiryItem>? items,
  }) : items = items ?? [];

  factory PurchaseInquiry.fromJson(Map<String, dynamic> j) => PurchaseInquiry(
        id: j['id'],
        inquiryNo: j['inquiry_no'],
        supplierId: j['supplier_id'],
        inquiryDate: j['inquiry_date'],
        status: j['status'] ?? 'Open',
        notes: j['notes'],
        items: ((j['items'] as List<dynamic>?) ?? [])
            .map((e) => InquiryItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'inquiry_no': (inquiryNo == null || inquiryNo!.isEmpty) ? null : inquiryNo,
        'supplier_id': supplierId,
        'inquiry_date': inquiryDate,
        'status': status,
        'notes': notes,
        'items': items.map((e) => e.toJson()).toList(),
      };
}

class SupplierQuotation {
  final int? id;
  String? quotationNo; // server-assigned (SQTN-0001) if left blank on create
  int? inquiryId;
  int supplierId;
  String? quotationDate;
  String? validUntil;
  String status; // Draft | Received | Accepted | Rejected | Expired | Converted
  String? notes;
  double subtotal;
  double discountAmount;
  double taxAmount;
  double totalAmount;
  List<DocLineItem> items;

  SupplierQuotation({
    this.id,
    this.quotationNo,
    this.inquiryId,
    required this.supplierId,
    this.quotationDate,
    this.validUntil,
    this.status = 'Draft',
    this.notes,
    this.subtotal = 0,
    this.discountAmount = 0,
    this.taxAmount = 0,
    this.totalAmount = 0,
    List<DocLineItem>? items,
  }) : items = items ?? [];

  factory SupplierQuotation.fromJson(Map<String, dynamic> j) => SupplierQuotation(
        id: j['id'],
        quotationNo: j['quotation_no'],
        inquiryId: j['inquiry_id'],
        supplierId: j['supplier_id'],
        quotationDate: j['quotation_date'],
        validUntil: j['valid_until'],
        status: j['status'] ?? 'Draft',
        notes: j['notes'],
        subtotal: (j['subtotal'] ?? 0).toDouble(),
        discountAmount: (j['discount_amount'] ?? 0).toDouble(),
        taxAmount: (j['tax_amount'] ?? 0).toDouble(),
        totalAmount: (j['total_amount'] ?? 0).toDouble(),
        items: ((j['items'] as List<dynamic>?) ?? [])
            .map((e) => DocLineItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'quotation_no': (quotationNo == null || quotationNo!.isEmpty) ? null : quotationNo,
        'inquiry_id': inquiryId,
        'supplier_id': supplierId,
        'quotation_date': quotationDate,
        'valid_until': validUntil,
        'status': status,
        'notes': notes,
        'items': items.map((e) => e.toJson()).toList(),
      };
}

class PurchaseOrder {
  final int? id;
  String? orderNo; // server-assigned (PO-0001) if left blank on create
  int? quotationId;
  int supplierId;
  String? orderDate;
  String status; // Draft | Sent | Confirmed | Cancelled
  String? notes;
  double subtotal;
  double discountAmount;
  double taxAmount;
  double totalAmount;
  List<DocLineItem> items;

  PurchaseOrder({
    this.id,
    this.orderNo,
    this.quotationId,
    required this.supplierId,
    this.orderDate,
    this.status = 'Draft',
    this.notes,
    this.subtotal = 0,
    this.discountAmount = 0,
    this.taxAmount = 0,
    this.totalAmount = 0,
    List<DocLineItem>? items,
  }) : items = items ?? [];

  factory PurchaseOrder.fromJson(Map<String, dynamic> j) => PurchaseOrder(
        id: j['id'],
        orderNo: j['order_no'],
        quotationId: j['quotation_id'],
        supplierId: j['supplier_id'],
        orderDate: j['order_date'],
        status: j['status'] ?? 'Draft',
        notes: j['notes'],
        subtotal: (j['subtotal'] ?? 0).toDouble(),
        discountAmount: (j['discount_amount'] ?? 0).toDouble(),
        taxAmount: (j['tax_amount'] ?? 0).toDouble(),
        totalAmount: (j['total_amount'] ?? 0).toDouble(),
        items: ((j['items'] as List<dynamic>?) ?? [])
            .map((e) => DocLineItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'order_no': (orderNo == null || orderNo!.isEmpty) ? null : orderNo,
        'quotation_id': quotationId,
        'supplier_id': supplierId,
        'order_date': orderDate,
        'status': status,
        'notes': notes,
        'items': items.map((e) => e.toJson()).toList(),
      };
}

// ---------------------------------------------------------------------------
// Phase 3/5: Delivery/Sales Invoice/Customer Receipt (Sales side) and
// Goods Receipt/Purchase Invoice/Supplier Payment (Purchase side), plus
// Warehouse. Mirrors backend/app/schemas/{sales,purchase,masters}.py 1:1.
// GRN/Delivery items are quantity-only (reuse InquiryItem); Invoice items
// are priced (reuse DocLineItem) -- see those models' backend docstrings
// for why pricing lives on the Invoice, not the GRN/Delivery.
// ---------------------------------------------------------------------------

class Warehouse {
  final int? id;
  String name;
  String? code;
  String? address;
  String status;

  Warehouse({this.id, required this.name, this.code, this.address, this.status = 'Active'});

  factory Warehouse.fromJson(Map<String, dynamic> j) => Warehouse(
        id: j['id'],
        name: j['name'],
        code: j['code'],
        address: j['address'],
        status: j['status'] ?? 'Active',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'code': code,
        'address': address,
        'status': status,
      };
}

class GoodsReceipt {
  final int? id;
  String? grnNo;
  int? purchaseOrderId;
  int supplierId;
  int? warehouseId;
  String? receiptDate;
  String status; // Draft | Confirmed | Cancelled
  String? notes;
  List<InquiryItem> items;

  GoodsReceipt({
    this.id,
    this.grnNo,
    this.purchaseOrderId,
    required this.supplierId,
    this.warehouseId,
    this.receiptDate,
    this.status = 'Draft',
    this.notes,
    List<InquiryItem>? items,
  }) : items = items ?? [];

  factory GoodsReceipt.fromJson(Map<String, dynamic> j) => GoodsReceipt(
        id: j['id'],
        grnNo: j['grn_no'],
        purchaseOrderId: j['purchase_order_id'],
        supplierId: j['supplier_id'],
        warehouseId: j['warehouse_id'],
        receiptDate: j['receipt_date'],
        status: j['status'] ?? 'Draft',
        notes: j['notes'],
        items: ((j['items'] as List<dynamic>?) ?? [])
            .map((e) => InquiryItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'grn_no': (grnNo == null || grnNo!.isEmpty) ? null : grnNo,
        'purchase_order_id': purchaseOrderId,
        'supplier_id': supplierId,
        'warehouse_id': warehouseId,
        'receipt_date': receiptDate,
        'status': status,
        'notes': notes,
        'items': items.map((e) => e.toJson()).toList(),
      };
}

class PurchaseInvoice {
  final int? id;
  String? invoiceNo;
  int? purchaseOrderId;
  int supplierId;
  String? invoiceDate;
  String? dueDate;
  String status; // Draft | Posted | PartiallyPaid | Paid | Cancelled
  String? notes;
  double subtotal;
  double discountAmount;
  double taxAmount;
  double totalAmount;
  double amountPaid;
  List<DocLineItem> items;

  PurchaseInvoice({
    this.id,
    this.invoiceNo,
    this.purchaseOrderId,
    required this.supplierId,
    this.invoiceDate,
    this.dueDate,
    this.status = 'Draft',
    this.notes,
    this.subtotal = 0,
    this.discountAmount = 0,
    this.taxAmount = 0,
    this.totalAmount = 0,
    this.amountPaid = 0,
    List<DocLineItem>? items,
  }) : items = items ?? [];

  double get outstanding => totalAmount - amountPaid;

  factory PurchaseInvoice.fromJson(Map<String, dynamic> j) => PurchaseInvoice(
        id: j['id'],
        invoiceNo: j['invoice_no'],
        purchaseOrderId: j['purchase_order_id'],
        supplierId: j['supplier_id'],
        invoiceDate: j['invoice_date'],
        dueDate: j['due_date'],
        status: j['status'] ?? 'Draft',
        notes: j['notes'],
        subtotal: (j['subtotal'] ?? 0).toDouble(),
        discountAmount: (j['discount_amount'] ?? 0).toDouble(),
        taxAmount: (j['tax_amount'] ?? 0).toDouble(),
        totalAmount: (j['total_amount'] ?? 0).toDouble(),
        amountPaid: (j['amount_paid'] ?? 0).toDouble(),
        items: ((j['items'] as List<dynamic>?) ?? [])
            .map((e) => DocLineItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'invoice_no': (invoiceNo == null || invoiceNo!.isEmpty) ? null : invoiceNo,
        'purchase_order_id': purchaseOrderId,
        'supplier_id': supplierId,
        'invoice_date': invoiceDate,
        'due_date': dueDate,
        'status': status,
        'notes': notes,
        'items': items.map((e) => e.toJson()).toList(),
      };
}

class SupplierPayment {
  final int? id;
  String? paymentNo;
  int supplierId;
  int purchaseInvoiceId;
  String? paymentDate;
  double amount;
  String mode; // Cash | Bank | Cheque | UPI
  String? notes;

  SupplierPayment({
    this.id,
    this.paymentNo,
    required this.supplierId,
    required this.purchaseInvoiceId,
    this.paymentDate,
    required this.amount,
    this.mode = 'Bank',
    this.notes,
  });

  factory SupplierPayment.fromJson(Map<String, dynamic> j) => SupplierPayment(
        id: j['id'],
        paymentNo: j['payment_no'],
        supplierId: j['supplier_id'],
        purchaseInvoiceId: j['purchase_invoice_id'],
        paymentDate: j['payment_date'],
        amount: (j['amount'] ?? 0).toDouble(),
        mode: j['mode'] ?? 'Bank',
        notes: j['notes'],
      );

  Map<String, dynamic> toJson() => {
        'payment_no': (paymentNo == null || paymentNo!.isEmpty) ? null : paymentNo,
        'supplier_id': supplierId,
        'purchase_invoice_id': purchaseInvoiceId,
        'payment_date': paymentDate,
        'amount': amount,
        'mode': mode,
        'notes': notes,
      };
}

class Delivery {
  final int? id;
  String? deliveryNo;
  int? salesOrderId;
  int customerId;
  int? warehouseId;
  String? deliveryDate;
  String status; // Draft | Confirmed | Cancelled
  String? notes;
  List<InquiryItem> items;

  Delivery({
    this.id,
    this.deliveryNo,
    this.salesOrderId,
    required this.customerId,
    this.warehouseId,
    this.deliveryDate,
    this.status = 'Draft',
    this.notes,
    List<InquiryItem>? items,
  }) : items = items ?? [];

  factory Delivery.fromJson(Map<String, dynamic> j) => Delivery(
        id: j['id'],
        deliveryNo: j['delivery_no'],
        salesOrderId: j['sales_order_id'],
        customerId: j['customer_id'],
        warehouseId: j['warehouse_id'],
        deliveryDate: j['delivery_date'],
        status: j['status'] ?? 'Draft',
        notes: j['notes'],
        items: ((j['items'] as List<dynamic>?) ?? [])
            .map((e) => InquiryItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'delivery_no': (deliveryNo == null || deliveryNo!.isEmpty) ? null : deliveryNo,
        'sales_order_id': salesOrderId,
        'customer_id': customerId,
        'warehouse_id': warehouseId,
        'delivery_date': deliveryDate,
        'status': status,
        'notes': notes,
        'items': items.map((e) => e.toJson()).toList(),
      };
}

class SalesInvoice {
  final int? id;
  String? invoiceNo;
  int? salesOrderId;
  int customerId;
  String? invoiceDate;
  String? dueDate;
  String status; // Draft | Posted | PartiallyPaid | Paid | Cancelled
  String? notes;
  double subtotal;
  double discountAmount;
  double taxAmount;
  double totalAmount;
  double amountPaid;
  List<DocLineItem> items;

  SalesInvoice({
    this.id,
    this.invoiceNo,
    this.salesOrderId,
    required this.customerId,
    this.invoiceDate,
    this.dueDate,
    this.status = 'Draft',
    this.notes,
    this.subtotal = 0,
    this.discountAmount = 0,
    this.taxAmount = 0,
    this.totalAmount = 0,
    this.amountPaid = 0,
    List<DocLineItem>? items,
  }) : items = items ?? [];

  double get outstanding => totalAmount - amountPaid;

  factory SalesInvoice.fromJson(Map<String, dynamic> j) => SalesInvoice(
        id: j['id'],
        invoiceNo: j['invoice_no'],
        salesOrderId: j['sales_order_id'],
        customerId: j['customer_id'],
        invoiceDate: j['invoice_date'],
        dueDate: j['due_date'],
        status: j['status'] ?? 'Draft',
        notes: j['notes'],
        subtotal: (j['subtotal'] ?? 0).toDouble(),
        discountAmount: (j['discount_amount'] ?? 0).toDouble(),
        taxAmount: (j['tax_amount'] ?? 0).toDouble(),
        totalAmount: (j['total_amount'] ?? 0).toDouble(),
        amountPaid: (j['amount_paid'] ?? 0).toDouble(),
        items: ((j['items'] as List<dynamic>?) ?? [])
            .map((e) => DocLineItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'invoice_no': (invoiceNo == null || invoiceNo!.isEmpty) ? null : invoiceNo,
        'sales_order_id': salesOrderId,
        'customer_id': customerId,
        'invoice_date': invoiceDate,
        'due_date': dueDate,
        'status': status,
        'notes': notes,
        'items': items.map((e) => e.toJson()).toList(),
      };
}

class CustomerReceipt {
  final int? id;
  String? receiptNo;
  int customerId;
  int salesInvoiceId;
  String? receiptDate;
  double amount;
  String mode; // Cash | Bank | Cheque | UPI
  String? notes;

  CustomerReceipt({
    this.id,
    this.receiptNo,
    required this.customerId,
    required this.salesInvoiceId,
    this.receiptDate,
    required this.amount,
    this.mode = 'Bank',
    this.notes,
  });

  factory CustomerReceipt.fromJson(Map<String, dynamic> j) => CustomerReceipt(
        id: j['id'],
        receiptNo: j['receipt_no'],
        customerId: j['customer_id'],
        salesInvoiceId: j['sales_invoice_id'],
        receiptDate: j['receipt_date'],
        amount: (j['amount'] ?? 0).toDouble(),
        mode: j['mode'] ?? 'Bank',
        notes: j['notes'],
      );

  Map<String, dynamic> toJson() => {
        'receipt_no': (receiptNo == null || receiptNo!.isEmpty) ? null : receiptNo,
        'customer_id': customerId,
        'sales_invoice_id': salesInvoiceId,
        'receipt_date': receiptDate,
        'amount': amount,
        'mode': mode,
        'notes': notes,
      };
}

// ---------------------------------------------------------------------------
// Inventory: stock is never a stored column -- it is derived from the
// append-only StockLedger (backend/app/models/inventory.py). StockBalance
// mirrors the computed StockBalanceOut/ProductStockOut; StockLedgerEntry
// mirrors one raw movement row.
// ---------------------------------------------------------------------------

/// Per-warehouse slice of one product's stock (ProductStockOut.warehouses).
class WarehouseStock {
  final int? warehouseId;
  final String? warehouseName;
  final double quantityIn;
  final double quantityOut;
  final double onHand;

  WarehouseStock({
    this.warehouseId,
    this.warehouseName,
    this.quantityIn = 0,
    this.quantityOut = 0,
    this.onHand = 0,
  });

  factory WarehouseStock.fromJson(Map<String, dynamic> j) => WarehouseStock(
        warehouseId: j['warehouse_id'],
        warehouseName: j['warehouse_name'],
        quantityIn: (j['quantity_in'] ?? 0).toDouble(),
        quantityOut: (j['quantity_out'] ?? 0).toDouble(),
        onHand: (j['on_hand'] ?? 0).toDouble(),
      );

  /// "Unassigned" covers movements posted without a warehouse -- the
  /// backend keys those under a null warehouse_id rather than dropping them.
  String get displayName => warehouseName ?? 'Unassigned';
}

/// One product's on-hand position. Read-only -- there is no endpoint that
/// writes a balance; stock changes only by posting a movement.
class StockBalance {
  final int productId;
  final String productCode;
  final String productName;
  final int? unitId;
  final int? warehouseId; // echoes the requested filter, null = all warehouses
  final double quantityIn;
  final double quantityOut;
  final double onHand;
  final double minimumStock;
  final double reorderLevel;
  final bool isLowStock;
  final bool isOutOfStock;
  final double purchasePrice;
  final double stockValue;
  final List<WarehouseStock> warehouses; // only populated by /stock/product/{id}

  StockBalance({
    required this.productId,
    required this.productCode,
    required this.productName,
    this.unitId,
    this.warehouseId,
    this.quantityIn = 0,
    this.quantityOut = 0,
    this.onHand = 0,
    this.minimumStock = 0,
    this.reorderLevel = 0,
    this.isLowStock = false,
    this.isOutOfStock = false,
    this.purchasePrice = 0,
    this.stockValue = 0,
    this.warehouses = const [],
  });

  factory StockBalance.fromJson(Map<String, dynamic> j) => StockBalance(
        productId: j['product_id'],
        productCode: j['product_code'] ?? '',
        productName: j['product_name'] ?? '',
        unitId: j['unit_id'],
        warehouseId: j['warehouse_id'],
        quantityIn: (j['quantity_in'] ?? 0).toDouble(),
        quantityOut: (j['quantity_out'] ?? 0).toDouble(),
        onHand: (j['on_hand'] ?? 0).toDouble(),
        minimumStock: (j['minimum_stock'] ?? 0).toDouble(),
        reorderLevel: (j['reorder_level'] ?? 0).toDouble(),
        isLowStock: j['is_low_stock'] ?? false,
        isOutOfStock: j['is_out_of_stock'] ?? false,
        purchasePrice: (j['purchase_price'] ?? 0).toDouble(),
        stockValue: (j['stock_value'] ?? 0).toDouble(),
        warehouses: ((j['warehouses'] as List<dynamic>?) ?? [])
            .map((e) => WarehouseStock.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// Drives the coloured pill in the stock list. Out-of-stock wins over
  /// low-stock, matching the backend's stock_flags().
  String get stockStatus {
    if (isOutOfStock) return 'Out of Stock';
    if (isLowStock) return 'Low Stock';
    return 'In Stock';
  }
}

/// One movement row. Append-only on the backend -- there is no update or
/// delete, which is why this model has no toJson.
class StockLedgerEntry {
  final int id;
  final int productId;
  final String? productCode;
  final String? productName;
  final int? warehouseId;
  final String? warehouseName;
  final String movementType; // IN | OUT
  final double quantity;
  final String referenceType; // GoodsReceipt | Delivery | Adjustment
  final int? referenceId;
  final String movementDate;
  final String? notes;

  StockLedgerEntry({
    required this.id,
    required this.productId,
    this.productCode,
    this.productName,
    this.warehouseId,
    this.warehouseName,
    required this.movementType,
    required this.quantity,
    required this.referenceType,
    this.referenceId,
    required this.movementDate,
    this.notes,
  });

  factory StockLedgerEntry.fromJson(Map<String, dynamic> j) => StockLedgerEntry(
        id: j['id'],
        productId: j['product_id'],
        productCode: j['product_code'],
        productName: j['product_name'],
        warehouseId: j['warehouse_id'],
        warehouseName: j['warehouse_name'],
        movementType: j['movement_type'] ?? 'IN',
        quantity: (j['quantity'] ?? 0).toDouble(),
        referenceType: j['reference_type'] ?? '',
        referenceId: j['reference_id'],
        movementDate: j['movement_date'] ?? '',
        notes: j['notes'],
      );

  bool get isIn => movementType == 'IN';
}

// ---------------------------------------------------------------------------
// Tasks & Reminders: follow-up calls, payment reminders and to-do
// checklists (backend/app/models/tasks.py). One shape covers all three --
// they differ only by taskType and by what they point at.
// ---------------------------------------------------------------------------

const kTaskTypes = ['Follow-up', 'Payment Reminder', 'Call', 'Meeting', 'To-do'];
const kTaskPriorities = ['Low', 'Medium', 'High', 'Urgent'];
const kTaskStatuses = ['Pending', 'In Progress', 'Completed', 'Cancelled'];

class TaskChecklistItem {
  final int? id;
  final int? taskId;
  String title;
  bool isDone;
  int position;

  TaskChecklistItem(
      {this.id, this.taskId, required this.title, this.isDone = false, this.position = 0});

  factory TaskChecklistItem.fromJson(Map<String, dynamic> j) => TaskChecklistItem(
        id: j['id'],
        taskId: j['task_id'],
        title: j['title'] ?? '',
        isDone: j['is_done'] ?? false,
        position: j['position'] ?? 0,
      );

  Map<String, dynamic> toJson() => {'title': title, 'is_done': isDone, 'position': position};
}

class TaskModel {
  final int? id;
  final String? taskNo; // server-assigned (TSK-0001)
  String title;
  String? description;
  String taskType;
  String priority;
  String status;
  String? dueDate; // YYYY-MM-DD
  String? reminderDate;
  int? assignedToId;
  final String? assignedToName;
  int? customerId;
  int? leadId;
  int? supplierId;
  final String? partyName; // resolved customer / lead / supplier name
  String? referenceType;
  int? referenceId;
  final String? outcome;
  final String? completedAt;

  /// Derived server-side per request, never stored -- a persisted
  /// "overdue" flag would go stale at midnight.
  final bool isOverdue;
  List<TaskChecklistItem> checklist;
  final int checklistTotal;
  final int checklistDone;

  TaskModel({
    this.id,
    this.taskNo,
    required this.title,
    this.description,
    this.taskType = 'To-do',
    this.priority = 'Medium',
    this.status = 'Pending',
    this.dueDate,
    this.reminderDate,
    this.assignedToId,
    this.assignedToName,
    this.customerId,
    this.leadId,
    this.supplierId,
    this.partyName,
    this.referenceType,
    this.referenceId,
    this.outcome,
    this.completedAt,
    this.isOverdue = false,
    this.checklist = const [],
    this.checklistTotal = 0,
    this.checklistDone = 0,
  });

  factory TaskModel.fromJson(Map<String, dynamic> j) => TaskModel(
        id: j['id'],
        taskNo: j['task_no'],
        title: j['title'] ?? '',
        description: j['description'],
        taskType: j['task_type'] ?? 'To-do',
        priority: j['priority'] ?? 'Medium',
        status: j['status'] ?? 'Pending',
        dueDate: j['due_date'],
        reminderDate: j['reminder_date'],
        assignedToId: j['assigned_to_id'],
        assignedToName: j['assigned_to_name'],
        customerId: j['customer_id'],
        leadId: j['lead_id'],
        supplierId: j['supplier_id'],
        partyName: j['party_name'],
        referenceType: j['reference_type'],
        referenceId: j['reference_id'],
        outcome: j['outcome'],
        completedAt: j['completed_at'],
        isOverdue: j['is_overdue'] ?? false,
        checklist: ((j['checklist'] as List<dynamic>?) ?? [])
            .map((e) => TaskChecklistItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        checklistTotal: j['checklist_total'] ?? 0,
        checklistDone: j['checklist_done'] ?? 0,
      );

  /// [includeChecklist] only on create -- TaskUpdate has no checklist
  /// field, and sending one to PUT would be silently dropped anyway.
  Map<String, dynamic> toJson({bool includeChecklist = false}) => {
        'title': title,
        'description': description,
        'task_type': taskType,
        'priority': priority,
        'due_date': dueDate,
        'reminder_date': reminderDate,
        'assigned_to_id': assignedToId,
        'customer_id': customerId,
        'lead_id': leadId,
        'supplier_id': supplierId,
        'reference_type': referenceType,
        'reference_id': referenceId,
        if (includeChecklist) 'checklist': checklist.map((c) => c.toJson()).toList(),
      };

  bool get isOpen => status == 'Pending' || status == 'In Progress';
}
