import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:goss/app/theme.dart';
import 'package:goss/providers/app_provider.dart';
import 'package:goss/providers/admin_provider.dart';
import 'package:goss/screens/customer/customer_shell.dart';

void main() {
  testWidgets('App builds without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppProvider()),
          ChangeNotifierProvider(create: (_) => AdminProvider()),
        ],
        child: MaterialApp(
          theme: gossTheme(),
          home: const CustomerShell(),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CustomerShell), findsOneWidget);
  });
}
