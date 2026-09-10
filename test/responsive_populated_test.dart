import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:goss/app/theme.dart';
import 'package:goss/models/models.dart';
import 'package:goss/providers/admin_provider.dart';
import 'package:goss/providers/app_provider.dart';

import 'package:goss/screens/customer/catalog_screen.dart';
import 'package:goss/screens/customer/my_orders_screen.dart';
import 'package:goss/screens/admin/admin_requests_tab.dart';
import 'package:goss/screens/admin/admin_tracking_tab.dart';
import 'package:goss/screens/admin/admin_customers_tab.dart';
import 'package:goss/screens/admin/admin_expenses_tab.dart';
import 'package:goss/screens/admin/admin_purchases_tab.dart';

/// Populated-content responsive sweep: every key screen renders REAL, long
/// Arabic/English business data (long company names, big numbers, many items,
/// edit/delete buttons) across small->large phones and tablets, at 1.0 and
/// 1.3 text scales, LTR and RTL. Any RenderFlex overflow is an exception.
const _sizes = <Size>[
  Size(320, 569),
  Size(360, 640),
  Size(411, 915),
  Size(430, 932),
  Size(915, 411),
  Size(800, 1280),
];
const _scales = <double>[1.0, 1.3];

Widget _harness(Widget home, double textScale, {bool ar = false}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AppProvider()),
      ChangeNotifierProvider(create: (_) => AdminProvider()),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: gossTheme(isArabic: ar),
      darkTheme: gossDarkTheme(isArabic: ar),
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      locale: ar ? const Locale('ar') : const Locale('en'),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        );
      },
      home: Scaffold(body: home),
    ),
  );
}

