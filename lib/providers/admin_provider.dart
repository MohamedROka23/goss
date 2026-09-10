import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/backend_manager.dart';

class AdminProvider extends ChangeNotifier {
  List<CustomerRequest> _requests = [];
  List<CustomerRequest> get requests => _requests;

  List<Expense> _expenses = [];
  List<Expense> get expenses => _expenses;

  List<Purchase> _purchases = [];
  List<Purchase> get purchases => _purchases;

  /// Test-only: inject requests without a backend.
  @visibleForTesting
  void seedRequests(List<CustomerRequest> requests) {
    _requests = requests;
    notifyListeners();
  }

  /// Test-only: inject expenses without a backend.
  @visibleForTesting
  void seedExpenses(List<Expense> expenses) {
    _expenses = expenses;
    notifyListeners();
  }

  /// Test-only: inject purchases without a backend.
  @visibleForTesting
  void seedPurchases(List<Purchase> purchases) {
    _purchases = purchases;
    notifyListeners();
  }

  StreamSubscription? _requestSub;
  String _lastSeenRequestAt = '';

  @override
  void dispose() {
    _requestSub?.cancel();
    super.dispose();
  }

  Future<void> startWatchingRequests(String token) async {
    final prefs = await SharedPreferences.getInstance();
    var seen = prefs.getString('goss-admin-request-seen') ?? '';
    if (seen.isEmpty) {
      // First sign-in on this device: treat existing requests as seen so the
      // badge does not start at a misleading "everything is new" count.
      seen = DateTime.now().toUtc().toIso8601String();
      await prefs.setString('goss-admin-request-seen', seen);
    }
    _lastSeenRequestAt = seen;
    try {
      final backend = await BackendManager.resolve();
      await _requestSub?.cancel();
      _requestSub = backend.watchRequests(token: token).listen((list) {
        _requests = list;
        notifyListeners();
      });
    } catch (_) {}
  }

  /// Stops background subscriptions and clears admin-only data (on sign out).
  Future<void> reset() async {
    await _requestSub?.cancel();
    _requestSub = null;
    _requests = [];
    _expenses = [];
    _purchases = [];
    notifyListeners();
  }

  int get unreadRequests {
    final seen = DateTime.tryParse(_lastSeenRequestAt);
    var count = 0;
    for (final r in _requests) {
      final t = DateTime.tryParse(r.createdAt);
      if (t != null && (seen == null || t.isAfter(seen))) count++;
    }
    return count;
  }

  Future<void> markRequestsSeen() async {
    _lastSeenRequestAt = DateTime.now().toUtc().toIso8601String();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('goss-admin-request-seen', _lastSeenRequestAt);
    notifyListeners();
  }

  Future<void> loadRequests(String token) async {
    try {
      final backend = await BackendManager.resolve();
      _requests = await backend.fetchRequests(token);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> updateRequestStatus(String token, String id, String status) async {
    final current = _requests.where((r) => r.id == id);
    if (current.isNotEmpty &&
        RequestStatus.isFrozen(current.first.status) &&
        current.first.status != status) {
      await loadRequests(token);
      return;
    }
    updateRequestStatusLocally(id, status);
    try {
      final backend = await BackendManager.resolve();
      await backend.updateRequestStatus(token, id, status);
    } catch (_) {}
    // Reconcile with the server so the UI never drifts from the stored state
    // when the live stream is slow or unavailable.
    await loadRequests(token);
  }

  /// Optimistically applies a status change so the admin UI responds instantly;
  /// the backend write runs in the background.
  void updateRequestStatusLocally(String id, String status) {
    final idx = _requests.indexWhere((r) => r.id == id);
    if (idx >= 0 && _requests[idx].status != status) {
      _requests[idx].status = status;
      notifyListeners();
    }
  }

  Future<void> loadExpenses(String token) async {
    try {
      final backend = await BackendManager.resolve();
      _expenses = await backend.fetchExpenses(token);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> saveExpense(String token, Map<String, dynamic> data) async {
    final backend = await BackendManager.resolve();
    await backend.saveExpense(token, data);
    await loadExpenses(token);
  }

  Future<void> updateExpense(String token, String id, Map<String, dynamic> data) async {
    final backend = await BackendManager.resolve();
    await backend.updateExpense(token, id, data);
    await loadExpenses(token);
  }

  Future<void> deleteExpense(String token, String id) async {
    final backend = await BackendManager.resolve();
    await backend.deleteExpense(token, id);
    await loadExpenses(token);
  }

  Future<void> loadPurchases(String token) async {
    try {
      final backend = await BackendManager.resolve();
      _purchases = await backend.fetchPurchases(token);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> savePurchase(String token, Map<String, dynamic> data) async {
    final backend = await BackendManager.resolve();
    await backend.savePurchase(token, data);
    await loadPurchases(token);
  }

  Future<void> updatePurchase(String token, String id, Map<String, dynamic> data) async {
    final backend = await BackendManager.resolve();
    await backend.updatePurchase(token, id, data);
    await loadPurchases(token);
  }

  Future<void> deletePurchase(String token, String id) async {
    final backend = await BackendManager.resolve();
    await backend.deletePurchase(token, id);
    await loadPurchases(token);
  }

  double get totalExpenses => _expenses.fold(0, (n, e) => n + e.amount);
  double get totalPurchases => _purchases.fold(0, (n, p) => n + p.total);

  double calculateProfit({
    required List<Product> products,
    required List<MapEntry<CartItem, Product>> items,
    double additionalExpenses = 0,
  }) {
    double sellTotal = 0;
    double costTotal = 0;
    for (var entry in items) {
      sellTotal += entry.value.price * entry.key.qty;
      costTotal += entry.value.costPrice * entry.key.qty;
    }
    return sellTotal - costTotal - additionalExpenses;
  }
}
