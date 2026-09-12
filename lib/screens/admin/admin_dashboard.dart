import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../providers/admin_provider.dart';
import '../../app/theme.dart';
import '../../models/models.dart';
import '../../services/notification_watcher.dart';
import 'admin_quotes_tab.dart';
import 'admin_purchases_tab.dart';
import 'admin_profit_tab.dart';
import 'admin_requests_tab.dart';
import 'admin_team_tab.dart';
import 'admin_customers_tab.dart';
import 'admin_tracking_tab.dart';
import 'admin_chat_tab.dart';
import 'accounting/admin_accounting_tab.dart';
import 'admin_settings_tab.dart';

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
        admin.loadRequests(app.token!);
        admin.loadExpenses(app.token!);
        admin.loadPurchases(app.token!);
        admin.loadJournal(app.token!);
        admin.loadPayments(app.token!);
        admin.startWatchingRequests(app.token!);
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
      (AdminPerms.requests, _Tab(title: en ? 'Requests' : '\u0627\u0644\u0637\u0644\u0628\u0627\u062a', icon: Icons.inbox_outlined), const AdminRequestsTab()),
      (AdminPerms.tracking, _Tab(title: en ? 'Tracking' : '\u0627\u0644\u062a\u0631\u0627\u0643\u0646\u062c \u0623\u0648\u0631\u062f\u0631', icon: Icons.route_outlined), const AdminTrackingTab()),
      (AdminPerms.customers, _Tab(title: en ? 'Customers' : '\u0627\u0644\u0639\u0645\u0644\u0627\u0621', icon: Icons.people_outline), const AdminCustomersTab()),
      (AdminPerms.quotes, _Tab(title: en ? 'Quotes' : '\u0639\u0631\u0648\u0636', icon: Icons.storefront_outlined), const AdminQuotesTab()),
      (AdminPerms.purchases, _Tab(title: en ? 'Purchasing' : '\u0627\u0644\u0634\u0631\u0627\u0621', icon: Icons.shopping_cart_outlined), const AdminPurchasesTab()),
      (AdminPerms.profit, _Tab(title: en ? 'Profit' : '\u0627\u0644\u0631\u0628\u062d', icon: Icons.trending_up), const AdminProfitTab()),
      (AdminPerms.accounting, _Tab(title: en ? 'Accounting' : '\u0627\u0644\u0645\u062d\u0627\u0633\u0628\u0629', icon: Icons.account_balance_outlined), AdminAccountingTab(onBack: () => _select(0, null))),
      (AdminPerms.team, _Tab(title: en ? 'Admins' : '\u0627\u0644\u0641\u0631\u064a\u0642', icon: Icons.group_outlined), const AdminTeamTab()),
      (AdminPerms.chat, _Tab(title: en ? 'Support' : '\u0627\u0644\u062f\u0639\u0645', icon: Icons.headset_mic_outlined), const AdminChatTab()),
    ].where((t) => app.can(t.$1)).toList();

    tabs.add(('settings', _Tab(title: en ? 'Settings' : '\u0627\u0644\u0625\u0639\u062f\u0627\u062f\u0627\u062a', icon: Icons.settings_outlined), const AdminSettingsTab()));

    if (_tab >= tabs.length) _tab = tabs.isEmpty ? 0 : tabs.length - 1;

    if (tabs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            en ? 'No panels are enabled for your account. Contact the team owner.' : 'لا توجد أقسام مفعلة لحسابك. تواصل مع مالك الفريق.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.mutedColor),
          ),
        ),
      );
    }

    final requestsIndex = tabs.indexWhere((t) => t.$1 == AdminPerms.requests);

    final chips = List.generate(tabs.length, (i) {
      final active = _tab == i;
      final badgeCount = (i == requestsIndex) ? admin.unreadRequests : 0;
      return InkWell(
        onTap: () => _select(i, i == requestsIndex ? () async { await admin.markRequestsSeen(); } : null),
        borderRadius: BorderRadius.circular(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  tabs[i].$2.icon,
                  color: active ? Colors.white : Colors.white54,
                  size: 20,
                ),
                if (badgeCount > 0)
                  PositionedDirectional(
                    end: -8,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: const BoxDecoration(color: GossColors.red, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      alignment: Alignment.center,
                      child: Text(
                        '$badgeCount',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              tabs[i].$2.title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: active ? Colors.white : Colors.white54,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    });

    return Column(
      children: [
        _AdminSlider(chips: chips),
        if (admin.lastError != null) ...[
          Material(
            color: GossColors.red.withValues(alpha: 0.06),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 16, color: GossColors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      admin.lastError!,
                      style: const TextStyle(fontSize: 12, color: GossColors.red),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    onPressed: () async {
                      if (app.token == null) return;
                      await admin.reloadAll(app.token!);
                      await app.loadAdmins();
                      await app.resolveCurrentAdmin();
                    },
                    child: Text(en ? 'Retry' : '\u0625\u0639\u0627\u062f\u0629 \u0627\u0644\u0645\u062d\u0627\u0648\u0644\u0629'),
                  ),
                ],
              ),
            ),
          ),
        ],
        Expanded(child: tabs[_tab].$3),
      ],
    );
  }
}

