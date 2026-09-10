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
  Future<String> loginAdmin(String email, String password);
  Future<void> registerAdmin(String name, String email, String password, String code);
  Future<void> changeAdminPassword(String email, String oldPassword, String newPassword);
  Future<List<AdminUser>> fetchAdmins(String token);
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

  static Future<void> saveBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUrl, url);
  }
}
