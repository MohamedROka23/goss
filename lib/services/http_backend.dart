import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';
import '../security/secure_http.dart';
import 'backend.dart';

class HttpBackend implements GossBackend {
  final String baseUrl;

  HttpBackend(this.baseUrl);

  AdminUser? _lastServerProfile;

  @override
  AdminUser? lastServerProfile() => _lastServerProfile;

  @override
  BackendMode get mode => BackendMode.http;
  @override
  bool get isFirebase => false;

  /// All outgoing requests go through the (optionally pinned) TLS client.
  final http.Client _client = SecureHttp.client;

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
    final res = await _client.get(_uri('/api/products'));
    _check(res);
    final data = await _decode(res) as List;
    return data.map((e) => Product.fromJson(e)).toList();
  }

  /// Wraps a one-shot fetch in a periodic stream, used only by the HTTP
  /// backend. Firestore mode delivers real push updates, but this backend has
  /// no server-sent channel, so it polls. The previous hand-rolled copies of
  /// this raced: `onCancel` closed the controller while an in-flight `poll()`
  /// could still `add()`, throwing on a closed sink. This version is safe to
  /// cancel from either side.
  Stream<List<T>> _polled<T>(Future<List<T>> Function() fetch) {
    late final StreamController<List<T>> controller;
    Timer? timer;
    var cancelled = false;
    controller = StreamController<List<T>>(
      onListen: () async {
        Future<void> poll() async {
          if (cancelled) return;
          try {
            final value = await fetch();
            if (!cancelled && !controller.isClosed) controller.add(value);
          } catch (_) {
            // Transient failure: keep the last good list on screen.
          }
        }

        await poll();
        timer = Timer.periodic(const Duration(seconds: 5), (_) => poll());
      },
      onCancel: () {
        cancelled = true;
        timer?.cancel();
        timer = null;
      },
    );
    return controller.stream;
  }

  @override
  Stream<List<Product>> watchProducts() => _polled(fetchProducts);

  @override
  Stream<List<AdminUser>> watchAdmins({String token = ''}) =>
      _polled(() => fetchAdmins(token));

  @override
  Stream<List<ProductCategory>> watchCategories() => _polled(fetchCategories);

  @override
  Stream<List<CustomerRequest>> watchMyRequests(String customerId) =>
      _polled(() => fetchMyRequests(customerId));

  @override
  Stream<List<Purchase>> watchPurchases({String token = ''}) =>
      _polled(() => fetchPurchases(token));

  @override
  Stream<List<Expense>> watchExpenses({String token = ''}) =>
      _polled(() => fetchExpenses(token));

  @override
  Stream<List<JournalEntry>> watchJournal({String token = ''}) =>
      _polled(() => fetchJournal(token));

  @override
  Stream<List<Payment>> watchPayments({String token = ''}) =>
      _polled(() => fetchPayments(token));

  @override
  Future<String> loginAdmin(String email, String password) async {
    final res = await _client.post(
      _uri('/api/login'),
      headers: _headers(),
      body: jsonEncode({'email': email, 'password': password}),
    );
    _check(res);
    final data = await _decode(res);
    final rawUser = data['user'];
    _lastServerProfile = rawUser is Map<String, dynamic>
        ? AdminUser.fromJson(rawUser)
        : null;
    return data['token'];
  }

  @override
  Future<bool> verifyAdminCredentials(String email, String password) async {
    try {
      final res = await _client.post(
        _uri('/api/login'),
        headers: _headers(),
        body: jsonEncode({'email': email, 'password': password}),
      );
      if (res.statusCode != 200) return false;
      final data = await _decode(res);
      return (data['token'] as String?)?.isNotEmpty ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestPasswordReset(String email) async {
    try {
      final res = await _client.post(
        _uri('/api/forgot-password'),
        headers: _headers(),
        body: jsonEncode({'email': email}),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> resetPassword(
    String email,
    String code,
    String newPassword,
  ) async {
    try {
      final res = await _client.post(
        _uri('/api/reset-password'),
        headers: _headers(),
        body: jsonEncode({
          'email': email,
          'code': code,
          'newPassword': newPassword,
        }),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<ProductCategory>> fetchCategories() async {
    final res = await _client.get(_uri('/api/categories'));
    _check(res);
    final data = await _decode(res) as List;
    return data.map((e) => ProductCategory.fromJson(e)).toList();
  }

  @override
  Future<void> addCategory(
    String token,
    String id,
    String en,
    String ar,
  ) async {
    final res = await _client.post(
      _uri('/api/categories'),
      headers: _headers(token: token),
      body: jsonEncode({'id': id, 'en': en, 'ar': ar}),
    );
    _check(res);
  }

  @override
  Future<void> changeAdminPassword(
    String email,
    String oldPassword,
    String newPassword,
  ) async {
    final res = await _client.post(
      _uri('/api/change-password'),
      headers: _headers(),
      body: jsonEncode({
        'email': email,
        'oldPassword': oldPassword,
        'newPassword': newPassword,
      }),
    );
    _check(res);
  }

  @override
  Future<List<AdminUser>> fetchAdmins(String token) async {
    final res = await _client.get(
      _uri('/api/admins'),
      headers: _headers(token: token),
    );
    _check(res);
    final data = await _decode(res) as List;
    return data.map((e) => AdminUser.fromJson(e)).toList();
  }

  @override
  Stream<AdminUser?> watchOwnAdmin(String uid) => const Stream.empty();

  @override
  Future<void> registerAdminByAdmin(
    String token,
    String name,
    String email,
    String password, {
    String role = AdminRole.admin,
    List<String> permissions = const [],
  }) async {
    final res = await _client.post(
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
    final res = await _client.patch(
      _uri('/api/admins/$adminId'),
      headers: _headers(token: token),
      body: jsonEncode({'role': ?role, 'permissions': ?permissions}),
    );
    _check(res);
  }

  @override
  Future<({bool authDeleted, String? warning})> deleteAdmin(
    String token,
    String id,
  ) async {
    final res = await _client.delete(
      _uri('/api/admins/$id'),
      headers: _headers(token: token),
    );
    _check(res);
    // The HTTP backend tombstones the account server-side and revokes its
    // sessions, so the credential is closed as part of the same request — no
    // separate Auth-deletion step exists on this path.
    return (authDeleted: true, warning: null);
  }

  @override
  Future<Product> saveProduct(String token, Map<String, dynamic> data) async {
    final id = data['id'];
    final url = _uri(id != null ? '/api/products/$id' : '/api/products');
    final res = id != null
        ? await _client.put(
            url,
            headers: _headers(token: token),
            body: jsonEncode(data),
          )
        : await _client.post(
            url,
            headers: _headers(token: token),
            body: jsonEncode(data),
          );
    _check(res);
    final d = await _decode(res);
    return Product.fromJson(d);
  }

  @override
  Future<void> deleteProduct(String token, String id) async {
    final res = await _client.delete(
      _uri('/api/products/$id'),
      headers: _headers(token: token),
    );
    _check(res);
  }

  @override
  Future<void> importProducts(
    String token, {
    required List<Map<String, dynamic>> categories,
    required List<Map<String, dynamic>> products,
  }) async {
    final res = await _client.post(
      _uri('/api/products/import'),
      headers: _headers(token: token),
      body: jsonEncode({'categories': categories, 'products': products}),
    );
    _check(res);
  }

  @override
  Future<CustomerRequest> submitRequest(Map<String, dynamic> payload) async {
    final res = await _client.post(
      _uri('/api/requests'),
      headers: _headers(token: payload['token'] as String?),
      body: jsonEncode(payload),
    );
    _check(res);
    return CustomerRequest.fromJson(await _decode(res));
  }

  @override
  Future<List<CustomerRequest>> fetchRequests(String token) async {
    final res = await _client.get(
      _uri('/api/requests'),
      headers: _headers(token: token),
    );
    _check(res);
    final data = await _decode(res) as List;
    return data.map((e) => CustomerRequest.fromJson(e)).toList();
  }

  @override
  Future<List<CustomerRequest>> fetchMyRequests(String customerId) async {
    final uri = _uri('/api/requests/mine')
        .replace(queryParameters: {'customerId': customerId});
    final res = await _client.get(
      uri,
      headers: {..._headers(), 'X-Customer-Id': customerId},
    );
    _check(res);
    final data = await _decode(res) as List;
    return data.map((e) => CustomerRequest.fromJson(e)).toList();
  }

  @override
  Future<void> acceptDelivery(String requestId, String customerId) async {
    final res = await _client.post(
      _uri('/api/requests/$requestId/confirm'),
      headers: _headers(),
      body: jsonEncode({'customerId': customerId}),
    );
    _check(res);
  }

  @override
  Future<void> rejectDelivery(String requestId, String customerId) async {
    final res = await _client.post(
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
  Future<void> updateRequestStatus(
    String token,
    String id,
    String status,
  ) async {
    final res = await _client.patch(
      _uri('/api/requests/$id'),
      headers: _headers(token: token),
      body: jsonEncode({'status': status}),
    );
    _check(res);
  }

  @override
  Future<void> archiveRequest(
    String token,
    String id, {
    required bool archived,
  }) async {
    final res = await _client.patch(
      _uri('/api/requests/$id'),
      headers: _headers(token: token),
      body: jsonEncode({'archived': archived, '_admin': true}),
    );
    _check(res);
  }

  @override
  Future<void> deleteRequestAdmin(String token, String id) async {
    final res = await _client.delete(
      _uri('/api/requests/$id'),
      headers: _headers(token: token),
      body: jsonEncode({'_admin': true}),
    );
    _check(res);
  }

  @override
  Future<void> markRequestConverted(String token, String id) async {
    final res = await _client.patch(
      _uri('/api/requests/$id'),
      headers: _headers(token: token),
      body: jsonEncode({'converted': true}),
    );
    _check(res);
  }

  @override
  Future<void> archiveMyRequest(
    String requestId,
    String customerId, {
    required bool archived,
  }) async {
    final res = await _client.patch(
      _uri('/api/requests/$requestId'),
      headers: {..._headers(), 'X-Customer-Id': customerId},
      body: jsonEncode({'archived': archived}),
    );
    _check(res);
  }

  @override
  Future<List<Purchase>> fetchPurchases(String token) async {
    final res = await _client.get(
      _uri('/api/purchases'),
      headers: _headers(token: token),
    );
    _check(res);
    final data = await _decode(res) as List;
    return data.map((e) => Purchase.fromJson(e)).toList();
  }

  @override
  Future<List<PriceUpdateNotification>> fetchNotifications() async {
    final res = await _client.get(_uri('/api/notifications'));
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
  Future<void> sendPriceUpdateNotification(
    String token,
    Map<String, dynamic> data,
  ) async {
    final res = await _client.post(
      _uri('/api/notifications'),
      headers: _headers(token: token),
      body: jsonEncode(data),
    );
    _check(res);
  }

  @override
  Future<Purchase> savePurchase(String token, Map<String, dynamic> data) async {
    final res = await _client.post(
      _uri('/api/purchases'),
      headers: _headers(token: token),
      body: jsonEncode(data),
    );
    _check(res);
    return Purchase.fromJson(await _decode(res));
  }

  @override
  Future<Purchase> updatePurchase(
    String token,
    String id,
    Map<String, dynamic> data,
  ) async {
    final res = await _client.patch(
      _uri('/api/purchases/$id'),
      headers: _headers(token: token),
      body: jsonEncode(data),
    );
    _check(res);
    return Purchase.fromJson(await _decode(res));
  }

  @override
  Future<void> deletePurchase(String token, String id) async {
    final res = await _client.delete(
      _uri('/api/purchases/$id'),
      headers: _headers(token: token),
    );
    _check(res);
  }

  @override
  Future<List<Expense>> fetchExpenses(String token) async {
    final res = await _client.get(
      _uri('/api/expenses'),
      headers: _headers(token: token),
    );
    _check(res);
    final data = await _decode(res) as List;
    return data.map((e) => Expense.fromJson(e)).toList();
  }

  @override
  Future<Expense> saveExpense(String token, Map<String, dynamic> data) async {
    final res = await _client.post(
      _uri('/api/expenses'),
      headers: _headers(token: token),
      body: jsonEncode(data),
    );
    _check(res);
    return Expense.fromJson(await _decode(res));
  }

  @override
  Future<Expense> updateExpense(
    String token,
    String id,
    Map<String, dynamic> data,
  ) async {
    final res = await _client.patch(
      _uri('/api/expenses/$id'),
      headers: _headers(token: token),
      body: jsonEncode(data),
    );
    _check(res);
    return Expense.fromJson(await _decode(res));
  }

  @override
  Future<void> deleteExpense(String token, String id) async {
    final res = await _client.delete(
      _uri('/api/expenses/$id'),
      headers: _headers(token: token),
    );
    _check(res);
  }

  @override
  Future<List<JournalEntry>> fetchJournal(String token) async {
    final res = await _client.get(
      _uri('/api/journal'),
      headers: _headers(token: token),
    );
    _check(res);
    final data = await _decode(res) as List;
    return data.map((e) => JournalEntry.fromJson(e)).toList();
  }

  @override
  Future<JournalEntry> saveJournalEntry(
    String token,
    Map<String, dynamic> data,
  ) async {
    final res = await _client.post(
      _uri('/api/journal'),
      headers: _headers(token: token),
      body: jsonEncode(data),
    );
    _check(res);
    return JournalEntry.fromJson(await _decode(res));
  }

  @override
  Future<void> deleteJournalEntry(String token, String id) async {
    final res = await _client.delete(
      _uri('/api/journal/$id'),
      headers: _headers(token: token),
    );
    _check(res);
  }

  @override
  Future<List<Payment>> fetchPayments(String token) async {
    final res = await _client.get(
      _uri('/api/payments'),
      headers: _headers(token: token),
    );
    _check(res);
    final data = await _decode(res) as List;
    return data.map((e) => Payment.fromJson(e)).toList();
  }

  @override
  Future<Payment> savePayment(String token, Map<String, dynamic> data) async {
    final res = await _client.post(
      _uri('/api/payments'),
      headers: _headers(token: token),
      body: jsonEncode(data),
    );
    _check(res);
    return Payment.fromJson(await _decode(res));
  }

  @override
  Future<void> deletePayment(String token, String id) async {
    final res = await _client.delete(
      _uri('/api/payments/$id'),
      headers: _headers(token: token),
    );
    _check(res);
  }
}