/// Interactive horizontal slider for the admin module menus: ~3 icon chips
/// visible on phones and swiping (or tapping the edge chevrons) reveals the
/// rest. Adapts chip size/scroll to every screen width.
class _AdminSlider extends StatefulWidget {
  const _AdminSlider({required this.chips});

  final List<Widget> chips;

  @override
  State<_AdminSlider> createState() => _AdminSliderState();
}

class _AdminSliderState extends State<_AdminSlider> {
  final ScrollController _ctrl = ScrollController();
  bool _canPrev = false;
  bool _canNext = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_update);
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  }

  @override
  void dispose() {
    _ctrl.removeListener(_update);
    _ctrl.dispose();
    super.dispose();
  }

  void _update({double? pixels, double? maxScrollExtent}) {
    final p = _ctrl.hasClients ? _ctrl.position : null;
    final px = pixels ?? p?.pixels ?? 0.0;
    final max = maxScrollExtent ?? p?.maxScrollExtent ?? 0.0;
    final prev = px > 1.0;
    final next = px < max - 1.0;
    if (prev != _canPrev || next != _canNext) {
      setState(() {
        _canPrev = prev;
        _canNext = next;
      });
    }
  }

  void _scrollBy(double delta) {
    final p = _ctrl.position;
    _ctrl.animateTo(
      (p.pixels + delta).clamp(0.0, p.maxScrollExtent),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _navButton(IconData icon, VoidCallback onTap, {required bool start}) {
    return PositionedDirectional(
      start: start ? 2 : null,
      end: start ? null : 2,
      top: 0,
      bottom: 0,
      child: Align(
        alignment: Alignment.center,
        child: Container(
          decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: SizedBox.square(
                dimension: 44,
                child: Icon(icon, size: 22, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final chipWidth = (width / 3).clamp(88.0, 150.0);
        return Container(
          color: GossColors.navy,
          child: Stack(
            alignment: Alignment.center,
            children: [
              NotificationListener<ScrollMetricsNotification>(
                onNotification: (n) {
                  _update(
                    pixels: n.metrics.pixels,
                    maxScrollExtent: n.metrics.maxScrollExtent,
                  );
                  return false;
                },
                child: SingleChildScrollView(
                  controller: _ctrl,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final chip in widget.chips)
                        SizedBox(width: chipWidth, height: 50, child: chip),
                    ],
                  ),
                ),
              ),
              if (_canPrev)
                _navButton(
                  rtl ? Icons.chevron_right : Icons.chevron_left,
                  () => _scrollBy(-width * 0.75),
                  start: true,
                ),
              if (_canNext)
                _navButton(
                  rtl ? Icons.chevron_left : Icons.chevron_right,
                  () => _scrollBy(width * 0.75),
                  start: false,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Tab {
  final String title;
  final IconData icon;
  const _Tab({required this.title, required this.icon});
}