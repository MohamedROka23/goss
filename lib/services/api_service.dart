import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import 'backend.dart';

class ApiService {
  // Android emulator: use 10.0.2.2 to reach the host machine's localhost.
  // On a real device, replace with your machine's LAN IP.
  static String _cachedUrl = 'http://10.0.2.2:4000';

  static String get baseUrl => _cachedUrl;

  /// Loads the user-saved backend URL (same one HttpBackend uses) once at startup.
  static Future<void> refreshBaseUrl() async {
    try {
      _cachedUrl = await BackendSettings.loadBaseUrl();
    } catch (_) {}
  }

  static Map<String, String> _headers({String? token}) {
    final h = <String, String>{'Content-Type': 'application/json'};
    if (token != null) h['Authorization'] = 'Bearer $token';
    return h;
  }

  static Future<List<Product>> fetchProducts() async {
    final res = await http.get(Uri.parse('$baseUrl/api/products'));
    if (res.statusCode != 200) throw Exception('Failed to load products');
    return (jsonDecode(res.body) as List).map((e) => Product.fromJson(e)).toList();
  }

  static Future<String> loginAdmin(String email, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/login'),
      headers: _headers(),
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (res.statusCode != 200) throw Exception('Invalid email or password');
    return jsonDecode(res.body)['token'];
  }

