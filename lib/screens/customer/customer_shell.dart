import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../app/theme.dart';
import '../role_screen.dart';
import '../chat/chat_list_screen.dart';
import 'home_screen.dart';
import 'about_screen.dart';
import 'logistics_screen.dart';
import 'supplies_screen.dart';
import 'catalog_screen.dart';
import 'quote_screen.dart';
import 'contact_screen.dart';
import 'settings_screen.dart';
import 'notifications_screen.dart';
import 'my_orders_screen.dart';
import '../../widgets/widgets.dart';

class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key});

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  int _index = 0;

  final ValueNotifier<int> _cartSignal = ValueNotifier<int>(0);

  late final List<Widget> _screens = [
    const HomeScreen(),
    const AboutScreen(),
    const LogisticsScreen(),
    const SuppliesScreen(),
    CatalogScreen(cartSignal: _cartSignal),
    const QuoteScreen(),
    const ContactScreen(),
  ];

  @override
  void dispose() {
    _cartSignal.dispose();
    super.dispose();
  }

  static const _labels = {
    0: 'GOSST HOME', 1: 'ABOUT', 2: 'LOGISTICS',
    3: 'SUPPLIES', 4: 'SUPPLY REQUEST', 5: 'PRICE QUOTE', 6: 'CONTACT',
  };

  static const _labelsAr = {
    0: 'الرئيسية', 1: 'من نحن', 2: 'الخدمات اللوجستية',
    3: 'التوريدات والتجارة', 4: 'طلب توريد', 5: 'عرض سعر', 6: 'تواصل معنا',
  };

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final en = !app.isArabic;

    // Build current screen with a Scaffold + AppBar that has the drawer
    return Scaffold(
      appBar: AppBar(
        backgroundColor: GossColors.navy,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Image.asset('assets/logo.png', width: 38, height: 38),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('GOSST', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  Text(
                    en ? _labels[_index]! : _labelsAr[_index]!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.8), letterSpacing: 0.5),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: en ? 'Notifications' : 'التنبيهات',
            icon: Badge(
              isLabelVisible: app.unreadNotifications > 0,
              backgroundColor: GossColors.red,
              label: Text('${app.unreadNotifications}'),
              child: const Icon(Icons.notifications_none, color: Colors.white),
            ),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
            },
          ),
          IconButton(
            tooltip: en ? 'Your request / cart' : '\u0637\u0644\u0628\u0643 / \u0627\u0644\u0633\u0644\u0629',
            icon: Badge(
              isLabelVisible: app.cartCount > 0,
              backgroundColor: GossColors.red,
              label: Text('${app.cartCount}'),
              child: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
            ),
            onPressed: () {
              setState(() => _index = 4);
              WidgetsBinding.instance.addPostFrameCallback((_) => _cartSignal.value++);
            },
          ),
          PopupMenuButton<String>(
            tooltip: en ? 'More options' : 'خيارات أكثر',
            color: GossColors.navy,
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (v) {
              if (v == 'role') {
                _switchRole();
              } else if (v == 'dark') {
                app.toggleDarkMode();
              } else if (v == 'lang') {
                app.toggleLanguage();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'role', child: Row(children: [const Icon(Icons.switch_account, color: Colors.white), const SizedBox(width: 8), Text(en ? 'Switch role' : 'تبديل الحساب', style: const TextStyle(color: Colors.white))])),
              PopupMenuItem(value: 'dark', child: Row(children: [Icon(app.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, color: Colors.white), const SizedBox(width: 8), Text(en ? 'Toggle dark mode' : 'الوضع الداكن', style: const TextStyle(color: Colors.white))])),
              PopupMenuItem(value: 'lang', child: Row(children: [const Icon(Icons.translate, color: Colors.white), const SizedBox(width: 8), Text(en ? 'العربية' : 'English', style: const TextStyle(color: Colors.white))])),
            ],
          ),
        ],
      ),
      body: _screens[_index],
      drawer: Drawer(
        backgroundColor: GossColors.navy,
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Image.asset('assets/logo.png', width: 44, height: 44),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('GOSST',
                              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                          Text(en ? 'Global Outsourcing Services Trading' : '\u0627\u0644\u062a\u0648\u0631\u064a\u062f\u0627\u062a \u0648\u0627\u0644\u062a\u062c\u0627\u0631\u0629 \u0627\u0644\u062e\u0627\u0631\u062c\u064a\u0629',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Color(0xFFC9D3E0), fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white24),
              _drawerItem(en ? 'Home' : '\u0627\u0644\u0631\u0626\u064a\u0633\u064a\u0629', Icons.home, 0),
              _drawerItem(en ? 'About Us' : '\u0645\u0646 \u0646\u062d\u0646', Icons.info, 1),
              _drawerItem(en ? 'Logistics Services' : 'الخدمات اللوجستية', Icons.local_shipping, 2),
              _drawerItem(en ? 'Supplies & Trade' : 'التوريدات والتجارة', Icons.inventory, 3),
              _drawerItem(en ? 'Supply Request' : 'طلب توريد', Icons.storefront, 4),
              _drawerItem(en ? 'Price Quote' : 'عرض سعر', Icons.request_quote, 5),
              _drawerItem(en ? 'Contact' : 'تواصل معنا', Icons.mail, 6),
              const Divider(color: Colors.white24),
              ListTile(
                leading: const Icon(Icons.receipt_long, color: Colors.white),
                title: Text(en ? 'My Orders' : 'طلباتي', style: const TextStyle(color: Colors.white)),
                subtitle: Text(en ? 'Track requests until delivery' : 'تابع طلباتك حتى التسليم', style: const TextStyle(color: Color(0xFFC9D3E0))),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyOrdersScreen()));
                },
              ),
              const Divider(color: Colors.white24),
              ListTile(
                leading: const Icon(Icons.headset_mic_outlined, color: GossColors.red),
                title: Text(en ? 'Support chat' : 'شات خدمة العملاء', style: const TextStyle(color: Colors.white)),
                subtitle: Text(en ? 'Encrypted end-to-end' : 'مشفّر من طرف لطرف', style: const TextStyle(color: Color(0xFFC9D3E0))),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChatListScreen()));
                },
              ),
              const Divider(color: Colors.white24),
              ListTile(
                leading: const Icon(Icons.settings, color: Colors.white),
                title: Text(en ? 'Settings' : '\u0627\u0644\u0625\u0639\u062f\u0627\u062f\u0627\u062a', style: const TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
                },
              ),
