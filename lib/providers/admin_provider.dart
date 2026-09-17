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

  List<JournalEntry> _journal = [];
  List<JournalEntry> get journal => _journal;

  List<Payment> _payments = [];
  List<Payment> get payments => _payments;

  /// Test-only: inject requests without a backend.
  @visibleForTesting
  void seedRequests(List<CustomerRequest> requests) {
    _requests = requests;
    notifyListeners();
  }

  /// Test-only: inject journal entries without a backend.
  @visibleForTesting
  void seedJournal(List<JournalEntry> entries) {
    _journal = entries;
    notifyListeners();
  }

  /// Test-only: inject payments without a backend.
  @visibleForTesting
  void seedPayments(List<Payment> payments) {
    _payments = payments;
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
  String? _lastError;
  String? get lastError => _lastError;

  void _setError(Object e) {
    _lastError = 'Failed to load data. Check your connection and retry.';
    debugPrint('AdminProvider load error: $e');
    notifyListeners();
  }

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
        _requests = _adminVisible(list);
        notifyListeners();
      });
      _lastError = null;
    } catch (e) {
      _setError(e);
    }
  }

  /// Re-runs every admin data load (used by the error banner retry button).
  Future<void> reloadAll(String token) async {
    await Future.wait([
      loadRequests(token),
      loadExpenses(token),
      loadPurchases(token),
      loadJournal(token),
      loadPayments(token),
    ]);
  }

  /// Stops background subscriptions and clears admin-only data (on sign out).
  Future<void> reset() async {
    await _requestSub?.cancel();
    _requestSub = null;
    _requests = [];
    _expenses = [];
    _purchases = [];
    _journal = [];
    _payments = [];
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
      _requests = _adminVisible(await backend.fetchRequests(token));
      _lastError = null;
      notifyListeners();
    } catch (e) {
      _setError(e);
    }
  }

  /// Price quotes reach the team as notifications ONLY — they never appear in
  /// the admin request lists, tracking, customers, or accounting views.
  static List<CustomerRequest> _adminVisible(List<CustomerRequest> list) =>
      list.where((r) => r.type != 'quote').toList();

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
      _lastError = null;
    } catch (e) {
      _setError(e);
    }
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

  Future<void> archiveRequest(String token, String id, {required bool archived}) async {
    await archiveRequests(token, [id], archived: archived);
  }

  Future<void> archiveRequests(String token, List<String> ids, {required bool archived}) async {
    if (ids.isEmpty) {
      await loadRequests(token);
      return;
    }
    try {
      final backend = await BackendManager.resolve();
      for (final id in ids) {
        await backend.archiveRequest(token, id, archived: archived);
        final idx = _requests.indexWhere((r) => r.id == id);
        if (idx >= 0 && _requests[idx].archived != archived) {
          _requests[idx] = _copyWithArchived(_requests[idx], archived);
        }
      }
      notifyListeners();
      _lastError = null;
    } catch (e) {
      _setError(e);
    }
    await loadRequests(token);
  }

  /// Permanent deletion of the given request ids (admin only). Orders are
  /// removed from Firestore and can never be restored.
  Future<void> deleteRequests(String token, List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      final backend = await BackendManager.resolve();
      for (final id in ids) {
        await backend.deleteRequestAdmin(token, id);
      }
      _requests = _requests.where((r) => !ids.contains(r.id)).toList();
      notifyListeners();
      _lastError = null;
    } catch (e) {
      _setError(e);
    }
    await loadRequests(token);
  }

  CustomerRequest _copyWithArchived(CustomerRequest r, bool archived) {
    return CustomerRequest(
      id: r.id,
      orderNo: r.orderNo,
      createdAt: r.createdAt,
      status: r.status,
      customerId: r.customerId,
      company: r.company,
      name: r.name,
      phone: r.phone,
      email: r.email,
      notes: r.notes,
      origin: r.origin,
      destination: r.destination,
      items: r.items,
      type: r.type,
      archived: archived,
      converted: r.converted,
    );
  }

  Future<void> loadExpenses(String token) async {
    try {
      final backend = await BackendManager.resolve();
      _expenses = await backend.fetchExpenses(token);
      _lastError = null;
      notifyListeners();
    } catch (e) {
      _setError(e);
    }
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
      _lastError = null;
      notifyListeners();
    } catch (e) {
      _setError(e);
    }
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

  Future<void> loadJournal(String token) async {
    try {
      final backend = await BackendManager.resolve();
      _journal = await backend.fetchJournal(token);
      _lastError = null;
      notifyListeners();
    } catch (e) {
      _setError(e);
    }
  }

  Future<void> saveJournalEntry(String token, Map<String, dynamic> data) async {
    final backend = await BackendManager.resolve();
    await backend.saveJournalEntry(token, data);
    await loadJournal(token);
  }

  Future<void> deleteJournalEntry(String token, String id) async {
    final backend = await BackendManager.resolve();
    await backend.deleteJournalEntry(token, id);
    await loadJournal(token);
  }

  Future<void> loadPayments(String token) async {
    try {
      final backend = await BackendManager.resolve();
      _payments = await backend.fetchPayments(token);
      _lastError = null;
      notifyListeners();
    } catch (e) {
      _setError(e);
    }
  }

  Future<void> savePayment(String token, Map<String, dynamic> data) async {
    final backend = await BackendManager.resolve();
    await backend.savePayment(token, data);
    await loadPayments(token);
  }

  Future<void> deletePayment(String token, String id) async {
    final backend = await BackendManager.resolve();
    await backend.deletePayment(token, id);
    await loadPayments(token);
  }

  double get totalJournalDebit => _journal.fold(0.0, (n, e) => n + e.totalDebit);

  double get totalPaymentsReceived => _payments.fold(0.0, (n, p) => n + p.amount);

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
