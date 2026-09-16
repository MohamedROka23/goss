class Product {
  final String id;
  final String category;
  final String unit;
  final double price;
  final double costPrice;
  final double stock;
  final String nameEn;
  final String nameAr;
  final String descEn;
  final String descAr;

  Product({
    required this.id,
    required this.category,
    required this.unit,
    required this.price,
    this.costPrice = 0,
    this.stock = 0,
    required this.nameEn,
    required this.nameAr,
    required this.descEn,
    required this.descAr,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? '',
      category: json['category'] ?? '',
      unit: json['unit'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      costPrice: (json['costPrice'] ?? 0).toDouble(),
      stock: (json['stock'] ?? 0).toDouble(),
      nameEn: json['nameEn'] ?? '',
      nameAr: json['nameAr'] ?? '',
      descEn: json['descEn'] ?? '',
      descAr: json['descAr'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'unit': unit,
        'price': price,
        'costPrice': costPrice,
        'stock': stock,
        'nameEn': nameEn,
        'nameAr': nameAr,
        'descEn': descEn,
        'descAr': descAr,
      };

  Map<String, dynamic> toCreateJson() => {
        'category': category,
        'unit': unit,
        'price': price,
        'costPrice': costPrice,
        'stock': stock,
        'nameEn': nameEn,
        'nameAr': nameAr,
        'descEn': descEn,
        'descAr': descAr,
      };
}

class AdminUser {
  final String id;
  final String name;
  final String email;
  final String role;
  final List<String> permissions;

  AdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    List<String>? permissions,
  }) : permissions = permissions ?? defaultPermissionsFor(role);

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    final role = json['role'] ?? 'admin';
    final raw = json['permissions'];
    final perms = raw is List
        ? raw.map((e) => e.toString()).toList()
        : null;
    return AdminUser(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: role,
      permissions: perms,
    );
  }

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'email': email, 'role': role, 'permissions': permissions};
}

class PriceUpdateNotification {
  final String id;
  final String type;
  final String productId;
  final String productNameEn;
  final String productNameAr;
  final double oldPrice;
  final double newPrice;
  final String unit;
  final String createdAt;

  PriceUpdateNotification({
    required this.id,
    this.type = 'price_update',
    required this.productId,
    required this.productNameEn,
    required this.productNameAr,
    required this.oldPrice,
    required this.newPrice,
    required this.unit,
    required this.createdAt,
  });

