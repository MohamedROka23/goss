import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

import '../models/models.dart';
import 'backend.dart';

/// Cloud backend backed by Firebase Firestore + Authentication.
///
/// Uses collection names: products, requests, purchases, expenses, admins.
/// Admin accounts are created in Firebase Authentication and mirrored in the
/// `admins` collection (doc id = user uid). The email admin@gossts.com signed
/// in with the account UID listed in firestore.rules remains the master admin.
class FirestoreBackend implements GossBackend {
  @override
  BackendMode get mode => BackendMode.firebase;
  @override
  bool get isFirebase => true;

  AdminUser? _lastServerProfile;

  @override
  AdminUser? lastServerProfile() => _lastServerProfile;

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  @override
  Future<List<ProductCategory>> fetchCategories() async {
    final snap = await _db.collection('categories').orderBy('order').get();
    return snap.docs
        .map((d) => ProductCategory.fromJson({...d.data(), 'id': d.id}))
        .toList();
  }

  @override
  Future<void> addCategory(
    String token,
    String id,
    String en,
    String ar,
  ) async {
    await _db.collection('categories').doc(id).set({
      'en': en,
      'ar': ar,
      'order': DateTime.now().millisecondsSinceEpoch,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<List<Product>> fetchProducts() async {
    final snap = await _db.collection('products').orderBy('createdAt').get();
    return snap.docs
        .map((d) => Product.fromJson({...d.data(), 'id': d.id}))
        .toList();
  }

  @override
  Stream<List<Product>> watchProducts() {
    return _db
        .collection('products')
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => Product.fromJson({...d.data(), 'id': d.id}))
              .toList(),
        );
  }

  @override
  Future<Product> saveProduct(String token, Map<String, dynamic> data) async {
    final id = data['id'];
    if (id == null) {
      final doc = _db.collection('products').doc();
      final payload = <String, dynamic>{
        'category': data['category'] ?? 'office',
        'unit': data['unit'] ?? 'unit',
        'price': (data['price'] as num?)?.toDouble() ?? 0,
        'costPrice': (data['costPrice'] as num?)?.toDouble() ?? 0,
        'stock': (data['stock'] as num?)?.toDouble() ?? 0,
        'nameEn': data['nameEn'] ?? '',
        'nameAr': data['nameAr'] ?? '',
        'descEn': data['descEn'] ?? '',
        'descAr': data['descAr'] ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      };
      await doc.set(payload);
      return Product.fromJson({...payload, 'id': doc.id});
    } else {
      final payload = <String, dynamic>{
        'category': data['category'] ?? 'office',
        'unit': data['unit'] ?? 'unit',
        'price': (data['price'] as num?)?.toDouble() ?? 0,
        'costPrice': (data['costPrice'] as num?)?.toDouble() ?? 0,
        'stock': (data['stock'] as num?)?.toDouble() ?? 0,
        'nameEn': data['nameEn'] ?? '',
        'nameAr': data['nameAr'] ?? '',
        'descEn': data['descEn'] ?? '',
        'descAr': data['descAr'] ?? '',
      };
      await _db.collection('products').doc(id).update(payload);
      return Product.fromJson({...payload, 'id': id});
    }
  }

  @override
  Future<void> deleteProduct(String token, String id) async {
    await _db.collection('products').doc(id).delete();
  }

  @override
  Future<void> importProducts(
    String token, {
    required List<Map<String, dynamic>> categories,
    required List<Map<String, dynamic>> products,
  }) async {
    final categoriesRef = _db.collection('categories');
    final productsRef = _db.collection('products');

    for (var i = 0; i < categories.length; i += 490) {
      final batch = _db.batch();
      var order = i;
      for (final c in categories.skip(i).take(490)) {
        batch.set(categoriesRef.doc(c['id'] as String), {
          'en': c['en'] ?? '',
          'ar': c['ar'] ?? '',
          'order': DateTime.now().millisecondsSinceEpoch + order++,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }

    for (var i = 0; i < products.length; i += 490) {
      final batch = _db.batch();
      for (final p in products.skip(i).take(490)) {
        batch.set(productsRef.doc(p['id'] as String), {
          'category': p['category'] ?? 'office',
          'unit': p['unit'] ?? 'unit',
          'price': (p['price'] as num?)?.toDouble() ?? 0,
          'costPrice': (p['costPrice'] as num?)?.toDouble() ?? 0,
          'stock': (p['stock'] as num?)?.toDouble() ?? 0,
          'nameEn': p['nameEn'] ?? '',
          'nameAr': p['nameAr'] ?? '',
          'descEn': p['descEn'] ?? '',
          'descAr': p['descAr'] ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }

  @override
  Future<String> loginAdmin(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = cred.user?.uid ?? 'firebase-admin';
      // A deleted member is fully blocked: after sign-in, confirm the admins
      // document actually exists. If it is gone (or Firestore refuses to let
      // us read it) the auth session is revoked immediately and login fails —
      // a deleted account can never reach the admin panels.
      DocumentSnapshot snap;
      try {
        snap = await _db.collection('admins').doc(uid).get();
      } catch (_) {
        // Read denied or document missing -> not an active team member.
        await _auth.signOut();
        throw Exception('This account has been deactivated');
      }
      if (!snap.exists || snap.data() == null) {
        await _auth.signOut();
        throw Exception('This account has been deactivated');
      }
      final data = snap.data() as Map<String, dynamic>;
      _lastServerProfile =
          AdminUser.fromJson({...data, 'id': uid, 'email': email.trim()});
      return uid;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Login failed');
    }
  }

  /// Signs the current Firebase admin out (used on app logout in Firebase mode).
  static Future<void> signOut() async {
    try {
      final u = FirebaseAuth.instance.currentUser;
      if (u != null) await FirebaseAuth.instance.signOut();
    } catch (_) {}
  }

  @override
  Future<bool> verifyAdminCredentials(String email, String password) async {
    try {
      // Re-auth of the same team member: same identity, tokens refreshed, the
      // app's in-memory session is left untouched on success.
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestPasswordReset(String email) async {
    try {
      // Firebase sends its own recovery e-mail; this mirrors the generic
      // response contract (no account enumeration even for unknown addresses).
      await _auth.sendPasswordResetEmail(email: email.trim());
      return true;
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
    // In Firebase mode the password reset is completed through the e-mailed
    // link (the oobCode flow), not through an in-app token exchange.
    return false;
  }

  @override
  Future<void> registerAdmin(
    String name,
    String email,
    String password,
    String code,
  ) async {
    final regCode = code.trim();
    if (regCode.isEmpty) {
      throw Exception('Admin registration code is required');
    }
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      // Self-registration is provisioning zero: the new team member is created
      // as a bare delegate (no permissions) and a super admin grants access
      // later through the team panel. Rules never trust a public register code.
      final doc = _db.collection('admins').doc(cred.user?.uid ?? '');
      await _writeAdminBootstrapDoc(doc, name, email);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        // The auth account already exists (e.g. from an earlier registration
        // that could not write /admins/{uid} under the old rules). Verify the
        // password, then create the missing admin document for that uid.
        try {
          final cred = await _auth.signInWithEmailAndPassword(
            email: email.trim(),
            password: password,
          );
          final uid = cred.user?.uid ?? '';
          if (uid.isEmpty) throw Exception('Registration failed');
          final doc = _db.collection('admins').doc(uid);
          await _writeAdminBootstrapDoc(doc, name, email);
        } catch (_) {
          throw Exception('An account with this email already exists');
        }
        return;
      }
      throw Exception(e.message ?? 'Registration failed');
    }
  }

  /// Writes the /admins/{uid} document as an UNPRIVILEGED delegate so no one
  /// can self-register admin access (matches the Firestore rules). A super
  /// admin later assigns the role and permissions through the team panel.
  Future<void> _writeAdminBootstrapDoc(
    DocumentReference<Map<String, dynamic>> doc,
    String name,
    String email,
  ) async {
    await doc.set({
      'name': name,
      'email': email.trim(),
      'role': 'delegate',
      'permissions': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> changeAdminPassword(
    String email,
    String oldPassword,
    String newPassword,
  ) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: oldPassword,
      );
      await _auth.currentUser?.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Password change failed');
    }
  }

  @override
  Future<List<AdminUser>> fetchAdmins(String token) async {
    final data = await _db.collection('admins').orderBy('createdAt').get();
    return data.docs
        .map((d) => AdminUser.fromJson({...d.data(), 'id': d.id}))
        .toList();
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
    // Create the new account through the Firebase Auth REST API instead of
    // createUserWithEmailAndPassword. The SDK method signs OUT the current
    // admin and signs in the newly created user, which made the next Firestore
    // write run as the new (not yet admin) user and be denied by the rules.
    // The REST call creates the account server-side without touching the
    // current admin session, so the /admins document can be written by the
    // caller below.
    final apiKey = _auth.app.options.apiKey;
    final resp = await http.post(
      Uri.parse(
        'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey',
      ),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email.trim(),
        'password': password,
        'returnSecureToken': true,
      }),
    );
    Map<String, dynamic> body;
    try {
      body = jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Registration failed');
    }
    if (resp.statusCode != 200 || body['localId'] == null) {
      final raw = (body['error'] as Map<String, dynamic>?)?['message'];
      if (raw == 'EMAIL_EXISTS') {
        throw Exception('An account with this email already exists');
      }
      throw Exception(raw is String ? raw : 'Registration failed');
    }
    final uid = body['localId'] as String? ?? '';
    if (uid.isEmpty) throw Exception('Registration failed');
    await _db.collection('admins').doc(uid).set({
      'name': name,
      'email': email.trim(),
      'role': role,
      'permissions': permissions,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> updateAdminRoleAndPermissions(
    String token,
    String adminId, {
    String? role,
    List<String>? permissions,
  }) async {
    await _db.collection('admins').doc(adminId).update({
      'role': ?role,
      'permissions': ?permissions,
    });
  }

  @override
  Future<void> deleteAdmin(String token, String id) async {
    // 1) Remove the Firestore document (denies rules-level access).
    await _db.collection('admins').doc(id).delete();
    // 2) Best-effort: ask the server to hard-delete the Firebase Auth user
    //    so the email/password can never be used again. Fails silently if
    //    the server is unreachable (defense-in-depth only).
    try {
      final baseUrl = await BackendSettings.loadBaseUrl();
      final res = await http.post(
        Uri.parse('$baseUrl/api/firestore/delete-auth-user'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'uid': id}),
      );
      if (res.statusCode != 200) {
        debugPrint('[deleteAdmin] auth delete returned ${res.statusCode}');
      }
    } catch (_) {}
  }

  @override
  Future<CustomerRequest> submitRequest(Map<String, dynamic> payload) async {
    final doc = _db.collection('requests').doc();
    final request = <String, dynamic>{
      'company': payload['company'] ?? '',
      'name': payload['name'] ?? '',
      'phone': payload['phone'] ?? '',
      'email': payload['email'] ?? '',
      'notes': payload['notes'] ?? '',
      'items': payload['items'] ?? [],
      'status': 'new',
      'customerId': payload['customerId'] ?? '',
      'origin': payload['origin'] ?? '',
      'destination': payload['destination'] ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'uid': _auth.currentUser?.uid ?? '',
    };
    await doc.set(request);
    return CustomerRequest.fromJson({...request, 'id': doc.id});
  }

  @override
  Future<List<CustomerRequest>> fetchRequests(String token) async {
    final snap = await _db
        .collection('requests')
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs
        .map((d) => CustomerRequest.fromJson({...d.data(), 'id': d.id}))
        .toList();
  }

  @override
  Future<List<CustomerRequest>> fetchMyRequests(String customerId) async {
    try {
      final snap = await _db
          .collection('requests')
          .where('customerId', isEqualTo: customerId)
          .orderBy('createdAt', descending: true)
          .get();
      return snap.docs
          .map((d) => CustomerRequest.fromJson({...d.data(), 'id': d.id}))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> acceptDelivery(String requestId, String customerId) async {
    final ref = _db.collection('requests').doc(requestId);
    final snap = await ref.get();
    if (!snap.exists) throw Exception('Request not found');
    if (snap.data()?['customerId'] != customerId) {
      throw Exception('Not your request');
    }
    await ref.update({'status': RequestStatus.confirmed});
  }

  @override
  Future<void> rejectDelivery(String requestId, String customerId) async {
    final ref = _db.collection('requests').doc(requestId);
    final snap = await ref.get();
    if (!snap.exists) throw Exception('Request not found');
    if (snap.data()?['customerId'] != customerId) {
      throw Exception('Not your request');
    }
    await ref.update({'status': 'rejected'});
  }

  @override
  Stream<List<CustomerRequest>> watchRequests({String token = ''}) {
    return _db
        .collection('requests')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => CustomerRequest.fromJson({...d.data(), 'id': d.id}))
              .toList(),
        );
  }

  @override
  Future<void> updateRequestStatus(
    String token,
    String id,
    String status,
  ) async {
    final ref = _db.collection('requests').doc(id);
    final snap = await ref.get();
    final current = snap.data()?['status'] as String?;
    if (current != null &&
        RequestStatus.isFrozen(current) &&
        current != status) {
      throw Exception('Order status is locked by the customer decision');
    }
    await ref.update({'status': status});
  }

  @override
  Future<List<Purchase>> fetchPurchases(String token) async {
    final snap = await _db
        .collection('purchases')
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs
        .map((d) => Purchase.fromJson({...d.data(), 'id': d.id}))
        .toList();
  }

  @override
  Future<List<PriceUpdateNotification>> fetchNotifications() async {
    final snap = await _db
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs
        .map((d) => PriceUpdateNotification.fromJson({...d.data(), 'id': d.id}))
        .toList();
  }

  @override
  Stream<List<PriceUpdateNotification>> watchNotifications() {
    return _db
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (d) =>
                    PriceUpdateNotification.fromJson({...d.data(), 'id': d.id}),
              )
              .toList(),
        );
  }

  @override
  Future<void> sendPriceUpdateNotification(
    String token,
    Map<String, dynamic> data,
  ) async {
    await _db.collection('notifications').add({
      'productId': data['productId'] ?? '',
      'productNameEn': data['productNameEn'] ?? '',
      'productNameAr': data['productNameAr'] ?? '',
      'oldPrice': (data['oldPrice'] as num?)?.toDouble() ?? 0,
      'newPrice': (data['newPrice'] as num?)?.toDouble() ?? 0,
      'unit': data['unit'] ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<Purchase> savePurchase(String token, Map<String, dynamic> data) async {
    final doc = _db.collection('purchases').doc();
    final qty = (data['qty'] as num?)?.toInt() ?? 0;
    final cost = (data['costPrice'] as num?)?.toDouble() ?? 0;
    final vat = (data['vat'] as num?)?.toDouble() ?? 0;
    final payload = <String, dynamic>{
      'date': DateTime.now().toUtc().toIso8601String(),
      'supplier': data['supplier'] ?? '',
      'productId': data['productId'] ?? '',
      'qty': qty,
      'costPrice': cost,
      'vat': vat,
      'total': qty * cost + vat,
      'createdAt': FieldValue.serverTimestamp(),
    };
    await doc.set(payload);
    return Purchase.fromJson({...payload, 'id': doc.id});
  }

  @override
  Future<Purchase> updatePurchase(
    String token,
    String id,
    Map<String, dynamic> data,
  ) async {
    final qty = (data['qty'] as num?)?.toInt() ?? 0;
    final cost = (data['costPrice'] as num?)?.toDouble() ?? 0;
    final vat = (data['vat'] as num?)?.toDouble() ?? 0;
    final payload = <String, dynamic>{
      'supplier': data['supplier'] ?? '',
      'productId': data['productId'] ?? '',
      'qty': qty,
      'costPrice': cost,
      'vat': vat,
      'total': qty * cost + vat,
    };
    await _db.collection('purchases').doc(id).update(payload);
    return Purchase.fromJson({...payload, 'id': id});
  }

  @override
  Future<void> deletePurchase(String token, String id) async {
    await _db.collection('purchases').doc(id).delete();
  }

  @override
  Future<List<Expense>> fetchExpenses(String token) async {
    final snap = await _db
        .collection('expenses')
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs
        .map((d) => Expense.fromJson({...d.data(), 'id': d.id}))
        .toList();
  }

  @override
  Future<Expense> saveExpense(String token, Map<String, dynamic> data) async {
    final doc = _db.collection('expenses').doc();
    final payload = <String, dynamic>{
      'date': data['date'] ?? DateTime.now().toIso8601String(),
      'category': data['category'] ?? 'General',
      'description': data['description'] ?? '',
      'amount': (data['amount'] as num?)?.toDouble() ?? 0,
      'createdAt': FieldValue.serverTimestamp(),
    };
    await doc.set(payload);
    return Expense.fromJson({...payload, 'id': doc.id});
  }

  @override
  Future<Expense> updateExpense(
    String token,
    String id,
    Map<String, dynamic> data,
  ) async {
    final payload = <String, dynamic>{
      if (data.containsKey('date'))
        'date': data['date'] ?? DateTime.now().toIso8601String(),
      if (data.containsKey('category'))
        'category': data['category'] ?? 'General',
      if (data.containsKey('description'))
        'description': data['description'] ?? '',
      if (data.containsKey('amount'))
        'amount': (data['amount'] as num?)?.toDouble() ?? 0,
    };
    await _db.collection('expenses').doc(id).update(payload);
    return Expense.fromJson({...payload, 'id': id});
  }

  @override
  Future<void> deleteExpense(String token, String id) async {
    await _db.collection('expenses').doc(id).delete();
  }

  @override
  Future<List<JournalEntry>> fetchJournal(String token) async {
    final snap = await _db
        .collection('journal')
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs
        .map((d) => JournalEntry.fromJson({...d.data(), 'id': d.id}))
        .toList();
  }

  @override
  Future<JournalEntry> saveJournalEntry(
    String token,
    Map<String, dynamic> data,
  ) async {
    final doc = _db.collection('journal').doc();
    final payload = <String, dynamic>{
      'date': data['date'] ?? DateTime.now().toIso8601String(),
      'memo': data['memo'] ?? '',
      'debits': (data['debits'] as List<dynamic>? ?? [])
          .map((l) => (l as Map).cast<String, dynamic>())
          .toList(),
      'credits': (data['credits'] as List<dynamic>? ?? [])
          .map((l) => (l as Map).cast<String, dynamic>())
          .toList(),
      'createdAt': FieldValue.serverTimestamp(),
    };
    await doc.set(payload);
    return JournalEntry.fromJson({...payload, 'id': doc.id});
  }

  @override
  Future<void> deleteJournalEntry(String token, String id) async {
    await _db.collection('journal').doc(id).delete();
  }

  @override
  Future<List<Payment>> fetchPayments(String token) async {
    final snap = await _db
        .collection('payments')
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs
        .map((d) => Payment.fromJson({...d.data(), 'id': d.id}))
        .toList();
  }

  @override
  Future<Payment> savePayment(String token, Map<String, dynamic> data) async {
    final doc = _db.collection('payments').doc();
    final payload = <String, dynamic>{
      'requestId': data['requestId'] ?? '',
      'customerId': data['customerId'] ?? '',
      'company': data['company'] ?? '',
      'name': data['name'] ?? '',
      'date': data['date'] ?? DateTime.now().toIso8601String(),
      'amount': (data['amount'] as num?)?.toDouble() ?? 0,
      'method': data['method'] ?? 'cash',
      'note': data['note'] ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    };
    await doc.set(payload);
    return Payment.fromJson({...payload, 'id': doc.id});
  }

  @override
  Future<void> deletePayment(String token, String id) async {
    await _db.collection('payments').doc(id).delete();
  }
}