ListTile(
                leading: const Icon(Icons.switch_account, color: Colors.white),
                title: Text(en ? 'Switch role' : 'تبديل الحساب', style: const TextStyle(color: Colors.white)),
                subtitle: Text(en ? 'Back to role selection' : 'العودة لاختيار الدخول', style: const TextStyle(color: Color(0xFFC9D3E0))),
                onTap: () {
                  Navigator.pop(context);
                  _switchRole();
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: GossColors.red),
                title: Text(en ? 'Log out' : 'تسجيل الخروج', style: const TextStyle(color: GossColors.red)),
                subtitle: Text(en ? 'Back to role selection' : 'العودة إلى شاشة اختيار الوضع', style: const TextStyle(color: Color(0xFFC9D3E0))),
                onTap: () {
                  Navigator.pop(context);
                  context.read<AppProvider>().logout();
                  _switchRole();
                },
              ),
              const SizedBox(height: 4),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: VersionBadge(compact: true, light: true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _switchRole() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RoleScreen()),
      (route) => false,
    );
  }

  Widget _drawerItem(String label, IconData icon, int index) {
    final app = context.read<AppProvider>();
    final active = _index == index;
    return ListTile(
      leading: Icon(icon, color: active ? GossColors.red : Colors.white),
      selected: active,
      selectedTileColor: Colors.white.withValues(alpha: 0.08),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      trailing: index == 4 && app.cartCount > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: const BoxDecoration(color: GossColors.red, shape: BoxShape.circle),
              child: Text('${app.cartCount}', style: const TextStyle(color: Colors.white, fontSize: 12)),
            )
          : null,
      onTap: () {
        Navigator.pop(context);
        setState(() => _index = index);
      },
    );
  }
}