  factory PriceUpdateNotification.fromJson(Map<String, dynamic> json) {
    return PriceUpdateNotification(
      id: json['id'] ?? '',
      type: json['type'] ?? 'price_update',
      productId: json['productId'] ?? '',
      productNameEn: json['productNameEn'] ?? '',
      productNameAr: json['productNameAr'] ?? '',
      oldPrice: (json['oldPrice'] ?? 0).toDouble(),
      newPrice: (json['newPrice'] ?? 0).toDouble(),
      unit: json['unit'] ?? '',
      createdAt: CustomerRequest._dateToString(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'productId': productId,
        'productNameEn': productNameEn,
        'productNameAr': productNameAr,
        'oldPrice': oldPrice,
        'newPrice': newPrice,
        'unit': unit,
        'createdAt': createdAt,
      };
}

class CartItem {
  final String productId;
  int qty;

  CartItem({required this.productId, required this.qty});

  factory CartItem.fromJson(Map<String, dynamic> json) {
    final raw = json['qty'];
    return CartItem(
      productId: json['productId'] ?? '',
      qty: raw is num ? raw.toInt().clamp(1, 9999) : 1,
    );
  }

  Map<String, dynamic> toJson() => {'productId': productId, 'qty': qty};
}

class RequestItem {
  final String productId;
  final String nameEn;
  final String nameAr;
  final int qty;
  final String unit;
  final double price;

  RequestItem({
    required this.productId,
    required this.nameEn,
    required this.nameAr,
    required this.qty,
    required this.unit,
    required this.price,
  });

  factory RequestItem.fromJson(Map<String, dynamic> json) {
    return RequestItem(
      productId: json['productId'] ?? '',
      nameEn: json['nameEn'] ?? '',
      nameAr: json['nameAr'] ?? '',
      qty: json['qty'] ?? 0,
      unit: json['unit'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'nameEn': nameEn,
        'nameAr': nameAr,
        'qty': qty,
        'unit': unit,
        'price': price,
      };
}

class CustomerRequest {
  final String id;
  final int orderNo;
  final String createdAt;
  String status;
  final String customerId;
  final String company;
  final String name;
  final String phone;
  final String email;
  final String notes;
  final String origin;
  final String destination;
  final List<RequestItem> items;
  final String type;

  /// Archived orders are hidden from the active admin requests list and live
  /// under the archive view. Archiving never deletes the underlying order.
  final bool archived;

  /// True once a price quote has been converted into a supply request, so the
  /// convert action cannot be repeated and duplicate orders are never created.
  final bool converted;

  /// Whether 14% VAT was included in the quote total.
  final bool vat;

  CustomerRequest({
    required this.id,
    this.orderNo = 0,
    required this.createdAt,
    required this.status,
    required this.customerId,
    required this.company,
    required this.name,
    required this.phone,
    required this.email,
    required this.notes,
    this.origin = '',
    this.destination = '',
    required this.items,
    this.type = 'supply',
    this.archived = false,
    this.converted = false,
    this.vat = false,
  });

  /// Human-readable sequential reference for the request:
  /// quotes GOSSTS01..., supply requests GOSSTT001... When no sequential
  /// number has been assigned yet, falls back to the short document id.
  String get orderLabel {
    if (orderNo > 0) return requestCodeFor(type, orderNo);
    return '#${id.split('-').first}';
  }

  static String _dateToString(dynamic v) {
    if (v == null) return '';
    if (v is DateTime) return v.toIso8601String();
    if (v is String) return v;
    // Firestore Timestamp
    try {
      final t = (v as dynamic);
      final seconds = t.seconds as int;
      final nanos = t.nanoseconds as int;
      return DateTime.fromMillisecondsSinceEpoch(
        seconds * 1000 + nanos ~/ 1000000,
        isUtc: true,
      ).toIso8601String();
    } catch (_) {
      return v.toString();
    }
  }

  factory CustomerRequest.fromJson(Map<String, dynamic> json) {
    final rawOrder = json['orderNo'];
    return CustomerRequest(
      id: json['id'] ?? '',
      orderNo: rawOrder is num ? rawOrder.toInt() : 0,
      createdAt: _dateToString(json['createdAt']),
      status: json['status'] ?? 'new',
      customerId: json['customerId'] ?? '',
      company: json['company'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      notes: json['notes'] ?? '',
      origin: json['origin'] ?? '',
      destination: json['destination'] ?? '',
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => RequestItem.fromJson(e))
          .toList(),
      type: json['type'] ?? 'supply',
      archived: json['archived'] ?? false,
      converted: json['converted'] ?? false,
      vat: json['vat'] ?? false,
    );
  }
}

class Expense {
  final String id;
  final String date;
  final String category;
  final String description;
  final double amount;

  Expense({
    required this.id,
    required this.date,
    required this.category,
    required this.description,
    required this.amount,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] ?? '',
      date: json['date'] ?? '',
      category: json['category'] ?? '',
      description: json['description'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'category': category,
        'description': description,
        'amount': amount,
      };
}

/// One debit/credit leg of a double-entry journal posting.
class JournalLine {
  final String accountCode;
  final String accountEn;
  final String accountAr;
  final double amount;

  const JournalLine({
    required this.accountCode,
    required this.accountEn,
    required this.accountAr,
    required this.amount,
  });

  factory JournalLine.fromJson(Map<String, dynamic> json) => JournalLine(
        accountCode: json['accountCode'] ?? '',
        accountEn: json['accountEn'] ?? '',
        accountAr: json['accountAr'] ?? '',
        amount: (json['amount'] ?? 0).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'accountCode': accountCode,
        'accountEn': accountEn,
        'accountAr': accountAr,
        'amount': amount,
      };
}

/// A balanced double-entry journal entry (debit side == credit side).
class JournalEntry {
  final String id;
  final String date;
  final String memo;
  final List<JournalLine> debits;
  final List<JournalLine> credits;
  final String createdAt;

  JournalEntry({
    required this.id,
    required this.date,
    required this.memo,
    required this.debits,
    required this.credits,
    required this.createdAt,
  });

  double get totalDebit => debits.fold(0, (n, l) => n + l.amount);
  double get totalCredit => credits.fold(0, (n, l) => n + l.amount);

  /// A posting is only book-kept when the debits equal the credits.
  bool get isBalanced => totalDebit > 0 && (totalDebit - totalCredit).abs() < 0.01;

  factory JournalEntry.fromJson(Map<String, dynamic> json) => JournalEntry(
        id: json['id'] ?? '',
        date: json['date'] ?? '',
        memo: json['memo'] ?? '',
        debits: (json['debits'] as List<dynamic>? ?? [])
            .map((e) => JournalLine.fromJson(e))
            .toList(),
        credits: (json['credits'] as List<dynamic>? ?? [])
            .map((e) => JournalLine.fromJson(e))
            .toList(),
        createdAt: CustomerRequest._dateToString(json['createdAt']),
      );

  Map<String, dynamic> toJson() => {
        'date': date,
        'memo': memo,
        'debits': debits.map((l) => l.toJson()).toList(),
        'credits': credits.map((l) => l.toJson()).toList(),
      };
}

/// Money received from a customer against one of their invoices (orders).
class Payment {
  final String id;
  final String requestId;
  final String customerId;
  final String company;
  final String name;
  final String date;
  final double amount;
  final String method;
  final String note;
  final String createdAt;

  Payment({
    required this.id,
    required this.requestId,
    required this.customerId,
    required this.company,
    required this.name,
    required this.date,
    required this.amount,
    this.method = 'cash',
    this.note = '',
    required this.createdAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
        id: json['id'] ?? '',
        requestId: json['requestId'] ?? '',
        customerId: json['customerId'] ?? '',
        company: json['company'] ?? '',
        name: json['name'] ?? '',
        date: json['date'] ?? '',
        amount: (json['amount'] ?? 0).toDouble(),
        method: json['method'] ?? 'cash',
        note: json['note'] ?? '',
        createdAt: CustomerRequest._dateToString(json['createdAt']),
      );

  Map<String, dynamic> toJson() => {
        'requestId': requestId,
        'customerId': customerId,
        'company': company,
        'name': name,
        'date': date,
        'amount': amount,
        'method': method,
        'note': note,
      };
}

class Purchase {
  final String id;
  final int orderNo;
  final String date;
  final String supplier;
  final String productId;
  final int qty;
  final double costPrice;

  /// Value-added tax recorded on the purchase invoice (0 when left empty).
  final double vat;

  /// Invoice total: goods value (qty * costPrice) plus VAT.
  final double total;

  Purchase({
    required this.id,
    this.orderNo = 0,
    required this.date,
    required this.supplier,
    required this.productId,
    required this.qty,
    required this.costPrice,
    this.vat = 0,
    required this.total,
  });

  String get code => purchaseCodeFor(orderNo);

  factory Purchase.fromJson(Map<String, dynamic> json) {
    final rawOrder = json['orderNo'];
    return Purchase(
      id: json['id'] ?? '',
      orderNo: rawOrder is num ? rawOrder.toInt() : 0,
      date: json['date'] ?? '',
      supplier: json['supplier'] ?? '',
      productId: json['productId'] ?? '',
      qty: json['qty'] ?? 0,
      costPrice: (json['costPrice'] ?? 0).toDouble(),
      vat: (json['vat'] ?? 0).toDouble(),
      total: (json['total'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'orderNo': orderNo,
        'date': date,
        'supplier': supplier,
        'productId': productId,
        'qty': qty,
        'costPrice': costPrice,
        'vat': vat,
        'total': total,
      };
}

const List<Map<String, String>> categories = [
  {'id': 'vegetables', 'en': 'Fresh Vegetables', 'ar': 'الخضروات الطازجة'},
  {'id': 'fruits', 'en': 'Fresh Fruits', 'ar': 'الفاكهة الطازجة'},
  {'id': 'general', 'en': 'General Goods', 'ar': 'عام'},
  {'id': 'office', 'en': 'Office Supplies', 'ar': 'الأدوات المكتبية'},
  {'id': 'hotel', 'en': 'Hotel Supplies', 'ar': 'أدوات فندقية'},
  {'id': 'restaurant', 'en': 'Restaurant Supplies', 'ar': 'لوازم المطاعم'},
  {'id': 'appliances', 'en': 'Appliances', 'ar': 'أجهزة'},
  {'id': 'packaging', 'en': 'Packaging & Wrapping Materials', 'ar': 'مواد التعبئة والتغليف'},
];

class ProductCategory {
  final String id;
  final String en;
  final String ar;
  const ProductCategory({required this.id, required this.en, required this.ar});

  factory ProductCategory.fromJson(Map<String, dynamic> json) =>
      ProductCategory(id: json['id'] ?? '', en: json['en'] ?? '', ar: json['ar'] ?? '');

  Map<String, dynamic> toJson() => {'id': id, 'en': en, 'ar': ar};
}

/// Request lifecycle: customer submits -> admin accepts -> fulfillment stages ->
/// delivered -> customer confirms delivery.
class RequestStatus {
  static const fresh = 'new';
  static const accepted = 'accepted';
  static const preparing = 'preparing';
  static const arriving = 'arriving';
  static const delivering = 'delivering';
  static const delivered = 'delivered';
  static const confirmed = 'confirmed';
  static const rejected = 'rejected';

  /// Forward journey stages (used by the customer/order timeline).
  static const List<String> stages = [
    fresh,
    accepted,
    preparing,
    arriving,
    delivering,
    delivered,
    confirmed,
  ];

  /// Every status the app knows about (admin status picker, chips, ...).
  static const List<String> all = [
    ...stages,
    rejected,
  ];

  /// Statuses sealed by the customer's decision (confirmed/rejected delivery).
  /// Once reached, the admin can no longer re-edit the order status.
  static const List<String> frozen = [
    confirmed,
    rejected,
  ];

  /// Whether a status is sealed and cannot be re-edited by the admin.
  static bool isFrozen(String status) => frozen.contains(status);

  /// Completed/terminal states (delivered + sealed). These are hidden from the
  /// active tracking/requests views and only live under the archive.
  static bool isDone(String status) =>
      status == delivered || frozen.contains(status);
}

const List<String> requestStatusValues = RequestStatus.all;

String requestStatusLabel(String status, {required bool ar}) {
  const en = {
    RequestStatus.fresh: 'New',
    RequestStatus.accepted: 'Accepted',
    RequestStatus.preparing: 'Preparing',
    RequestStatus.arriving: 'Arriving on site',
    RequestStatus.delivering: 'Delivering',
    RequestStatus.delivered: 'Delivered',
    RequestStatus.confirmed: 'Confirmed by customer',
    RequestStatus.rejected: 'Delivery rejected',
  };
  const arMap = {
    RequestStatus.fresh: 'جديد',
    RequestStatus.accepted: 'تم استلام الطلب',
    RequestStatus.preparing: 'جاري التجهيز',
    RequestStatus.arriving: 'جاري الوصول للموقع',
    RequestStatus.delivering: 'جاري التسليم',
    RequestStatus.delivered: 'تم التسليم',
    RequestStatus.confirmed: 'مؤكد التسليم',
    RequestStatus.rejected: 'تم رفض التسليم',
  };
  return (ar ? arMap : en)[status] ?? status;
}

/// Delivery promise shown once the admin/delegate accepts an order and sent in
/// the acceptance push notification.
String deliveryPromiseNote({required bool ar}) =>
    ar ? 'سيتم التسليم خلال 48 ساعة من وقت قبول الطلب.' : 'Delivery will be completed within 48 hours from order acceptance.';

/// Sequential code generators. Each operation type has its own prefix and
/// zero-padded digit count so codes are unique and identifiable.
String requestCodeFor(String type, int orderNo) {
  if (orderNo <= 0) return '';
  if (type == 'quote') return 'GOSSTS${orderNo.toString().padLeft(2, '0')}';
  return 'GOSSTT${orderNo.toString().padLeft(3, '0')}';
}

String purchaseCodeFor(int orderNo) {
  if (orderNo <= 0) return '';
  return 'GOSSTP${orderNo.toString().padLeft(4, '0')}';
}

/// Admin roles: super (owner), admin (full/permission-gated team member),
/// delegate (field/fulfilment agent), each granted permissions by the owner.
class AdminRole {
  static const super_ = 'super';
  static const admin = 'admin';
  static const delegate = 'delegate';
}

String adminRoleLabel(String role, {required bool ar}) {
  switch (role) {
    case AdminRole.super_:
      return ar ? 'المالك' : 'Owner';
    case AdminRole.delegate:
      return ar ? 'مندوب' : 'Delegate';
    default:
      return ar ? 'مسؤول' : 'Admin';
  }
}

/// Permission keys controlling which admin panels/tabs are visible.
class AdminPerms {
  static const requests = 'requests';
  static const customers = 'customers';
  static const quotes = 'quotes';
  static const purchases = 'purchases';
  static const profit = 'profit';
  static const expenses = 'expenses';
  static const tracking = 'tracking';
  static const team = 'team';
  static const accounting = 'accounting';
  static const chat = 'chat';
}

const List<String> allPermissionKeys = [
  AdminPerms.requests,
  AdminPerms.customers,
  AdminPerms.quotes,
  AdminPerms.purchases,
  AdminPerms.profit,
  AdminPerms.expenses,
  AdminPerms.tracking,
  AdminPerms.team,
  AdminPerms.accounting,
  AdminPerms.chat,
];

List<String> defaultPermissionsFor(String role) {
  if (role == AdminRole.delegate) {
    return [AdminPerms.requests, AdminPerms.customers, AdminPerms.tracking];
  }
  return [...allPermissionKeys];
}

String permissionLabel(String key, {required bool ar}) {
  const en = {
    AdminPerms.requests: 'Requests',
    AdminPerms.customers: 'Customers',
    AdminPerms.quotes: 'Quotes & Prices',
    AdminPerms.purchases: 'Purchasing',
    AdminPerms.profit: 'Profit',
    AdminPerms.expenses: 'Expenses',
    AdminPerms.tracking: 'Tracking orders',
    AdminPerms.team: 'Team & Permissions',
    AdminPerms.accounting: 'Accounting',
    AdminPerms.chat: 'Support chat',
  };
  const arMap = {
    AdminPerms.requests: 'الطلبات',
    AdminPerms.customers: 'العملاء',
    AdminPerms.quotes: 'عروض وتعديل الأسعار',
    AdminPerms.purchases: 'الشراء',
    AdminPerms.profit: 'الربح (النسبة والأرقام)',
    AdminPerms.expenses: 'المصاريف',
    AdminPerms.tracking: 'التراكنج أوردر',
    AdminPerms.team: 'الفريق والصلاحيات',
    AdminPerms.accounting: 'المحاسبة',
    AdminPerms.chat: 'شات خدمة العملاء',
  };
  return (ar ? arMap : en)[key] ?? key;
}
