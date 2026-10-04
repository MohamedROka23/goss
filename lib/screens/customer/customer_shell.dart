import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/icons.dart';
import '../../app/motion.dart';
import '../../app/responsive.dart';
import '../../app/spacing.dart';
import '../../app/theme.dart';
import '../../providers/app_provider.dart';
import '../../widgets/icon_3d.dart';
import '../../widgets/premium_header.dart';
import '../../widgets/premium_nav.dart';
import '../../widgets/widgets.dart';
import '../chat/chat_list_screen.dart';
import '../role_screen.dart';
import 'about_screen.dart';
import 'catalog_screen.dart';
import 'contact_screen.dart';
import 'home_screen.dart';
import 'logistics_screen.dart';
import 'my_orders_screen.dart';
import 'notifications_screen.dart';
import 'quote_screen.dart';
import 'settings_screen.dart';
import 'supplies_screen.dart';

/// Customer-facing shell.
///
/// Presents one of three navigations depending on the window: a bottom bar on
/// a phone, an icon rail on a tablet, and a labelled sidebar on a desktop-sized
/// window. The seven destinations and their order are unchanged; only the
/// chrome around them is new.
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

  // Index-aligned with `_screens`. Kept as index keys so the existing tab
  // behaviour (and the cart notifier wiring) is untouched.
  static const _primaryEn = <int, String>{
    0: 'Home',
    1: 'About',
    2: 'Logistics',
    3: 'Supplies',
    4: 'Supply request',
    5: 'Price quote',
    6: 'Contact',
  };

  static const _primaryAr = <int, String>{
    0: 'الرئيسية',
    1: 'من نحن',
    2: 'الخدمات اللوجستية',
    3: 'التوريدات والتجارة',
    4: 'طلب توريد',
    5: 'عرض سعر',
    6: 'تواصل معنا',
  };

  static const _primaryIcons = <int, IconData>{
    0: AppIcons.home,
    1: AppIcons.about,
    2: AppIcons.logistics,
    3: AppIcons.supplies,
    4: AppIcons.catalog,
    5: AppIcons.quotes,
    6: AppIcons.contact,
  };

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final en = !app.isArabic;
    final labels = en ? _primaryEn : _primaryAr;

    final primary = <NavDestination>[
      for (var i = 0; i < _screens.length; i++)
        NavDestination(
          id: '$i',
          label: labels[i]!,
          icon: _primaryIcons[i]!,
          // The cart count rides on the supply-request destination, exactly as
          // it did on the drawer badge before.
          badge: i == 4 ? app.cartCount : null,
        ),
    ];

    final account = <NavDestination>[
      NavDestination(
        id: 'orders',
        label: en ? 'My orders' : 'طلباتي',
        icon: AppIcons.orders,
        tone: IconTone.brand,
      ),
      NavDestination(
        id: 'chat',
        label: en ? 'Support chat' : 'شات الدعم',
        icon: AppIcons.chat,
        tone: IconTone.brand,
      ),
      NavDestination(
        id: 'notifications',
        label: en ? 'Notifications' : 'الإشعارات',
        icon: AppIcons.notifications,
      ),
      NavDestination(
        id: 'settings',
        label: en ? 'Settings' : 'الإعدادات',
        icon: AppIcons.settings,
      ),
      NavDestination(
        id: 'role',
        label: en ? 'Switch role' : 'تبديل الحساب',
        icon: AppIcons.signOut,
        tone: IconTone.neutral,
      ),
    ];

    final content = Column(
      children: [
        // A compact 58dp bar. No gradient, no logo block, no oversized title:
        // the destination name plus a single overflow control.
        PremiumHeader(
          title: labels[_index],
          actions: [
            IconAction(
              icon: AppIcons.notifications,
              tooltip: en ? 'Notifications' : 'الإشعارات',
              tone: IconTone.primary,
              onPressed: () => _push(const NotificationsScreen()),
            ),
            _OverflowMenu(
              en: en,
              onDark: app.isDark,
              onLang: app.toggleLanguage,
            ),
          ],
        ),
        Expanded(
          child: FadeSwitcher(
            // One constrain on the shared body caps and centres the embedded
            // screens on a wide window instead of letting them span 1024dp.
            child: context.constrain(
              KeyedSubtree(
                key: ValueKey('customer-tab-$_index'),
                child: _index < _screens.length
                    ? _screens[_index]
                    : _screens.first,
              ),
            ),
          ),
        ),
      ],
    );

    return PremiumShellLayout(
      selectedId: '$_index',
      secondary: account,
      brand: _Brand(en: en),
      navFooter: _ThemeToggle(onDark: app.isDark, onToggle: app.toggleDarkMode),
      nav: (layout) => PremiumNav(
        layout: layout,
        destinations: primary,
        secondary: account,
        selectedId: '$_index',
        onSelected: (id) => _onNav(id, account),
      ),
      content: content,
    );
  }

  /// Routes a selection. Numeric ids move the tab; the rest push a page or
  /// perform an action, which is how the drawer's extra entries behaved before.
  void _onNav(String id, List<NavDestination> account) {
    final numeric = int.tryParse(id);
    if (numeric != null) {
      if (numeric == _index) return;
      setState(() => _index = numeric);
      return;
    }

    switch (id) {
      case 'orders':
        _push(const MyOrdersScreen());
      case 'chat':
        _push(const ChatListScreen());
      case 'notifications':
        _push(const NotificationsScreen());
      case 'settings':
        _push(const SettingsScreen());
      case 'role':
        _switchRole();
    }
  }

  void _push(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  void _switchRole() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RoleScreen()),
      (route) => false,
    );
  }
}

