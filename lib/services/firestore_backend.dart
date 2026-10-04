import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  /// Generates the next sequential number for a given counter key using a
  /// Firestore transaction. Each operation type uses its own counter doc so
  /// quotes, supply requests, and purchases each start from 1.
  Future<int> _nextSequence(String key) async {
    final ref = _db.collection('counters').doc(key);
    return _db.runTransaction<int>((tx) async {
      final snap = await tx.get(ref);
      final next = ((snap.data()?['value'] as num?) ?? 0).toInt() + 1;
      tx.set(ref, {'value': next});
      return next;
    });
  }

  @override
  Future<List<ProductCategory>> fetchCategories() async {
    final snap = await _db.collection('categories').orderBy('order').get();
    return snap.docs
        .map((d) => ProductCategory.fromJson({...d.data(), 'id': d.id}))
        .toList();
  }

  @override
  Stream<List<ProductCategory>> watchCategories() {
    return _db
        .collection('categories')
        .orderBy('order')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => ProductCategory.fromJson({...d.data(), 'id': d.id}))
              .toList(),
        );
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
    final costs = await _costsFor(snap.docs.map((d) => d.id).toList());
    return snap.docs
        .map(
          (d) => Product.fromJson({
            ...d.data(),
            'id': d.id,
            if (costs.containsKey(d.id)) 'costPrice': costs[d.id],
          }),
        )
        .toList();
  }

  /// Supplier costs live in their own collection: /products is world-readable
  /// (the customer catalogue), and Firestore rules cannot redact a single field
  /// from a granted read. Returns an empty map for anyone without the quotes
  /// permission, which is the correct result for a customer — they never see
  /// cost figures.
  ///
  /// The collection is fetched whole rather than with an `in` query: Firestore
  /// caps a disjunction at 30 values, and each document is a single number, so
  /// a full read is cheaper than paginating the catalogue.
  Future<Map<String, double>> _costsFor(List<String> ids) async {
    if (ids.isEmpty) return {};
    final wanted = ids.toSet();
    final out = <String, double>{};
    try {
      final snaps = await _db.collection('product_costs').get();
      for (final d in snaps.docs) {
        if (!wanted.contains(d.id)) continue;
        final v = (d.data()['costPrice'] as num?)?.toDouble();
        if (v != null) out[d.id] = v;
      }
    } catch (_) {
      // Permission denied (a customer): no costs. Not an error.
    }
    return out;
  }

  @override
  Stream<List<Product>> watchProducts() {
    return _db
        .collection('products')
        .orderBy('createdAt')
        .snapshots()
        .asyncMap((snap) async {
          final ids = snap.docs.map((d) => d.id).toList();
          final costs = await _costsFor(ids);
          return snap.docs
              .map(
                (d) => Product.fromJson({
                  ...d.data(),
                  'id': d.id,
                  if (costs.containsKey(d.id)) 'costPrice': costs[d.id],
                }),
              )
              .toList();
        });
  }

  @override
  Future<Product> saveProduct(String token, Map<String, dynamic> data) async {
    final id = data['id'];
    final cost = (data['costPrice'] as num?)?.toDouble() ?? 0;

    // A product must always belong to a real section. The deployed rules
    // reject a write whose `category` does not exist, which would otherwise
    // surface as an opaque permission error; checking here gives a clear
    // message and stops an orphan being created in the first place.
    final category = (data['category'] as String?)?.trim() ?? '';
    if (category.isEmpty) {
      throw ArgumentError(
        'Pick a section for this product. A product cannot be saved without one.',
      );
    }
    final catDoc = await _db.collection('categories').doc(category).get();
    if (!catDoc.exists) {
      throw ArgumentError(
        'That section no longer exists. Reload the sections and pick another.',
      );
    }

    if (id == null) {
      final doc = _db.collection('products').doc();
      final payload = <String, dynamic>{
        'category': category,
        'unit': data['unit'] ?? 'unit',
        'price': (data['price'] as num?)?.toDouble() ?? 0,
        'stock': (data['stock'] as num?)?.toDouble() ?? 0,
        'nameEn': data['nameEn'] ?? '',
        'nameAr': data['nameAr'] ?? '',
        'descEn': data['descEn'] ?? '',
        'descAr': data['descAr'] ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      };
      await doc.set(payload);
      await _db.collection('product_costs').doc(doc.id).set({'costPrice': cost});
      return Product.fromJson({...payload, 'id': doc.id, 'costPrice': cost});
    } else {
      final payload = <String, dynamic>{
        'category': data['category'] ?? 'office',
        'unit': data['unit'] ?? 'unit',
        'price': (data['price'] as num?)?.toDouble() ?? 0,
        'stock': (data['stock'] as num?)?.toDouble() ?? 0,
        'nameEn': data['nameEn'] ?? '',
        'nameAr': data['nameAr'] ?? '',
        'descEn': data['descEn'] ?? '',
        'descAr': data['descAr'] ?? '',
      };
      await _db.collection('products').doc(id).update(payload);
      await _db.collection('product_costs').doc(id).set({'costPrice': cost});
      return Product.fromJson({...payload, 'id': id, 'costPrice': cost});
    }
  }

  @override
  Future<void> deleteProduct(String token, String id) async {
    await _db.collection('products').doc(id).delete();
    try {
      await _db.collection('product_costs').doc(id).delete();
    } catch (_) {}
  }

  @override
  Future<void> importProducts(
    String token, {
    required List<Map<String, dynamic>> categories,
    required List<Map<String, dynamic>> products,
  }) async {
    final categoriesRef = _db.collection('categories');
    final productsRef = _db.collection('products');
    final costsRef = _db.collection('product_costs');

    // Categories are written first so every product can point at a section that
    // already exists, which is what the rules require.
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

    // Any product whose category is not in this import and not already stored
    // would be orphaned, so it is reported instead of being written.
    final known = <String>{
      ...categories.map((c) => c['id'] as String),
      ...(await categoriesRef.get()).docs.map((d) => d.id),
    };
    final orphans = products
        .where((p) => !known.contains((p['category'] ?? '').toString()))
        .toList();
    if (orphans.isNotEmpty) {
      throw ArgumentError(
        '${orphans.length} product(s) have no valid section and were not '
        'imported. First: ${orphans.first['nameEn'] ?? orphans.first['id']}',
      );
    }

    for (var i = 0; i < products.length; i += 490) {
      final batch = _db.batch();
      for (final p in products.skip(i).take(490)) {
        final id = p['id'] as String;
        batch.set(productsRef.doc(id), {
          'category': p['category'] ?? '',
          'unit': p['unit'] ?? 'unit',
          'price': (p['price'] as num?)?.toDouble() ?? 0,
          'stock': (p['stock'] as num?)?.toDouble() ?? 0,
          'nameEn': p['nameEn'] ?? '',
          'nameAr': p['nameAr'] ?? '',
          'descEn': p['descEn'] ?? '',
          'descAr': p['descAr'] ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        });
        batch.set(costsRef.doc(id), {
          'costPrice': (p['costPrice'] as num?)?.toDouble() ?? 0,
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
      // A removed member is fully blocked. After sign-in we re-read the admins
      // document, which is the single source of truth for "is still on the
      // team". Three ways to fail closed:
      //   - the read is denied or the document is gone,
      //   - the document exists but is a `revoked` tombstone (removed member),
      //   - the document exists but carries no active role.
      // In every case the auth session is revoked immediately so a removed
      // account can never hold a signed-in session, not even briefly.
      DocumentSnapshot snap;
      try {
        snap = await _db.collection('admins').doc(uid).get();
      } catch (_) {
        // Read denied or document missing -> not an active team member.
        await _auth.signOut();
        throw Exception('This account has been deactivated');
      }
      final data = snap.data();
      if (!snap.exists || data == null) {
        await _auth.signOut();
        throw Exception('This account has been deactivated');
      }
      final role = (data as Map<String, dynamic>)['role']?.toString() ?? '';
      if (!AdminRole.active.contains(role)) {
        await _auth.signOut();
        throw Exception('This account has been deactivated');
      }
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

  /// Confirms an e-mail/password pair belongs to a CURRENT team member.
  ///
  /// This is the credential check behind quick sign-in and the password-change
  /// sheet, so it must apply exactly the same membership test as
  /// [loginAdmin] — otherwise a removed member keeps a working credential on a
  /// device that never re-runs the full sign-in path.
  @override
  Future<bool> verifyAdminCredentials(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = cred.user?.uid;
      if (uid == null) return false;
      final snap = await _db.collection('admins').doc(uid).get();
      final data = snap.data();
      if (!snap.exists || data == null) {
        await _auth.signOut();
        return false;
      }
      final role = data['role']?.toString() ?? '';
      if (!AdminRole.active.contains(role)) {
        await _auth.signOut();
        return false;
      }
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
        .where((u) => AdminRole.active.contains(u.role))
        .toList();
  }

  @override
  Stream<AdminUser?> watchOwnAdmin(String uid) {
    return _db.collection('admins').doc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return AdminUser.fromJson({...snap.data()!, 'id': snap.id});
    });
  }

  @override
  Stream<List<AdminUser>> watchAdmins({String token = ''}) {
    return _db
        .collection('admins')
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => AdminUser.fromJson({...d.data(), 'id': d.id}))
              .where((u) => AdminRole.active.contains(u.role))
              .toList(),
        );
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

  /// Removes a member from the team.
  ///
  /// Two layers, and BOTH must land for the account to be truly gone:
  ///
  /// 1. The Firestore document is rewritten into a `revoked` tombstone rather
  ///    than deleted. That single write strips every permission immediately
  ///    (the rules grant nothing to a role outside admin/super), lets the
  ///    removed member's own still-signed-in device detect the change and sign
  ///    itself out, and keeps the e-mail reserved so the address cannot be
  ///    re-registered by anyone else. It is a one-way door: no rule can restore
  ///    it, so only a fresh provisioning can bring that address back.
  ///
  /// 2. Best-effort: ask the server to disable AND delete the Firebase Auth
  ///    record, so the raw e-mail/password stops working even against a
  ///    different client. This depends on the server being reachable, so step 1
  ///    carries the guarantee on its own; the returned warning tells the caller
  ///    when the credential may still be live.
  @override
  Future<({bool authDeleted, String? warning})> deleteAdmin(
    String token,
    String id,
  ) async {
    // 1) Revoke: role outside every allow-list + empty permission list.
    final ref = _db.collection('admins').doc(id);
    final snap = await ref.get();
    if (snap.exists) {
      await ref.update({
        'role': AdminRole.revoked,
        'permissions': <String>[],
        'revokedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await ref.set({
        'role': AdminRole.revoked,
        'permissions': <String>[],
        'revokedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    // 2) Best-effort hard-delete of the Firebase Auth user.
    var authDeleted = true;
    String? warning;
    try {
      final baseUrl = await BackendSettings.loadBaseUrl();
      final res = await http.post(
        Uri.parse('$baseUrl/api/firestore/delete-auth-user'),
        headers: {
          'Content-Type': 'application/json',
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'uid': id}),
      );
      if (res.statusCode != 200) {
        authDeleted = false;
        warning =
            'تم إلغاء الوصول، لكن تعطيل بيانات الدخول لم يكتمل (السيرفر ${res.statusCode}). '
            'الحساب لن يستطيع الوصول لأي لوحة.';
      }
    } catch (_) {
      authDeleted = false;
      warning =
          'تم إلغاء الوصول، لكن تعطيل بيانات الدخول لم يكتمل (السيرفر غير متاح). '
          'الحساب لن يستطيع الوصول لأي لوحة.';
    }
    return (authDeleted: authDeleted, warning: warning);
  }

  @override
  Future<CustomerRequest> submitRequest(Map<String, dynamic> payload) async {
    final doc = _db.collection('requests').doc();
    final type = payload['type'] ?? 'supply';
    final orderNo = await _nextSequence(type == 'quote' ? 'quote' : 'supply');
    final request = <String, dynamic>{
      'company': payload['company'] ?? '',
      'name': payload['name'] ?? '',
      'phone': payload['phone'] ?? '',
      'email': payload['email'] ?? '',
      'notes': payload['notes'] ?? '',
      'items': payload['items'] ?? [],
      'status': 'new',
      'type': type,
      'customerId': payload['customerId'] ?? '',
      'origin': payload['origin'] ?? '',
      'destination': payload['destination'] ?? '',
      'orderNo': orderNo,
      'vat': payload['vat'] ?? false,
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
  Stream<List<CustomerRequest>> watchMyRequests(String customerId) {
    return _db
        .collection('requests')
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => CustomerRequest.fromJson({...d.data(), 'id': d.id}))
              .toList(),
        );
  }

  @override
  Future<void> acceptDelivery(String requestId, String customerId) async {
    final ref = _db.collection('requests').doc(requestId);
    final snap = await ref.get();
    if (!snap.exists) throw Exception('Request not found');
    if (snap.data()?['customerId'] != customerId) {
      throw Exception('Not your request');
    }
    // Confirmed delivery is a terminal state: archive it immediately.
    await ref.update({'status': RequestStatus.confirmed, 'archived': true});
  }

  @override
  Future<void> rejectDelivery(String requestId, String customerId) async {
    final ref = _db.collection('requests').doc(requestId);
    final snap = await ref.get();
    if (!snap.exists) throw Exception('Request not found');
    if (snap.data()?['customerId'] != customerId) {
      throw Exception('Not your request');
    }
    await ref.update({'status': 'rejected', 'archived': true});
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
    // A completed/terminal state is archived immediately so it never stays in
    // the active lists of either the admin or the customer.
    final updates = <String, dynamic>{'status': status};
    if (RequestStatus.isDone(status) && snap.data()?['archived'] != true) {
      updates['archived'] = true;
    }
    await ref.update(updates);
  }

  @override
  Future<void> archiveRequest(
    String token,
    String id, {
    required bool archived,
  }) async {
    final ref = _db.collection('requests').doc(id);
    final snap = await ref.get();
    if (!snap.exists) throw Exception('Request not found');
    await ref.update({'archived': archived});
  }

  @override
  Future<void> deleteRequestAdmin(String token, String id) async {
    await _db.collection('requests').doc(id).delete();
  }

  @override
  Future<void> markRequestConverted(String token, String id) async {
    final ref = _db.collection('requests').doc(id);
    final snap = await ref.get();
    if (!snap.exists) throw Exception('Request not found');
    await ref.update({'converted': true});
  }

  @override
  Future<void> archiveMyRequest(
    String requestId,
    String customerId, {
    required bool archived,
  }) async {
    final ref = _db.collection('requests').doc(requestId);
    final snap = await ref.get();
    if (!snap.exists) throw Exception('Request not found');
    if (snap.data()?['customerId'] != customerId) {
      throw Exception('Not your request');
    }
    await ref.update({'archived': archived});
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
  Stream<List<Purchase>> watchPurchases({String token = ''}) {
    return _db
        .collection('purchases')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => Purchase.fromJson({...d.data(), 'id': d.id}))
              .toList(),
        );
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
    final orderNo = await _nextSequence('purchase');
    final payload = <String, dynamic>{
      'orderNo': orderNo,
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
  Stream<List<Expense>> watchExpenses({String token = ''}) {
    return _db
        .collection('expenses')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => Expense.fromJson({...d.data(), 'id': d.id}))
              .toList(),
        );
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
  Stream<List<JournalEntry>> watchJournal({String token = ''}) {
    return _db
        .collection('journal')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => JournalEntry.fromJson({...d.data(), 'id': d.id}))
              .toList(),
        );
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
  Stream<List<Payment>> watchPayments({String token = ''}) {
    return _db
        .collection('payments')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => Payment.fromJson({...d.data(), 'id': d.id}))
              .toList(),
        );
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
