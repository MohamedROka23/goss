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
import 'package:goss/screens/customer/customer_shell.dart';
import 'package:goss/screens/customer/my_orders_screen.dart';
import 'package:goss/screens/admin/admin_shell.dart';
import 'package:goss/screens/admin/admin_requests_tab.dart';
import 'package:goss/screens/admin/admin_quotes_tab.dart';

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

final _tomato = Product(
  id: 'p1',
  category: 'vegetables',
  unit: 'kg',
  price: 18.5,
  costPrice: 12,
  nameEn: 'Fresh Tomato',
  nameAr: 'طماطم طازجة',
  descEn: 'Fresh and ripe tomatoes',
  descAr: 'طماطم طازجة وناضجة',
);
final _banana = Product(
  id: 'p2',
  category: 'fruits',
  unit: 'kg',
  price: 22,
  costPrice: 16,
  nameEn: 'Banana',
  nameAr: 'موز',
  descEn: 'Sweet bananas',
  descAr: 'موز حلو',
);
final _products = [_tomato, _banana];

CustomerRequest _req(String id, String status) => CustomerRequest(
      id: id,
      createdAt: DateTime.now().toUtc().toIso8601String(),
      status: status,
      customerId: 'cust1',
      company: 'Acme',
      name: 'Ahmed',
      phone: '01234567890',
      email: 'ahmed@acme.com',
      notes: '',
      items: [
        RequestItem(
          productId: 'p1',
          nameEn: 'Fresh Tomato',
          nameAr: 'طماطم طازجة',
          qty: 2,
          unit: 'kg',
          price: 18.5,
        ),
      ],
    );

Future<void> _dismissSnackBars(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

/// Scrolls an in-body button into view, then taps it (catalog/shell/orders
/// content lives inside scrollables, so buttons can sit below the fold).
Future<void> _tapScroll(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder, warnIfMissed: false);
  await tester.pumpAndSettle();
}