/// Compact brand lockup used at the top of the rail and sidebar.
class _Brand extends StatelessWidget {
  const _Brand({required this.en});

  final bool en;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/logo.png', width: 26, height: 26),
        const SizedBox(width: Insets.xs),
        Flexible(
          child: Text(
            'GOSST',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: context.headingColor,
            ),
          ),
        ),
      ],
    );
  }
}

/// Overflow control in the header: language, appearance, account.
class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu({
    required this.en,
    required this.onDark,
    required this.onLang,
  });

  final bool en;
  final bool onDark;
  final VoidCallback onLang;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: en ? 'More' : 'المزيد',
      color: context.raisedColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Corners.md),
        side: BorderSide(color: context.borderColor),
      ),
      icon: Icon(AppIcons.more, color: context.secondaryTextColor),
      onSelected: (v) {
        if (v == 'dark') {
          context.read<AppProvider>().toggleDarkMode();
        } else if (v == 'lang') {
          onLang();
        } else if (v == 'logout') {
          context.read<AppProvider>().logout();
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const RoleScreen()),
            (route) => false,
          );
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'dark',
          height: 42,
          child: _MenuRow(
            icon: onDark ? AppIcons.sun : AppIcons.moon,
            label: onDark
                ? (en ? 'Light mode' : 'الوضع الفاتح')
                : (en ? 'Dark mode' : 'الوضع الداكن'),
          ),
        ),
        PopupMenuItem(
          value: 'lang',
          height: 42,
          child: _MenuRow(
            icon: AppIcons.language,
            label: en ? 'العربية' : 'English',
          ),
        ),
        PopupMenuItem(
          value: 'logout',
          height: 42,
          child: _MenuRow(
            icon: AppIcons.signOut,
            label: en ? 'Switch role' : 'تبديل الحساب',
            tone: IconTone.danger,
          ),
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    this.tone = IconTone.neutral,
  });

  final IconData icon;
  final String label;
  final IconTone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      IconTone.danger => context.dangerColor,
      _ => context.bodyColor,
    };
    return Row(
      children: [
        Icon(icon, size: IconSize.action, color: color, weight: 500),
        const SizedBox(width: Insets.sm),
        Text(
          label,
          style: TextStyle(
            fontSize: TypeScale.body,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Two-state appearance switch for the rail and sidebar footer, matching the
/// reference's compact segmented control.
class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle({required this.onDark, required this.onToggle});

  final bool onDark;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return PressableScale(
      onTap: onToggle,
      pressedScale: 0.96,
      child: Container(
        height: ControlSize.sm,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: context.isDarkMode
              ? GossColors.darkBg
              : GossColors.lightSurfaceAlt,
          borderRadius: BorderRadius.circular(Corners.md),
          border: Border.all(color: context.borderColor),
        ),
        child: Row(
          children: [
            _half(
              context: context,
              icon: AppIcons.sun,
              active: !onDark,
              accent: accent,
            ),
            _half(
              context: context,
              icon: AppIcons.moon,
              active: onDark,
              accent: accent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _half({
    required BuildContext context,
    required IconData icon,
    required bool active,
    required Color accent,
  }) {
    return Expanded(
      child: AnimatedContainer(
        duration: Motion.fast,
        curve: Motion.entrance,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? accent.withValues(alpha: 0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(Corners.sm),
        ),
        child: Icon(
          icon,
          size: IconSize.inline,
          weight: active ? 600 : 500,
          color: active ? accent : context.mutedColor,
        ),
      ),
    );
  }
}
