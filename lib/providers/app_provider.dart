import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/backend.dart';
import '../services/backend_manager.dart';
import '../services/firestore_backend.dart';
import '../services/fcm_service.dart';
import '../services/secure_store.dart';
import '../services/notification_watcher.dart';

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

  // Quick lock (قفل سريع) for the admin area: once enabled, resuming the app
  // (or a cold start with a saved session) requires a biometric check or the
  // saved 4-digit PIN before the dashboard is shown. The PIN is stored only as
  // a SHA-256 hash; the enabled setting is purely local to this device.
  bool _quickLockEnabled = false;
  bool get quickLockEnabled => _quickLockEnabled;

  /// Whether the session currently needs an unlock before showing the panel.
  bool _quickLocked = false;
  bool get quickLocked => _quickLocked;

  /// Whether biometric unlock was chosen (a fingerprint / face prompt).
  bool _quickLockBio = false;
  bool get quickLockBio => _quickLockBio;

  String _quickLockPinHash = '';
  String get quickLockPinHash => _quickLockPinHash;

  static String _hashQuickPin(String pin) =>
      sha256.convert(utf8.encode('goss-quick-lock:$pin')).toString();

  /// Persists the settings with the (hashed) PIN. Pass [bio] to also offer a
  /// biometric prompt on this device.
  Future<void> enableQuickLock({required bool bio, required String pin}) async {
    _quickLockEnabled = true;
    _quickLockBio = bio;
    _quickLockPinHash = _hashQuickPin(pin);
    _quickLocked = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('goss-quicklock', true);
    await prefs.setBool('goss-quicklock-bio', bio);
    await prefs.setString('goss-quicklock-pin', _quickLockPinHash);
    await prefs.setBool('goss-quicklock-locked', false);
    await SecureStore.writeQuickLockPinHash(_quickLockPinHash);
    notifyListeners();
  }

  Future<void> disableQuickLock() async {
    _quickLockEnabled = false;
    _quickLockBio = false;
    _quickLockPinHash = '';
    _quickLocked = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('goss-quicklock');
    await prefs.remove('goss-quicklock-bio');
    await prefs.remove('goss-quicklock-pin');
    await prefs.remove('goss-quicklock-locked');
    await SecureStore.clearQuickLockPinHash();
    notifyListeners();
  }

  bool verifyQuickLockPin(String pin) =>
      _quickLockPinHash.isNotEmpty && _hashQuickPin(pin) == _quickLockPinHash;

  // Quick sign-in (الدخول السريع): the login screen can sign the admin back in
  // with a device passcode or fingerprint instead of retyping the password.
  // The credentials live only in SecureStore (keystore/keychain), the passcode
  // is kept hashed, and arming it requires a verified current password. This
  // device-local profile intentionally survives logout(), so quick sign-in
  // stays available from the admin login screen after a sign out.
  bool _quickSignInEnabled = false;
  bool get quickSignInEnabled => _quickSignInEnabled;

  bool _quickSignInBio = false;
  bool get quickSignInBio => _quickSignInBio;

  String _quickSignInRole = '';
  String get quickSignInRole => _quickSignInRole;

  static const _qsEnabledKey = 'goss-quick-signin';
  static const _qsBioKey = 'goss-quick-signin-bio';
  static const _qsRoleKey = 'goss-quick-signin-role';

  Future<bool> quickSignInArmed() async =>
      _quickSignInEnabled && await SecureStore.hasCredentials();

  Future<String?> rememberedEmail() => SecureStore.readEmail();

  /// Encrypted password; callers must have passed a local auth gate (passcode
  /// or biometric) before invoking this.
  Future<String?> rememberedPassword() => SecureStore.readPassword();

  Future<bool> verifyQuickSignInPasscode(String passcode) =>
      SecureStore.verifyPasscode(passcode);

  /// Stores the quick sign-in profile. Returns an empty string on success or a
  /// user-facing error message otherwise.
  Future<String> armQuickSignIn({
    required String email,
    required String password,
    required String passcode,
    required bool bio,
    String? role,
  }) async {
    if (!RegExp(r'^\d{4}$').hasMatch(passcode)) {
      return 'Enter a 4-digit passcode.';
    }
    final err = await SecureStore.storeCredentials(
      email: email,
      password: password,
      passcode: passcode,
    );
    if (err != null) {
      return 'Could not protect this device: please try again.';
    }
    _quickSignInEnabled = true;
    _quickSignInBio = bio;
    _quickSignInRole = role ?? _activeRole ?? '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_qsEnabledKey, true);
    await prefs.setBool(_qsBioKey, _quickSignInBio);
    await prefs.setString(_qsRoleKey, _quickSignInRole);
    _quickLocked = false;
    await prefs.setBool('goss-quicklock-locked', false);
    notifyListeners();
    return '';
  }

  Future<void> setQuickSignInBio(bool bio) async {
    _quickSignInBio = bio;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_qsBioKey, bio);
    notifyListeners();
  }

  Future<void> disarmQuickSignIn() async {
    await SecureStore.clear();
    _quickSignInEnabled = false;
    _quickSignInBio = false;
    _quickSignInRole = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_qsEnabledKey);
    await prefs.remove(_qsBioKey);
    await prefs.remove(_qsRoleKey);
    notifyListeners();
  }

  /// Locks the admin area (called when the app goes to the background while a
  /// quick lock is configured).
  Future<void> markQuickLocked() async {
    if (!_quickLockEnabled || _quickLocked) return;
    _quickLocked = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('goss-quicklock-locked', true);
  }

  /// Records a successful unlock (biometric or PIN).
  Future<void> unmarkQuickLocked() async {
    if (!_quickLocked) return;
    _quickLocked = false;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('goss-quicklock-locked', false);
  }

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
    final legacyToken = prefs.getString('goss-token');
    // Seed the session from the plaintext copy right away: the vault lookup is
    // async and its platform plugin can be slow or absent (e.g. widget tests),
    // so startup must never block on it. When the vault answers, it overrides.
    _token = legacyToken;
    if (legacyToken != null) {
      // One-time migration: move the session token into the vault, then drop
      // the plaintext copy from the SharedPreferences archive.
      unawaited(_migrateTokenToVault(legacyToken));
    } else {
      unawaited(_recoverVaultToken());
    }
    _adminEmail = prefs.getString('goss-admin-email') ?? '';
    _lastSeenNotifAt = prefs.getString('goss-notif-seen') ?? '';
    _cachedPermissions = prefs.getStringList('goss-admin-permissions');
    _quickLockEnabled = prefs.getBool('goss-quicklock') ?? false;
    _quickLockBio = prefs.getBool('goss-quicklock-bio') ?? false;
    final securedPin = await SecureStore.readQuickLockPinHash();
    final legacyPin = prefs.getString('goss-quicklock-pin') ?? '';
    _quickLockPinHash = securedPin ?? legacyPin;
    if (legacyPin.isNotEmpty && legacyPin != securedPin) {
      // One-time migration: secure the quick-lock hash and remove the
      // SharePreferences copy that an offline brute-force could scrape.
      await SecureStore.writeQuickLockPinHash(legacyPin);
      await prefs.remove('goss-quicklock-pin');
    } else if (legacyPin.isNotEmpty) {
      await prefs.remove('goss-quicklock-pin');
    }
    _quickLocked = _quickLockEnabled && (prefs.getBool('goss-quicklock-locked') ?? false);
    _quickSignInEnabled = prefs.getBool(_qsEnabledKey) ?? false;
    _quickSignInBio = prefs.getBool(_qsBioKey) ?? false;
    _quickSignInRole = prefs.getString(_qsRoleKey) ?? '';
    final savedRole = prefs.getString('goss-admin-role') ?? '';
    _activeRole = (savedRole == AdminRole.delegate || savedRole == AdminRole.admin) ? savedRole : null;
    // Vault-first admin metadata: any stale plaintext pref copies from older
    // builds are read only as a fallback, then migrated into the keystore and
    // dropped from the archive (same pattern as the quick-lock PIN).
    unawaited(_restoreAdminMetadataFromVault(legacyToken: legacyToken));
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

  Future<void> _migrateTokenToVault(String token) async {
    await SecureStore.writeToken(token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('goss-token');
  }

  Future<void> _recoverVaultToken() async {
    final secured = await SecureStore.readToken();
    if (secured == null || secured.isEmpty || secured == _token) return;
    _token = secured;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('goss-token');
  }

  /// Reads the admin session metadata from the vault and migrates any stale
  /// plaintext pref copies from older builds into the keystore, then deletes
  /// the plaintext copies so an extracted SharedPreferences archive cannot
  /// replay or reveal them.
  Future<void> _restoreAdminMetadataFromVault({
    required String? legacyToken,
  }) async {
    try {
      final email = await SecureStore.readAdminEmail();
      if (email != null && email.isNotEmpty) {
        _adminEmail = email;
      }
      final permList = await SecureStore.readAdminPermissions();
      if (permList != null) {
        _cachedPermissions = permList;
      }
      final savedRole = await SecureStore.readAdminRole();
      if (savedRole != null && savedRole.isNotEmpty) {
        _activeRole = (savedRole == AdminRole.delegate || savedRole == AdminRole.admin)
            ? savedRole
            : null;
      }
    } catch (_) {}
    // Only when running with a live session does the offline metadata matter.
    final needsMigration = legacyToken != null || _token != null;
    if (!needsMigration) return;
    final prefs = await SharedPreferences.getInstance();
    final legacyEmail = prefs.getString('goss-admin-email');
    final legacyPerms = prefs.getStringList('goss-admin-permissions');
    final legacyRole = prefs.getString('goss-admin-role');
    if (_adminEmail.isEmpty && legacyEmail != null && legacyEmail.isNotEmpty) {
      _adminEmail = legacyEmail;
      await SecureStore.writeAdminEmail(_adminEmail);
    }
    if (_cachedPermissions == null && legacyPerms != null) {
      _cachedPermissions = legacyPerms;
      await SecureStore.writeAdminPermissions(legacyPerms);
    }
    if (_activeRole == null && (legacyRole == AdminRole.delegate || legacyRole == AdminRole.admin)) {
      _activeRole = legacyRole;
      await SecureStore.writeAdminRole(_activeRole!);
    }
    await prefs.remove('goss-admin-email');
    await prefs.remove('goss-admin-permissions');
    await prefs.remove('goss-admin-role');
    notifyListeners();
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

  /// Bulk upserts the categories and products parsed from an uploaded Excel
  /// sheet. Returns (error, categoriesCreated, productsCreated, productsUpdated).
  Future<(String, int, int, int)> bulkImportProducts(
    List<Map<String, dynamic>> categories,
    List<Map<String, dynamic>> products,
  ) async {
    if (_token == null) return ('Not logged in', 0, 0, 0);
    final existingCats = productCategories.map((c) => c.id).toSet();
    final existingProds = _products.map((p) => p.id).toSet();
    final catsCreated = categories.where((c) => !existingCats.contains(c['id'] as String)).length;
    var created = 0;
    var updated = 0;
    for (final p in products) {
      if (existingProds.contains(p['id'] as String)) {
        updated++;
      } else {
        created++;
      }
    }
    try {
      final backend = await BackendManager.resolve();
      await backend.importProducts(_token!, categories: categories, products: products);
      await loadCategories();
      await loadProducts();
      return ('', catsCreated, created, updated);
    } catch (e) {
      return (e.toString(), 0, 0, 0);
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
      await SecureStore.writeToken(_token!);
      await prefs.remove('goss-token');
      _adminEmail = email.trim();
      await SecureStore.writeAdminEmail(_adminEmail);
      // The server (HTTP) / admins record (Firestore) decides the member's
      // role and permissions. A user-chosen role from the login screen is
      // never trusted for delegation in the other direction.
      _currentAdmin = backend.lastServerProfile();
      _cachedPermissions = null;
      _quickLocked = false;
      await prefs.setBool('goss-quicklock-locked', false);
      _activeRole = backend.lastServerProfile()?.role;
      if (_activeRole != null) await SecureStore.writeAdminRole(_activeRole!);
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
    // A named login that no longer resolves to any team member is treated as
    // having zero permissions (never escalates to the full admin set).
    if (_currentAdmin == null && _adminEmail.isNotEmpty) {
      return const [];
    }
    final granted = _currentAdmin?.permissions.isNotEmpty == true
        ? _currentAdmin!.permissions
        : (_cachedPermissions?.isNotEmpty == true ? _cachedPermissions! : defaultPermissionsFor(_currentAdmin?.role ?? AdminRole.admin));
    // If the member signed in under a delegate role, limit them to the
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
    // Only overwrite _currentAdmin when the team list confirms a profile.
    // When loadAdmins fails (e.g. a delegate lacks the "team" permission to
    // read the full list) the server-authoritative profile set during login
    // is already in _currentAdmin and must be preserved — never overwrite it
    // with null, or all panels disappear.
    if (matched != null) {
      _currentAdmin = matched;
      _cachedPermissions = matched.permissions.isNotEmpty ? matched.permissions : defaultPermissionsFor(matched.role);
      _activeRole = matched.role;
    } else if (_currentAdmin == null && _adminEmail.isNotEmpty) {
      // A named login that no longer matches any team member (e.g. deleted by
      // the owner) must NOT keep its prior permissions: block it here rather
      // than falling back to the full panel set.
      _cachedPermissions = const [];
    }
    await SecureStore.writeAdminPermissions(permissions.toList());
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
    final legacyToken = _token;
    _token = null;
    _currentAdmin = null;
    _cachedPermissions = null;
    _activeRole = null;
    _adminEmail = '';
    _myRequests = [];
    NotificationWatcher.instance.stopAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('goss-token');
    await prefs.remove('goss-admin-permissions');
    await prefs.remove('goss-admin-role');
    await prefs.remove('goss-admin-email');
    await SecureStore.clearAdminMetadata();
    _quickLockEnabled = false;
    _quickLockBio = false;
    _quickLockPinHash = '';
    _quickLocked = false;
    await prefs.remove('goss-quicklock');
    await prefs.remove('goss-quicklock-bio');
    await prefs.remove('goss-quicklock-pin');
    await prefs.remove('goss-quicklock-locked');
    await SecureStore.clearToken();
    await SecureStore.clearQuickLockPinHash();
    try {
      // revoke the Firebase session on sign out when running in Firebase mode
      final backend = await BackendManager.resolve();
      if (backend.isFirebase) {
        await FirestoreBackend.signOut();
      }
    } catch (_) {}
    // Force-invalidate the caller's server session (the server only ever
    // revokes the presented token, never everyone else's).
    try {
      final baseUrl = await BackendSettings.loadBaseUrl();
      final token = legacyToken;
      await http.post(
        Uri.parse('$baseUrl/api/logout'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        },
      );
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
    String type = 'supply',
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
        'type': type,
      });
      clearCart();
      _loading = false;
      notifyListeners();
    } catch (e) {
      _loading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Convert a quote request into a supply request using the same items.
  Future<void> convertQuoteToSupply(CustomerRequest quote) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final items = quote.items.map((i) => {
        'productId': i.productId,
        'nameEn': i.nameEn,
        'nameAr': i.nameAr,
        'qty': i.qty,
        'unit': i.unit,
        'price': i.price,
      }).toList();
      final backend = await BackendManager.resolve();
      await backend.submitRequest({
        'token': _token ?? '',
        'company': quote.company,
        'name': quote.name,
        'phone': quote.phone,
        'email': quote.email,
        'notes': quote.notes,
        'items': items,
        'customerId': quote.customerId,
        'origin': quote.origin,
        'destination': quote.destination,
        'type': 'supply',
      });
      await loadMyRequests();
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