/// Like [_tapScroll] but drags the scrollable until the target is really
/// hit-testable. `ensureVisible` with long forms + small viewports can scroll
/// the button out of the screen and silently miss the tap.
Future<void> _tapScrollDown(WidgetTester tester, Finder finder) async {
  await tester.dragUntilVisible(
    finder,
    find.byType(Scrollable).first,
    const Offset(0, -120),
    maxIteration: 40,
  );
  await tester.pumpAndSettle();
  await tester.tap(finder, warnIfMissed: false);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'goss-lang': 'en',
      'goss-token': 'test-token',
      'goss-admin-permissions': allPermissionKeys,
      'goss-admin-role': 'admin',
    });
  });

  // ── Catalog: products grid, cart, input validation, send ──────────────
  testWidgets('catalog cart flow + input validation @ 320x569 scale 1.3', (tester) async {
    _at(tester, const Size(320, 569));
    await tester.pumpWidget(_harness(const CatalogScreen(), 1.3));
    await tester.pump(const Duration(milliseconds: 100));
    appOf(tester).seedProducts(_products);
    await tester.pump();
    expect(find.text('Fresh Tomato'), findsWidgets);
    expect(find.text('Banana'), findsWidgets);

    await _tapScroll(tester, find.text('Add to request').first);
    expect(find.text('Customer request'), findsOneWidget);

    await _tapScrollDown(tester, find.text('Send request'));
    await tester.pump();
    expect(find.text('Please enter your name.'), findsOneWidget);

    // order of TextFields: search(0), qty(1), company(2), name(3), phone(4), email(5), origin(6), destination(7), notes(8)
    await tester.enterText(find.byType(TextField).at(3), 'Ahmed');
    await tester.enterText(find.byType(TextField).at(4), '01234567890');
    await tester.enterText(find.byType(TextField).at(5), 'not-an-email');
    await _tapScrollDown(tester, find.text('Send request'));
    await tester.pump();
    expect(find.text('Please enter a valid email address.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(5), 'ahmed@acme.com');
    await _tapScrollDown(tester, find.text('Send request'));
    expect(find.text('Confirm request'), findsOneWidget);
    await tester.tap(find.text('Send').last);
    await tester.pumpAndSettle();
    expect(
      find.text('Failed to send the request. Check your connection and try again.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // ── My Orders: accept/reject buttons + reject confirmation ────────────
  testWidgets('my orders reject confirm flow @ 320x569 scale 1.3', (tester) async {
    _at(tester, const Size(320, 569));
    await tester.pumpWidget(_harness(const MyOrdersScreen(), 1.3));
    await tester.pump(const Duration(milliseconds: 100));
    appOf(tester).seedMyRequests([_req('r1', RequestStatus.delivering)]);
    await tester.pump();
    expect(find.text('Accept delivery'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);

    // cancel path
    await _tapScroll(tester, find.text('Reject'));
    expect(find.text('Reject delivery'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Reject delivery'), findsNothing);

    // confirm path -> backend fails -> error snackbar (command handled safely)
    await _tapScroll(tester, find.text('Reject'));
    await tester.tap(find.text('Reject').last);
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);
    await _dismissSnackBars(tester);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // ── Admin Requests: cards render with data (RTL) + status picker ──────
  testWidgets('admin requests cards + status picker @ 411x915 RTL scale 1.0', (tester) async {
    SharedPreferences.setMockInitialValues({
      'goss-lang': 'ar',
      'goss-token': 'test-token',
      'goss-admin-permissions': allPermissionKeys,
      'goss-admin-role': 'admin',
    });
    _at(tester, const Size(411, 915));
    await tester.pumpWidget(_harness(const AdminRequestsTab(), 1.0, ar: true));
    await tester.pump(const Duration(milliseconds: 100));
    admOf(tester).seedRequests([
      _req('r1', RequestStatus.fresh),
      _req('r2', RequestStatus.confirmed),
      _req('r3', RequestStatus.delivering),
    ]);
    await tester.pump();
    expect(find.text('Ahmed · Acme'), findsWidgets);
    expect(find.text('قبول الطلب'), findsOneWidget);
    expect(find.text('مؤكد التسليم'), findsWidgets);

    // third card may sit below the lazy viewport -> scroll to it, then back
    await tester.fling(find.byType(ListView), const Offset(0, -400), 1200);
    await tester.pumpAndSettle();
    expect(find.text('Ahmed · Acme'), findsNWidgets(3));
    await tester.fling(find.byType(ListView), const Offset(0, 400), 1200);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButton<String>).first);
    await tester.pumpAndSettle();
    expect(find.text('تم استلام الطلب'), findsWidgets);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // ── Admin Quotes: product rows + Add-section dialog command + inputs ──
  testWidgets('admin quotes add-section command @ 320x569 scale 1.3', (tester) async {
    _at(tester, const Size(320, 569));
    await tester.pumpWidget(_harness(const AdminQuotesTab(), 1.3));
    await tester.pump(const Duration(milliseconds: 100));
    appOf(tester).seedProducts([_tomato]);
    await tester.pump();
    // sections sit below the fold in a lazy ListView -> scroll down to build them
    await tester.dragUntilVisible(
      find.text('Fresh Tomato'),
      find.byType(ListView),
      const Offset(0, -150),
    );
    expect(find.text('Fresh Tomato'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Add section'),
      find.byType(ListView),
      const Offset(0, 150),
    );

    await tester.tap(find.text('Add section'));
    await tester.pumpAndSettle();
    expect(find.text('Add a new section'), findsOneWidget);
    final dialog = find.byType(AlertDialog);
    await tester.enterText(
      find.descendant(of: dialog, matching: find.byType(TextField)).at(0),
      'Trucking',
    );
    await tester.enterText(
      find.descendant(of: dialog, matching: find.byType(TextField)).at(1),
      'نقل',
    );
    await tester.tap(find.descendant(of: dialog, matching: find.text('Add')));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);
    await _dismissSnackBars(tester);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // ── Admin change-password dialog: input validation ────────────────────
  testWidgets('admin change-password dialog validation @ 320x569 scale 1.3', (tester) async {
    _at(tester, const Size(320, 569));
    await tester.pumpWidget(_harness(const AdminShell(), 1.3));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byIcon(Icons.lock));
    await tester.pumpAndSettle();
    expect(find.text('Change password'), findsOneWidget);
    final dialog = find.byType(AlertDialog);
    // fields: email(0), old(1), new(2), confirm(3)
    await tester.enterText(
      find.descendant(of: dialog, matching: find.byType(TextField)).at(2),
      '123456',
    );
    await tester.enterText(
      find.descendant(of: dialog, matching: find.byType(TextField)).at(3),
      '654321',
    );
    await tester.tap(find.descendant(of: dialog, matching: find.text('Save')));
    await tester.pumpAndSettle();
    expect(find.text('Passwords do not match.'), findsOneWidget);

    await tester.enterText(
      find.descendant(of: dialog, matching: find.byType(TextField)).at(2),
      '12345',
    );
    await tester.enterText(
      find.descendant(of: dialog, matching: find.byType(TextField)).at(3),
      '12345',
    );
    await tester.tap(find.descendant(of: dialog, matching: find.text('Save')));
    await tester.pumpAndSettle();
    expect(find.text('New password must be at least 6 characters.'), findsOneWidget);

    await tester.tap(find.descendant(of: dialog, matching: find.text('Cancel')));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // ── Customer drawer navigation commands ────────────────────────────────
  testWidgets('customer drawer navigation @ 320x569 scale 1.0', (tester) async {
    _at(tester, const Size(320, 569));
    await tester.pumpWidget(_harness(const CustomerShell(), 1.0));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(find.text('Logistics Services'), findsOneWidget);
    await tester.tap(find.text('Logistics Services'));
    await tester.pumpAndSettle();
    expect(find.text('Logistics & Shipping Operations'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supplies & Trade'));
    await tester.pumpAndSettle();
    expect(find.text('Supplies & Trade'), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // ── Admin slider: chevron buttons reveal later modules ────────────────
  testWidgets('admin slider chevron nav buttons @ 430x932 scale 1.0', (tester) async {
    _at(tester, const Size(430, 932));
    await tester.pumpWidget(_harness(const AdminShell(), 1.0));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    bool fullyVisible(String t) => tester
        .widgetList<Text>(find.text(t))
        .map<Rect>((w) => tester.getRect(find.byWidget(w)))
        .any((rect) => rect.left >= 0 && rect.right <= 430);
    expect(fullyVisible('Requests'), isTrue);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget,
        reason: 'strip overflows 430px so the right chevron must appear');
    expect(find.byIcon(Icons.chevron_left), findsNothing);
    await tester.tap(find.byIcon(Icons.chevron_right).last);
    await tester.pumpAndSettle();
    expect(
      fullyVisible('Purchasing') || fullyVisible('Profit') || fullyVisible('Accounting'),
      isTrue,
      reason: 'right chevron must slide the strip forward',
    );
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    await tester.tap(find.byIcon(Icons.chevron_left).first);
    await tester.pumpAndSettle();
    expect(fullyVisible('Requests'), isTrue, reason: 'left chevron must slide back');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}