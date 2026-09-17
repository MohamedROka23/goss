import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

enum BackendMode { http, firebase }

/// Abstract data layer. Implemented by both the local HTTP backend and the
/// cloud Firestore backend so the rest of the app does not care which one
/// is active.
abstract class GossBackend {
  bool get isFirebase;
  BackendMode get mode;

  // Products / Quotes
  Future<List<Product>> fetchProducts();
  Stream<List<Product>> watchProducts();
  Future<Product> saveProduct(String token, Map<String, dynamic> data);
  Future<void> deleteProduct(String token, String id);

  /// Bulk upserts categories and products parsed from an uploaded Excel sheet.
  /// Each entry must carry a stable `id`; existing documents are overwritten,
  /// new ones are created. Runs as a Firestore WriteBatch.
  Future<void> importProducts(
    String token, {
    required List<Map<String, dynamic>> categories,
    required List<Map<String, dynamic>> products,
  });
  Future<String> loginAdmin(String email, String password);

  /// After a successful [loginAdmin], the *server-authoritative* profile for
  /// the signed-in member (role + granted permissions). The server decides a
  /// member's role; the client must never trust a user-chosen role from the
  /// login screen.
  AdminUser? lastServerProfile();

  /// True when [email] + [password] are valid on the server. Used to authorize
  /// enabling quick sign-in (الدخول السريع) without mutating the live session.
  Future<bool> verifyAdminCredentials(String email, String password);
  Future<void> changeAdminPassword(String email, String oldPassword, String newPassword);

  /// Sends a password-recovery message to the registered admin email. The
  /// response is intentionally generic to avoid leaking which emails exist.
  Future<bool> requestPasswordReset(String email);

  /// Applies a new admin password using the one-time recovery [code] e-mailed
  /// by [requestPasswordReset].
  Future<bool> resetPassword(String email, String code, String newPassword);
  Future<List<AdminUser>> fetchAdmins(String token);
  /// Live stream of the signed-in member's OWN admin document, so role and
  /// permission changes made by the owner on another device propagate to this
  /// device in real time (Firestore mode). HTTP mode returns an empty stream.
  Stream<AdminUser?> watchOwnAdmin(String uid);
  Future<void> registerAdminByAdmin(
    String token,
    String name,
    String email,
    String password, {
    String role = AdminRole.admin,
    List<String> permissions = const [],
  });

  /// Updates an existing team member's role and/or permission set (owner only).
  Future<void> updateAdminRoleAndPermissions(
    String token,
    String adminId, {
    String? role,
    List<String>? permissions,
  });

  /// Removes a team member (never the owner/super admin; enforced by the server).
  Future<void> deleteAdmin(String token, String id);

  // Price quote notifications
  Future<List<PriceUpdateNotification>> fetchNotifications();
  Stream<List<PriceUpdateNotification>> watchNotifications();
  Future<void> sendPriceUpdateNotification(String token, Map<String, dynamic> data);

  // Categories (dynamic product sections)
  Future<List<ProductCategory>> fetchCategories();
  Future<void> addCategory(String token, String id, String en, String ar);

  // Customer requests
  Future<CustomerRequest> submitRequest(Map<String, dynamic> payload);
  Future<List<CustomerRequest>> fetchRequests(String token);
  Future<List<CustomerRequest>> fetchMyRequests(String customerId);
  Stream<List<CustomerRequest>> watchRequests({String token = ''});
  Future<void> updateRequestStatus(String token, String id, String status);

  /// Permanent deletion of a request (admin only). Used to clean up a
  /// customer's orders. Once gone the order cannot be restored.
  Future<void> deleteRequestAdmin(String token, String id);

  /// Marks a price-quote as converted so it can never be converted twice.
  Future<void> markRequestConverted(String token, String id);

  /// Archives (or restores) an order: archived orders are hidden from the
  /// active admin list and live under the archive view.
  Future<void> archiveRequest(String token, String id, {required bool archived});

  /// Customer-side archive: marks one of the customer's own orders archived
  /// (or restores it). Verifies ownership before writing.
  Future<void> archiveMyRequest(String requestId, String customerId, {required bool archived});

  /// Customer accepts delivery while the order is 'delivering' -> 'delivered'.
  Future<void> acceptDelivery(String requestId, String customerId);

  /// Customer rejects delivery while the order is 'delivering' -> 'rejected'.
  Future<void> rejectDelivery(String requestId, String customerId);

  // Purchases
  Future<List<Purchase>> fetchPurchases(String token);
  Future<Purchase> savePurchase(String token, Map<String, dynamic> data);
  Future<Purchase> updatePurchase(String token, String id, Map<String, dynamic> data);
  Future<void> deletePurchase(String token, String id);

  // Expenses
  Future<List<Expense>> fetchExpenses(String token);
  Future<Expense> saveExpense(String token, Map<String, dynamic> data);
  Future<Expense> updateExpense(String token, String id, Map<String, dynamic> data);
  Future<void> deleteExpense(String token, String id);

  // Accounting: double-entry journal
  Future<List<JournalEntry>> fetchJournal(String token);
  Future<JournalEntry> saveJournalEntry(String token, Map<String, dynamic> data);
  Future<void> deleteJournalEntry(String token, String id);

  // Accounting: customer payments / receivables
  Future<List<Payment>> fetchPayments(String token);
  Future<Payment> savePayment(String token, Map<String, dynamic> data);
  Future<void> deletePayment(String token, String id);
}

class BackendSettings {
  static const _key = 'goss_backend_mode';
  static const _keyUrl = 'goss_base_url';

  static Future<BackendMode> loadMode() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_key);
    return v == 'firebase' ? BackendMode.firebase : BackendMode.http;
  }

  static Future<void> saveMode(BackendMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }

  static Future<String> loadBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUrl) ?? 'http://10.0.2.2:4000';
  }

  /// Only HTTPS endpoints are accepted for the API so credentials can never be
  /// sent in the clear. Loopback dev hosts (local/emulator) still allow http.
  static bool isValidBaseUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return false;
    if (uri.scheme == 'https') return true;
    if (uri.scheme == 'http') {
      const loopback = {'localhost', '127.0.0.1', '10.0.2.2', '::1'};
      return loopback.contains(uri.host.toLowerCase());
    }
    return false;
  }

  static Future<void> saveBaseUrl(String url) async {
    if (!isValidBaseUrl(url)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUrl, url);
  }
}
