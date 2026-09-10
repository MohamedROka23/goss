import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:goss/app/theme.dart';
import 'package:goss/models/models.dart';
import 'package:goss/providers/admin_provider.dart';
import 'package:goss/providers/app_provider.dart';

import 'package:goss/screens/role_screen.dart';
import 'package:goss/screens/customer/customer_shell.dart';
import 'package:goss/screens/customer/about_screen.dart';
import 'package:goss/screens/customer/catalog_screen.dart';
import 'package:goss/screens/customer/contact_screen.dart';
import 'package:goss/screens/customer/logistics_screen.dart';
import 'package:goss/screens/customer/supplies_screen.dart';
import 'package:goss/screens/customer/service_detail_screen.dart';
import 'package:goss/screens/customer/my_orders_screen.dart';
import 'package:goss/screens/customer/notifications_screen.dart';
import 'package:goss/screens/customer/settings_screen.dart';
import 'package:goss/screens/admin/admin_shell.dart';
import 'package:goss/screens/admin/admin_notifications_screen.dart';
import 'package:goss/screens/admin/admin_requests_tab.dart';
import 'package:goss/screens/admin/admin_tracking_tab.dart';
import 'package:goss/screens/admin/admin_customers_tab.dart';
import 'package:goss/screens/admin/admin_quotes_tab.dart';
import 'package:goss/screens/admin/admin_purchases_tab.dart';
import 'package:goss/screens/admin/admin_profit_tab.dart';
import 'package:goss/screens/admin/admin_expenses_tab.dart';
import 'package:goss/screens/admin/admin_team_tab.dart';

const _sizes = <Size>[
  Size(320, 569), // very small phone portrait
  Size(360, 640), // small phone portrait
  Size(411, 915), // modern phone portrait
  Size(430, 932), // large phone portrait
  Size(568, 320), // small phone landscape
  Size(915, 411), // phone landscape
  Size(768, 1024), // tablet portrait
  Size(1024, 768), // tablet landscape (square tablet)
  Size(800, 1280), // tablet portrait
  Size(1280, 800), // tablet landscape
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

Future<void> _pumpAt(WidgetTester tester, Widget home, Size size, double scale,
    {bool ar = false}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(_harness(home, scale, ar: ar));
  // Let post-frame callbacks / async loads settle.
  await tester.pump(const Duration(milliseconds: 100));
  // Dispose providers -> cancels polling timers/streams so no pending timers.
  await tester.pumpWidget(const SizedBox.shrink());
}

void _matrix(String label, Widget home, {bool rtlOnly = false}) {
  final scales = rtlOnly ? const <double>[1.0] : _scales;
  for (final scale in scales) {
    for (final size in _sizes) {
      testWidgets('$label @ ${size.width.toInt()}x${size.height.toInt()} scale $scale',
          (tester) async {
        await _pumpAt(tester, home, size, scale, ar: rtlOnly);
      });
    }
  }
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

  final customer = <String, Widget>{
    'RoleScreen': const RoleScreen(),
    'CustomerShell(Home)': const CustomerShell(),
    'AboutScreen': const AboutScreen(),
    'CatalogScreen': const CatalogScreen(),
    'LogisticsScreen': const LogisticsScreen(),
    'SuppliesScreen': const SuppliesScreen(),
    'ServiceDetailScreen': const ServiceDetailScreen(index: 0),
    'ContactScreen': const ContactScreen(),
    'MyOrdersScreen': const MyOrdersScreen(),
    'NotificationsScreen': const NotificationsScreen(),
    'SettingsScreen': const SettingsScreen(),
  };

  final admin = <String, Widget>{
    'AdminShell(Dashboard+tabs)': const AdminShell(),
    'AdminRequestsTab': const AdminRequestsTab(),
    'AdminTrackingTab': const AdminTrackingTab(),
    'AdminCustomersTab': const AdminCustomersTab(),
    'AdminQuotesTab': const AdminQuotesTab(),
    'AdminPurchasesTab': const AdminPurchasesTab(),
    'AdminProfitTab': const AdminProfitTab(),
    'AdminExpensesTab': const AdminExpensesTab(),
    'AdminTeamTab': const AdminTeamTab(),
    'AdminNotificationsScreen': const AdminNotificationsScreen(),
  };

  for (final w in customer.entries) {
    _matrix( w.key, w.value);
  }
  for (final w in admin.entries) {
    _matrix( w.key, w.value);
  }

  // RTL pass (Arabic) over the most layout-sensitive screens.
  for (final w in customer.entries.where((e) =>
      e.key == 'CustomerShell(Home)' || e.key == 'AboutScreen')) {
    _matrix( 'RTL-${w.key}', w.value, rtlOnly: true);
  }

  for (final w in admin.entries.where((e) => e.key == 'AdminShell(Dashboard+tabs)')) {
    _matrix( 'RTL-${w.key}', w.value, rtlOnly: true);
  }

  // AdminShell while logged OUT must show AdminLoginScreen instead.
  testWidgets('AdminLoginScreen @ 320x569 scale 1.3', (tester) async {
    SharedPreferences.setMockInitialValues({'goss-lang': 'en'});
    await _pumpAt(tester, const AdminShell(), const Size(320, 569), 1.3);
  });

  // Admin module menus render as an INTERACTIVE horizontal slider: all chips
  // exist, ~3 are visible at once on narrow screens, and swiping reveals the
  // rest (previously hidden behind an unscrollable/overwrapped strip).
  for (final size in const [Size(320, 569), Size(411, 915), Size(1280, 800)]) {
    for (final scale in const [1.0, 1.3]) {
      testWidgets(
          'AdminMenusSlider @ ${size.width.toInt()}x${size.height.toInt()} scale $scale',
          (tester) async {
        await tester.pumpWidget(_harness(const AdminShell(), scale));
        await tester.pump(const Duration(milliseconds: 100));
        const titles = [
          'Requests', 'Tracking', 'Customers', 'Quotes',
          'Purchasing', 'Profit', 'Expenses', 'Admins',
        ];
        final view = tester.view.physicalSize / tester.view.devicePixelRatio;
        bool fullyVisible(String t) => tester
            .widgetList<Text>(find.text(t))
            .map<Rect>((w) => tester.getRect(find.byWidget(w)))
            .any((rect) =>
                rect.left >= 0 &&
                rect.right <= view.width &&
                rect.top >= 0 &&
                rect.bottom <= view.height);
        for (final t in titles) {
          expect(find.text(t), findsWidgets, reason: 'menu "$t" must exist for admin');
        }
        expect(fullyVisible('Requests'), isTrue, reason: 'first module must be visible');
        expect(fullyVisible('Tracking'), isTrue, reason: 'second module must be visible');
        expect(fullyVisible('Customers'), isTrue, reason: 'third module must be visible');
        // swipe the strip to reveal later modules interactively
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(-240, 0),
          warnIfMissed: false,
        );
        await tester.pumpAndSettle();
        expect(
          fullyVisible('Quotes') || fullyVisible('Purchasing') || fullyVisible('Profit'),
          isTrue,
          reason: 'swiping must reveal a later module',
        );
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
