import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
import '../../app/theme.dart';
import '../../app/responsive.dart';
import '../../providers/admin_provider.dart';
import 'admin_login_screen.dart';
import 'admin_dashboard.dart';
import 'admin_notifications_screen.dart';
import 'admin_quick_lock_screen.dart';

/// Admin area wrapped in a proper scaffold with a branded app bar. Also hosts
/// the life-cycle observer that engages the quick lock (قفل سريع) whenever the
/// app is backgrounded with a locked session configured.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && mounted) {
      context.read<AppProvider>().markQuickLocked();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();

    // The shell is only a gate now. Header, navigation and content all belong
    // to the dashboard, which knows the permission-filtered module list; keeping
    // an AppBar here would stack a title bar above the navigation on wide
    // layouts, which is exactly what the redesign removes.
    if (!app.isLoggedIn) return const AdminLoginScreen();
    if (app.quickLockEnabled && app.quickLocked) {
      return const AdminQuickLockScreen();
    }
    return const AdminDashboard();
  }
}
