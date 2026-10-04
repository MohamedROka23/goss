import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
import '../../providers/admin_provider.dart';
import '../../app/icons.dart';
import '../../app/spacing.dart';
import '../../app/theme.dart';
import '../../app/responsive.dart';
import '../../app/motion.dart';
import '../../models/models.dart';
import '../../services/notification_watcher.dart';
import '../../widgets/icon_3d.dart';
import '../../widgets/premium_header.dart';
import '../../widgets/premium_nav.dart';
import 'admin_quotes_tab.dart';
import 'admin_purchases_tab.dart';
import 'admin_requests_tab.dart';
import 'admin_team_tab.dart';
import 'admin_customers_tab.dart';
import 'admin_tracking_tab.dart';
import 'admin_chat_tab.dart';
import 'accounting/admin_accounting_tab.dart';
import 'admin_settings_tab.dart';
import 'admin_notifications_screen.dart';
import 'change_password_dialog.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final app = context.read<AppProvider>();
      final admin = context.read<AdminProvider>();
      if (app.token != null) {
        // Live subscriptions, not one-shot loads: every write on any device
        // (a status change, a new order, an expense, a deletion, a permission
        // change) is pushed to this screen the moment it commits. The one-shot
        // loads stay as the immediate first paint and as the retry path.
        admin.loadRequests(app.token!);
        admin.loadExpenses(app.token!);
        admin.loadPurchases(app.token!);
        admin.loadJournal(app.token!);
        admin.loadPayments(app.token!);
        admin.startWatchingRequests(app.token!);
        admin.startWatchingCollections(app.token!);
        app.resolveCurrentAdmin();
        // Team-side notification watcher: new requests + chat messages.
        String uid = '';
        try {
          uid = FirebaseAuth.instance.currentUser?.uid ?? '';
        } catch (_) {
          // Firebase not initialized (e.g. widget tests without a backend).
        }
        if (uid.isNotEmpty) {
          unawaited(NotificationWatcher.instance.startAdmin(uid));
        }
      }
    });
  }

  void _select(int index, void Function()? onRequestsTab) {
    onRequestsTab?.call();
    setState(() => _tab = index);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final admin = context.watch<AdminProvider>();
    final en = !app.isArabic;

    final tabs = <(String, _Tab, Widget)>[
      (
        AdminPerms.requests,
        _Tab(
          title: en ? 'Requests' : '\u0627\u0644\u0637\u0644\u0628\u0627\u062a',
          icon: AppIcons.orders,
        ),
        const AdminRequestsTab(),
      ),
      (
        AdminPerms.tracking,
        _Tab(
          title: en ? 'Tracking' : '\u0627\u0644\u062a\u0631\u0627\u0643\u0646\u062c \u0623\u0648\u0631\u062f\u0631',
          icon: AppIcons.tracking,
        ),
        const AdminTrackingTab(),
      ),
      (
        AdminPerms.customers,
        _Tab(
          title: en
              ? 'Customers'
              : '\u0627\u0644\u0639\u0645\u0644\u0627\u0621',
          icon: AppIcons.customers,
        ),
        const AdminCustomersTab(),
      ),
      (
        AdminPerms.quotes,
        _Tab(
          title: en
              ? 'Products'
              : '\u0627\u0644\u0645\u0646\u062a\u062c\u0627\u062a',
          icon: AppIcons.products,
        ),
        const AdminQuotesTab(),
      ),
      (
        AdminPerms.purchases,
        _Tab(
          title: en ? 'Purchasing' : '\u0627\u0644\u0634\u0631\u0627\u0621',
          icon: AppIcons.purchases,
        ),
        const AdminPurchasesTab(),
      ),
      (
        AdminPerms.accounting,
        _Tab(
          title: en
              ? 'Accounting'
              : '\u0627\u0644\u0645\u062d\u0627\u0633\u0628\u0629',
          icon: AppIcons.accounting,
        ),
        AdminAccountingTab(onBack: () => _select(0, null)),
      ),
      (
        AdminPerms.team,
        _Tab(
          title: en ? 'Admins' : '\u0627\u0644\u0641\u0631\u064a\u0642',
          icon: AppIcons.team,
        ),
        const AdminTeamTab(),
      ),
      (
        AdminPerms.chat,
        _Tab(
          title: en ? 'Support' : '\u0627\u0644\u062f\u0639\u0645',
          icon: AppIcons.chat,
        ),
        const AdminChatTab(),
      ),
    ].where((t) => app.can(t.$1)).toList();

    tabs.add((
      'settings',
      _Tab(
        title: en
            ? 'Settings'
            : '\u0627\u0644\u0625\u0639\u062f\u0627\u062f\u0627\u062a',
        icon: AppIcons.settings,
      ),
      const AdminSettingsTab(),
    ));

    if (_tab >= tabs.length) _tab = tabs.isEmpty ? 0 : tabs.length - 1;

    if (tabs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            en
                ? 'No panels are enabled for your account. Contact the team owner.'
                : 'لا توجد أقسام مفعلة لحسابك. تواصل مع مالك الفريق.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.mutedColor),
          ),
        ),
      );
    }

    final requestsIndex = tabs.indexWhere((t) => t.$1 == AdminPerms.requests);

    // Permission-filtered destinations. Settings is always present, appended
    // after the gated modules exactly as before.
    final destinations = <NavDestination>[
      for (var i = 0; i < tabs.length; i++)
        NavDestination(
          id: '$i',
          label: tabs[i].$2.title,
          icon: tabs[i].$2.icon,
          badge: i == requestsIndex ? admin.unreadRequests : null,
          // Settings is the account group rather than a module.
          tone: tabs[i].$1 == 'settings' ? IconTone.neutral : IconTone.primary,
        ),
    ];

    if (tabs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Insets.xxl),
          child: EmptyState(
            icon: AppIcons.shield,
            title: en ? 'No panels enabled' : 'لا توجد أقسام مفعلة',
            message: en
                ? 'No panels are enabled for your account. Contact the team owner.'
                : 'لا توجد أقسام مفعلة لحسابك. تواصل مع مالك الفريق.',
          ),
        ),
      );
    }

    void select(String id) {
      final index = int.tryParse(id);
      if (index == null || index == _tab) return;
      if (index == requestsIndex) {
        unawaited(admin.markRequestsSeen());
      }
      setState(() => _tab = index);
    }

    final errorBanner = admin.lastError == null
        ? const SizedBox.shrink()
        : _ErrorBanner(
            message: admin.lastError!,
            isArabic: !en,
            onRetry: () async {
              if (app.token == null) return;
              await admin.reloadAll(app.token!);
              // Best-effort: a failed team refresh must not throw out of the
              // retry handler.
              await app.loadAdmins().catchError((_) {});
              await app.resolveCurrentAdmin();
            },
          );

    final body = Column(
      children: [
        errorBanner,
        Expanded(
          child: FadeSwitcher(
            child: KeyedSubtree(
              key: ValueKey('admin-tab-$_tab'),
              child: tabs[_tab].$3,
            ),
          ),
        ),
      ],
    );

    // The dashboard owns the Scaffold now that the shell is only a gate. The
    // admin tabs below still bring their own Scaffold for the nested "back"
    // flow, which Flutter handles by stacking rather than nesting chrome.
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final layout = navLayoutFor(constraints.maxWidth);

            // The compact header sits above both presentations, so the rail and
            // the sidebar start underneath a consistent title bar.
            final header = PremiumHeader(
              title: tabs[_tab].$2.title,
              actions: [
                if (tabs[_tab].$1 == AdminPerms.accounting)
                  IconAction(
                    icon: AppIcons.backAuto,
                    tooltip: en ? 'Back' : 'رجوع',
                    onPressed: () => select('0'),
                  ),
                IconAction(
                  icon: AppIcons.notifications,
                  tooltip: en ? 'Notifications' : 'التنبيهات',
                  tone: IconTone.primary,
                  badge: admin.unreadRequests,
                  onPressed: () async {
                    await admin.markRequestsSeen();
                    if (!context.mounted) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AdminNotificationsScreen(),
                      ),
                    );
                  },
                ),
                IconAction(
                  icon: AppIcons.lock,
                  tooltip: en ? 'Change password' : 'تغيير كلمة المرور',
                  onPressed: () => showChangePasswordDialog(
                    context,
                    app: app,
                    isEnglish: en,
                  ),
                ),
              ],
            );

            if (layout == NavLayout.bottomBar) {
              // Too many modules for a bottom bar on a phone, so the narrow layout
              // uses a compact scrolling strip instead — 44dp tall, well under the
              // budget a bottom bar would need.
              return Column(
                children: [
                  header,
                  _ModuleStrip(
                    labels: [for (final t in tabs) t.$2.title],
                    icons: [for (final t in tabs) t.$2.icon],
                    selected: _tab,
                    badgeIndex: requestsIndex,
                    badgeCount: admin.unreadRequests,
                    onSelect: select,
                  ),
                  Expanded(child: body),
                ],
              );
            }

            return Column(
              children: [
                header,
                Expanded(
                  child: Row(
                    children: [
                      PremiumNav(
                        layout: layout,
                        destinations: destinations,
                        selectedId: '$_tab',
                        onSelected: select,
                      ),
                      VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: context.borderColor,
                      ),
                      Expanded(child: body),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Slim error strip shown when a background refresh fails. Deliberately one
/// line tall so it does not push the module content off screen.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.message,
    required this.isArabic,
    required this.onRetry,
  });

  final String message;
  final bool isArabic;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final danger = context.dangerColor;
    return Container(
      width: double.infinity,
      color: danger.withValues(alpha: 0.08),
      padding: const EdgeInsetsDirectional.fromSTEB(
        Insets.md,
        Insets.xs,
        Insets.xs,
        Insets.xs,
      ),
      child: Row(
        children: [
          Icon(AppIcons.warning, size: IconSize.inline, color: danger),
          const SizedBox(width: Insets.xs),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: TypeScale.caption, color: danger),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: danger,
            ),
            onPressed: onRetry,
            child: Text(isArabic ? 'إعادة' : 'Retry'),
          ),
        ],
      ),
    );
  }
}