  static Future<void> registerAdmin(String name, String email, String password, String code) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/register'),
      headers: _headers(),
      body: jsonEncode({'name': name, 'email': email, 'password': password, 'code': code}),
    );
    if (res.statusCode != 200 && res.statusCode != 201) throw Exception('Registration failed');
  }

  static Future<void> changeAdminPassword(String email, String oldPassword, String newPassword) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/change-password'),
      headers: _headers(),
      body: jsonEncode({'email': email, 'oldPassword': oldPassword, 'newPassword': newPassword}),
    );
    if (res.statusCode != 200) throw Exception('Password change failed');
  }

  static Future<List<AdminUser>> fetchAdmins(String token) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/admins'),
      headers: _headers(token: token),
    );
    if (res.statusCode != 200) throw Exception('Failed to load admins');
    return (jsonDecode(res.body) as List).map((e) => AdminUser.fromJson(e)).toList();
  }

  static Future<void> registerAdminByAdmin(String token, String name, String email, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/admins'),
      headers: _headers(token: token),
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    );
    if (res.statusCode != 200 && res.statusCode != 201) throw Exception('Registration failed');
  }

  static Future<Product> saveProduct(String token, Map<String, dynamic> data) async {
    final id = data['id'];
    final url = id != null ? '$baseUrl/api/products/$id' : '$baseUrl/api/products';
    final res = id != null
        ? await http.put(
            Uri.parse(url),
            headers: _headers(token: token),
            body: jsonEncode(data),
          )
        : await http.post(
            Uri.parse(url),
            headers: _headers(token: token),
            body: jsonEncode(data),
          );
    if (res.statusCode != 200 && res.statusCode != 201) throw Exception('Save failed');
    return Product.fromJson(jsonDecode(res.body));
  }

  static Future<void> deleteProduct(String token, String id) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/api/products/$id'),
      headers: _headers(token: token),
    );
    if (res.statusCode != 200) throw Exception('Delete failed');
  }

  static Future<CustomerRequest> submitRequest({
    required String token,
    required String company,
    required String name,
    required String phone,
    required String email,
    required String notes,
    required List<Map<String, dynamic>> items,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/requests'),
      headers: _headers(token: token),
      body: jsonEncode({
        'company': company,
        'name': name,
        'phone': phone,
        'email': email,
        'notes': notes,
        'items': items,
      }),
    );
    if (res.statusCode != 200 && res.statusCode != 201) throw Exception('Request failed');
    return CustomerRequest.fromJson(jsonDecode(res.body));
  }

  static Future<List<CustomerRequest>> fetchRequests(String token) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/requests'),
      headers: _headers(token: token),
    );
    if (res.statusCode != 200) throw Exception('Failed to load requests');
    return (jsonDecode(res.body) as List).map((e) => CustomerRequest.fromJson(e)).toList();
  }

  static Future<void> updateRequestStatus(String token, String id, String status) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/api/requests/$id'),
      headers: _headers(token: token),
      body: jsonEncode({'status': status}),
    );
    if (res.statusCode != 200) throw Exception('Update failed');
  }

  static Future<List<Expense>> fetchExpenses(String token) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/expenses'),
      headers: _headers(token: token),
    );
    if (res.statusCode != 200) throw Exception('Failed to load expenses');
    return (jsonDecode(res.body) as List).map((e) => Expense.fromJson(e)).toList();
  }

  static Future<Expense> saveExpense(String token, Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/expenses'),
      headers: _headers(token: token),
      body: jsonEncode(data),
    );
    if (res.statusCode != 200 && res.statusCode != 201) throw Exception('Save failed');
    return Expense.fromJson(jsonDecode(res.body));
  }

  static Future<void> deleteExpense(String token, String id) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/api/expenses/$id'),
      headers: _headers(token: token),
    );
    if (res.statusCode != 200) throw Exception('Delete failed');
  }

  static Future<List<Purchase>> fetchPurchases(String token) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/purchases'),
      headers: _headers(token: token),
    );
    if (res.statusCode != 200) throw Exception('Failed to load purchases');
    return (jsonDecode(res.body) as List).map((e) => Purchase.fromJson(e)).toList();
  }

  static Future<Purchase> savePurchase(String token, Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/purchases'),
      headers: _headers(token: token),
      body: jsonEncode(data),
    );
    if (res.statusCode != 200 && res.statusCode != 201) throw Exception('Save failed');
    return Purchase.fromJson(jsonDecode(res.body));
  }

  static Future<void> deletePurchase(String token, String id) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/api/purchases/$id'),
      headers: _headers(token: token),
    );
    if (res.statusCode != 200) throw Exception('Delete failed');
  }

  static Future<List<ProductCategory>> fetchCategories() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/categories'),
      headers: _headers(),
    );
    if (res.statusCode != 200) throw Exception('Failed to load categories');
    return (jsonDecode(res.body) as List)
        .map((e) => ProductCategory.fromJson(e))
        .toList();
  }

  static Future<void> addCategory(String token, String id, String en, String ar) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/categories'),
      headers: _headers(token: token),
      body: jsonEncode({'id': id, 'en': en, 'ar': ar}),
    );
    if (res.statusCode != 200 && res.statusCode != 201) throw Exception('Failed to add category');
  }

  static Future<List<PriceUpdateNotification>> fetchNotifications() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/notifications'),
      headers: _headers(),
    );
    if (res.statusCode != 200) throw Exception('Failed to load notifications');
    return (jsonDecode(res.body) as List)
        .map((e) => PriceUpdateNotification.fromJson(e))
        .toList();
  }

  static Future<void> sendPriceUpdateNotification(String token, Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/notifications'),
      headers: _headers(token: token),
      body: jsonEncode(data),
    );
    if (res.statusCode != 200 && res.statusCode != 201) throw Exception('Failed to send notification');
  }

  /// Fire-and-forget external push: admin updated a price -> customers' devices.
  static Future<void> notifyPriceUpdate({
    required String token,
    required String productNameEn,
    required String productNameAr,
    required double oldPrice,
    required double newPrice,
    required String unit,
  }) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/api/notify/price-update'),
        headers: _headers(token: token),
        body: jsonEncode({
          'productNameEn': productNameEn,
          'productNameAr': productNameAr,
          'oldPrice': oldPrice,
          'newPrice': newPrice,
          'unit': unit,
        }),
      );
    } catch (_) {
      // Push is best-effort; in-app updates still work without the server.
    }
  }
}
