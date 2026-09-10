import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:goss/providers/app_provider.dart';
import 'package:goss/providers/admin_provider.dart';
import 'package:goss/screens/splash_screen.dart';
import 'package:goss/screens/role_screen.dart';

void main() {
  testWidgets('SplashScreen animates the logo then opens RoleScreen',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppProvider()),
          ChangeNotifierProvider(create: (_) => AdminProvider()),
        ],
        child: const MaterialApp(home: SplashScreen()),
      ),
    );

    String logoAsset() =>
        (tester.widget<Image>(find.byType(Image)).image as AssetImage).assetName;

    final first = logoAsset();
    await tester.pump(const Duration(milliseconds: 40));
    expect(logoAsset(), isNot(first), reason: 'logo frames should advance');

    final second = logoAsset();
    await tester.pump(const Duration(milliseconds: 40));
    expect(logoAsset(), isNot(second), reason: 'logo keeps animating');

    // The whole loop plays for 2.2s, then the splash navigates away.
    await tester.pump(const Duration(milliseconds: 2400));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(RoleScreen), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);

    // Dispose everything so no timers remain pending.
    await tester.pumpWidget(const SizedBox.shrink());
  });
}