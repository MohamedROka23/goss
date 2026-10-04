import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'app/responsive.dart';
import 'app/theme.dart';
import 'models/chat_models.dart';
import 'providers/app_provider.dart';
import 'providers/admin_provider.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/customer/my_orders_screen.dart';
import 'screens/splash_screen.dart';
import 'security/rasp_guard.dart';
import 'security/screen_protection.dart';
import 'services/backend_manager.dart';
import 'services/fcm_service.dart';
import 'services/notification_watcher.dart';
import 'services/api_service.dart';

/// Global navigator key used by [FcmService] to deep-link from notification
/// taps when the user is not yet inside the main app widget tree.
final navigatorKey = GlobalKey<NavigatorState>();

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
  await _activateAppCheck();
  unawaited(ScreenProtection.secure());
  unawaited(RaspGuard.start());
  unawaited(FcmService.instance.init());
  unawaited(ApiService.refreshBaseUrl());
  unawaited(NotificationWatcher.instance.startCustomer());
  FcmService.instance.onOpen = _NotificationRouter.open;
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
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: gossTheme(isArabic: app.isArabic),
      darkTheme: gossDarkTheme(isArabic: app.isArabic),
      themeMode: app.themeMode,
      locale: app.locale,
      supportedLocales: const [Locale('en'), Locale('ar')],
      // Every scrollable in the app inherits this: momentum-based dragging
      // with consistent wheel and touch behaviour, so lists glide instead of
      // snapping and no screen has to opt in.
      scrollBehavior: const _GossScrollBehavior(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        final media = MediaQuery.of(context);
        // One adaptive hook for the whole app. Multiplying a device factor into
        // the system text scale resizes every piece of text — including the
        // ~260 hard-coded fontSize values across the screens — so a 7" or 10"
        // tablet gets proportional body copy while a small phone stays
        // legible, with no per-screen declarations.
        final adaptive = Responsive.of(context).scale;
        final system = media.textScaler.scale(1).clamp(0.85, 1.3);
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(system * adaptive),
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

Future<void> _activateAppCheck() async {
  try {
    if (kReleaseMode) {
      // Play Integrity: requires Play Console SHA-1 linkage + enforcement
      // toggle in Firebase Console → App Check → Play Integrity.
      // On Apple platforms deviceCheck is used (works on iOS 11+/macOS 11+).
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.playIntegrity,
        appleProvider: AppleProvider.deviceCheck,
      );
    } else {
      // Debug builds: debug attestation provider (emulators + debug builds).
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.debug,
        appleProvider: AppleProvider.debug,
      );
    }
  } catch (e) {
    if (kDebugMode) debugPrint('App Check activation error (non-fatal): $e');
  }
}

/// Lightweight notification deep-link router. Only the most important targets
/// are implemented; anything else simply opens the app.
class _NotificationRouter {
  _NotificationRouter._();

  static Future<void> open(Map<String, String> data) async {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    final type = data['type'] ?? '';
    final navi = Navigator.of(ctx, rootNavigator: true);

    switch (type) {
      case 'chat':
        final id = data['conversationId'] ?? '';
        final senderRole = data['senderRole'] ?? '';
        if (id.isEmpty) return;
        try {
          final doc = await FirebaseFirestore.instance
              .collection('chat_conversations')
              .doc(id)
              .get();
          if (doc.exists && ctx.mounted) {
            final conv = ChatConversation.fromDoc(doc);
            final role = senderRole == 'admin' ? 'customer' : 'admin';
            navi.push(
              MaterialPageRoute(builder: (_) => ChatScreen(conversation: conv, role: role)),
            );
          }
        } catch (_) {}
        return;
      case 'request_status':
        if (ctx.mounted) {
          navi.push(
            MaterialPageRoute(builder: (_) => const MyOrdersScreen()),
          );
        }
        return;
      default:
        // Fallback: just open the app (the last route is shown).
        return;
    }
  }
}
/// Global scroll tuning.
///
/// Android lists normally stop dead at the ends; iOS ones bounce. This gives
/// the whole app one behaviour: momentum everywhere, with the rubber-band
/// overscroll so a list that has reached its end still feels alive, and drag
/// devices enabled so a mouse or stylus scrolls the same way a finger does.
class _GossScrollBehavior extends MaterialScrollBehavior {
  const _GossScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // The default Material indicator draws a glowing vertical bar down the
    // screen edge. Dropping it keeps long lists visually calm.
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      );
}