/// Compact scrolling module strip used only on the narrow layout.
///
/// 46dp tall with a pill behind the active module — the same selected
/// treatment the rail and sidebar use, so the identity holds across layouts.
class _ModuleStrip extends StatelessWidget {
  const _ModuleStrip({
    required this.labels,
    required this.icons,
    required this.selected,
    required this.badgeIndex,
    required this.badgeCount,
    required this.onSelect,
  });

  final List<String> labels;
  final List<IconData> icons;
  final int selected;
  final int badgeIndex;
  final int badgeCount;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: context.surfaceColor,
        border: Border(bottom: BorderSide(color: context.borderColor)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
        physics: const BouncingScrollPhysics(),
        itemCount: labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: Insets.xxs),
        itemBuilder: (context, i) {
          final active = i == selected;
          return Center(
            child: PressableScale(
              onTap: () => onSelect('$i'),
              pressedScale: 0.95,
              child: AnimatedContainer(
                duration: Motion.fast,
                curve: Motion.entrance,
                padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
                decoration: BoxDecoration(
                  color: active
                      ? accent.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(Corners.md),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          icons[i],
                          size: IconSize.nav,
                          weight: active ? 600 : 500,
                          color: active ? accent : context.mutedColor,
                        ),
                        if (i == badgeIndex && badgeCount > 0)
                          PositionedDirectional(
                            end: -5,
                            top: -3,
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: Insets.xs - 2),
                    Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: TypeScale.caption,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                        color: active ? accent : context.secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A module entry in the admin navigation: its display title and icon.
///
/// Replaces the old `_Tab` tuple element so the navigation destinations can
/// be built directly from it.
class _Tab {
  const _Tab({required this.title, required this.icon});

  final String title;
  final IconData icon;
}
