import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'app/theme.dart';
import 'providers/app_provider.dart';
import 'providers/admin_provider.dart';
import 'screens/splash_screen.dart';
import 'services/backend_manager.dart';
import 'services/fcm_service.dart';
import 'services/api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Surface any uncaught framework/platform error instead of failing silently.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    if (kDebugMode) debugPrint('Flutter error: ${details.exceptionAsString()}');
  };
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    if (kDebugMode) debugPrint('Uncaught platform error: $error\n$stack');
    return true;
  };
  await BackendManager.initializeFirebase();
  unawaited(FcmService.instance.init());
  unawaited(ApiService.refreshBaseUrl());
  if (kDebugMode) SemanticsBinding.instance.ensureSemantics();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
      ],
      child: const GossApp(),
    ),
  );
}

class GossApp extends StatelessWidget {
  const GossApp({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();

    return MaterialApp(
      title: 'GOSST',
      debugShowCheckedModeBanner: false,
      theme: gossTheme(isArabic: app.isArabic),
      darkTheme: gossDarkTheme(isArabic: app.isArabic),
      themeMode: app.themeMode,
      locale: app.locale,
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        // Clamp the system text scale so accessibility font sizes never
        // overflow the fixed-height cards, grids, buttons and chips used
        // throughout the app. (1.0–1.3 keeps content readable on every screen.)
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(maxScaleFactor: 1.3),
          ),
          child: Directionality(
            textDirection: app.isArabic ? TextDirection.rtl : TextDirection.ltr,
            child: child!,
          ),
        );
      },
      home: const SplashScreen(),
    );
  }
}
