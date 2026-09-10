import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/backend_manager.dart';
import '../services/firestore_backend.dart';
import '../services/fcm_service.dart';

class AppProvider extends ChangeNotifier {
  String _langSetting = 'en';
  String get langSetting => _langSetting;

  Locale get locale => _resolveLocale();
  bool get isArabic => locale.languageCode == 'ar';

  Locale _resolveLocale() {
    if (_langSetting == 'system') {
      final sys = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
      return Locale(sys == 'ar' ? 'ar' : 'en');
    }
    return Locale(_langSetting == 'ar' ? 'ar' : 'en');
  }

  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;

  List<Product> _products = [];
  List<Product> get products => _products;

  /// Live connection state used to warn the customer when the app is offline
  /// (a request cannot reach Gosst right now). Optimistic until proven wrong.
  bool _online = true;
  bool get online => _online;

  Timer? _connectivityTimer;
  bool _disposed = false;

  void _startConnectivityWatch() {
    _connectivityTimer?.cancel();
    _connectivityTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _pingConnectivity(),
    );
  }

  Future<void> _pingConnectivity() async {
    // The app always runs on Firebase; there is no local HTTP backend, so the
    // online flag stays true (optimistic) and requests go straight to Firestore.
    _setOnline(true);
  }

  void _setOnline(bool value) {
    if (_disposed || _online == value) return;
    _online = value;
    notifyListeners();
  }

  List<ProductCategory> _categories = [];
  List<ProductCategory> get productCategories =>
      _categories.isEmpty ? _fallbackCategories : _categories;

  static final List<ProductCategory> builtinFallbackCategories = const [
    ProductCategory(id: 'vegetables', en: 'Fresh Vegetables', ar: '\u0627\u0644\u062e\u0636\u0631\u0648\u0627\u062a \u0627\u0644\u0637\u0627\u0632\u062c\u0629'),
    ProductCategory(id: 'fruits', en: 'Fresh Fruits', ar: '\u0627\u0644\u0641\u0627\u0643\u0647\u0629 \u0627\u0644\u0637\u0627\u0632\u062c\u0629'),
    ProductCategory(id: 'general', en: 'General Goods', ar: '\u0639\u0627\u0645'),
    ProductCategory(id: 'office', en: 'Office Supplies', ar: '\u0627\u0644\u0623\u062f\u0648\u0627\u062a \u0627\u0644\u0645\u0643\u062a\u0628\u064a\u0629'),
    ProductCategory(id: 'hotel', en: 'Hotel Supplies', ar: '\u0623\u062f\u0648\u0627\u062a \u0641\u0646\u062f\u0642\u064a\u0629'),
    ProductCategory(id: 'restaurant', en: 'Restaurant Supplies', ar: '\u0644\u0648\u0627\u0632\u0645 \u0627\u0644\u0645\u0637\u0627\u0639\u0645'),
    ProductCategory(id: 'appliances', en: 'Appliances', ar: '\u0623\u062c\u0647\u0632\u0629'),
    ProductCategory(id: 'packaging', en: 'Packaging & Wrapping Materials', ar: '\u0645\u0648\u0627\u062f \u0627\u0644\u062a\u0639\u0628\u0626\u0629 \u0648\u0627\u0644\u062a\u063a\u0644\u064a\u0641'),
  ];

  List<ProductCategory> get _fallbackCategories => builtinFallbackCategories;

  List<CartItem> _cart = [];
  List<CartItem> get cart => _cart;

  String? _token;
  String? get token => _token;
  bool get isLoggedIn => _token != null;

  /// Test-only: inject products without hitting a backend.
  @visibleForTesting
  void seedProducts(List<Product> products) {
    _products = products;
    notifyListeners();
  }

  /// Test-only: inject the customer's own requests without a backend.
  @visibleForTesting
  void seedMyRequests(List<CustomerRequest> requests) {
    _myRequests = requests;
    _myRequestsLoading = false;
    notifyListeners();
  }

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  StreamSubscription<List<Product>>? _productSub;
  StreamSubscription<List<PriceUpdateNotification>>? _notifSub;
  List<PriceUpdateNotification> _notifs = [];
  List<PriceUpdateNotification> get notifications => _notifs;
  String _lastSeenNotifAt = '';

  AppProvider() {
    _loadFromStorage();
  }

  @override
  void dispose() {
    _disposed = true;
    _connectivityTimer?.cancel();
    _productSub?.cancel();
    _notifSub?.cancel();
    super.dispose();
  }

  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final lang = prefs.getString('goss-lang') ?? 'en';
    _langSetting = ['system', 'ar'].contains(lang) ? lang : 'en';
    final mode = prefs.getString('goss-dark');
    _themeMode = mode == 'dark' ? ThemeMode.dark : (mode == 'system' ? ThemeMode.system : ThemeMode.light);
    _token = prefs.getString('goss-token');
    _adminEmail = prefs.getString('goss-admin-email') ?? '';
    _lastSeenNotifAt = prefs.getString('goss-notif-seen') ?? '';
    _cachedPermissions = prefs.getStringList('goss-admin-permissions');
    final savedRole = prefs.getString('goss-admin-role') ?? '';
    _activeRole = (savedRole == AdminRole.delegate || savedRole == AdminRole.admin) ? savedRole : null;
    try {
      final cartStr = prefs.getString('goss-cart');
      if (cartStr != null) {
        _cart = (jsonDecode(cartStr) as List).map((e) => CartItem.fromJson(e)).toList();
      }
    } catch (_) {}
    notifyListeners();
    await loadProducts();
    await _watchProducts();
    await _watchNotifications();
    await loadCategories();
    if (_token != null) {
      await resolveCurrentAdmin();
    }
    _startConnectivityWatch();
  }

  Future<void> loadCategories() async {
    try {
      final backend = await BackendManager.resolve();
      final list = await backend.fetchCategories();
      if (list.isNotEmpty) {
        _categories = list;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<String> addCategory({
    required String en,
    required String ar,
  }) async {
    if (_token == null) return 'Not logged in';
    final base = en.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
    var id = base.isEmpty ? 'category' : base;
    final used = productCategories.map((c) => c.id).toSet();
    var n = 2;
    while (used.contains(id)) {
      id = '${base.isEmpty ? 'category' : base}_$n';
      n++;
    }
    try {
      final backend = await BackendManager.resolve();
      await backend.addCategory(_token!, id, en.trim(), ar.trim());
      await loadCategories();
      return '';
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> _watchNotifications() async {
    try {
      final backend = await BackendManager.resolve();
      _notifSub = backend.watchNotifications().listen((list) {
        _notifs = list;
        notifyListeners();
      });
    } catch (_) {}
  }

  int get unreadNotifications {
    final seen = DateTime.tryParse(_lastSeenNotifAt);
    var count = 0;
    for (final x in _notifs) {
      if (x.type != 'price_update') continue;
      final t = DateTime.tryParse(x.createdAt);
      if (t != null && (seen == null || t.isAfter(seen))) count++;
    }
    return count;
  }

  Future<void> markNotificationsSeen() async {
    _lastSeenNotifAt = DateTime.now().toUtc().toIso8601String();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('goss-notif-seen', _lastSeenNotifAt);
    notifyListeners();
  }

  Future<String> sendPriceUpdate({
    required Product product,
    required double oldPrice,
  }) async {
    if (_token == null) return '';
    try {
      final backend = await BackendManager.resolve();
      await backend.sendPriceUpdateNotification(_token!, {
        'type': 'price_update',
        'productId': product.id,
        'productNameEn': product.nameEn,
        'productNameAr': product.nameAr,
        'oldPrice': oldPrice,
        'newPrice': product.price,
        'unit': product.unit,
      });
      return '';
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> _watchProducts() async {
    try {
      final backend = await BackendManager.resolve();
      _productSub = backend.watchProducts().listen((list) {
        _products = list;
        notifyListeners();
      });
    } catch (_) {}
  }

  void setDarkMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('goss-dark', mode.name);
    notifyListeners();
  }

  void toggleDarkMode() {
    setDarkMode(isDark ? ThemeMode.light : ThemeMode.dark);
  }

  void setLanguage(String setting) async {
    _langSetting = (setting == 'system' || setting == 'ar') ? setting : 'en';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('goss-lang', _langSetting);
    notifyListeners();
  }

  void toggleLanguage() {
    setLanguage(isArabic ? 'en' : 'ar');
  }

  Future<void> loadProducts() async {
    try {
      final backend = await BackendManager.resolve();
      _products = await backend.fetchProducts();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void addToCart(String productId, {int qty = 1}) {
    var qty0 = qty < 1 ? 1 : qty;
    final existing = _cart.where((c) => c.productId == productId);
    if (existing.isNotEmpty) {
      existing.first.qty = (existing.first.qty + qty0).clamp(1, 9999);
    } else {
      _cart.add(CartItem(productId: productId, qty: qty0));
    }
    _saveCart();
    notifyListeners();
  }

  void setCartQty(String productId, int qty) {
    for (var c in _cart) {
      if (c.productId == productId) {
        c.qty = qty < 1 ? 1 : qty;
        break;
      }
    }
    _saveCart();
    notifyListeners();
  }

  void removeFromCart(String productId) {
    _cart.removeWhere((c) => c.productId == productId);
    _saveCart();
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    _saveCart();
    notifyListeners();
  }

  int get cartCount => _cart.fold(0, (n, i) => n + i.qty);

  double get cartTotal {
    double total = 0;
    for (var c in _cart) {
      final p = _products.where((x) => x.id == c.productId);
      if (p.isNotEmpty) total += p.first.price * c.qty;
    }
    return total;
  }

  List<MapEntry<CartItem, Product>> get cartLines {
    return _cart.map((c) {
      final p = _products.where((x) => x.id == c.productId);
      return p.isNotEmpty ? MapEntry(c, p.first) : null;
    }).whereType<MapEntry<CartItem, Product>>().toList();
  }

  Future<bool> loginAdmin(String email, String password, {String? role}) async {
    try {
      final backend = await BackendManager.resolve();
      _token = await backend.loginAdmin(email, password);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('goss-token', _token!);
      await prefs.setString('goss-admin-email', email.trim());
      _adminEmail = email.trim();
      _currentAdmin = null;
      _cachedPermissions = null;
      _activeRole = (role == AdminRole.delegate || role == AdminRole.admin) ? role : null;
      await prefs.setString('goss-admin-role', _activeRole ?? '');
      _error = null;
      notifyListeners();
      FcmService.instance.onAdminLoggedIn(_token!);
      await resolveCurrentAdmin();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  String get adminEmail => _adminEmail;
  String _adminEmail = '';

  static const _masterAdminUids = {'Lt3KI3MAoIgnK1tt028suzJJDlq1'};

  AdminUser? _currentAdmin;
  AdminUser? get currentAdmin => _currentAdmin;
  List<String>? _cachedPermissions;
  String? _activeRole;

  bool get isOwner {
    final a = _currentAdmin;
    if (a != null) {
      return a.role == AdminRole.super_ || _masterAdminUids.contains(a.id);
    }
    // Cold start / legacy master-password session: the saved permission set
    // already includes the team panel, so treat it as the owner.
    return _cachedPermissions != null && _cachedPermissions!.contains(AdminPerms.team);
  }

  /// Effective permissions of the logged-in team member.
  List<String> get permissions {
    if (isOwner) return allPermissionKeys;
    final granted = _currentAdmin?.permissions.isNotEmpty == true
        ? _currentAdmin!.permissions
        : (_cachedPermissions?.isNotEmpty == true ? _cachedPermissions! : defaultPermissionsFor(_currentAdmin?.role ?? AdminRole.admin));
    // If the member chose to sign in as a delegate, limit them to the
    // delegate panels (never escalates beyond what the owner granted).
    if (_activeRole == AdminRole.delegate) {
      final delegateSet = defaultPermissionsFor(AdminRole.delegate).toSet();
      return granted.where(delegateSet.contains).toList();
    }
    return granted;
  }

  /// Whether the current admin may use the given [key] (see [AdminPerms]).
  bool can(String key) => isOwner || permissions.contains(key);

  /// Finds the current admin's profile (role + permissions) from the team list
  /// and caches it locally so the dashboard can gate tabs offline.
  Future<void> resolveCurrentAdmin() async {
    if (_token == null) return;
    try {
      await loadAdmins();
    } catch (_) {}
    AdminUser? matched;
    for (final a in _admins) {
      if (a.email.toLowerCase() == _adminEmail.toLowerCase()) {
        matched = a;
        break;
      }
    }
    // Legacy master-password login (no email address): fall back to the team
    // owner so the account keeps working. A named login that does not match a
    // team member must NOT escalate to the owner, so it stays unresolved.
    if (matched == null && _adminEmail.isEmpty) {
      for (final a in _admins) {
        if (a.role == AdminRole.super_ || _masterAdminUids.contains(a.id)) {
          matched = a;
          break;
        }
      }
      if (matched == null && _admins.isNotEmpty) matched = _admins.first;
    }
    _currentAdmin = matched;
    if (matched != null) {
      _cachedPermissions = matched.permissions.isNotEmpty ? matched.permissions : defaultPermissionsFor(matched.role);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('goss-admin-permissions', permissions.toList());
    notifyListeners();
  }

  Future<String> registerAdmin({
    required String name,
    required String email,
    required String password,
    required String code,
  }) async {
    try {
      final backend = await BackendManager.resolve();
      await backend.registerAdmin(name, email, password, code);
      final ok = await loginAdmin(email, password);
      if (!ok) throw Exception('Account created, please sign in');
      return '';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String> changeAdminPassword({
    required String email,
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final backend = await BackendManager.resolve();
      await backend.changeAdminPassword(email, oldPassword, newPassword);
      return '';
    } catch (e) {
      return e.toString();
    }
  }

  List<AdminUser> _admins = [];
  List<AdminUser> get admins => _admins;

  Future<void> loadAdmins() async {
    if (_token == null) return;
    try {
      final backend = await BackendManager.resolve();
      _admins = await backend.fetchAdmins(_token!);
      notifyListeners();
    } catch (_) {}
  }

  Future<String> addAdmin({
    required String name,
    required String email,
    required String password,
    String role = AdminRole.admin,
    List<String> permissions = const [],
  }) async {
    if (_token == null) return 'Not logged in';
    try {
      final backend = await BackendManager.resolve();
      await backend.registerAdminByAdmin(
        _token!,
        name,
        email,
        password,
        role: role,
        permissions: permissions,
      );
      await loadAdmins();
      return '';
    } catch (e) {
      return e.toString();
    }
  }

  /// Owner tool: change a team member's role and/or permissions.
  Future<String> updateAdminRoleAndPermissions({
    required String adminId,
    String? role,
    List<String>? permissions,
  }) async {
    if (_token == null) return 'Not logged in';
    try {
      final backend = await BackendManager.resolve();
      await backend.updateAdminRoleAndPermissions(
        _token!,
        adminId,
        role: role,
        permissions: permissions,
      );
      await loadAdmins();
      await resolveCurrentAdmin();
      return '';
    } catch (e) {
      return e.toString();
    }
  }

  /// Owner tool: permanently remove a team member (the owner/super admins are
  /// protected by the server and by the UI).
  Future<String> deleteAdmin(String adminId) async {
    if (_token == null) return 'Not logged in';
    try {
      final backend = await BackendManager.resolve();
      await backend.deleteAdmin(_token!, adminId);
      await loadAdmins();
      if (_currentAdmin?.id == adminId) {
        _currentAdmin = null;
        _cachedPermissions = null;
      }
      return '';
    } catch (e) {
      return e.toString();
    }
  }

  List<CustomerRequest> _myRequests = [];
  List<CustomerRequest> get myRequests => _myRequests;
  bool _myRequestsLoading = true;
  bool get myRequestsLoading => _myRequestsLoading;

  /// Requests submitted from this device (identified by the persistent customer id).
  Future<void> loadMyRequests({bool silent = false}) async {
    if (!silent) {
      _myRequestsLoading = true;
      notifyListeners();
    }
    try {
      final id = await BackendManager.customerId();
      final backend = await BackendManager.resolve();
      _myRequests = await backend.fetchMyRequests(id);
    } catch (_) {
    } finally {
      _myRequestsLoading = false;
      notifyListeners();
    }
  }

  /// Customer accepts delivery while the order is out for delivery.
  Future<String> acceptDelivery(String requestId) async {
    try {
      final id = await BackendManager.customerId();
      final backend = await BackendManager.resolve();
      await backend.acceptDelivery(requestId, id);
      await loadMyRequests(silent: true);
      return '';
    } catch (e) {
      return e.toString();
    }
  }

  /// Customer rejects delivery while the order is out for delivery.
  Future<String> rejectDelivery(String requestId) async {
    try {
      final id = await BackendManager.customerId();
      final backend = await BackendManager.resolve();
      await backend.rejectDelivery(requestId, id);
      await loadMyRequests(silent: true);
      return '';
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> logout() async {
    _token = null;
    _currentAdmin = null;
    _cachedPermissions = null;
    _activeRole = null;
    _adminEmail = '';
    _myRequests = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('goss-token');
    await prefs.remove('goss-admin-permissions');
    await prefs.remove('goss-admin-role');
    await prefs.remove('goss-admin-email');
    try {
      // revoke the Firebase session on sign out when running in Firebase mode
      final backend = await BackendManager.resolve();
      if (backend.isFirebase) {
        await FirestoreBackend.signOut();
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> sendRequest({
    required String company,
    required String name,
    required String phone,
    required String email,
    required String notes,
    String origin = '',
    String destination = '',
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final items = cartLines.map((e) => {
        'productId': e.value.id,
        'nameEn': e.value.nameEn,
        'nameAr': e.value.nameAr,
        'qty': e.key.qty,
        'unit': e.value.unit,
        'price': e.value.price,
      }).toList();
      final backend = await BackendManager.resolve();
      await backend.submitRequest({
        'token': _token ?? '',
        'company': company,
        'name': name,
        'phone': phone,
        'email': email,
        'notes': notes,
        'items': items,
        'customerId': await BackendManager.customerId(),
        'origin': origin,
        'destination': destination,
      });
      clearCart();
      ApiService.notifyNewRequest(customerName: name.isEmpty ? phone : name, itemsCount: items.length);
      _loading = false;
      notifyListeners();
    } catch (e) {
      _loading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Serializes cart writes so out-of-order saves can never leave an older
  // snapshot as the last one on disk.
  Future<void> _cartSaveQueue = Future.value();

  void _saveCart() {
    // Snapshot synchronously: the cart may change while the prefs handle is
    // being awaited, and reading it lazily would persist a stale state.
    final snapshot = jsonEncode(_cart.map((e) => e.toJson()).toList());
    _cartSaveQueue = _cartSaveQueue.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('goss-cart', snapshot);
    }).catchError((_) {
      // Persisting the cart is best-effort; the in-memory cart still works.
    });
  }
}
