import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/backend.dart';
import '../services/backend_manager.dart';
import '../services/biometric_service.dart';
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
  List<ProductCategory> get productCategories => _categories;

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
  ///
  /// The PIN verifier is written ONLY to the secure store. An earlier version
  /// also mirrored the hash into plain SharedPreferences, which contradicted the
  /// invariant in secure_store.dart and exposed the verifier to anything that
  /// can read an app backup.
  Future<void> enableQuickLock({required bool bio, required String pin}) async {
    _quickLockEnabled = true;
    _quickLockBio = bio;
    _quickLockPinHash = _hashQuickPin(pin);
    _quickLocked = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('goss-quicklock', true);
    await prefs.setBool('goss-quicklock-bio', bio);
    // Remove any verifier a previous build left in plain preferences.
    await prefs.remove('goss-quicklock-pin');
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

  /// Live biometric capability for this device.
  ///
  /// Exposed as a single enum instead of several booleans so a screen cannot
  /// offer the fingerprint button on a device whose sensor has nothing
  /// enrolled, which is what used to make the button appear and then fail.
  BiometricCapability get biometricCapability => biometrics.capability;
  bool get biometricReady => biometrics.canPrompt;
  bool get biometricHardwarePresent => biometrics.hasHardware;

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

  /// Re-reads the device biometric state.
  ///
  /// Call after a successful prompt (the user may have just enrolled a
  /// fingerprint from the system settings sheet that the prompt sent them to)
  /// and whenever a screen is about to show a biometric option. If the user
  /// has since enrolled something, the saved "use biometrics" preference is
  /// re-enabled automatically — otherwise a device that was enrolled after
  /// first setup would stay locked out of the feature forever.
  Future<BiometricCapability> refreshBiometrics() async {
    final capability = await biometrics.probe();
    if (capability == BiometricCapability.available && !_quickSignInBio) {
      await setQuickSignInBio(true);
    } else if (capability != BiometricCapability.available && _quickSignInBio) {
      // The sensor is gone or nothing is enrolled: turn the preference off so
      // the UI does not keep offering a prompt that cannot succeed.
      await setQuickSignInBio(false);
    } else {
      notifyListeners();
    }
    return capability;
  }

  /// Runs a biometric prompt with the app's own localized reason.
  /// Never throws: on any failure it returns false and refreshes [biometricCapability].
  Future<bool> authenticateBiometric({required bool isArabic}) async {
    final ok = await biometrics.authenticate(
      reason: isArabic
          ? 'الدخول إلى لوحة الأدمن'
          : 'Sign in to the admin panel',
    );
    if (!ok) await refreshBiometrics();
    return ok;
  }

  /// Label for the biometric button, matching the enrolled modality.
  Future<String> biometricLabel({required bool isArabic}) =>
      biometrics.label(isArabic: isArabic);

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

  /// Guards against duplicate request submission from a double tap while the
  /// previous submit is still in flight.
  bool _requestInFlight = false;

  String? _error;
  String? get error => _error;

  StreamSubscription<List<Product>>? _productSub;
  StreamSubscription<List<PriceUpdateNotification>>? _notifSub;
  StreamSubscription<List<ProductCategory>>? _catSub;
  StreamSubscription<List<AdminUser>>? _adminsSub;
  StreamSubscription<List<CustomerRequest>>? _myReqSub;
  StreamSubscription<AdminUser?>? _adminSub;
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
    _catSub?.cancel();
    _adminsSub?.cancel();
    _myReqSub?.cancel();
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
    // The saved preference is a cache of what worked before; the live device
    // state decides what to offer, so probe once at startup and reconcile.
    unawaited(refreshBiometrics());
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
      await watchOwnAdmin();
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
      _categories = list;
      notifyListeners();
    } catch (_) {}
  }

  /// Live categories. A section added or renamed by the owner reaches the
  /// customer catalogue and the admin editor as soon as the write commits,
  /// without a pull-to-refresh. The first event also serves as the initial
  /// load, so this supersedes the periodic reload the category editor used.
  Future<void> watchCategories() async {
    try {
      final backend = await BackendManager.resolve();
      await _catSub?.cancel();
      _catSub = backend.watchCategories().listen((list) {
        if (_disposed) return;
        _categories = list;
        notifyListeners();
      });
    } catch (_) {}
  }

  /// Live team roster, so a permission change, demotion or removal made on
  /// another device shows up in the team panel immediately.
  Future<void> watchAdmins() async {
    if (_token == null) return;
    try {
      final backend = await BackendManager.resolve();
      await _adminsSub?.cancel();
      _adminsSub = backend.watchAdmins(token: _token!).listen((list) {
        if (_disposed) return;
        _admins = list;
        notifyListeners();
        // A change to any member can revoke or shrink this account's own
        // access, so re-resolve against the fresh roster.
        unawaited(resolveCurrentAdmin());
      });
    } catch (_) {}
  }

  /// Live view of the signed-in customer's own orders. Replaces the 5-second
  /// poll in the "my orders" screen, so a status change made by the shop (or a
  /// new order placed from another device) lands immediately.
  Future<void> watchMyRequests() async {
    try {
      final id = await BackendManager.customerId();
      final backend = await BackendManager.resolve();
      await _myReqSub?.cancel();
      _myReqSub = backend.watchMyRequests(id).listen((list) {
        if (_disposed) return;
        _myRequests = list;
        _myRequestsLoading = false;
        notifyListeners();
      });
    } catch (_) {
      _myRequestsLoading = false;
      if (!_disposed) notifyListeners();
    }
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
      await watchOwnAdmin();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  String get adminEmail => _adminEmail;
  String _adminEmail = '';

  AdminUser? _currentAdmin;
  AdminUser? get currentAdmin => _currentAdmin;
  List<String>? _cachedPermissions;
  String? _activeRole;

  /// Whether the signed-in member holds the owner role.
  ///
  /// Derived ONLY from the live team record. The previous version fell back to
  /// the cached permission list, which meant that if the team list failed to
  /// load (offline, permission-denied, cold start) any member whose cache
  /// contained `team` was treated as the owner and `can()` answered true for
  /// every panel. Owner status is a server-side fact; a cache is never evidence.
  ///
  /// The compiled-in uid list is intentionally no longer an authorization input.
  /// It cannot be revoked, so the owner's owner-rights were unrevocable from any
  /// other device; the `/admins` document is the single source of truth.
  bool get isOwner => _currentAdmin?.role == AdminRole.super_;

  /// Effective permissions of the logged-in team member.
  ///
  /// Precedence: the live profile, then the last known cached set, then the
  /// default for the role. The cache is a display convenience only — it is
  /// never treated as proof of ownership (see [isOwner]), and a *named* login
  /// that no longer resolves to any team member is denied outright rather than
  /// falling back, because that is exactly the revoked case.
  List<String> get permissions {
    final a = _currentAdmin;
    if (a == null && _adminEmail.isNotEmpty) {
      // Signed in with an address that is not (or no longer) a team member:
      // revoked or deleted. No panels, no fallback.
      return const [];
    }
    if (a != null) {
      if (a.role == AdminRole.super_) return allPermissionKeys;
      if (!AdminRole.active.contains(a.role)) return const [];
    }
    final role = a?.role ?? AdminRole.admin;
    final granted = (a?.permissions.isNotEmpty ?? false)
        ? a!.permissions
        : (_cachedPermissions?.isNotEmpty == true
            ? _cachedPermissions!
            : defaultPermissionsFor(role));
    // A member signed in under a delegate role is limited to the delegate
    // panels (never escalates beyond what the owner granted).
    if (role == AdminRole.delegate) {
      final delegateSet = defaultPermissionsFor(AdminRole.delegate).toSet();
      return granted.where(delegateSet.contains).toList();
    }
    return granted;
  }

  /// Whether the current admin may use the given [key] (see [AdminPerms]).
  bool can(String key) => isOwner || permissions.contains(key);

  /// Finds the current admin's profile (role + permissions) from the team list
  /// and caches it locally so the dashboard can gate tabs offline.
  /// Live-listens to the signed-in member's OWN /admins/{uid} document so the
  /// permissions and role granted by the owner on another device take effect on
  /// this device immediately, without a restart. Ignores the stream in HTTP
  /// mode and when no Firestore session is resolved.
  ///
  /// Removal is handled here too: when the owner deletes the member (which
  /// writes a `revoked` tombstone) or the document disappears, this device signs
  /// itself out on the spot instead of holding a session that the rules would
  /// already be refusing. The listener is re-armed on error, because a
  /// permission-denied error is exactly what a demotion produces and a dead
  /// subscription would freeze the old permission set on screen forever.
  Future<void> watchOwnAdmin() async {
    final uid = _currentAdmin?.id;
    if (uid == null || uid.isEmpty) return;
    final backend = await BackendManager.resolve();
    if (!backend.isFirebase) return;
    await _adminSub?.cancel();
    _adminSub = backend.watchOwnAdmin(uid).listen(
      (snap) {
        if (_disposed) return;
        if (snap == null || !AdminRole.active.contains(snap.role)) {
          // Removed from the team while signed in: drop the session now.
          unawaited(_handleRevoked());
          return;
        }
        final prev = _currentAdmin;
        _currentAdmin = snap;
        _cachedPermissions =
            snap.permissions.isNotEmpty ? snap.permissions : defaultPermissionsFor(snap.role);
        _activeRole = snap.role;
        if (snap.role != prev?.role) {
          unawaited(SecureStore.writeAdminRole(snap.role));
        }
        if (prev?.permissions != snap.permissions || prev?.role != snap.role) {
          unawaited(SecureStore.writeAdminPermissions(permissions.toList()));
        }
        notifyListeners();
      },
      onError: (Object _) {
        // The document became unreadable (e.g. the role was demoted to
        // delegate, which no longer satisfies isAdmin() for the full list).
        // Re-arm so the next revocation is still observed.
        if (_disposed) return;
        scheduleMicrotask(watchOwnAdmin);
      },
    );
  }

  /// Wipes the local session after the owner removed this account.
  ///
  /// This runs on a Firestore listener callback, so it must never throw: an
  /// exception here would abort before the session is cleared and leave a
  /// revoked member signed in on screen. Local state is nulled first and
  /// synchronously, so the panels disappear even if the teardown below fails.
  Future<void> _handleRevoked() async {
    if (_disposed) return;
    _error = 'تم إلغاء هذا الحساب من الفريق. تم تسجيل الخروج.';
    _currentAdmin = null;
    _cachedPermissions = const [];
    _activeRole = null;
    notifyListeners();
    try {
      await _adminSub?.cancel();
    } catch (_) {}
    _adminSub = null;
    try {
      await logout();
    } catch (_) {
      // Teardown partially failed (offline keychain, unreachable backend). The
      // in-memory session is already gone, which is what gates the UI; the
      // stored token is revoked server-side the moment the tombstone lands.
    }
  }

  Future<void> resolveCurrentAdmin() async {
    if (_token == null) return;
    // Did the team list actually load? A failed read is NOT evidence that the
    // member was removed, and must never be treated as a revocation: that would
    // sign a perfectly valid admin out on the first flaky network response.
    var listLoaded = true;
    try {
      await loadAdmins();
    } catch (_) {
      listLoaded = false;
    }

    // Match by uid first. uid is the document key, so it cannot drift the way an
    // e-mail can (this project already had an owner whose Auth address was
    // info@gossts.com while the /admins document said info@gosst.com, and the
    // e-mail comparison silently signed them out). The server profile already
    // carries the uid, so the common path never depends on a list read at all.
    AdminUser? matched;
    final uid = _currentAdmin?.id;
    if (uid != null && uid.isNotEmpty) {
      for (final a in _admins) {
        if (a.id == uid) {
          matched = a;
          break;
        }
      }
    }
    if (matched == null && _adminEmail.isNotEmpty) {
      for (final a in _admins) {
        if (a.email.trim().toLowerCase() == _adminEmail.trim().toLowerCase()) {
          matched = a;
          break;
        }
      }
    }
    // Legacy master-password login (no e-mail address, HTTP mode only): fall
    // back to the team owner so the account keeps working.
    if (matched == null && _adminEmail.isEmpty && listLoaded) {
      for (final a in _admins) {
        if (a.role == AdminRole.super_) {
          matched = a;
          break;
        }
      }
      if (matched == null && _admins.isNotEmpty) matched = _admins.first;
    }

    if (matched != null) {
      // The team list confirms a live profile. This is the only writer allowed
      // to populate _currentAdmin, so a stale cache can never be promoted.
      _currentAdmin = matched;
      _cachedPermissions = matched.permissions.isNotEmpty
          ? matched.permissions
          : defaultPermissionsFor(matched.role);
      _activeRole = matched.role;
    } else if (listLoaded) {
      // The list loaded fine and this account is genuinely not in it — that is
      // the revoked/removed case. Clear the profile and drop the session.
      _currentAdmin = null;
      _cachedPermissions = const [];
      _activeRole = null;
      if (_adminEmail.isNotEmpty) {
        await _handleRevoked();
        return;
      }
    }
    // else: the list could not be read. Keep the server profile from sign-in
    // (it was validated against the live /admins document by the backend) and
    // stay signed in. watchOwnAdmin still reports a real removal promptly.
    await SecureStore.writeAdminPermissions(permissions.toList());
    notifyListeners();
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
    // Rethrows on purpose. `resolveCurrentAdmin` must be able to tell "the
    // read failed" from "the team is genuinely empty" — swallowing the error
    // here made a transient network failure look like a revocation and signed
    // a valid admin out.
    final backend = await BackendManager.resolve();
    _admins = await backend.fetchAdmins(_token!);
    notifyListeners();
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
      // The write already succeeded; a failed refresh must not be reported as
      // a failed save.
      await loadAdmins().catchError((_) {});
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
      await loadAdmins().catchError((_) {});
      await resolveCurrentAdmin();
      return '';
    } catch (e) {
      return e.toString();
    }
  }

  /// Owner tool: remove a team member.
  ///
  /// The backend rewrites the account into a `revoked` tombstone, which strips
  /// its permissions immediately and reserves the e-mail permanently. It also
  /// asks the server to disable/delete the Firebase Auth record so the raw
  /// credential stops working.
  ///
  /// Returns a [message] plus [fatal]. `fatal: false` with a non-empty message
  /// means access was revoked but closing the sign-in credential did not
  /// complete (server unreachable) — the caller should warn, not report failure,
  /// because the account still cannot reach any panel.
  /// The owner/super admin is protected by the rules and the server.
  Future<({String message, bool fatal})> deleteAdmin(String adminId) async {
    if (_token == null) {
      return (message: 'Not logged in', fatal: true);
    }
    try {
      final backend = await BackendManager.resolve();
      final res = await backend.deleteAdmin(_token!, adminId);
      await loadAdmins().catchError((_) {});
      if (_currentAdmin?.id == adminId) {
        _currentAdmin = null;
        _cachedPermissions = const [];
      }
      return (message: res.warning ?? '', fatal: false);
    } catch (e) {
      return (message: e.toString(), fatal: true);
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

  /// Customer-side archive: hides one of the customer's own orders (or restores).
  Future<String> archiveMyOrder(CustomerRequest r, {required bool archived}) async {
    try {
      final id = await BackendManager.customerId();
      final backend = await BackendManager.resolve();
      await backend.archiveMyRequest(r.id, id, archived: archived);
      await loadMyRequests(silent: true);
      return '';
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> logout() async {
    final legacyToken = _token;
    // Stop the own-admin listener first: it is the component that can rewrite
    // _currentAdmin, so leaving it alive would let a late event resurrect the
    // session that this method is tearing down.
    await _adminSub?.cancel();
    _adminSub = null;
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
    bool vat = false,
    List<CartItem>? lines,
  }) async {
    // One submit at a time: a double tap must never create a duplicate order.
    if (_requestInFlight) {
      throw Exception('Request is already being sent');
    }
    _requestInFlight = true;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      // The dedicated Quote screen keeps its own local list, so use the lines
      // it passes; otherwise fall back to the shared catalog cart.
      final sourceLines = lines ?? _cart;
      final items = sourceLines.map((c) {
        final match = _products.where((p) => p.id == c.productId);
        if (match.isEmpty) return null;
        final p = match.first;
        return <String, dynamic>{
          'productId': p.id,
          'nameEn': p.nameEn,
          'nameAr': p.nameAr,
          'qty': c.qty,
          'unit': p.unit,
          'price': p.price,
        };
      }).whereType<Map<String, dynamic>>().toList();
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
        'vat': vat,
      });
      // Only clear the shared catalog cart when it was the source; a local
      // quote cart is cleared by its own screen.
      if (lines == null) clearCart();
      _loading = false;
      _requestInFlight = false;
      notifyListeners();
    } catch (e) {
      _loading = false;
      _requestInFlight = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Convert a quote request into a supply request using the same items.
  Future<void> convertQuoteToSupply(CustomerRequest quote) async {
    if (quote.converted) return;
    // A double tap must never create two supply requests from one quote.
    if (_requestInFlight) return;
    _requestInFlight = true;
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
      // Flag the original quote as converted so the action cannot repeat.
      if (quote.customerId.isNotEmpty) {
        try {
          await backend.markRequestConverted(_token ?? '', quote.id);
        } catch (_) {}
      }
      await loadMyRequests();
      _loading = false;
      _requestInFlight = false;
      notifyListeners();
    } catch (e) {
      _loading = false;
      _requestInFlight = false;
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