void _at(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

AppProvider appOf(WidgetTester tester) =>
    Provider.of<AppProvider>(tester.element(find.byType(MaterialApp)), listen: false);

AdminProvider admOf(WidgetTester tester) =>
    Provider.of<AdminProvider>(tester.element(find.byType(MaterialApp)), listen: false);

final _products = <Product>[
  Product(
    id: 'p1',
    category: 'vegetables',
    unit: 'kg',
    price: 1234.5,
    costPrice: 950.25,
    nameEn: 'Premium Grade A Fresh Egyptian Strawberries',
    nameAr: 'فراولة مصرية طازجة درجة أولى ممتازة مخصصة للتصدير',
    descEn: 'Hand-picked strawberries packed in export boxes with full traceability.',
    descAr: 'فراولة منتقاة يدوياً معبأة في صناديق تصدير مع تتبع كامل للمصدر.',
  ),
  Product(
    id: 'p2',
    category: 'fruits',
    unit: 'carton',
    price: 4567.89,
    costPrice: 3100.0,
    nameEn: 'Fresh Imported Bananas - Ecuador Origin',
    nameAr: 'موز مستورد طازج من الإكوادور - عبوة تصدير كبيرة',
    descEn: 'Large export cartons, cold-chain handled from farm to port.',
    descAr: 'كراتين تصدير كبيرة مبردة من المزرعة حتى الميناء.',
  ),
  Product(
    id: 'p3',
    category: 'packaging',
    unit: 'roll',
    price: 89.75,
    costPrice: 52.1,
    nameEn: 'Heavy Duty Stretch Film Wrapping 500m',
    nameAr: 'فيلم تغليف شريطي شديد التحمل بطول 500 متر',
    descEn: 'Industrial pallet wrapping film.',
    descAr: 'فيلم تغليف منصات صناعي.',
  ),
];

CustomerRequest _req(String id, String status) => CustomerRequest(
      id: id,
      orderNo: 1,
      createdAt: DateTime.now().toUtc().toIso8601String(),
      status: status,
      customerId: 'cust1',
      company: 'Global Outsourcing Services & Trading Company (GOSST)',
      name: 'Ahmed Mohamed Abdelrahman El-Sayed',
      phone: '+201011428818',
      email: 'ahmed.mohamed.abdelrahman@example-company.com',
      notes: 'يرجى التأكد من جودة التغليف قبل الشحن، والتسليم خلال يومين عمل كحد أقصى.',
      items: [
        RequestItem(
          productId: 'p1',
          nameEn: 'Premium Grade A Fresh Egyptian Strawberries',
          nameAr: 'فراولة مصرية طازجة درجة أولى ممتازة مخصصة للتصدير',
          qty: 250,
          unit: 'kg',
          price: 1234.5,
        ),
        RequestItem(
          productId: 'p2',
          nameEn: 'Fresh Imported Bananas - Ecuador Origin',
          nameAr: 'موز مستورد طازج من الإكوادور - عبوة تصدير كبيرة',
          qty: 80,
          unit: 'carton',
          price: 4567.89,
        ),
      ],
    );

final _expenses = <Expense>[
  Expense(
    id: 'e1',
    date: DateTime.now().toUtc().toIso8601String(),
    category: 'Transportation & Fuel Logistics',
    description: 'شحن ثلاجة تبريد من الإسكندرية للقاهرة مع مصاريف عوابر وطرق',
    amount: 1234567.89,
  ),
  Expense(
    id: 'e2',
    date: DateTime.now().toUtc().toIso8601String(),
    category: 'Warehouse Rent & Utilities',
    description: 'إيجار المخزن الشهري بجانب فواتير الكهرباء والمياه للمركز اللوجستي',
    amount: 987654.32,
  ),
];

final _purchases = <Purchase>[
  Purchase(
    id: 'a1',
    date: DateTime.now().toUtc().toIso8601String(),
    supplier: 'International Fresh Produce Trading Company LLC',
    productId: 'p1',
    qty: 9999,
    costPrice: 12345.67,
    total: 9999 * 12345.67,
  ),
  Purchase(
    id: 'a2',
    date: DateTime.now().toUtc().toIso8601String(),
    supplier: 'Ecuadorian Bananas Export Group',
    productId: 'p2',
    qty: 7500,
    costPrice: 8765.43,
    total: 7500 * 8765.43,
  ),
];

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'goss-lang': 'en',
      'goss-token': 'test-token',
      'goss-admin-permissions': allPermissionKeys,
      'goss-admin-role': 'admin',
    });
  });

  final build = <String, Widget>{
    'AdminRequestsTab': const AdminRequestsTab(),
    'AdminTrackingTab': const AdminTrackingTab(),
    'AdminCustomersTab': const AdminCustomersTab(),
    'AdminExpensesTab': const AdminExpensesTab(),
    'AdminPurchasesTab': const AdminPurchasesTab(),
    'MyOrdersScreen': const MyOrdersScreen(),
    'CatalogScreen': const CatalogScreen(),
  };

  void seed(String key, WidgetTester tester) {
    switch (key) {
      case 'AdminRequestsTab':
        admOf(tester).seedRequests([
          _req('r1', RequestStatus.fresh),
          _req('r2', RequestStatus.delivering),
          _req('r3', RequestStatus.rejected),
        ]);
        break;
      case 'AdminTrackingTab':
        admOf(tester).seedRequests([
          _req('r1', RequestStatus.preparing),
          _req('r2', RequestStatus.arriving),
        ]);
        break;
      case 'AdminCustomersTab':
        admOf(tester).seedRequests([
          _req('r1', RequestStatus.fresh),
          _req('r2', RequestStatus.confirmed),
          _req('r3', RequestStatus.delivering),
          _req('r4', RequestStatus.rejected),
        ]);
        break;
      case 'AdminExpensesTab':
        admOf(tester).seedExpenses(_expenses);
        break;
      case 'AdminPurchasesTab':
        appOf(tester).seedProducts(_products);
        admOf(tester).seedPurchases(_purchases);
        break;
      case 'MyOrdersScreen':
        appOf(tester).seedMyRequests([
          _req('r1', RequestStatus.delivering),
          _req('r2', RequestStatus.delivered),
          _req('r3', RequestStatus.rejected),
          _req('r4', RequestStatus.fresh),
        ]);
        break;
      case 'CatalogScreen':
        appOf(tester).seedProducts(_products);
        break;
    }
  }

  Future<void> pump(WidgetTester tester, String key, Size size, double scale, bool ar) async {
    _at(tester, size);
    await tester.pumpWidget(_harness(build[key]!, scale, ar: ar));
    await tester.pump(const Duration(milliseconds: 100));
    seed(key, tester);
    await tester.pump();
    expect(tester.takeException(), isNull,
        reason: '$key must not overflow with populated data');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpWidget(const SizedBox.shrink());
  }

  for (final scale in _scales) {
    for (final size in _sizes) {
      for (final key in build.keys) {
        testWidgets('P $key @ ${size.width.toInt()}x${size.height.toInt()} scale $scale',
            (tester) async {
          await pump(tester, key, size, scale, false);
        });
      }
    }
  }

  // RTL (Arabic) pass over the most data-dense screens at max phone size + scale.
  for (final size in const [Size(320, 569), Size(411, 915), Size(430, 932)]) {
    for (final key in build.keys) {
      testWidgets('P-RTL $key @ ${size.width.toInt()}x${size.height.toInt()} scale 1.3',
          (tester) async {
        SharedPreferences.setMockInitialValues({
          'goss-lang': 'ar',
          'goss-token': 'test-token',
          'goss-admin-permissions': allPermissionKeys,
          'goss-admin-role': 'admin',
        });
        await pump(tester, key, size, 1.3, true);
      });
    }
  }
}