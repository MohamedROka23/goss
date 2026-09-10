import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import 'backend.dart';

class HttpBackend implements GossBackend {
  final String baseUrl;

  HttpBackend(this.baseUrl);

  @override
  BackendMode get mode => BackendMode.http;
  @override
  bool get isFirebase => false;

  Map<String, String> _headers({String? token}) {
    final h = <String, String>{'Content-Type': 'application/json'};
    if (token != null) h['Authorization'] = 'Bearer $token';
    return h;
  }

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<dynamic> _decode(http.Response res) async {
    if (res.bodyBytes.isEmpty) return null;
    try {
      final text = utf8.decode(res.bodyBytes, allowMalformed: true);
      return jsonDecode(text);
    } catch (_) {
      return null;
    }
  }

  void _check(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}');
    }
  }

  @override
  Future<List<Product>> fetchProducts() async {
    final res = await http.get(_uri('/api/products'));
    _check(res);
    final data = await _decode(res) as List;
    return data.map((e) => Product.fromJson(e)).toList();
  }

  @override
  Stream<List<Product>> watchProducts() {
    final controller = StreamController<List<Product>>();
    Future<void> poll() async {
      try {
        controller.add(await fetchProducts());
      } catch (_) {}
    }

    poll();
    final timer = Timer.periodic(const Duration(seconds: 5), (_) => poll());
    controller.onCancel = () {
      timer.cancel();
      controller.close();
    };
    return controller.stream;
  }

  @override
  Future<String> loginAdmin(String email, String password) async {
    final res = await http.post(
      _uri('/api/login'),
      headers: _headers(),
      body: jsonEncode({'email': email, 'password': password}),
    );
    _check(res);
    final data = await _decode(res);
    return data['token'];
  }

  @override
  Future<void> registerAdmin(String name, String email, String password, String code) async {
    final res = await http.post(
      _uri('/api/register'),
      headers: _headers(),
      body: jsonEncode({'name': name, 'email': email, 'password': password, 'code': code}),
    );
    _check(res);
  }

  @override
  Future<List<ProductCategory>> fetchCategories() async {
    final res = await http.get(_uri('/api/categories'));
    _check(res);
    final data = await _decode(res) as List;
    return data.map((e) => ProductCategory.fromJson(e)).toList();
  }

  @override
  Future<void> addCategory(String token, String id, String en, String ar) async {
    final res = await http.post(
      _uri('/api/categories'),
      headers: _headers(token: token),
      body: jsonEncode({'id': id, 'en': en, 'ar': ar}),
    );
    _check(res);
  }

  @override
  Future<void> changeAdminPassword(String email, String oldPassword, String newPassword) async {
    final res = await http.post(
      _uri('/api/change-password'),
      headers: _headers(),
      body: jsonEncode({'email': email, 'oldPassword': oldPassword, 'newPassword': newPassword}),
    );
    _check(res);
  }

  @override
  Future<List<AdminUser>> fetchAdmins(String token) async {
    final res = await http.get(_uri('/api/admins'), headers: _headers(token: token));
    _check(res);
    final data = await _decode(res) as List;
    return data.map((e) => AdminUser.fromJson(e)).toList();
  }

  @override
  Future<void> registerAdminByAdmin(
    String token,
    String name,
    String email,
    String password, {
    String role = AdminRole.admin,
    List<String> permissions = const [],
  }) async {
    final res = await http.post(
      _uri('/api/admins'),
      headers: _headers(token: token),
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'role': role,
        'permissions': permissions,
      }),
    );
    _check(res);
  }

  @override
  Future<void> updateAdminRoleAndPermissions(
    String token,
    String adminId, {
    String? role,
    List<String>? permissions,
  }) async {
    final res = await http.patch(
      _uri('/api/admins/$adminId'),
      headers: _headers(token: token),
      body: jsonEncode({
        if (role != null) 'role': role,
        if (permissions != null) 'permissions': permissions,
      }),
    );
    _check(res);
  }

  @override
  Future<void> deleteAdmin(String token, String id) async {
    final res = await http.delete(_uri('/api/admins/$id'), headers: _headers(token: token));
    _check(res);
  }

  @override
  Future<Product> saveProduct(String token, Map<String, dynamic> data) async {
    final id = data['id'];
    final url = _uri(id != null ? '/api/products/$id' : '/api/products');
    final res = id != null
        ? await http.put(url, headers: _headers(token: token), body: jsonEncode(data))
        : await http.post(url, headers: _headers(token: token), body: jsonEncode(data));
    _check(res);
    final d = await _decode(res);
    return Product.fromJson(d);
  }

  @override
  Future<void> deleteProduct(String token, String id) async {
    final res = await http.delete(_uri('/api/products/$id'), headers: _headers(token: token));
    _check(res);
  }

  @override
  Future<CustomerRequest> submitRequest(Map<String, dynamic> payload) async {
    final res = await http.post(
      _uri('/api/requests'),
      headers: _headers(token: payload['token'] as String?),
      body: jsonEncode(payload),
    );
    _check(res);
    return CustomerRequest.fromJson(await _decode(res));
  }

  @override
  Future<List<CustomerRequest>> fetchRequests(String token) async {
    final res = await http.get(_uri('/api/requests'), headers: _headers(token: token));
    _check(res);
    final data = await _decode(res) as List;
    return data.map((e) => CustomerRequest.fromJson(e)).toList();
  }

  @override
  Future<List<CustomerRequest>> fetchMyRequests(String customerId) async {
    final uri = _uri('/api/requests/mine')
        .replace(queryParameters: {'customerId': customerId});
    final res = await http.get(uri, headers: _headers());
    _check(res);
    final data = await _decode(res) as List;
    return data.map((e) => CustomerRequest.fromJson(e)).toList();
  }

  @override
  Future<void> acceptDelivery(String requestId, String customerId) async {
    final res = await http.post(
      _uri('/api/requests/$requestId/confirm'),
      headers: _headers(),
      body: jsonEncode({'customerId': customerId}),
    );
    _check(res);
  }

  @override
  Future<void> rejectDelivery(String requestId, String customerId) async {
    final res = await http.post(
      _uri('/api/requests/$requestId/reject'),
      headers: _headers(),
      body: jsonEncode({'customerId': customerId}),
    );
    _check(res);
  }

  @override
  Stream<List<CustomerRequest>> watchRequests({String token = ''}) {
    final controller = StreamController<List<CustomerRequest>>();
    Future<void> poll() async {
      try {
        controller.add(await fetchRequests(token));
      } catch (_) {}
    }

    poll();
    final timer = Timer.periodic(const Duration(seconds: 5), (_) => poll());
    controller.onCancel = () {
      timer.cancel();
      controller.close();
    };
    return controller.stream;
  }

  @override
  Future<void> updateRequestStatus(String token, String id, String status) async {
    final res = await http.patch(
      _uri('/api/requests/$id'),
      headers: _headers(token: token),
      body: jsonEncode({'status': status}),
    );
    _check(res);
  }

  @override
  Future<List<Purchase>> fetchPurchases(String token) async {
    final res = await http.get(_uri('/api/purchases'), headers: _headers(token: token));
    _check(res);
    final data = await _decode(res) as List;
    return data.map((e) => Purchase.fromJson(e)).toList();
  }

  @override
  Future<List<PriceUpdateNotification>> fetchNotifications() async {
    final res = await http.get(_uri('/api/notifications'));
    _check(res);
    final data = await _decode(res) as List;
    return data.map((e) => PriceUpdateNotification.fromJson(e)).toList();
  }

  @override
  Stream<List<PriceUpdateNotification>> watchNotifications() {
    final controller = StreamController<List<PriceUpdateNotification>>();
    Future<void> poll() async {
      try {
        controller.add(await fetchNotifications());
      } catch (_) {}
    }

    poll();
    final timer = Timer.periodic(const Duration(seconds: 5), (_) => poll());
    controller.onCancel = () {
      timer.cancel();
      controller.close();
    };
    return controller.stream;
  }

  @override
  Future<void> sendPriceUpdateNotification(String token, Map<String, dynamic> data) async {
    final res = await http.post(
      _uri('/api/notifications'),
      headers: _headers(token: token),
      body: jsonEncode(data),
    );
    _check(res);
  }

  @override
  Future<Purchase> savePurchase(String token, Map<String, dynamic> data) async {
    final res = await http.post(
      _uri('/api/purchases'),
      headers: _headers(token: token),
      body: jsonEncode(data),
    );
    _check(res);
    return Purchase.fromJson(await _decode(res));
  }

  @override
  Future<Purchase> updatePurchase(String token, String id, Map<String, dynamic> data) async {
    final res = await http.patch(
      _uri('/api/purchases/$id'),
      headers: _headers(token: token),
      body: jsonEncode(data),
    );
    _check(res);
    return Purchase.fromJson(await _decode(res));
  }

  @override
  Future<void> deletePurchase(String token, String id) async {
    final res = await http.delete(_uri('/api/purchases/$id'), headers: _headers(token: token));
    _check(res);
  }

  @override
  Future<List<Expense>> fetchExpenses(String token) async {
    final res = await http.get(_uri('/api/expenses'), headers: _headers(token: token));
    _check(res);
    final data = await _decode(res) as List;
    return data.map((e) => Expense.fromJson(e)).toList();
  }

  @override
  Future<Expense> saveExpense(String token, Map<String, dynamic> data) async {
    final res = await http.post(
      _uri('/api/expenses'),
      headers: _headers(token: token),
      body: jsonEncode(data),
    );
    _check(res);
    return Expense.fromJson(await _decode(res));
  }

  @override
  Future<Expense> updateExpense(String token, String id, Map<String, dynamic> data) async {
    final res = await http.patch(
      _uri('/api/expenses/$id'),
      headers: _headers(token: token),
      body: jsonEncode(data),
    );
    _check(res);
    return Expense.fromJson(await _decode(res));
  }

  @override
  Future<void> deleteExpense(String token, String id) async {
    final res = await http.delete(_uri('/api/expenses/$id'), headers: _headers(token: token));
    _check(res);
  }
}
